@tool
class_name IcosaGalleryThumbnail
extends Button

@onready var progress = %Progress
@onready var formats : MenuButton = %Formats 
var thumbnail_request := HTTPRequest.new()

var display_name : String : set = set_display_name
func set_display_name(new_name):
	display_name = new_name
	%AssetName.text = display_name
	
var author_name : String : set = set_author_name
func set_author_name(new_name):
	author_name = new_name
	%AuthorName.text = author_name

var thumbnail_url = ""

func kill_tween(tween : Tween):
	tween.kill()

func fade_in():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1,1,1,1), 1.0)
	tween.finished.connect(kill_tween.bind(tween))

func _ready():
	var popup = %Formats.get_popup() as PopupMenu
	popup.index_pressed.connect(download_popup_pressed)
	add_child(thumbnail_request)
	thumbnail_request.request_completed.connect(thumbnail_request_completed)
	var error = thumbnail_request.request(thumbnail_url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func thumbnail_request_completed(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Image couldn't be downloaded. Try a different image.")
		## TODO add something for no image.
	var image = Image.new()
	var error = image.load_png_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")
	var texture = ImageTexture.create_from_image(image)
	%ThumbnailImage.texture = texture
	fade_in()
	thumbnail_request.queue_free()

func _on_download_queue_completed():
	%Progress.hide()
	%BufferingIcon.hide()
	%DownloadFinished.show()

func update_progress(current_file: int, total_files: int):
	%FilesDownloaded.value = current_file
	%FilesDownloaded.max_value = total_files
	%ProgressLabel.text = "%s/%s" % [current_file, total_files]

func download_popup_pressed(index_pressed):
	%Progress.show()
	%Formats.hide() # hide the download button.

func update_bytes_progress(current_bytes: int, total_bytes: int):
	%DownloadProgress.show()
	%DownloadProgress.value = current_bytes
	%DownloadProgress.max_value = total_bytes
