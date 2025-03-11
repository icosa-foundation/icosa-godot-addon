@tool
extends EditorPlugin

var icosa_endpoint = {"icosa-gallery.com" : "https://icosa-gallery.com/api/v1/assets"}


@onready var thumbnail_scene = preload("res://addons/icosa-gallery/icosa_gallery_thumbnail.tscn")
func add_endpoint():
	var settings = EditorInterface.get_editor_settings()
	var urls = settings.get_setting("asset_library/available_urls")
	if not (icosa_endpoint.keys()[0] in urls):
		urls[icosa_endpoint.keys()[0]] = icosa_endpoint.values()[0]
		settings.set_setting("asset_library/available_urls", urls)

func remove_endpoint():
	var settings = EditorInterface.get_editor_settings()
	var urls = settings.get_setting("asset_library/available_urls")
	if icosa_endpoint.keys()[0] in urls:
		urls.erase(icosa_endpoint.keys()[0])
		settings.set_setting("asset_library/available_urls", urls)

func _enter_tree():
	#var profile = EditorFeatureProfile.new()
	#profile.set_disable_feature(EditorFeatureProfile.FEATURE_ASSET_LIB, true)
	#profile.save_to_file("addons/icosa-gallery/tmp/reload.txt")
	#profile.load_from_file("addons/icosa-gallery/tmp/reload.txt")
	add_endpoint()
	#profile.set_disable_feature(EditorFeatureProfile.FEATURE_ASSET_LIB, false)

func _exit_tree():
	remove_endpoint()

func _create_thumbnail(asset_data: Dictionary, texture: ImageTexture = null) -> void:
	var thumbnail = thumbnail_scene.instantiate()
	thumbnail.setup({
		"name": asset_data.name,
		"author": asset_data.author,
		# ... other asset data ...
	}, texture)
