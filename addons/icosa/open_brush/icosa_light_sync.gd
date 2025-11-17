extends Node
## Automatically syncs Godot scene lights to Icosa brush shader global uniforms
## Tracks up to 2 DirectionalLight3D nodes and updates shader parameters every frame

var tracked_lights: Array[DirectionalLight3D] = []
var lights_dirty := true

func _ready() -> void:
	# Connect to scene tree signals for dynamic light detection
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)

	# Initial light detection
	_update_light_references()

func _process(_delta: float) -> void:
	# Re-scan for lights if needed
	if lights_dirty:
		_update_light_references()
		lights_dirty = false

	# Sync light transforms and colors every frame
	_sync_lights()

func _on_node_added(node: Node) -> void:
	if node is DirectionalLight3D:
		lights_dirty = true

func _on_node_removed(node: Node) -> void:
	if node is DirectionalLight3D:
		lights_dirty = true

func _update_light_references() -> void:
	tracked_lights.clear()

	# First, check for lights in the "icosa_lights" group (explicit control)
	var grouped_lights = get_tree().get_nodes_in_group("icosa_lights")
	for light in grouped_lights:
		if light is DirectionalLight3D and light.visible:
			tracked_lights.append(light)
			if tracked_lights.size() >= 2:
				return

	# Fallback: find first two visible directional lights in scene
	var all_lights = get_tree().root.find_children("*", "DirectionalLight3D", true, false)
	for light in all_lights:
		if light.visible and not light in tracked_lights:
			tracked_lights.append(light)
			if tracked_lights.size() >= 2:
				return

func _sync_lights() -> void:
	# Sync light 0 (main light)
	if tracked_lights.size() > 0 and is_instance_valid(tracked_lights[0]):
		var light0 = tracked_lights[0]
		var direction = -light0.global_transform.basis.z
		var color = light0.light_color * light0.light_energy

		RenderingServer.global_shader_parameter_set("u_SceneLight_0_direction", direction)
		RenderingServer.global_shader_parameter_set("u_SceneLight_0_color", color)
	else:
		# Default main light (pointing down)
		RenderingServer.global_shader_parameter_set("u_SceneLight_0_direction", Vector3(0, -1, 0))
		RenderingServer.global_shader_parameter_set("u_SceneLight_0_color", Color.WHITE)

	# Sync light 1 (secondary light)
	if tracked_lights.size() > 1 and is_instance_valid(tracked_lights[1]):
		var light1 = tracked_lights[1]
		var direction = -light1.global_transform.basis.z
		var color = light1.light_color * light1.light_energy

		RenderingServer.global_shader_parameter_set("u_SceneLight_1_direction", direction)
		RenderingServer.global_shader_parameter_set("u_SceneLight_1_color", color)
	else:
		# Default secondary light (pointing up, dimmer)
		RenderingServer.global_shader_parameter_set("u_SceneLight_1_direction", Vector3(0, 1, 0))
		RenderingServer.global_shader_parameter_set("u_SceneLight_1_color", Color(0.5, 0.5, 0.5, 1.0))

	# Sync ambient light (use first Environment found, or default)
	var ambient_color := Color(0.2, 0.2, 0.2, 1.0)
	var world_env = get_tree().root.find_child("WorldEnvironment", true, false)
	if world_env and world_env.environment:
		var env: Environment = world_env.environment
		if env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR:
			ambient_color = env.ambient_light_color * env.ambient_light_energy

	RenderingServer.global_shader_parameter_set("u_ambient_light_color", ambient_color)
