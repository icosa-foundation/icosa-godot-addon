@tool
extends EditorPlugin
func _get_plugin_name(): return "Icosa Gallery"
func _get_plugin_icon(): return EditorInterface.get_editor_theme().get_icon("GridMap", "EditorIcons")


const MainPanel = preload("res://addons/icosa/browser/browser.tscn")
const FixOriginTool = preload("res://addons/icosa/misc/fix_origin.gd")
const UploadStudio = preload("res://addons/icosa/upload/upload_studio.tscn")
var main_panel_instance

var gltf : IcosaGLTF
var open_brush_gltf : IcosaOpenBrushGLTF
var fix_origin_tool : IcosaFixOriginTool
var fix_origin_button : Button

var upload_studio_instance : IcosaUploadStudio
var upload_studio_window : Window
var upload_asset_button : Button

var _prev_distraction_free := false
var _scene_tabs: Control = null

var settings = {
	"icosa/downloads/local_download_path"           : "res://icosa_downloads",
	"icosa/downloads/runtime_download_path"         : "user://icosa_downloads",
	"icosa/environment/import_world_environment"      : false,
	"icosa/environment/import_tilt_brush_environment" : false,
	"icosa/debug/debug_print_requests"          : false,
}

class ProjectSetting:
	func _init(path: String, default: Variant):
		if not ProjectSettings.has_setting(path):
			ProjectSettings.set_setting(path, default)
		ProjectSettings.set_initial_value(path, default)

func build_project_settings():
	for path in settings:
		ProjectSetting.new(path, settings[path])

func _enter_tree():
	main_panel_instance = MainPanel.instantiate()
	get_editor_interface().get_editor_main_screen().add_child(main_panel_instance)
	gltf = IcosaGLTF.new()
	GLTFDocument.register_gltf_document_extension(gltf)
	open_brush_gltf = IcosaOpenBrushGLTF.new()
	GLTFDocument.register_gltf_document_extension(open_brush_gltf)
	main_panel_instance.visible = false

	fix_origin_tool = FixOriginTool.new()

	var settings = EditorInterface.get_editor_settings()
	settings.set_setting("docks/filesystem/other_file_extensions", "ico,icns,bin")

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

	build_project_settings()


func _exit_tree():
	if main_panel_instance:
		main_panel_instance.queue_free()
	GLTFDocument.unregister_gltf_document_extension(gltf)
	GLTFDocument.unregister_gltf_document_extension(open_brush_gltf)

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

	# Restore scene tabs if they were hidden
	if _scene_tabs:
		_scene_tabs.visible = true
		_scene_tabs = null

	var settings = EditorInterface.get_editor_settings()
	settings.set_setting("docks/filesystem/other_file_extensions", "ico,icns")

func _on_fix_origin():
	if fix_origin_tool:
		fix_origin_tool.run_for_selection(get_editor_interface())

func _ensure_upload_studio():
	if upload_studio_window:
		return
	upload_studio_window = Window.new()
	upload_studio_window.title = "Upload to Icosa Gallery"
	upload_studio_window.size = Vector2i(1200, 800)
	upload_studio_window.unresizable = false
	upload_studio_window.close_requested.connect(_on_upload_studio_close)

	upload_studio_instance = UploadStudio.instantiate() as IcosaUploadStudio
	upload_studio_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	upload_studio_window.add_child(upload_studio_instance)
	add_child(upload_studio_window)
	upload_studio_window.hide()

	var browser_node = main_panel_instance.get_node("Browser/IcosaBrowser")
	upload_studio_instance.set("browser", browser_node)

func _on_upload_asset():
	if not main_panel_instance:
		printerr("[Plugin] Panel instance is null!")
		return
	_ensure_upload_studio()
	var edited_scene_root = get_editor_interface().get_edited_scene_root()
	if edited_scene_root:
		var scene_path = edited_scene_root.scene_file_path
		upload_studio_window.popup_centered()
		if scene_path:
			upload_studio_instance.load_current_scene(edited_scene_root, scene_path)
	else:
		printerr("[Plugin] No scene is currently being edited!")
		upload_studio_window.popup_centered()

func _on_upload_studio_close():
	if upload_studio_window:
		upload_studio_window.hide()

func _find_scene_tabs() -> Control:
	# EditorSceneTabs is a sibling of EditorMainScreen inside a VBoxContainer (depth 1 up from main screen).
	# Layout: VBoxContainer -> [EditorSceneTabs, EditorMainScreen]
	var main_screen = get_editor_interface().get_editor_main_screen()
	# main_screen parent is EditorMainScreen, its parent is the VBoxContainer we want
	var vbox = main_screen.get_parent().get_parent()
	if vbox == null:
		return null
	for child in vbox.get_children():
		if child.get_class() == "EditorSceneTabs":
			return child as Control
	return null

func _has_main_screen():
	return true

func _make_visible(visible):
	if main_panel_instance:
		main_panel_instance.visible = visible
	if _scene_tabs == null:
		_scene_tabs = _find_scene_tabs()
	if visible:
		_prev_distraction_free = EditorInterface.distraction_free_mode
		EditorInterface.distraction_free_mode = true
		hide_bottom_panel()
		if _scene_tabs:
			_scene_tabs.visible = false
		# Trigger first-time requests now that the panel is actually shown
		var browser_node = main_panel_instance.get_node_or_null("Browser/IcosaBrowser")
		if browser_node and browser_node.has_method("first_activate"):
			browser_node.first_activate()
	else:
		EditorInterface.distraction_free_mode = _prev_distraction_free
		if _scene_tabs:
			_scene_tabs.visible = true
