class_name HTTPDownload
extends HTTPRequest

signal download_completed(save_path: String, success: bool)

var _save_path: String
var _filename: String
var _url: String

func _init(url: String, filename: String, save_dir: String = "res://addons/icosa-gallery/downloads/"):
	_url = url
	_filename = filename
	_save_path = save_dir + filename
	
	# Ensure the download directory exists
	var dir = DirAccess.open("res://addons/icosa-gallery")
	if !dir.dir_exists("downloads"):
		dir.make_dir("downloads")
	
	# Connect the signal
	request_completed.connect(_on_request_completed)

func _ready():
	# Start the download once the node is in the scene tree
	var error = request(_url)
	if error != OK:
		push_error("Failed to start download: " + str(error))
		queue_free()

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Download failed with result: " + str(result))
		download_completed.emit("", false)
		queue_free()
		return
	
	# Save the file
	var file = FileAccess.open(_save_path, FileAccess.WRITE)
	if file:
		file.store_buffer(body)
		download_completed.emit(_save_path, true)
	else:
		push_error("Failed to save file: " + str(FileAccess.get_open_error()))
		download_completed.emit("", false)
	
	queue_free() 
