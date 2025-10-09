@tool
class_name IcosaGLTF
extends GLTFDocumentExtension

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

	## aaronfranke patch #2, removing meshes (only for specific Obj2Gltf files)
	var asset = gltf_json.get("asset")
	if asset is Dictionary and asset.get("generator") == "Obj2GltfConverter" or asset.get("generator") == "glTF 1-to-2 Upgrader for Google Blocks":
		var meshes = gltf_json.get("meshes")
		if meshes is Array and meshes.size() == 1:
			if extensions.has("GOOGLE_backgrounds") and extensions.has("GOOGLE_camera_settings"):
				var ext_used: Array = gltf_json["extensionsUsed"]
				ext_used.append("GODOT_single_root")

	if gltf_json.get("asset", {}).get("generator", "").find("Tilt Brush") != -1:
		# Tilt Brush exports may have embedded images/textures we don't want to load
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

		## Map custom attributes to standard GLTF attributes that Godot recognizes
		_map_custom_attributes_to_standard_slots(gltf_json)

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

	# Add vertex IDs to particle brush meshes BEFORE final mesh processing
	_add_vertex_ids_to_particle_brushes(gltf_state)

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

func _add_vertex_ids_to_particle_brushes(gltf_state: GLTFState):
	var meshes = gltf_state.get_meshes()
	var materials = gltf_state.get_materials()



	for mesh_idx in range(meshes.size()):
		var mesh = meshes[mesh_idx]
		var importer_mesh = mesh.mesh

		# Check if this is a particle brush by examining material names
		var is_particle_brush = false
		for surface_idx in range(importer_mesh.get_surface_count()):
			var mat = importer_mesh.get_surface_material(surface_idx)
			if mat != null:
				var mat_name = mat.resource_name

				if (mat_name.contains("Smoke") or
					mat_name.contains("Bubbles") or
					mat_name.contains("Dots") or
					mat_name.contains("Snow") or
					mat_name.contains("Stars") or
					mat_name.contains("Embers")):
					is_particle_brush = true
					break

		if not is_particle_brush:
			continue

		# Collect all surface data with vertex IDs added
		var surfaces = []
		for surface_idx in range(importer_mesh.get_surface_count()):
			var arrays = importer_mesh.get_surface_arrays(surface_idx)
			var vertex_count = arrays[Mesh.ARRAY_VERTEX].size()

			# Create vertex data buffer: CUSTOM0 stores vertex ID and particle center
			var centers = arrays[Mesh.ARRAY_NORMAL]
			if centers == null:
				centers = PackedVector3Array()

			# Remap TANGENT if it contains VEC4 TEXCOORD data (u, v, rotation, timestamp)
			# This happens when we created a VEC4 accessor from VEC4 TEXCOORD_0
			var tangents = arrays[Mesh.ARRAY_TANGENT]
			if tangents != null and tangents.size() >= 4:
				# Check if this looks like remapped VEC4 TEXCOORD data
				# (first two components in 0-1 range, indicating UV coordinates)
				var tx = tangents[0]
				var ty = tangents[1]
				if tx >= 0.0 and tx <= 1.0 and ty >= 0.0 and ty <= 1.0:
					# Remap: extract rotation from .z, set x/y to 0, w to 1
					var new_tangents = PackedFloat32Array()
					new_tangents.resize(vertex_count * 4)
					for i in range(vertex_count):
						var base = i * 4
						new_tangents[base + 0] = 0.0
						new_tangents[base + 1] = 0.0
						new_tangents[base + 2] = tangents[base + 2]  # rotation from .z
						new_tangents[base + 3] = 1.0
					arrays[Mesh.ARRAY_TANGENT] = new_tangents

			var custom0 = PackedFloat32Array()
			custom0.resize(vertex_count * 4)

			for i in range(vertex_count):
				var base := i * 4
				custom0[base] = float(i)
				var center := Vector3.ZERO
				if centers is PackedVector3Array and i < centers.size():
					center = centers[i]
				custom0[base + 1] = center.x
				custom0[base + 2] = center.y
				custom0[base + 3] = center.z

			# Remove particle centers from NORMAL slot so Godot doesn't treat them as normals
			arrays[Mesh.ARRAY_NORMAL] = null

			# Set CUSTOM0 data
			arrays[Mesh.ARRAY_CUSTOM0] = custom0

			# Store surface data
			surfaces.append({
				"primitive_type": importer_mesh.get_surface_primitive_type(surface_idx),
				"arrays": arrays,
				"material": importer_mesh.get_surface_material(surface_idx),
				"name": importer_mesh.get_surface_name(surface_idx)
			})

		# Create a new ImporterMesh with CUSTOM0 data
		var new_mesh = ImporterMesh.new()

		for i in range(surfaces.size()):
			var surface_data = surfaces[i]

			# Get the correct brush material for this surface
			var original_material = surface_data["material"]
			var material_name = original_material.resource_name if original_material else ""
			var brush_material = _find_matching_brush_material(material_name)
			var final_material = brush_material if brush_material != null else original_material


			# Set array format - build flags based on which arrays exist
			var format_flags = 0
			var arrays = surface_data["arrays"]
			if arrays[Mesh.ARRAY_VERTEX] != null:
				format_flags |= Mesh.ARRAY_FORMAT_VERTEX
			if arrays[Mesh.ARRAY_NORMAL] != null:
				format_flags |= Mesh.ARRAY_FORMAT_NORMAL
			if arrays[Mesh.ARRAY_TANGENT] != null:
				format_flags |= Mesh.ARRAY_FORMAT_TANGENT
			if arrays[Mesh.ARRAY_COLOR] != null:
				format_flags |= Mesh.ARRAY_FORMAT_COLOR
			if arrays[Mesh.ARRAY_TEX_UV] != null:
				format_flags |= Mesh.ARRAY_FORMAT_TEX_UV
			if arrays[Mesh.ARRAY_TEX_UV2] != null:
				format_flags |= Mesh.ARRAY_FORMAT_TEX_UV2
			if arrays[Mesh.ARRAY_INDEX] != null:
				format_flags |= Mesh.ARRAY_FORMAT_INDEX
			# Add CUSTOM0 with RGBA float format (vertex ID + center)
			if arrays[Mesh.ARRAY_CUSTOM0] != null:
				format_flags |= (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)

			new_mesh.add_surface(
				surface_data["primitive_type"],
				arrays,
				[],
				{},
				final_material,
				surface_data["name"],
				format_flags
			)

			# Verify CUSTOM0 was added
			var surface_idx = new_mesh.get_surface_count() - 1

			var check_arrays = new_mesh.get_surface_arrays(surface_idx)
			var check_custom0 = check_arrays[Mesh.ARRAY_CUSTOM0]

		# Replace the old mesh with the new one
		mesh.mesh = new_mesh


		# Final verification - check if mesh has valid data
		for i in range(new_mesh.get_surface_count()):
			var final_arrays = new_mesh.get_surface_arrays(i)
			var verts = final_arrays[Mesh.ARRAY_VERTEX]
			var indices = final_arrays[Mesh.ARRAY_INDEX]
			var custom0 = final_arrays[Mesh.ARRAY_CUSTOM0]


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

func _split_vec4_texcoord_accessor(gltf_json: Dictionary, vec4_accessor: Dictionary) -> Array:
	# Split a VEC4 TEXCOORD_0 accessor into:
	# [0] = VEC2 accessor for UV coordinates (first 2 components)
	# [1] = VEC4 accessor for all 4 components (for tangent/rotation data)

	# Create VEC2 accessor for UV coordinates
	var uv_accessor = vec4_accessor.duplicate()
	uv_accessor["type"] = "VEC2"

	# Update min/max if present (take only first 2 components)
	if uv_accessor.has("min") and uv_accessor["min"] is Array and uv_accessor["min"].size() >= 2:
		uv_accessor["min"] = [uv_accessor["min"][0], uv_accessor["min"][1]]
	if uv_accessor.has("max") and uv_accessor["max"] is Array and uv_accessor["max"].size() >= 2:
		uv_accessor["max"] = [uv_accessor["max"][0], uv_accessor["max"][1]]

	# Create VEC4 accessor for tangent data (keeps all 4 components)
	var tangent_accessor = vec4_accessor.duplicate()

	return [uv_accessor, tangent_accessor]

func _map_custom_attributes_to_standard_slots(gltf_json: Dictionary):
	# Map Tilt Brush custom attributes to standard GLTF attributes per-brush
	if not gltf_json.has("meshes"):
		return

	# Get materials array for brush name lookup
	var materials = gltf_json.get("materials", [])

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

			# Get material name to determine brush type
			var material_name = "unknown"
			if primitive.has("material"):
				var mat_index = primitive["material"]
				if mat_index < materials.size() and materials[mat_index] is Dictionary:
					material_name = materials[mat_index].get("name", "")

			var attrs_to_rename = {}

			# PARTICLE BRUSH MAPPING (Smoke, Bubbles, Dots, Snow, Stars)
			# These brushes have: POSITION, COLOR_0, TEXCOORD_0, _TB_TIMESTAMP, _TB_UNITY_NORMAL, _TB_UNITY_TEXCOORD_0
			# They do NOT have: NORMAL or TANGENT - we can use these!
			var is_particle_brush = (material_name.contains("Smoke") or
									 material_name.contains("Bubbles") or
									 material_name.contains("Dots") or
									 material_name.contains("Snow") or
									 material_name.contains("Stars") or
									 material_name.contains("Embers"))

			if is_particle_brush:
				# _TB_UNITY_NORMAL (particle center, VEC3) → NORMAL
				if attributes.has("_TB_UNITY_NORMAL"):
					attrs_to_rename["_TB_UNITY_NORMAL"] = "NORMAL"

				# _TB_UNITY_TEXCOORD_0 (has rotation in .z) → TANGENT
				if attributes.has("_TB_UNITY_TEXCOORD_0"):
					attrs_to_rename["_TB_UNITY_TEXCOORD_0"] = "TANGENT"
				# SPECIAL CASE: Some files have rotation in TEXCOORD_0.z (VEC4 instead of VEC2)
				# Fix by creating new accessors for VEC2 UV and VEC4 tangent data
				elif attributes.has("TEXCOORD_0"):
					var texcoord_idx = attributes["TEXCOORD_0"]
					var accessors = gltf_json.get("accessors", [])
					if texcoord_idx < accessors.size():
						var accessor = accessors[texcoord_idx]
						if accessor.get("type") == "VEC4":
							# Create new accessors for VEC2 UV and VEC4 tangent
							var new_accessors = _split_vec4_texcoord_accessor(gltf_json, accessor)
							if new_accessors.size() == 2:
								# Add new accessors to the array
								var uv_accessor_idx = accessors.size()
								var tangent_accessor_idx = accessors.size() + 1
								accessors.append(new_accessors[0])  # VEC2 for UV
								accessors.append(new_accessors[1])  # VEC4 for tangent

								# Update attribute references
								attributes["TEXCOORD_0"] = uv_accessor_idx
								attributes["TANGENT"] = tangent_accessor_idx

				# _TB_TIMESTAMP → TEXCOORD_1 (UV2)
				if attributes.has("_TB_TIMESTAMP"):
					attrs_to_rename["_TB_TIMESTAMP"] = "TEXCOORD_1"

			# Perform the renaming
			for old_name in attrs_to_rename.keys():
				var new_name = attrs_to_rename[old_name]
				attributes[new_name] = attributes[old_name]
				attributes.erase(old_name)

func _find_matching_brush_material(material_name: String) -> Material:
	var original_name = material_name

	# Handle "material_<GUID>" format - look up GUID in name mapping
	if material_name.begins_with("material_"):
		# Extract GUID from either "material_<GUID>" or "material_<name>-<GUID>"
		# GUIDs are in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (4 dashes)
		var rest = material_name.substr(9)  # Everything after "material_"
		var guid = ""
		var parts = rest.split("-")
		if parts.size() >= 5:
			guid = "-".join(parts.slice(parts.size() - 5, parts.size()))

		if guid != "":
			material_name = name_mapping.get(guid, material_name)
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
