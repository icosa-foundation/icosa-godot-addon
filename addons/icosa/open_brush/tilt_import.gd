@tool
class_name IcosaTiltImport
extends RefCounted

## Handles all Tilt Brush / Open Brush-specific GLTF import logic.
## Called from IcosaGLTF (gltf_import.gd) when the asset_type is TILT.

var material_cache: Dictionary = {}
var brush_materials: Dictionary = {}
var name_mapping: Dictionary = {}

# Default Tilt Brush light rig used when the file doesn't specify lights.
const DEFAULT_LIGHT_0_DIRECTION := Vector3(0.0, -0.707, 0.707)  # warm key, upper-right
const DEFAULT_LIGHT_0_COLOR := Color(1.0, 0.99, 0.95, 1.0)
const DEFAULT_LIGHT_1_DIRECTION := Vector3(0.0, 0.5, -0.866)    # cool fill, lower-left
const DEFAULT_LIGHT_1_COLOR := Color(0.35, 0.4, 0.55, 1.0)
const DEFAULT_AMBIENT_COLOR := Color(0.2, 0.2, 0.2, 1.0)


func setup() -> void:
	if brush_materials.is_empty():
		_load_brush_materials()
	if name_mapping.is_empty():
		_load_name_mapping()


# ---------------------------------------------------------------------------
# Preflight: called from IcosaGLTF._import_preflight for TILT files
# ---------------------------------------------------------------------------

func preflight(gltf_json: Dictionary) -> void:
	# Clear embedded textures/images — Tilt Brush files embed textures we don't want;
	# brush materials supply their own textures.
	if gltf_json.has("images"):
		gltf_json["images"] = []
	if gltf_json.has("textures"):
		gltf_json["textures"] = []

	# Clear material texture references so Godot doesn't try to load them.
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
			if material.has("extensions"):
				material["extensions"].erase("GOOGLE_tilt_brush_material")

	# Remap custom vertex attributes to standard GLTF slots Godot recognises.
	_map_custom_attributes_to_standard_slots(gltf_json)


# ---------------------------------------------------------------------------
# Post-parse: called from IcosaGLTF._import_post_parse for TILT files
# ---------------------------------------------------------------------------

func post_parse(gltf_state: GLTFState) -> void:
	_replace_materials_with_brush_materials(gltf_state)


# ---------------------------------------------------------------------------
# Post-import: called from IcosaGLTF._import_post for TILT files.
# Parses lights from the GLTF JSON and stamps uniform values onto every
# brush ShaderMaterial in the scene tree.
# ---------------------------------------------------------------------------

func apply_lights(root: Node, gltf_json: Dictionary) -> void:
	var light_0_dir := DEFAULT_LIGHT_0_DIRECTION
	var light_0_col := DEFAULT_LIGHT_0_COLOR
	var light_1_dir := DEFAULT_LIGHT_1_DIRECTION
	var light_1_col := DEFAULT_LIGHT_1_COLOR
	var ambient_col := DEFAULT_AMBIENT_COLOR

	# Try to read lights from KHR_lights_punctual extension
	var parsed_lights := _parse_khr_lights(gltf_json)
	if parsed_lights.size() >= 1:
		light_0_dir = parsed_lights[0]["direction"]
		light_0_col = parsed_lights[0]["color"]
	if parsed_lights.size() >= 2:
		light_1_dir = parsed_lights[1]["direction"]
		light_1_col = parsed_lights[1]["color"]

	# Walk the tree and stamp values onto every ShaderMaterial
	_apply_light_uniforms_to_node(root, light_0_dir, light_0_col, light_1_dir, light_1_col, ambient_col)


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _load_brush_materials() -> void:
	_scan_directory_for_materials("res://addons/icosa/open_brush/brush_materials/")


func _scan_directory_for_materials(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var found_material_in_dir := false

	while file_name != "":
		var full_path := dir_path + file_name
		if dir.current_is_dir():
			_scan_directory_for_materials(full_path + "/")
		elif file_name.ends_with(".tres") and not found_material_in_dir:
			var material_name := file_name.get_basename()
			brush_materials[material_name] = full_path
			found_material_in_dir = true
		file_name = dir.get_next()


func _load_name_mapping() -> void:
	var json_path := "res://addons/icosa/open_brush/name_mapping.json"
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed := JSON.parse_string(text)
	if parsed is Dictionary:
		name_mapping = parsed


func _replace_materials_with_brush_materials(gltf_state: GLTFState) -> void:
	var materials := gltf_state.get_materials()
	for i in range(materials.size()):
		var original_material := materials[i]
		var material_name := original_material.resource_name
		if material_name.is_empty():
			continue
		var brush_material := _find_matching_brush_material(material_name)
		if brush_material != null:
			materials[i] = brush_material
	gltf_state.set_materials(materials)


func _find_matching_brush_material(material_name: String) -> Material:
	var original_name := material_name

	# "material_<GUID>" or "material_<name>-<GUID>" — look up GUID in name mapping.
	if material_name.begins_with("material_"):
		var rest := material_name.substr(9)
		var parts := rest.split("-")
		if parts.size() >= 5:
			var guid := "-".join(parts.slice(parts.size() - 5, parts.size()))
			if guid != "":
				material_name = name_mapping.get(guid, material_name)
	elif material_name.begins_with("brush_"):
		material_name = material_name.substr(6)
	elif material_name.begins_with("ob-"):
		material_name = material_name.substr(3)

	if material_cache.has(original_name):
		return material_cache[original_name]

	# Exact match
	if brush_materials.has(material_name):
		var loaded := load(brush_materials[material_name]) as Material
		if loaded != null:
			material_cache[original_name] = loaded
			return loaded

	# Case-insensitive match
	var lower := material_name.to_lower()
	for brush_name in brush_materials.keys():
		if brush_name.to_lower() == lower:
			var loaded := load(brush_materials[brush_name]) as Material
			if loaded != null:
				material_cache[original_name] = loaded
				return loaded

	push_warning("TiltImport: no brush material for '%s' (mapped: '%s')" % [original_name, material_name])
	material_cache[original_name] = null
	return null


func _split_vec4_texcoord_accessor(gltf_json: Dictionary, vec4_accessor: Dictionary) -> Array:
	var uv_accessor := vec4_accessor.duplicate()
	uv_accessor["type"] = "VEC2"
	if uv_accessor.has("min") and uv_accessor["min"] is Array and uv_accessor["min"].size() >= 2:
		uv_accessor["min"] = [uv_accessor["min"][0], uv_accessor["min"][1]]
	if uv_accessor.has("max") and uv_accessor["max"] is Array and uv_accessor["max"].size() >= 2:
		uv_accessor["max"] = [uv_accessor["max"][0], uv_accessor["max"][1]]
	var tangent_accessor := vec4_accessor.duplicate()
	return [uv_accessor, tangent_accessor]


func _map_custom_attributes_to_standard_slots(gltf_json: Dictionary) -> void:
	if not gltf_json.has("meshes"):
		return

	var materials := gltf_json.get("materials", [])
	var accessors: Array = gltf_json.get("accessors", [])
	var meshes: Array = gltf_json["meshes"]

	for mesh in meshes:
		if not mesh is Dictionary:
			continue
		var primitives: Array = mesh.get("primitives", [])
		for primitive in primitives:
			if not primitive is Dictionary:
				continue
			var attributes: Dictionary = primitive.get("attributes", {})
			if not attributes is Dictionary:
				continue

			var material_name := "unknown"
			if primitive.has("material"):
				var mat_index: int = primitive["material"]
				if mat_index < materials.size() and materials[mat_index] is Dictionary:
					material_name = materials[mat_index].get("name", "")

			var is_particle_brush: bool = (
				material_name.contains("Smoke") or
				material_name.contains("Bubbles") or
				material_name.contains("Dots") or
				material_name.contains("Snow") or
				material_name.contains("Stars") or
				material_name.contains("Embers")
			)

			# --- Particle brush: remap custom attributes to standard slots ---
			if is_particle_brush:
				# _TB_UNITY_NORMAL (particle center VEC3) → NORMAL
				if attributes.has("_TB_UNITY_NORMAL"):
					attributes["NORMAL"] = attributes["_TB_UNITY_NORMAL"]
					attributes.erase("_TB_UNITY_NORMAL")

				# _TB_UNITY_TEXCOORD_0 (rotation in .z, VEC4) → TANGENT
				if attributes.has("_TB_UNITY_TEXCOORD_0"):
					attributes["TANGENT"] = attributes["_TB_UNITY_TEXCOORD_0"]
					attributes.erase("_TB_UNITY_TEXCOORD_0")

				# _TB_TIMESTAMP → TEXCOORD_1
				if attributes.has("_TB_TIMESTAMP"):
					attributes["TEXCOORD_1"] = attributes["_TB_TIMESTAMP"]
					attributes.erase("_TB_TIMESTAMP")

			# --- All brushes: fix TEXCOORD_0 if it is VEC4 → split to VEC2 UV + VEC4 TANGENT ---
			# Tilt Brush bakes rotation/extra data into TEXCOORD_0.z/.w on many brush types.
			# Godot's GLTF importer strictly expects TEXCOORD_0 to be VEC2; anything else errors.
			if attributes.has("TEXCOORD_0"):
				var texcoord_idx: int = attributes["TEXCOORD_0"]
				if texcoord_idx < accessors.size():
					var accessor: Dictionary = accessors[texcoord_idx]
					if accessor.get("type") == "VEC4":
						var new_accessors := _split_vec4_texcoord_accessor(gltf_json, accessor)
						if new_accessors.size() == 2:
							var uv_idx := accessors.size()
							var tangent_idx := accessors.size() + 1
							accessors.append(new_accessors[0])   # VEC2 for UV
							accessors.append(new_accessors[1])   # VEC4 for TANGENT
							attributes["TEXCOORD_0"] = uv_idx
							# Only set TANGENT from TEXCOORD_0 if not already set by particle remap
							if not attributes.has("TANGENT"):
								attributes["TANGENT"] = tangent_idx

			# --- All brushes: fix NORMAL if it is VEC4 → truncate to VEC3 ---
			# Some brush types store extra data in NORMAL.w; Godot expects VEC3.
			if attributes.has("NORMAL"):
				var normal_idx: int = attributes["NORMAL"]
				if normal_idx < accessors.size():
					var accessor: Dictionary = accessors[normal_idx]
					if accessor.get("type") == "VEC4":
						var vec3_accessor := accessor.duplicate()
						vec3_accessor["type"] = "VEC3"
						if vec3_accessor.has("min") and vec3_accessor["min"] is Array and vec3_accessor["min"].size() >= 3:
							vec3_accessor["min"] = [vec3_accessor["min"][0], vec3_accessor["min"][1], vec3_accessor["min"][2]]
						if vec3_accessor.has("max") and vec3_accessor["max"] is Array and vec3_accessor["max"].size() >= 3:
							vec3_accessor["max"] = [vec3_accessor["max"][0], vec3_accessor["max"][1], vec3_accessor["max"][2]]
						var new_idx := accessors.size()
						accessors.append(vec3_accessor)
						attributes["NORMAL"] = new_idx


func _parse_khr_lights(gltf_json: Dictionary) -> Array:
	## Returns up to 2 Dictionaries with keys "direction" (Vector3) and "color" (Color).
	## Reads KHR_lights_punctual directional lights from nodes, sorted by appearance.
	var result: Array = []

	var extensions_used: Array = gltf_json.get("extensionsUsed", [])
	if not extensions_used.has("KHR_lights_punctual"):
		return result

	var ext: Dictionary = gltf_json.get("extensions", {})
	var khr: Dictionary = ext.get("KHR_lights_punctual", {})
	var lights_arr: Array = khr.get("lights", [])
	if lights_arr.is_empty():
		return result

	# Gather directional light indices referenced by scene nodes
	var nodes: Array = gltf_json.get("nodes", [])
	for node in nodes:
		if not node is Dictionary:
			continue
		var node_ext: Dictionary = node.get("extensions", {})
		var node_khr: Dictionary = node_ext.get("KHR_lights_punctual", {})
		if not node_khr.has("light"):
			continue
		var light_idx: int = node_khr["light"]
		if light_idx >= lights_arr.size():
			continue
		var light_def: Dictionary = lights_arr[light_idx]
		if light_def.get("type", "") != "directional":
			continue

		# Direction: in GLTF the node's -Z axis points in the light's direction.
		# Read from node rotation (quaternion) if present, otherwise use defaults.
		var direction := Vector3(0.0, -1.0, 0.0)
		if node.has("rotation"):
			var r: Array = node["rotation"]
			if r.size() == 4:
				var q := Quaternion(r[0], r[1], r[2], r[3])
				direction = q * Vector3(0.0, 0.0, -1.0)

		# Color: GLTF stores as [r, g, b] linear floats; intensity is separate.
		var col := Color.WHITE
		if light_def.has("color"):
			var c: Array = light_def["color"]
			if c.size() >= 3:
				col = Color(c[0], c[1], c[2], 1.0)
		var intensity: float = light_def.get("intensity", 1.0)
		col = col * intensity

		result.append({"direction": direction, "color": col})
		if result.size() >= 2:
			break

	return result


func _apply_light_uniforms_to_node(
		node: Node,
		light_0_dir: Vector3, light_0_col: Color,
		light_1_dir: Vector3, light_1_col: Color,
		ambient_col: Color) -> void:
	if node is MeshInstance3D:
		var mesh := node.mesh
		if mesh != null:
			for i in range(mesh.get_surface_count()):
				var mat := mesh.surface_get_material(i)
				if mat is ShaderMaterial:
					_set_light_params(mat, light_0_dir, light_0_col, light_1_dir, light_1_col, ambient_col)

	for child in node.get_children():
		_apply_light_uniforms_to_node(child, light_0_dir, light_0_col, light_1_dir, light_1_col, ambient_col)


func _set_light_params(
		mat: ShaderMaterial,
		light_0_dir: Vector3, light_0_col: Color,
		light_1_dir: Vector3, light_1_col: Color,
		ambient_col: Color) -> void:
	# Only set the parameter if the shader actually declares it, to avoid warnings.
	var shader := mat.shader
	if shader == null:
		return
	var params := RenderingServer.get_shader_parameter_list(shader.get_rid())
	var param_names: Array = params.map(func(p): return p["name"])

	if "u_SceneLight_0_direction" in param_names:
		mat.set_shader_parameter("u_SceneLight_0_direction", light_0_dir)
	if "u_SceneLight_0_color" in param_names:
		mat.set_shader_parameter("u_SceneLight_0_color", light_0_col)
	if "u_SceneLight_1_direction" in param_names:
		mat.set_shader_parameter("u_SceneLight_1_direction", light_1_dir)
	if "u_SceneLight_1_color" in param_names:
		mat.set_shader_parameter("u_SceneLight_1_color", light_1_col)
	if "u_ambient_light_color" in param_names:
		mat.set_shader_parameter("u_ambient_light_color", ambient_col)
