@tool
extends EditorPlugin
func _get_plugin_name(): return "Icosa Gallery"
func _get_plugin_icon(): return EditorInterface.get_editor_theme().get_icon("GridMap", "EditorIcons") #return load("res://addons/icosa-gallery/logo/logo_tiny.png")
const MainPanel = preload("res://addons/icosa/browser.tscn")
const LightSync = preload("res://addons/icosa/icosa_light_sync.gd")
const FixOriginTool = preload("res://addons/icosa/fix_origin.gd")
var main_panel_instance

var gltf : IcosaGLTF
var light_sync_instance
var fix_origin_tool : IcosaFixOriginTool
var fix_origin_button : Button


func _enter_tree():
	main_panel_instance = MainPanel.instantiate()
	get_editor_interface().get_editor_main_screen().add_child(main_panel_instance)
	gltf = IcosaGLTF.new()
	GLTFDocument.register_gltf_document_extension(gltf)
	main_panel_instance.visible = false

	fix_origin_tool = FixOriginTool.new()

	var settings = EditorInterface.get_editor_settings()
	settings.set_setting("docks/filesystem/other_file_extensions", "ico,icns,bin")

	# Register global shader parameters for Icosa brush lighting
	_register_global_shader_parameters()

	# Add light sync node to keep shader parameters updated
	light_sync_instance = LightSync.new()
	add_child(light_sync_instance)

	fix_origin_button = Button.new()
	fix_origin_button.text = "Fix Origin"
	fix_origin_button.tooltip_text = "Wrap selected MeshInstance3D and recenter its pivot."
	fix_origin_button.pressed.connect(_on_fix_origin)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, fix_origin_button)

	add_tool_menu_item("Icosa/Fix Selected Mesh Origin", Callable(self, "_on_fix_origin"))


func _exit_tree():
	if main_panel_instance:
		main_panel_instance.queue_free()
	GLTFDocument.unregister_gltf_document_extension(gltf)

	# Clean up light sync
	if light_sync_instance:
		light_sync_instance.queue_free()

	remove_tool_menu_item("Icosa/Fix Selected Mesh Origin")
	if fix_origin_button:
		if fix_origin_button.pressed.is_connected(_on_fix_origin):
			fix_origin_button.pressed.disconnect(_on_fix_origin)
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, fix_origin_button)
		fix_origin_button.queue_free()
		fix_origin_button = null
	fix_origin_tool = null

	# Remove global shader parameters
	_unregister_global_shader_parameters()

	var settings = EditorInterface.get_editor_settings()
	settings.set_setting("docks/filesystem/other_file_extensions", "ico,icns")

func _on_fix_origin():
	if fix_origin_tool:
		fix_origin_tool.run_for_selection(get_editor_interface())

func _has_main_screen():
	return true

func _make_visible(visible):
	if main_panel_instance:
		main_panel_instance.visible = visible

func _register_global_shader_parameters():
	# Light 0 (main light)
	if not RenderingServer.global_shader_parameter_get("u_SceneLight_0_direction"):
		RenderingServer.global_shader_parameter_add("u_SceneLight_0_direction",
			RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0, -1, 0))
	if not RenderingServer.global_shader_parameter_get("u_SceneLight_0_color"):
		RenderingServer.global_shader_parameter_add("u_SceneLight_0_color",
			RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color.WHITE)

	# Light 1 (secondary light)
	if not RenderingServer.global_shader_parameter_get("u_SceneLight_1_direction"):
		RenderingServer.global_shader_parameter_add("u_SceneLight_1_direction",
			RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0, 1, 0))
	if not RenderingServer.global_shader_parameter_get("u_SceneLight_1_color"):
		RenderingServer.global_shader_parameter_add("u_SceneLight_1_color",
			RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(0.5, 0.5, 0.5, 1.0))

	# Ambient light
	if not RenderingServer.global_shader_parameter_get("u_ambient_light_color"):
		RenderingServer.global_shader_parameter_add("u_ambient_light_color",
			RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color(0.2, 0.2, 0.2, 1.0))

func _unregister_global_shader_parameters():
	RenderingServer.global_shader_parameter_remove("u_SceneLight_0_direction")
	RenderingServer.global_shader_parameter_remove("u_SceneLight_0_color")
	RenderingServer.global_shader_parameter_remove("u_SceneLight_1_direction")
	RenderingServer.global_shader_parameter_remove("u_SceneLight_1_color")
	RenderingServer.global_shader_parameter_remove("u_ambient_light_color")
