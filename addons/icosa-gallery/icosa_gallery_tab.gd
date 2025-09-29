## icosa tab
## general purpose tab that displays assets.
@tool
extends Control
#class_name IcosaTab
## which kind of tab to display, default being a search tab
enum TabMode {SEARCH, USER_PROFILE, USER_LIKED}
var mode : TabMode = TabMode.SEARCH

var api = IcosaGalleryAPI.new()
@onready var thumbnail_scene := preload("res://addons/icosa-gallery/thumbnail.tscn")

var current_search: IcosaGalleryAPI.Search = IcosaGalleryAPI.create_default_search()
var current_page = 1
var total_assets = 0

# UI References
@onready var search_bar = %SearchBar
@onready var search_options_menu = %SearchOptionsMenu
@onready var asset_grid = %AssetGrid
@onready var assets_found = %AssetsFound
@onready var no_assets_label = %NoAssetsLabel
@onready var logo = %Logo
@onready var pagination = %Pagination
@onready var previous_page = %PreviousPage
@onready var page_numbers = %PageNumbers
@onready var next_page = %NextPage

# Search option references
@onready var search_author: LineEdit = %SearchAuthor
@onready var search_description: LineEdit = %SearchDescription
@onready var gltf_2: CheckButton = %GLTF2
@onready var obj: CheckButton = %OBJ
@onready var fbx: CheckButton = %FBX
@onready var remixable: CheckButton = %REMIXABLE
@onready var nd: CheckButton = %ND
@onready var min_triangles: SpinBox = %MinTriangles
@onready var max_triangles: SpinBox = %MaxTriangles
@onready var curated: CheckButton = %CURATED
@onready var page_size: SpinBox = %PageSize
@onready var order: OptionButton = %ORDER

signal search_requested(url, headers, method, body)
signal model_downloaded(model_file)
signal tab_title_changed(title)

func _ready():
	# Connect signals
	search_bar.text_submitted.connect(_on_search_bar_text_submitted)
	previous_page.pressed.connect(_on_previous_page_pressed)
	next_page.pressed.connect(_on_next_page_pressed)
	
	# Connect search option signals
	search_author.text_changed.connect(_on_search_author_text_changed)
	search_description.text_changed.connect(_on_search_description_text_changed)
	gltf_2.toggled.connect(_on_gltf_2_toggled)
	obj.toggled.connect(_on_obj_toggled)
	fbx.toggled.connect(_on_fbx_toggled)
	remixable.toggled.connect(_on_remixable_toggled)
	nd.toggled.connect(_on_nd_toggled)
	min_triangles.value_changed.connect(_on_min_triangles_value_changed)
	max_triangles.value_changed.connect(_on_max_triangles_value_changed)
	curated.toggled.connect(_on_curated_toggled)
	page_size.value_changed.connect(_on_page_size_value_changed)
	search_author.text_submitted.connect(_on_search_author_text_submitted)
	search_description.text_submitted.connect(_on_search_description_text_submitted)
	
	# Initialize order options
	_initialize_order_options()
	perform_search("")


func _initialize_order_options():
	for ordering in IcosaGalleryAPI.order_by:
		order.add_item(ordering)
	order.item_selected.connect(_on_order_item_selected)

func perform_search(keywords: String = ""):
	current_search.keywords = keywords
	current_page = 1
	current_search.page_token = current_page
	
	var url = api.build_query_url_from_search_object(current_search)
	search_requested.emit(url, PackedStringArray(), HTTPClient.METHOD_GET, "")
	
	# Update tab title
	var title = "Search: " + current_search.keywords
	if title.length() > 20:
		title = title.substr(0, 17) + "..."
	tab_title_changed.emit(title)

func handle_search_response(response):
	if "totalSize" in response:
		total_assets = response["totalSize"]
		_update_asset_display(total_assets)
	
	# Update pagination
	if total_assets > 0:
		var total_pages = api.get_pages_from_total_assets(current_search.page_size, total_assets)
		_refresh_pagination_buttons(current_page, total_pages)
		pagination.visible = total_assets > current_search.page_size
	else:
		pagination.hide()
	
	# Process and display assets
	var assets = api.get_asset_objects_from_response(response)
	_display_assets(assets)

func _update_asset_display(total_assets):
	if total_assets == 0:
		logo.show()
		no_assets_label.show()
		assets_found.hide()
	else:
		logo.hide()
		no_assets_label.hide()
		assets_found.show()
		assets_found.text = "Total assets found: " + str(int(total_assets))

func _display_assets(assets):
	# Clear previous assets
	for child in asset_grid.get_children():
		child.queue_free()
	
	# Create new asset thumbnails
	for asset in assets:
		var asset_thumbnail = thumbnail_scene.instantiate()
		asset_thumbnail.pressed.connect(_on_thumbnail_pressed.bind(asset_thumbnail))
		asset_thumbnail.display_name = asset.display_name
		asset_thumbnail.author_name = asset.author_name
		asset_thumbnail.description = asset.description
		asset_thumbnail.license = asset.license
		asset_thumbnail.thumbnail_url = asset.thumbnail
		asset_grid.add_child(asset_thumbnail)
		
		# Add format options
		var format_index = 0
		for format_type in asset.formats:
			if format_type == "GLTF2":
				var svg_code = '<svg width="16" height="16"><circle cx="12" cy="6" r="12" fill="green"/></svg>'
				var image = Image.new()
				var icon = image.load_svg_from_string(svg_code, 1.0)
				asset_thumbnail.formats.get_popup().add_icon_item(image, format_type)
			else:
				asset_thumbnail.formats.get_popup().add_item(format_type, format_index)
			format_index += 1
		asset_thumbnail.formats.get_popup().id_pressed.connect(_on_format_selected.bind(asset, asset_thumbnail))

func _on_thumbnail_pressed(thumbnail):
	# Emit signal to browser to handle tab creation
	pass  # This will be handled by the browser

func _on_format_selected(index, asset, thumbnail):
	# Handle asset download
	var format_type = asset.formats.keys()[index]
	var download_queue = []
	
	for urls in asset.formats.values()[index]:
		download_queue.append(urls)
	
	var download = IcosaDownload.new()
	get_tree().current_scene.add_child(download)
	
	var processed_queue = []
	for url in download_queue:
		url = url as String
		var address = url.split("https://")
		if address.size() > 2:
			url = "https://" + address[1] + address[2].uri_encode()
			processed_queue.append(url)
	
	var asset_name_sanitized = asset.display_name.validate_filename().to_lower()
	download.asset_name = asset_name_sanitized
	download.asset_id = asset.id
	download.url_queue = processed_queue
	
	download.files_downloaded.connect(thumbnail.update_progress)
	download.download_progress.connect(thumbnail.update_bytes_progress)
	download.download_queue_completed.connect(thumbnail._on_download_queue_completed)
	download.host_offline.connect(_on_host_offline)
	
	var id = download.asset_id.split("/")[1]
	var model_file = download.root_directory + "icosa_downloads/" + download.asset_name + "_" + id + "/" + IcosaDownload.file_from_url(processed_queue[0])
	download.download_queue_completed.connect(func():
		model_downloaded.emit(model_file)
	)
	
	download.start()

func _refresh_pagination_buttons(current, total_pages):
	for child in page_numbers.get_children():
		child.queue_free()
	
	var page_buttons = _get_pagination_buttons(current, total_pages)
	for page_label in page_buttons:
		var page_button = Button.new()
		if typeof(page_label) == TYPE_INT:
			page_button.text = str(page_label)
			page_button.toggle_mode = true
			page_button.disabled = (page_label == current)
			page_button.toggled.connect(_on_page_number_pressed.bind(page_label, page_button))
		else:
			page_button.text = "..."
			page_button.disabled = true
		page_numbers.add_child(page_button)

func _get_pagination_buttons(current, total_pages):
	var pages = []
	
	if total_pages <= 6:
		for i in range(1, total_pages + 1):
			pages.append(i)
	else:
		if current <= 3:
			pages = [1, 2, 3, 4, "...", total_pages]
		elif current >= total_pages - 2:
			pages = [1, "...", total_pages - 3, total_pages - 2, total_pages - 1, total_pages]
		else:
			pages = [1, "...", current - 1, current, current + 1, "...", total_pages]
			
	return pages

# Signal handlers
func _on_search_bar_text_submitted(new_text):
	perform_search(new_text)

func _on_previous_page_pressed():
	if current_page > 1:
		current_page -= 1
		current_search.page_token = current_page
		_request_new_page()

func _on_next_page_pressed():
	var total_pages = api.get_pages_from_total_assets(current_search.page_size, total_assets)
	if current_page < total_pages:
		current_page += 1
		current_search.page_token = current_page
		_request_new_page()

func _on_page_number_pressed(toggled, page_number, page_button):
	current_page = page_number
	current_search.page_token = page_number
	var total_pages = api.get_pages_from_total_assets(current_search.page_size, total_assets)
	_refresh_pagination_buttons(current_page, total_pages)
	_request_new_page()

func _request_new_page():
	var url = api.build_query_url_from_search_object(current_search)
	search_requested.emit(url, PackedStringArray(), HTTPClient.METHOD_GET, "")

# Search option handlers (same as your existing ones)
func _on_search_author_text_changed(new_text):
	current_search.author_name = new_text

func _on_search_description_text_changed(new_text):
	current_search.description = new_text

func _on_gltf_2_toggled(toggled_on):
	if toggled_on:
		current_search.formats.append("GLTF2")
		current_search.formats.erase("-GLTF2")
	else:
		current_search.formats.append("-GLTF2")
		current_search.formats.erase("GLTF2")

func _on_obj_toggled(toggled_on):
	if toggled_on:
		current_search.formats.append("OBJ")
		current_search.formats.erase("-OBJ")
	else:
		current_search.formats.append("-OBJ")
		current_search.formats.erase("OBJ")

func _on_fbx_toggled(toggled_on):
	if toggled_on:
		current_search.formats.append("FBX")
		current_search.formats.erase("-FBX")
	else:
		current_search.formats.append("-FBX")
		current_search.formats.erase("FBX")

func _on_remixable_toggled(toggled_on):
	current_search.license.append("REMIXABLE")

func _on_nd_toggled(toggled_on):
	current_search.license.append("ALL_CC")

func _on_min_triangles_value_changed(value):
	current_search.triangle_count_min = value

func _on_max_triangles_value_changed(value):
	current_search.triangle_count_max = value

func _on_curated_toggled(toggled_on):
	current_search.curated = toggled_on

func _on_page_size_value_changed(value):
	current_search.page_size = value

func _on_search_author_text_submitted(new_text):
	perform_search(current_search.keywords)

func _on_search_description_text_submitted(new_text):
	perform_search(current_search.keywords)

func _on_order_item_selected(index):
	current_search.order.append(order.get_item_text(index))


func _handle_search_response(response):
		
	var total_assets
	if "totalSize" in response:
		total_assets = response["totalSize"]
		api.total_size = total_assets
	
	# Update asset found / not found labels
	if total_assets == 0:
		%Logo.show()
		%NoAssetsLabel.show()
		%AssetsFound.hide()
	else:
		%Logo.hide()
		%NoAssetsLabel.hide()
		%AssetsFound.show()
		if total_assets is int:
			%AssetsFound.text = "Total assets found: " + str(int(total_assets))
	
	# Create/update pagination buttons
	if total_assets is int and total_assets > 0:
		var total_pages = api.get_pages_from_total_assets(api.current_search.page_size, total_assets)
		_refresh_pagination_buttons(api.page, total_pages)
		
		# Show/hide pagination controls based on total assets
		if total_assets > api.current_search.page_size:
			%Pagination.show()
		else:
			%Pagination.hide()
	
	# Process assets
	var assets = api.get_asset_objects_from_response(response)
	_display_assets(assets)

func download_asset(index, asset : IcosaGalleryAPI.Asset, thumbnail : IcosaGalleryThumbnail):
	# Get the format type (e.g., "GLTF2", "OBJ", etc.)
	var format_type = asset.formats.keys()[index]
	
	# Create a sanitized asset name for the directory and file prefix
	var asset_name_sanitized = asset.display_name.validate_filename().to_lower()
	
	# Get the URLs for the selected format
	var download_queue = []
	for urls in asset.formats.values()[index]:
		download_queue.append(urls)
	
	# Create a single HTTPDownload instance for all files
	var download = IcosaDownload.new()
	add_child(download)
	
	var processed_queue = []
	for url in download_queue:
		url = url as String
		var address = url.split("https://")
		if address.size() > 2:
			url = "https://" + address[1] + address[2].uri_encode()
			processed_queue.append(url)
	
	# Set the asset name for the download directory
	download.asset_name = asset_name_sanitized
	download.asset_id = asset.id
	download.url_queue = processed_queue
	
	# Connect signals for progress tracking
	download.files_downloaded.connect(thumbnail.update_progress)
	download.download_progress.connect(thumbnail.update_bytes_progress)
	download.download_queue_completed.connect(thumbnail._on_download_queue_completed)
	
	var id = download.asset_id.split("/")[1]
	var model_file = download.root_directory + "icosa_downloads/" + download.asset_name + "_" + id + "/" + IcosaDownload.file_from_url(processed_queue[0])
	download.download_queue_completed.connect(func():
		emit_signal("model_downloaded", model_file)
	)
	
	#download.host_offline.connect(show_host_offline_popup)
	# Start the download process
	download.start()

var cross_icon = load("res://addons/icosa-gallery/icons/close.svg")
func select_asset(selected_thumbnail : IcosaGalleryThumbnail):
	var thumb = selected_thumbnail.duplicate()
	thumb.is_preview = true
	thumb.name = selected_thumbnail.display_name
	
	# Insert before the add tab
	var add_tab_index = %Tabs.get_tab_count() - 1
	%Tabs.add_child(thumb)
	%Tabs.move_child(thumb, add_tab_index)
	%Tabs.set_tab_button_icon(%Tabs.get_tab_count() - 2, cross_icon)
	%Tabs.current_tab = %Tabs.get_tab_count() - 2



func _on_host_offline():
	%HostOffline.show()
