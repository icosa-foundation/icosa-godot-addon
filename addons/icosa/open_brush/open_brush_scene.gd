@tool
class_name IcosaOpenBrushScene
extends EditorImportPlugin

func _get_importer_name(): return "open_brush_scene"
func _get_visible_name(): return "Open Brush scene"
func _get_recognized_extensions(): return ["tilt", "gltf", "glb"]

func _get_resource_type(): return "Scene" # ?
func _get_preset_count(): return 1 # not sure what this means..
func _get_preset_name(preset_index): return "Default" # not sure what this means..
func _get_import_options(path, preset_index): return [] # not sure what this means..

## EditorImportPlugin.import()
func _import(source_file, save_path, options, r_platform_variants, r_gen_files):
	var importer := ResourceImporterScene.new()
	
	var settings = {
	"meshes/generate_lods" : false,
	"meshes/create_shadow_meshes" : false,
	
	"meshes/light_baking" : false, # ?
	"meshes/ensure_tangents" : false, # ?
	"meshes/force_disable_compression" : true # ?
	}
	
	
	for setting in settings:
		importer.set(setting, settings[setting])
	
	var format = source_file.get_extension()
	match format:
		"glb": pass 
		"gltf": pass 
		## diabling shadow meshes + lods here is enough.
		## rest of job done via IcosaOpenBrushGLTF 
		"tilt": pass 
		## the juicy bit of loading binary tilt files!
		# var tilt_loader = TiltLoader.new() # from TiltLoader.cs i presume.
