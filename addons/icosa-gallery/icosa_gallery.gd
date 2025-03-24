@tool
## icosa browser.
extends Control

var current_page = 1
const DEFAULT_COLUMN_SIZE = 5
@export var api : IcosaGalleryAPI
@onready var thumbnail_scene := preload("res://addons/icosa-gallery/thumbnail.tscn")

func _ready():
	api.fade_in(%Logo)
	
	

	
func _on_search_bar_text_submitted(new_text):
	api.fade_out(%Logo)
	
	var search = api.create_default_search()
	search.keywords = new_text
	var url = api.build_query_url_from_search_object(search)
	
	api.current_request = IcosaGalleryAPI.RequestType.SEARCH
	var error = api.request(url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")


func _on_api_request_completed(result, response_code, headers, body):
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	
	if api.current_request == IcosaGalleryAPI.RequestType.SEARCH:
		%NoAssetsLabel.hide()
		var assets = api.get_asset_objects_from_response(response)
		for child in %AssetGrid.get_children(): child.queue_free()
		for asset in assets:
			var asset_thumbnail = thumbnail_scene.instantiate() as IcosaGalleryThumbnail
			asset_thumbnail.pressed.connect(select_asset.bind(asset_thumbnail))
			asset_thumbnail.display_name = asset.display_name
			asset_thumbnail.author_name = asset.author_name
			asset_thumbnail.thumbnail_url = asset.thumbnail
			%AssetGrid.add_child(asset_thumbnail)
			
			
			var format_index = 0
			for format_type in asset.formats:
				var download_url = asset.formats[format_type]
				asset_thumbnail.formats.get_popup().add_item(format_type, format_index)
				asset_thumbnail.formats.get_popup().id_pressed.connect(asset_thumbnail.download.start_download)
				format_index += 1


				
		_on_asset_columns_value_changed(%AssetColumns.value)
	if api.total_size == 0:
		## TODO MAKE A MESSAGE!
		%NoAssetsLabel.show()



var chosen_thumbnail : Control
func select_asset(selected_thumbnail : Control):
	for thumbnail in selected_thumbnail.get_parent().get_children():
		thumbnail.hide()
	selected_thumbnail.show()
	selected_thumbnail.custom_minimum_size = size/1.25
	selected_thumbnail.disabled = true
	%AssetGrid.alignment = FlowContainer.AlignmentMode.ALIGNMENT_CENTER
	chosen_thumbnail = selected_thumbnail
	%GoBack.show()
	
func _on_go_back_pressed():
	%GoBack.hide()
	chosen_thumbnail.disabled = false
	%AssetGrid.alignment = FlowContainer.AlignmentMode.ALIGNMENT_BEGIN
	for thumbnail in %AssetGrid.get_children():
		thumbnail.custom_minimum_size = Vector2(asset_size, asset_size)
		thumbnail.show()

var asset_size = 250
func _on_resized():
	var width = size.x
	var height = size.y
	_on_asset_columns_value_changed(%AssetColumns.value)
	


## pagination.
func _on_previous_page_pressed():
	pass # Replace with function body.
	
func _on_next_page_pressed():
	pass # Replace with function body.


func _on_asset_columns_value_changed(value):
	var width = size.x
	var height = size.y
	var each = width/value - 10
	for asset in %AssetGrid.get_children():
		asset.custom_minimum_size = Vector2(each , each)
		asset.size = Vector2(each , each)
	
