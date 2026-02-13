@tool
extends EditorPlugin
func _get_plugin_name(): return "Icosa Gallery"
func _get_plugin_icon(): return EditorInterface.get_editor_theme().get_icon("GridMap", "EditorIcons")


const MainPanel = preload("res://addons/icosa/browser/browser.tscn")
const LightSync = preload("res://addons/icosa/open_brush/icosa_light_sync.gd")
const FixOriginTool = preload("res://addons/icosa/misc/fix_origin.gd")
const UploadStudio = preload("res://addons/icosa/upload/upload_studio.tscn")
var main_panel_instance

var gltf : IcosaGLTF
var light_sync_instance
var fix_origin_tool : IcosaFixOriginTool
var fix_origin_button : Button

var upload_studio_instance : IcosaUploadStudio
var upload_studio_window : Window
var upload_asset_button : Button

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

	## upload from the editor
	upload_asset_button = Button.new()
	upload_asset_button.text = "Upload To Icosa"
	upload_asset_button.tooltip_text = "Upload scene to the Icosa Gallery"
	upload_asset_button.pressed.connect(_on_upload_asset)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, upload_asset_button)
	add_tool_menu_item("Icosa/Upload Scene to Gallery", Callable(self, "_on_upload_asset"))

	# Initialize upload studio wrapped in a Window
	upload_studio_window = Window.new()
	upload_studio_window.title = "Upload to Icosa Gallery"
	upload_studio_window.size = Vector2i(1200, 800)
	upload_studio_window.unresizable = false
	upload_studio_window.close_requested.connect(_on_upload_studio_close)

	upload_studio_instance = UploadStudio.instantiate() as IcosaUploadStudio
	upload_studio_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	upload_studio_window.add_child(upload_studio_instance)

	# Add window as child but keep it hidden
	add_child(upload_studio_window)
	upload_studio_window.hide()

	# Set the browser reference after the node is in the scene tree
	var browser_node = main_panel_instance.get_node("Browser/IcosaBrowser")
	upload_studio_instance.set("browser", browser_node)
	


func _exit_tree():
	if main_panel_instance:
		main_panel_instance.queue_free()
	GLTFDocument.unregister_gltf_document_extension(gltf)

	# Clean up light sync
	if light_sync_instance:
		light_sync_instance.queue_free()

	remove_tool_menu_item("Icosa/Fix Selected Mesh Origin")
	remove_tool_menu_item("Icosa/Upload Scene to Gallery")

	if fix_origin_button:
		if fix_origin_button.pressed.is_connected(_on_fix_origin):
			fix_origin_button.pressed.disconnect(_on_fix_origin)
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, fix_origin_button)
		fix_origin_button.queue_free()
		fix_origin_button = null
	fix_origin_tool = null

	if upload_asset_button:
		if upload_asset_button.pressed.is_connected(_on_upload_asset):
			upload_asset_button.pressed.disconnect(_on_upload_asset)
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, upload_asset_button)
		upload_asset_button.queue_free()
		upload_asset_button = null

	if upload_studio_window:
		upload_studio_window.queue_free()

	# Remove global shader parameters
	_unregister_global_shader_parameters()

	var settings = EditorInterface.get_editor_settings()
	settings.set_setting("docks/filesystem/other_file_extensions", "ico,icns")

func _on_fix_origin():
	if fix_origin_tool:
		fix_origin_tool.run_for_selection(get_editor_interface())

func _on_upload_asset():
	print("[Plugin] Upload asset button clicked")
	if upload_studio_window and main_panel_instance:
		# Get the currently edited scene
		var edited_scene_root = get_editor_interface().get_edited_scene_root()
		if edited_scene_root:
			var scene_path = edited_scene_root.scene_file_path
			print("[Plugin] Current edited scene: ", scene_path)

			# Show the upload studio window centered
			upload_studio_window.popup_centered()

			# Auto-load the current scene into the studio
			if upload_studio_instance and scene_path:
				upload_studio_instance.load_current_scene(edited_scene_root, scene_path)
		else:
			printerr("[Plugin] No scene is currently being edited!")
			# Still show the window so they can manually load a scene
			upload_studio_window.popup_centered()
	else:
		printerr("[Plugin] Window or panel instance is null!")

func _on_upload_studio_close():
	if upload_studio_window:
		upload_studio_window.hide()

func _has_main_screen():
	return true

func _make_visible(visible):
	if main_panel_instance:
		main_panel_instance.visible = visible




## TODO: make these parameters local.
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
