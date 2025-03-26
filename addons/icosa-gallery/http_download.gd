class_name HTTPDownload
extends HTTPRequest

signal download_started()
signal download_completed()
signal queue_completed()
signal download_failed(error: String)

var queue: Array = []
var current_request: HTTPRequest = null

# Constructor for backward compatibility
func _init(url: String = "", headers: PackedStringArray = PackedStringArray(), filename: String = "", directory: String = "", root_dir: String = "res://downloads/"):
	print("HTTPDownload _init called with url: ", url, " filename: ", filename)
	if url != "" and filename != "":
		# If parameters are provided, add to queue automatically
		add_to_queue(url, headers, filename, directory, root_dir)

func add_to_queue(url: String, headers: PackedStringArray, filename: String, directory: String, root_dir: String = "res://downloads/") -> void:
	print("Adding download to queue: ", {"url": url, "filename": filename, "directory": directory, "root_dir": root_dir})
	queue.push_back({
		"url": url,
		"headers": headers,
		"filename": filename,
		"directory": directory,
		"root_dir": root_dir
	})
	print("Queue size after adding: ", queue.size())
	if queue.size() == 1 and not current_request:
		print("Queue was empty and no current request exists. Starting next download.")
		_start_next_download()

func _start_next_download() -> void:
	if queue.is_empty():
		print("Queue is empty.")
		if current_request != null:
			print("Current request exists; emitting queue_completed signal.")
			emit_signal("queue_completed")
		current_request = null
		return

	var download = queue[0]
	print("Starting next download. Queue front: ", download)
	current_request = HTTPRequest.new()
	add_child(current_request)
	current_request.request_completed.connect(_on_request_completed)
	
	# Ensure directories exist
	var full_path = download.root_dir.path_join(download.directory)
	print("Ensuring directory exists: ", full_path)
	DirAccess.make_dir_recursive_absolute(full_path)

	var error = current_request.request(download.url, download.headers, HTTPClient.METHOD_GET)
	print("HTTP request sent. Error code: ", error)
	if error != OK:
		var err_msg = "Failed to start download: " + str(error)
		print(err_msg)
		emit_signal("download_failed", err_msg)
		queue.pop_front()
		_start_next_download()
	else:
		print("Download started successfully.")
		emit_signal("download_started")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("Request completed callback triggered.")
	print("Result: ", result, " Response Code: ", response_code)
	print("Headers: ", headers)
	print("Body size: ", body.size(), " bytes")
	
	if result != HTTPRequest.RESULT_SUCCESS:
		var err_msg = "Download failed with error: " + str(result)
		print(err_msg)
		emit_signal("download_failed", err_msg)
	else:
		var download = queue[0]
		var file_path = download.root_dir.path_join(download.directory).path_join(download.filename)
		print("Saving file to path: ", file_path)
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			file.store_buffer(body)
			file.close()
			print("File saved successfully: ", file_path)
			emit_signal("download_completed")
		else:
			var err_msg = "Failed to save file: " + file_path
			print(err_msg)
			emit_signal("download_failed", err_msg)

	queue.pop_front()
	print("Download removed from queue. Remaining queue size: ", queue.size())
	_start_next_download()
