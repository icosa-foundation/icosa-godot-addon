@tool
## icosa browser.
extends Control

var current_page = 1
const DEFAULT_COLUMN_SIZE = 5
@export var api : IcosaGalleryAPI
@onready var thumbnail_scene := preload("res://addons/icosa-gallery/thumbnail.tscn")

var viewing_single_asset = false
var current_search : IcosaGalleryAPI.Search
var chosen_thumbnail : Control
var asset_size = 250

func _ready():
	api.fade_in(%Logo)

func _on_search_bar_text_submitted(new_text):
	api.fade_out(%Logo)
	
	var search = api.create_default_search()
	search.keywords = new_text
	current_search = search
	current_page = 1
	current_search.page_token = current_page
	
	var url = api.build_query_url_from_search_object(search)
	api.current_request = IcosaGalleryAPI.RequestType.SEARCH
	var error = api.request(url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _on_api_request_completed(result, response_code, headers, body):
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	var total_assets = response["totalSize"]

	# Update asset found / not found labels
	if total_assets == 0:
		%NoAssetsLabel.show()
		%AssetsFound.hide()
	else:
		%NoAssetsLabel.hide()
		%AssetsFound.show()
		%AssetsFound.text = "Total assets found: " + str(int(total_assets))
		
		# Create/update pagination buttons
		var total_pages = api.get_pages_from_total_assets(current_search.page_size, total_assets)
		_refresh_pagination_buttons(current_page, total_pages)
		# Optionally show/hide pagination controls based on total assets
	if total_assets > api.PAGE_SIZE_DEFAULT:
		%Pagination.show()
	else:
		%Pagination.hide()
	# Process assets if it's a search result
	if api.current_request == IcosaGalleryAPI.RequestType.SEARCH:
		var assets = api.get_asset_objects_from_response(response)
		# Clear previous assets
		for child in %AssetGrid.get_children():
			child.queue_free()
		# Create new asset thumbnails
		for asset in assets:
			var asset_thumbnail = thumbnail_scene.instantiate() as IcosaGalleryThumbnail
			asset_thumbnail.pressed.connect(select_asset.bind(asset_thumbnail))
			asset_thumbnail.display_name = asset.display_name
			asset_thumbnail.author_name = asset.author_name
			asset_thumbnail.thumbnail_url = asset.thumbnail
			%AssetGrid.add_child(asset_thumbnail)
			var format_index = 0
			for format_type in asset.formats:
				asset_thumbnail.formats.get_popup().add_item(format_type, format_index)
				format_index += 1
			asset_thumbnail.formats.get_popup().id_pressed.connect(download_asset.bind(asset, asset_thumbnail))
			
		_on_asset_columns_value_changed(%AssetColumns.value)

func download_asset(index, asset : IcosaGalleryAPI.Asset, thumbnail : IcosaGalleryThumbnail):
	# Get the format type (e.g., "GLTF2", "OBJ", etc.)
	var format_type = asset.formats.keys()[index]
	
	# Create a sanitized asset name for the directory and file prefix
	# Convert to lowercase for consistent file naming
	var asset_name_sanitized = asset.display_name.validate_filename().to_lower()
	
	# Get the URLs for the selected format
	var download_queue = []
	for urls in asset.formats.values()[index]:
		download_queue.append(urls)
	
	# Show the progress bar before starting downloads
	thumbnail.update_progress(0)
	
	# Create a single HTTPDownload instance for all files
	var download = HTTPDownload.new()
	download.name = "AssetDownload"
	add_child(download)
	
	# Connect signals to the thumbnail's handler methods
	download.download_started.connect(thumbnail._on_download_started)
	download.download_completed.connect(thumbnail._on_download_completed)
	download.queue_completed.connect(thumbnail._on_download_queue_completed)
	download.download_failed.connect(thumbnail._on_download_failed)
	
	# Add each file to the download queue
	var file_index = 0
	for url in download_queue:
		# Create a unique filename with appropriate extension
		var extension = url.get_file().get_extension()
		
		# Determine if this is the main file or a resource file
		var filename
		if file_index == 0 and download_queue.size() > 1:
			# For the main file, use the asset name
			filename = "%s.%s" % [asset_name_sanitized, extension if extension else "bin"]
		else:
			# For resource files, use a more descriptive name to avoid conflicts
			var file_basename = url.get_file().get_basename().to_lower()
			filename = "%s_%s.%s" % [asset_name_sanitized, file_basename, extension if extension else "bin"]
		
		print("Downloading: " + url + " to " + filename)
		
		# Add this file to the download queue
		download.add_to_queue(url, api.web_safe_headers, filename, asset_name_sanitized)
		file_index += 1

func select_asset(selected_thumbnail : Control):
	# Hide all other thumbnails and enlarge the selected one
	for thumbnail in selected_thumbnail.get_parent().get_children():
		thumbnail.hide()
	selected_thumbnail.show()
	selected_thumbnail.custom_minimum_size = size / 1.25
	selected_thumbnail.disabled = true
	%AssetGrid.alignment = FlowContainer.AlignmentMode.ALIGNMENT_CENTER
	chosen_thumbnail = selected_thumbnail
	%GoBack.show()
	%Pagination.hide()
	viewing_single_asset = true

func _on_go_back_pressed():
	viewing_single_asset = false
	%GoBack.hide()
	%Pagination.show()
	chosen_thumbnail.disabled = false
	%AssetGrid.alignment = FlowContainer.AlignmentMode.ALIGNMENT_BEGIN
	for thumbnail in %AssetGrid.get_children():
		thumbnail.custom_minimum_size = Vector2(asset_size, asset_size)
		thumbnail.show()

func _on_resized():
	if viewing_single_asset:
		pass
	else:
		_on_asset_columns_value_changed(%AssetColumns.value)

func _on_asset_columns_value_changed(value):
	if viewing_single_asset: 
		pass
	else:
		var width = size.x
		var each = width / value - 10
		for asset in %AssetGrid.get_children():
			asset.custom_minimum_size = Vector2(each, each)
			asset.size = Vector2(each, each)

# Pagination Button Logic
func _refresh_pagination_buttons(current, total_pages):
	# Clear previous pagination buttons
	for child in %PageNumbers.get_children():
		child.queue_free()
	
	# Get the page labels to show (numbers or "...")
	var page_buttons = get_pagination_buttons(current, total_pages)
	for page_label in page_buttons:
		var page_button = Button.new()
		# If the label is a number, configure button to be clickable
		if typeof(page_label) == TYPE_INT:
			page_button.text = str(page_label)
			page_button.toggle_mode = true
			# Disable button if it's the current page
			page_button.disabled = (page_label == current)
			page_button.toggled.connect(on_page_number_pressed.bind(page_label, page_button))
		else:
			# If it's a string (i.e. "..."), show a disabled button
			page_button.text = "..."
			page_button.disabled = true
		
		%PageNumbers.add_child(page_button)
	


func get_pagination_buttons(current, total_pages):
	var pages = []
	
	if total_pages <= 6:
		# If there are 6 or fewer pages, show all pages
		for i in range(1, total_pages + 1):
			pages.append(i)
	else:
		# When there are more than 6 pages, dynamically choose which pages to show
		if current <= 3:
			# Show first four pages, ellipsis, and last page
			pages = [1, 2, 3, 4, "...", total_pages]
		elif current >= total_pages - 2:
			# Show first page, ellipsis, and last four pages
			pages = [1, "...", total_pages - 3, total_pages - 2, total_pages - 1, total_pages]
		else:
			# Show first page, ellipsis, current -1, current, current +1, ellipsis, and last page
			pages = [1, "...", current - 1, current, current + 1, "...", total_pages]
			
	return pages

func on_page_number_pressed(toggled, page_number, page_button):
	current_page = page_number
	current_search.page_token = page_number
	
	# Refresh pagination buttons so the current page is highlighted
	var total_pages = api.get_pages_from_total_assets(current_search.page_size, api.total_size)
	_refresh_pagination_buttons(current_page, total_pages)
	
	request_new_page()

func _on_previous_page_pressed():
	if current_page > 1:
		current_page -= 1
		current_search.page_token = current_page
		request_new_page()

func _on_next_page_pressed():
	var total_pages = api.get_pages_from_total_assets(current_search.page_size, api.total_size)
	if current_page < total_pages:
		current_page += 1
		current_search.page_token = current_page
		request_new_page()

func request_new_page():
	var url = api.build_query_url_from_search_object(current_search)
	api.current_request = IcosaGalleryAPI.RequestType.SEARCH
	var error = api.request(url)
	if error != OK:
		push_error("Failed to load new page.")
