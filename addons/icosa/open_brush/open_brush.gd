@tool
class_name IcosaOpenBrush
extends RefCounted

## Shared data and format-agnostic helpers for Open Brush / Tilt Brush importers.
## Instantiated once in plugin.gd and shared between IcosaOpenBrushGLTF and
## IcosaOpenBrushScene so material / name / environment caches are warm for both.

var material_cache: Dictionary = {}
var brush_materials: Dictionary = {}
var name_mapping: Dictionary = {}
var environment_data: Dictionary = {}

# Default Open Brush light rig used when the file doesn't specify lights.
const DEFAULT_LIGHT_0_DIRECTION := Vector3(0.0, -0.707, 0.707)
const DEFAULT_LIGHT_0_COLOR := Color(1.0, 0.99, 0.95, 1.0)
const DEFAULT_LIGHT_1_DIRECTION := Vector3(0.0, 0.5, -0.866)
const DEFAULT_LIGHT_1_COLOR := Color(0.35, 0.4, 0.55, 1.0)
const DEFAULT_AMBIENT_COLOR := Color(1.0, 1.0, 1.0, 1.0)


func ensure_loaded() -> void:
	if brush_materials.is_empty():
		_scan_directory_for_materials("res://addons/icosa/open_brush/brush_materials/")
	if name_mapping.is_empty():
		var file := FileAccess.open("res://addons/icosa/open_brush/name_mapping.json", FileAccess.READ)
		if file != null:
			var parsed := JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				name_mapping = parsed
	if environment_data.is_empty():
		var file := FileAccess.open("res://addons/icosa/open_brush/environments/environments.json", FileAccess.READ)
		if file != null:
			var parsed := JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				environment_data = parsed


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
			brush_materials[file_name.get_basename()] = full_path
			found_material_in_dir = true
		file_name = dir.get_next()


func find_matching_brush_material(material_name: String) -> Material:
	var original_name := material_name

	if material_name.begins_with("material_"):
		var parts := material_name.substr(9).split("-")
		if parts.size() >= 5:
			var guid := "-".join(parts.slice(parts.size() - 5, parts.size()))
			material_name = name_mapping.get(guid, material_name)
	elif material_name.begins_with("brush_"):
		material_name = material_name.substr(6)
	elif material_name.begins_with("ob-"):
		material_name = material_name.substr(3)

	if material_cache.has(original_name):
		return material_cache[original_name]

	if brush_materials.has(material_name):
		var loaded := load(brush_materials[material_name]) as Material
		if loaded != null:
			material_cache[original_name] = loaded
			return loaded

	var lower := material_name.to_lower()
	for brush_name in brush_materials.keys():
		if brush_name.to_lower() == lower:
			var loaded := load(brush_materials[brush_name]) as Material
			if loaded != null:
				material_cache[original_name] = loaded
				return loaded

	push_warning("IcosaOpenBrush: no brush material for '%s' (mapped: '%s')" % [original_name, material_name])
	material_cache[original_name] = null
	return null


## Resolve a brush GUID to a human-readable brush name via name_mapping.json.
func resolve_brush_name(guid: String) -> String:
	if guid.is_empty():
		return "Unknown"
	return name_mapping.get(guid, guid)


## Resolve environment GUID from either a direct GUID or a preset name string.
func resolve_env_guid(env_guid: String, env_name: String) -> String:
	if not env_guid.is_empty() and environment_data.has(env_guid):
		return env_guid
	if not env_name.is_empty():
		for guid in environment_data:
			if environment_data[guid].get("name", "") == env_name:
				return guid
	return ""


## Add a WorldEnvironment node to root using environment_data for the given GUID.
## sky_color_a / sky_color_b / gradient_dir can override the environment defaults
## (pass Color(0,0,0,0) / Vector3.ZERO to fall back to environment defaults).
func apply_world_environment(
		root: Node,
		env_guid: String,
		sky_color_a: Color,
		sky_color_b: Color,
		gradient_dir: Vector3) -> void:
	if env_guid.is_empty() or not environment_data.has(env_guid):
		return

	var env_def: Dictionary = environment_data[env_guid]

	# Helper: convert {r,g,b} dict to Color.
	var c := func(d: Dictionary, fallback: Color):
		if d.is_empty():
			return fallback
		return Color(d.get("r", 0.0), d.get("g", 0.0), d.get("b", 0.0))

	var rs: Dictionary = env_def.get("renderSettings", {})

	# Use caller-supplied overrides if non-zero, else fall back to environment defaults.
	var sky_a: Color = sky_color_a if sky_color_a.a > 0.0 else c.call(env_def.get("skyboxColorA", {}), Color.BLACK)
	var sky_b: Color = sky_color_b if sky_color_b.a > 0.0 else c.call(env_def.get("skyboxColorB", {}), Color.BLACK)
	var grad_dir: Vector3 = gradient_dir if gradient_dir != Vector3.ZERO else Vector3.UP

	var sky_shader := load("res://addons/icosa/open_brush/tilt_brush_sky.gdshader") as Shader
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = sky_shader
	sky_mat.set_shader_parameter("sky_color_a", sky_a)
	sky_mat.set_shader_parameter("sky_color_b", sky_b)
	sky_mat.set_shader_parameter("gradient_direction", grad_dir)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = c.call(rs.get("ambientColor", {}), Color(1.0, 1.0, 1.0))
	env.ambient_light_energy = 1.0
	env.fog_enabled = false

	var world_env := WorldEnvironment.new()
	world_env.name = "IcosaWorldEnvironment"
	world_env.environment = env
	root.add_child(world_env)
	world_env.owner = root


## Add a GLB environment mesh node to root for the given environment GUID.
func apply_environment(root: Node, env_guid: String) -> void:
	if env_guid.is_empty():
		return

	var env_dir := "res://addons/icosa/open_brush/environments/%s/" % env_guid
	var dir := DirAccess.open(env_dir)
	if dir == null:
		push_warning("IcosaOpenBrush: environment folder not found: %s" % env_dir)
		return

	var glb_path := ""
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.get_extension().to_lower() == "glb":
			glb_path = env_dir + fname
			break
		fname = dir.get_next()
	dir.list_dir_end()

	if glb_path.is_empty():
		push_warning("IcosaOpenBrush: no GLB found in environment folder: %s" % env_dir)
		return

	var env_scene: PackedScene = load(glb_path)
	if env_scene == null:
		push_warning("IcosaOpenBrush: failed to load environment GLB: %s" % glb_path)
		return

	var env_node := env_scene.instantiate() as Node3D
	env_node.name = "OpenBrushEnvironment"
	env_node.scale = Vector3(0.1, 0.1, 0.1)
	env_node.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	root.add_child(env_node)
	env_node.owner = root


## Extract light parameters from environments.json for a given env GUID.
## Returns a dict: { "light_0_dir", "light_0_col", "light_1_dir", "light_1_col", "ambient_col" }
## Falls back to built-in defaults if the GUID is missing or has no lights array.
func extract_lights_from_env(env_guid: String) -> Dictionary:
	var result := {
		"light_0_dir": DEFAULT_LIGHT_0_DIRECTION,
		"light_0_col": DEFAULT_LIGHT_0_COLOR,
		"light_1_dir": DEFAULT_LIGHT_1_DIRECTION,
		"light_1_col": DEFAULT_LIGHT_1_COLOR,
		"ambient_col": DEFAULT_AMBIENT_COLOR,
	}
	if env_guid.is_empty() or not environment_data.has(env_guid):
		return result

	var env_def: Dictionary = environment_data[env_guid]

	var c := func(d: Dictionary, fallback: Color):
		if d.is_empty(): return fallback
		return Color(d.get("r", 1.0), d.get("g", 1.0), d.get("b", 1.0))

	var rs: Dictionary = env_def.get("renderSettings", {})
	result["ambient_col"] = c.call(rs.get("ambientColor", {}), DEFAULT_AMBIENT_COLOR)

	var lights: Array = env_def.get("lights", [])
	for i in range(mini(lights.size(), 2)):
		var light: Dictionary = lights[i]
		var col: Color = c.call(light.get("color", {}), Color.WHITE)
		# Unity Euler angles (X=pitch down, Y=yaw, Z=roll) → Godot direction vector.
		# The light "points" along -Y in its local frame rotated by the Euler angles.
		# We apply: rotate around Y (yaw), then X (pitch), negate Z for handedness.
		var rot: Dictionary = light.get("rotation", {})
		var pitch_deg: float = rot.get("x", 0.0)
		var yaw_deg: float   = rot.get("y", 0.0)
		var dir := _unity_euler_to_direction(pitch_deg, yaw_deg)
		if i == 0:
			result["light_0_col"] = col
			result["light_0_dir"] = dir
		else:
			result["light_1_col"] = col
			result["light_1_dir"] = dir

	return result


## Convert Unity directional-light Euler angles (pitch, yaw in degrees) to a
## world-space direction vector in Godot's coordinate system.
## A Unity directional light at (pitch=0, yaw=0) points straight down (-Y).
## Pitch rotates it forward (toward +Z in Unity = -Z in Godot).
## Yaw rotates around the Y axis.
func _unity_euler_to_direction(pitch_deg: float, yaw_deg: float) -> Vector3:
	# Start with down direction (-Y), apply pitch (X rotation) then yaw (Y rotation).
	var pitch := deg_to_rad(pitch_deg)
	var yaw   := deg_to_rad(yaw_deg)
	# After pitch: dir = (0, -cos(pitch), sin(pitch))  [Unity Z-forward]
	# Convert Unity Z-forward → Godot Z-backward: negate Z component.
	var dir_unity := Vector3(0.0, -cos(pitch), sin(pitch))
	# Apply yaw around Y axis.
	dir_unity = Vector3(
		dir_unity.x * cos(yaw) + dir_unity.z * sin(yaw),
		dir_unity.y,
		-dir_unity.x * sin(yaw) + dir_unity.z * cos(yaw)
	)
	# Convert Unity left-hand (Z-forward) → Godot right-hand (Z-backward): negate Z.
	return Vector3(dir_unity.x, dir_unity.y, -dir_unity.z).normalized()


## Add DirectionalLight3D nodes and set shader light uniforms on all mesh materials.
func apply_lights(
		root: Node,
		light_0_dir: Vector3, light_0_col: Color,
		light_1_dir: Vector3, light_1_col: Color,
		ambient_col: Color) -> void:
	_add_directional_light(root, "u_SceneLight_0", light_0_col, light_0_dir)
	_add_directional_light(root, "u_SceneLight_1", light_1_col, light_1_dir)
	apply_light_uniforms_to_node(root, light_0_dir, light_0_col, light_1_dir, light_1_col, ambient_col)


func _add_directional_light(root: Node, light_name: String, col: Color, direction: Vector3) -> void:
	var light := DirectionalLight3D.new()
	light.name = light_name
	light.light_color = col
	# Point the light along `direction` by rotating from the default -Z forward.
	if direction != Vector3.ZERO:
		light.transform = Transform3D(
			Basis.looking_at(-direction.normalized()),
			Vector3.ZERO)
	root.add_child(light)
	light.owner = root


func apply_light_uniforms_to_node(
		node: Node,
		light_0_dir: Vector3, light_0_col: Color,
		light_1_dir: Vector3, light_1_col: Color,
		ambient_col: Color) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		if mesh != null:
			for i in range(mesh.get_surface_count()):
				var mat := mesh.surface_get_material(i)
				if mat is ShaderMaterial:
					_set_light_params(mat, light_0_dir, light_0_col, light_1_dir, light_1_col, ambient_col)
	for child in node.get_children():
		apply_light_uniforms_to_node(child, light_0_dir, light_0_col, light_1_dir, light_1_col, ambient_col)


func _set_light_params(
		mat: ShaderMaterial,
		light_0_dir: Vector3, light_0_col: Color,
		light_1_dir: Vector3, light_1_col: Color,
		ambient_col: Color) -> void:
	var shader := mat.shader
	if shader == null:
		return
	var param_names: Array = RenderingServer.get_shader_parameter_list(shader.get_rid()).map(
		func(p): return p["name"])

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
