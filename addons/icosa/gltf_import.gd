@tool
class_name IcosaGLTF
extends GLTFDocumentExtension

var has_google_extensions = false
var material_cache = {}
var brush_materials = {}
var name_mapping = {}

## fixes a critical error that won't open certain gltf from icosa.
func _import_preflight(gltf_state: GLTFState, extensions: PackedStringArray) -> Error:
## written by aaronfranke. thank you!
	# HACK: This is workaround for an issue fixed in Godot 4.5.
	var gltf_json_variant := gltf_state.json
	if not (gltf_json_variant is Dictionary):
		return OK
	var gltf_json: Dictionary = gltf_json_variant

	# Clear texture/image references early to prevent loading errors (we'll use brush materials instead)
	if gltf_json.has("images"):
		gltf_json["images"] = []
	if gltf_json.has("textures"):
		gltf_json["textures"] = []
	# Also clear material texture references
	if gltf_json.has("materials"):
		for material in gltf_json["materials"]:
			if not material is Dictionary:
				continue
			if material.has("pbrMetallicRoughness"):
				var pbr = material["pbrMetallicRoughness"]
				pbr.erase("baseColorTexture")
				pbr.erase("metallicRoughnessTexture")
			material.erase("normalTexture")
			material.erase("occlusionTexture")
			material.erase("emissiveTexture")
			# Clear Google-specific extensions
			if material.has("extensions"):
				material["extensions"].erase("GOOGLE_tilt_brush_material")

	if not gltf_json.has("bufferViews"):
		return OK
	var buffer_views = gltf_json["bufferViews"]
	if not buffer_views is Array:
		return OK
	for i in range(buffer_views.size()):
		var buffer_view_dict: Dictionary = buffer_views[i]
		if not buffer_view_dict.has("byteStride"):
			continue
		var stride: int = buffer_view_dict["byteStride"]
		if stride < 4 or stride > 252 or stride % 4 != 0:
			## error msg hidden from the user.
			#printerr("glTF import: Invalid byte stride " + str(stride) + " for buffer view at index " + str(i) + " while importing file '" + gltf_state.filename + "'. If defined, byte stride must be a multiple of 4 and between 4 and 252.")
			buffer_view_dict.erase("byteStride")

	## check for uneeded lights and cameras.
	if "GOOGLE_camera_settings" in extensions or "GOOGLE_backgrounds" in extensions:
		has_google_extensions = true
	
	
	
	
	
	## Map custom attributes to CUSTOM0-3 for shader access
	_map_custom_attributes_to_custom_slots(gltf_json)

	## aaronfranke patch #2, removing meshes (only for specific Obj2Gltf files)
	var asset = gltf_json.get("asset")
	if asset is Dictionary and asset.get("generator") == "Obj2GltfConverter" or asset.get("generator") == "glTF 1-to-2 Upgrader for Google Blocks":
		var meshes = gltf_json.get("meshes")
		if meshes is Array and meshes.size() == 1:
			if extensions.has("GOOGLE_backgrounds") and extensions.has("GOOGLE_camera_settings"):
				var ext_used: Array = gltf_json["extensionsUsed"]
				ext_used.append("GODOT_single_root")

	return OK

func _import_post_parse(gltf_state: GLTFState) -> Error:
	# Only do the node replacement for specific Obj2GltfConverter files
	var gltf_json_variant := gltf_state.json
	if not (gltf_json_variant is Dictionary):
		return OK
	var gltf_json: Dictionary = gltf_json_variant

	var asset = gltf_json.get("asset")
	if asset is Dictionary and asset.get("generator") == "Obj2GltfConverter":
		var mesh_node := GLTFNode.new()
		mesh_node.original_name = gltf_state.filename
		mesh_node.resource_name = gltf_state.filename
		mesh_node.mesh = 0
		var nodes: Array[GLTFNode] = [mesh_node]
		gltf_state.set_nodes(nodes)
		gltf_state.root_nodes = PackedInt32Array([0])

	# Load brush materials and name mapping if not already loaded
	if brush_materials.is_empty():
		_load_brush_materials()
	if name_mapping.is_empty():
		_load_name_mapping()

	# Replace materials with brush materials if matches found
	_replace_materials_with_brush_materials(gltf_state)

	return OK

func _load_brush_materials():
	# Scan the brush materials directory
	_scan_directory_for_materials("res://addons/icosa/brush_materials/")

func _scan_directory_for_materials(dir_path: String):
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return

	# Track if we've found a material in this directory
	var found_material_in_dir = false

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = dir_path + file_name

		if dir.current_is_dir():
			# Recursively scan subdirectories
			_scan_directory_for_materials(full_path + "/")
		elif file_name.ends_with(".tres") and not found_material_in_dir:
			# Use the .tres filename (without extension) as the key
			var material_name = file_name.get_basename()
			brush_materials[material_name] = full_path
			found_material_in_dir = true

		file_name = dir.get_next()

func _load_name_mapping():
	var mapping_script = load("res://addons/icosa/name_mapping.gd")
	if mapping_script != null:
		var mapping_instance = mapping_script.new()
		name_mapping = mapping_instance.name_mapping
		mapping_instance.free()

func _replace_materials_with_brush_materials(gltf_state: GLTFState):
	# Get all materials from the GLTF
	var materials = gltf_state.get_materials()

	for i in range(materials.size()):
		var original_material = materials[i]
		var material_name = original_material.resource_name

		# Skip if no resource name
		if material_name.is_empty():
			continue

		# Check for exact name match first
		var brush_material = _find_matching_brush_material(material_name)

		if brush_material != null:
			# Replace the material in the array
			materials[i] = brush_material

	# Set the modified materials array back
	gltf_state.set_materials(materials)

func _import_post(gltf_state: GLTFState, root: Node) -> Error:
	# Apply materials to all ImporterMeshInstance3D nodes
	_apply_materials_to_importer_scene(root, gltf_state)
	return OK

func _apply_materials_to_importer_scene(node: Node, gltf_state: GLTFState):
	if node.get_class() == "ImporterMeshInstance3D":
		var importer_mesh = node.get("mesh")
		if importer_mesh != null:
			# Apply materials to each surface
			for i in range(importer_mesh.get_surface_count()):
				var current_mat = importer_mesh.get_surface_material(i)
				if current_mat != null and current_mat.resource_name != "":
					# Find this material in our replaced materials array
					var brush_material = _find_matching_brush_material(current_mat.resource_name)
					if brush_material != null:
						importer_mesh.set_surface_material(i, brush_material)

	# Recursively process children
	for child in node.get_children():
		_apply_materials_to_importer_scene(child, gltf_state)

func _map_custom_attributes_to_custom_slots(gltf_json: Dictionary):
	# Process each mesh's primitives
	if not gltf_json.has("meshes"):
		return

	var meshes = gltf_json["meshes"]
	for mesh in meshes:
		if not mesh is Dictionary:
			continue

		var primitives = mesh.get("primitives", [])
		for primitive in primitives:
			if not primitive is Dictionary:
				continue

			var attributes = primitive.get("attributes", {})
			if not attributes is Dictionary:
				continue

			# Track which CUSTOM slots we've used (0-3)
			var custom_slot = 0
			var attrs_to_rename = {}

			# Find all custom attributes (those starting with underscore)
			for attr_name in attributes.keys():
				if attr_name.begins_with("_") and custom_slot < 4:
					var new_name = "_CUSTOM" + str(custom_slot)
					attrs_to_rename[attr_name] = new_name
					custom_slot += 1
					push_warning("Mapping custom attribute ", attr_name, " to ", new_name, " (will be CUSTOM", str(custom_slot - 1), " in shader)")

			# Perform the renaming
			for old_name in attrs_to_rename.keys():
				var new_name = attrs_to_rename[old_name]
				attributes[new_name] = attributes[old_name]
				attributes.erase(old_name)

func _find_matching_brush_material(material_name: String) -> Material:
	var original_name = material_name

	# Handle "material_<GUID>" format - look up GUID in name mapping
	if material_name.begins_with("material_"):
		# Distinguish "material_<name>-<GUID>" from "material_<GUID>"
		# Count dashes to help identify the GUID
		var rest = material_name.substr(9)
		var dash_count = rest.count("-")
		if dash_count >= 4:
			# Likely a GUID (with or without a name prefix)
			var dash_index = rest.find("-")
			var guid = rest.substr(dash_index + 1)
		else:
			# Handle unexpected format
			var guid = rest
	# Remove other prefixes if present
	elif material_name.begins_with("brush_"):
		material_name = material_name.substr(6, material_name.length() - 6)
	elif material_name.begins_with("ob-"):
		material_name = material_name.substr(3, material_name.length() - 3)

	# Check cache first (use original name as cache key to avoid conflicts)
	if material_cache.has(original_name):
		return material_cache[original_name]

	# Try exact name matching
	if brush_materials.has(material_name):
		var material_path = brush_materials[material_name]
		var loaded_material = load(material_path) as Material
		if loaded_material != null:
			material_cache[original_name] = loaded_material
			return loaded_material

	# Try case-insensitive matching
	var material_name_lower = material_name.to_lower()
	for brush_name in brush_materials.keys():
		if brush_name.to_lower() == material_name_lower:
			var material_path = brush_materials[brush_name]
			var loaded_material = load(material_path) as Material
			if loaded_material != null:
				material_cache[original_name] = loaded_material
				return loaded_material

	# No match found
	push_warning("No brush material found for: '" + original_name + "' (mapped to: '" + material_name + "')")
	material_cache[original_name] = null
	return null
