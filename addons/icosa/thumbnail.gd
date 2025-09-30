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
signal download_requested(urls : Array[String])
signal delete_requested(asset_url)


var is_downloaded = false
var preview_scene_path = ""
var no_thumbnail_image = false


func init(chosen_asset : IcosaAsset):
	asset = chosen_asset

func _ready():
	
	load_license_sticker()
	
	%AssetName.text = asset.display_name
	%AuthorName.text = asset.author_name
	%Description.text = asset.description
	
	if asset.user_asset:
		%DeleteAsset.show()
	
	if is_preview:
		disabled = true
		%Description.show()
		%ThumbnailImage.expand_mode = TextureRect.ExpandMode.EXPAND_FIT_WIDTH_PROPORTIONAL
		%ThumbnailImage.stretch_mode = TextureRect.StretchMode.STRETCH_KEEP_ASPECT_CENTERED
		
		if is_downloaded:
			%ThumbnailImage.hide()
			%Preview.show()

	add_child(thumbnail_request)
	thumbnail_request.request_completed.connect(thumbnail_request_completed)
	if !asset.thumbnail_url.is_empty():
		disabled = false
		
		var error = thumbnail_request.request(asset.thumbnail_url)
		if error != OK:
			push_error("An error occurred in the HTTP request.")
	
	
func thumbnail_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Image couldn't be downloaded. Try a different image.")
	var image = Image.new()
	var error = image.load_png_from_buffer(body)
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
	%BufferingIcon.hide()
	%DownloadFinished.show()

func downlad_failed():
	%DownloadFailed.show()

func update_progress(current_file: int, total_files: int):
	%FilesDownloaded.value = current_file
	%FilesDownloaded.max_value = total_files
	%ProgressLabel.text = "%s/%s" % [current_file, total_files]
	
func download_popup_pressed(index_pressed):
	%Progress.show()
	%Formats.hide() # hide the download button.
	%ProgressLabel.text = "Downloading.."
	
#func update_bytes_progress(current_bytes: int, total_bytes: int):
	#%DownloadProgress.show()
	#%DownloadProgress.value = current_bytes
	#%DownloadProgress.max_value = total_bytes


func _on_download_pressed():
	var formats = Dictionary(asset.formats)
	var gltf_urls = formats["GLTF2"]
	download_urls = gltf_urls
	var download = IcosaDownload.new()
	add_child(download)
	download.url_queue = download_urls
	download.download_queue_completed.connect(_on_queue_downloaded)
	download.file_downloaded_to_path.connect(_on_file_downloaded)
	download.start_next_download()

func _on_file_downloaded(path : String):
	if path.ends_with(".gltf"):
		preview_scene_path = path
	print(path)

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

func _on_queue_downloaded(model_file):
	is_downloaded = true

	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
	
	
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
	


func _on_delete_asset_pressed():
	delete_requested.emit(asset.id)
