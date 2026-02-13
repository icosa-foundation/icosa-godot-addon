@tool
class_name IcosaThumbnail
extends Button
@onready var root_directory = "res://" if Engine.is_editor_hint() else "user://"
@onready var progress = %Progress
#@onready var formats : MenuButton = %Formats 
var thumbnail_request := HTTPRequest.new()
var asset : IcosaAsset
var is_preview = false

var download_urls: Array
var current_download_url:= 1
var download_urls_size: int
signal download_requested(urls : Array)
signal delete_requested(asset_url)
var downloaded_bytes : int = 0

signal author_id_clicked(author_id : String)

var is_downloaded = false
var preview_scene_path = ""
var no_thumbnail_image = false
var on_author_profile = false

func init(chosen_asset : IcosaAsset):
	asset = chosen_asset

func _ready():

	load_license_sticker()

	%AssetName.text = asset.display_name
	var url_bbcode = "[url=%s]%s[url]"
	var author_link = url_bbcode % [asset.author_id, asset.author_name]
	%AuthorName.text = author_link
	%Description.text = asset.description

	if asset.user_asset:
		%DeleteAsset.show()

	# Connect the AddToCollection menu button
	if has_node("%AddToCollection"):
		var menu_button = %AddToCollection as MenuButton
		menu_button.about_to_popup.connect(_on_add_to_collection_about_to_popup)
	
	if is_preview:
		disabled = true
		%Description.show()
		%ThumbnailImage.expand_mode = TextureRect.ExpandMode.EXPAND_FIT_WIDTH_PROPORTIONAL
		%ThumbnailImage.stretch_mode = TextureRect.StretchMode.STRETCH_KEEP_ASPECT_CENTERED
		
		if is_downloaded:
			%ThumbnailImage.hide()
			%Preview.show()
	
	if on_author_profile:
		%AuthorName.hide()
		
	
	add_child(thumbnail_request)
	thumbnail_request.request_completed.connect(thumbnail_request_completed)
	if !asset.thumbnail_url.is_empty():
		disabled = false
		
		var error = thumbnail_request.request(asset.thumbnail_url)
		if error != OK:
			push_error("An error occurred in the HTTP request.")
	
	
func thumbnail_request_completed(result, response_code, headers, body : PackedByteArray):
	var is_png = true
	for header in headers:
		if header.begins_with("Content-Type: "):
			var type = header.replace("Content-Type: image/", "")
			if type == "jpeg":
				print("TRYING JPEG")
				is_png = false
			
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Image couldn't be downloaded. Try a different image.")
	## TODO: Error spam happens here when response is not an image.
	
	var image = Image.new()
	if is_png:
		var error = image.load_png_from_buffer(body)
		if error != OK:
			push_error("Couldn't load the image.")
	else:
		## TODO: ask if there are any other thumbnail image formats
		var error = image.load_jpg_from_buffer(body)
		if error != OK:
			push_error("Couldn't load the image.")
			
			
	var texture = ImageTexture.create_from_image(image)
	%ThumbnailImage.texture = texture
	# cannot be clicked if has no image!
	if !is_preview:
		disabled = false
	thumbnail_request.queue_free()
	
	
func _on_download_queue_completed():
	%Progress.hide()
#	%BufferingIcon.hide()
	%Download.hide()
	%DownloadFinished.show()
	
func downlad_failed():
	%DownloadFailed.show()

func update_progress():
	if !download_urls.is_empty():
		%FilesDownloaded.value = current_download_url
		%FilesDownloaded.max_value = download_urls_size
		%ProgressLabel.text = "%s/%s" % [current_download_url, download_urls_size]

	else:
		_on_download_queue_completed()
	
func start_download_progress():
	%Progress.show()
	#%Formats.hide() # hide the download button.
	%ProgressLabel.text = "Downloading.."
	
#func update_bytes_progress(current_bytes: int, total_bytes: int):
	#%DownloadProgress.show()
	#%DownloadProgress.value = current_bytes
	#%DownloadProgress.max_value = total_bytes


func _on_download_pressed():
	var formats = Dictionary(asset.formats)

	# Determine which format to download
	# Use preferred format if available and it's GLTF or OBJ, otherwise fall back to GLTF2
	var format_to_download = "GLTF2"  # Default fallback
	var supported_formats = ["GLTF2", "OBJ"]

	# Prefer the marked format if it's one of the supported formats
	if asset.preferred_format != "" and asset.preferred_format in formats and asset.preferred_format in supported_formats:
		format_to_download = asset.preferred_format
	# Otherwise use GLTF2 if available
	elif "GLTF2" in formats:
		format_to_download = "GLTF2"
	# Fall back to OBJ if GLTF2 not available
	elif "OBJ" in formats:
		format_to_download = "OBJ"
	else:
		push_error("Neither GLTF2 nor OBJ format available for asset '%s'" % asset.display_name)
		return

	var download_urls_by_format = formats[format_to_download]
	download_urls = download_urls_by_format

	# Get the browser instance by searching up the tree
	var browser = get_tree().root.find_child("IcosaBrowser", true, false) as IcosaBrowser
	if not browser:
		push_error("Could not find IcosaBrowser in the scene tree")
		return

	download_urls_size = download_urls.size()

	# Connect to download queue signals
	if not browser.download_queue.download_completed.is_connected(_on_queue_downloaded):
		browser.download_queue.download_completed.connect(_on_queue_downloaded)
	if not browser.download_queue.file_downloaded.is_connected(_on_file_downloaded):
		browser.download_queue.file_downloaded.connect(_on_file_downloaded)

	# Add this download to the queue
	browser.download_queue.queue_download(
		self,
		download_urls_by_format,
		asset.display_name,
		asset.id.replace("assets/", "")
	)

	start_download_progress()
	update_progress()

func _on_file_downloaded(asset_name: String, path : String):
	if asset_name != asset.display_name:
		return
	if path.ends_with(".gltf"):
		preview_scene_path = path
	current_download_url += 1
	update_progress()

func load_license_sticker():
	var sticker_table = {
		"UNKNOWN"                         : "cc",#"unknown",
		"REMIXABLE"                       : "remix",   
		"ALL_CC"                          : "cc",
		"ALL_RIGHTS_RESERVED"             : "cc",  
		"CREATIVE_COMMONS_BY_3_0"         : "by",                 
		"CREATIVE_COMMONS_BY_ND_3_0"      : "nd",                    
		"CREATIVE_COMMONS_BY_4_0"         : "by",                 
		"CREATIVE_COMMONS_BY_ND_4_0"      : "nd",                   
		"CREATIVE_COMMONS_BY"             : "by",             
		"CREATIVE_COMMONS_BY_ND"          : "nd",                
		"CREATIVE_COMMONS_0"              : "zero",            
		"CC0"                             : "zero",            
	}
	%License.tooltip_text = asset.license
	%License.texture = load("res://addons/icosa/icons/cc/"+sticker_table[asset.license]+".svg")

func _on_queue_downloaded(asset_name: String):
	if asset_name != asset.display_name:
		return
	is_downloaded = true
	_on_download_queue_completed()
	await get_tree().process_frame
	if Engine.is_editor_hint():
		await EditorInterface.get_resource_filesystem().scan()
		var toaster = EditorInterface.get_editor_toaster()
		toaster.push_toast("Downloaded: ", preview_scene_path)
	
	## TODO: 3D preview code (terrible, but working)
	#if is_preview:
		#%ThumbnailImage.hide()
		#%Preview.show()
		#print(preview_scene_path)
		#var gltf_document_load = GLTFDocument.new()
		#var gltf_state_load = GLTFState.new()
		#var error = gltf_document_load.append_from_file(preview_scene_path, gltf_state_load)
		#if error == OK:
			#var gltf_scene_root_node = gltf_document_load.generate_scene(gltf_state_load)
			#%Root3D.add_child(gltf_scene_root_node)
			#
		#else:
			#printerr("Couldn't load glTF scene (error code: %s)." % error_string(error))
		#
		##%Root3D.print_tree_pretty()
		#
		#var content = %Root3D.get_node("scene").get_node("Node").get_node("Node2").get_node("Node3")
		#for node in content.get_children():
			#if node is MeshInstance3D:
				#%Orbit.target = node.position
		#var cam1 = %Root3D.get_node("scene").get_node("Node").get_node("Node2").get_node("Node3").get_node("render_camera_n3d")
		#var cam2 = %Root3D.get_node("scene").get_node("Camera")
		#%Orbit.camera = cam2
		#cam2.current = true
	
#func _process(delta):
	#var downloaded_bytes = download.get_downloaded_bytes()
	#var current_file_bytes = download

func _on_delete_asset_pressed():
	delete_requested.emit(asset.id)

func _on_author_name_meta_clicked(meta):
	author_id_clicked.emit(str(meta), asset.author_name)

## no endpoint for this, it could be nice though.
func _on_like_pressed():
	pass # Replace with function body.

func _on_add_to_collection_about_to_popup():
	var menu_button = %AddToCollection as MenuButton
	var popup = menu_button.get_popup()
	popup.clear()

	# Get the browser (same way as download button does)
	var browser = get_tree().root.find_child("IcosaBrowser", true, false) as IcosaBrowser
	if not browser:
		popup.add_item("Browser not found")
		popup.set_item_disabled(0, true)
		return

	# Find IcosaUserTab in the browser's children recursively
	var user_tab: IcosaUserTab = _find_user_tab(browser)
	if not user_tab:
		popup.add_item("Not logged in")
		popup.set_item_disabled(0, true)
		return

	var collections = user_tab.get_user_collections()
	if collections.is_empty():
		popup.add_item("No collections yet")
		popup.set_item_disabled(0, true)
		return

	# Add each collection to the menu
	for i in range(collections.size()):
		var collection = collections[i]
		popup.add_item(collection.collection_name, i)

	# Connect the menu item selection
	if not popup.id_pressed.is_connected(_on_collection_selected):
		popup.id_pressed.connect(_on_collection_selected)

func _on_collection_selected(id: int):
	var browser = get_tree().root.find_child("IcosaBrowser", true, false) as IcosaBrowser
	if not browser:
		return

	var user_tab: IcosaUserTab = _find_user_tab(browser)
	if not user_tab:
		return

	var collections = user_tab.get_user_collections()
	if id < collections.size():
		var collection = collections[id]
		print("Adding asset ", asset.display_name, " to collection ", collection.collection_name)
		user_tab.add_asset_to_collection(asset.id, collection)

func _find_user_tab(node: Node) -> IcosaUserTab:
	"""Recursively find the IcosaUserTab node"""
	if node is IcosaUserTab:
		return node

	for child in node.get_children():
		var result = _find_user_tab(child)
		if result:
			return result

	return null
