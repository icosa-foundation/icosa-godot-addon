class_name HTTPDownload
extends HTTPClient

signal bytes_received(bytes: int, total_bytes: int)
signal download_completed(save_path: String, success: bool)

var _save_path: String
var _filename: String
var _url: String
var _total_size: int = 0
var _downloaded_size: int = 0
var _file: FileAccess
var _timer: Timer

func _init(
	url: String, 
	headers: Array[String], 
	filename: String,  
	download_directory: String, 
	root_directory: String = "res://downloads/"
): 
	_url = url
	_filename = filename
	_save_path = root_directory + download_directory + filename
	
	# Ensure directories exist
	if !DirAccess.dir_exists_absolute(root_directory):
		DirAccess.make_dir_absolute(root_directory)
	var dir = DirAccess.open(root_directory)
	if !dir.dir_exists(download_directory):
		dir.make_dir(download_directory)

	# Open file for writing
	_file = FileAccess.open(_save_path, FileAccess.WRITE)
	if _file == null:
		push_error("Failed to open file for writing: " + _save_path)
		return

	# Start HTTP request
	download_completed.connect(on_download_completed)
	
	var hostname = url.split("/")[2]
	
	connect_to_host(hostname)
	#var error = connect_to_host()
	request(HTTPClient.METHOD_GET, url, headers, "")

	# Start polling.
	poll()

func exhaustive_poll() -> void:
	# Use a loop to continuously poll until download finishes or an error occurs.
	while true:
		var status = get_status()
		match status:
			HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_REQUESTING:
				# The request is still being processed. Call poll() and yield briefly.
				poll()
			HTTPClient.STATUS_BODY:
				# Read all available data chunks.
				while true:
					var chunk: PackedByteArray = read_response_body_chunk()
					if chunk.size() == 0:
						break  # No more data immediately available.
					_downloaded_size += chunk.size()
					_file.store_buffer(chunk)
					# Emit signal with current progress.
					# (If _total_size is unknown, use a fallback value like 1 to avoid division errors.)
					bytes_received.emit(_downloaded_size, (_total_size))
				
				# If the response is fully received, then finish.
				# Depending on your server the end might be signaled by get_status() changing
				# or by has_response() returning true.
				if has_response():
					_file.close()
					download_completed.emit(_save_path, true)
					return
			HTTPClient.STATUS_DISCONNECTED:
				# Finished (or closed by the server). Assume success if response exists.
				_file.close()
				download_completed.emit(_save_path, true)
				return
			HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
				# Error states – close file and emit failure.
				if _file:
					_file.close()
				download_completed.emit(_save_path, false)
				return
			_:
				# Other statuses can be handled or simply ignored.
				pass
		
		# Brief delay to avoid locking the engine. Adjust the delay as needed.
		OS.delay_msec(10)

func get_file_size() -> int:
	var head_client = HTTPClient.new()
	head_client.connect_to_host(_url.get_base_dir())  # Connect to the host
	while head_client.get_status() == HTTPClient.STATUS_CONNECTING or head_client.get_status() == HTTPClient.STATUS_RESOLVING:
		head_client.poll()
	
	# Send a HEAD request
	head_client.request(HTTPClient.METHOD_HEAD, _url, [], "")
	
	while head_client.get_status() == HTTPClient.STATUS_REQUESTING:
		head_client.poll()
	
	# Wait for response
	while head_client.get_status() == HTTPClient.STATUS_BODY:
		head_client.poll()
	
	# Extract content length
	var headers = head_client.get_response_headers_as_dictionary()
	if "Content-Length" in headers:
		_total_size = int(headers["Content-Length"])
	else:
		_total_size = -1  # Unknown size
	
	head_client.close()
	return _total_size


func _update_progress():
	bytes_received.emit(_downloaded_size, _total_size if _total_size > 0 else 1)  # Avoid division by zero

func on_download_completed(path, success: bool):
	if _file:
		_file.close()
	_timer.stop()
	free()
