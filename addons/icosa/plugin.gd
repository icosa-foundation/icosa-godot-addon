@tool
extends EditorPlugin
func _get_plugin_name(): return "Icosa Gallery"
func _get_plugin_icon(): return EditorInterface.get_editor_theme().get_icon("GridMap", "EditorIcons") #return load("res://addons/icosa-gallery/logo/logo_tiny.png")
const MainPanel = preload("res://addons/icosa/browser.tscn")
var main_panel_instance

var gltf : IcosaGLTF

func _enter_tree():
	main_panel_instance = MainPanel.instantiate()
	get_editor_interface().get_editor_main_screen().add_child(main_panel_instance)
	gltf = IcosaGLTF.new()
	GLTFDocument.register_gltf_document_extension(gltf)
	main_panel_instance.visible = false
	
func _exit_tree():
	if main_panel_instance:
		main_panel_instance.queue_free()
	GLTFDocument.unregister_gltf_document_extension(gltf)

func _has_main_screen():
	return true

func _make_visible(visible): 
	if main_panel_instance:
		main_panel_instance.visible = visible
