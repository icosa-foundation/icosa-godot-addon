## plugin.gd - main hook for godot addons.
@tool
extends EditorPlugin
func _get_plugin_name(): return "Icosa Gallery"
func _get_plugin_icon(): return EditorInterface.get_editor_theme().get_icon("GridMap", "EditorIcons") #return load("res://addons/icosa-gallery/logo/logo_tiny.png")


const MainPanel = preload("res://addons/icosa-gallery/icosa_gallery.tscn")
var main_panel_instance

func _enter_tree():
	main_panel_instance = MainPanel.instantiate()
	get_editor_interface().get_editor_main_screen().add_child(main_panel_instance)

func _exit_tree():
	if main_panel_instance:
		main_panel_instance.queue_free()

func _has_main_screen():
	return true
		
func _make_visible(visible): 
	if main_panel_instance:
		main_panel_instance.visible = visible
