### OLD SCRIPT!


class_name HTTPDownloadClient
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
	print("[HTTPDownload] Initializing download for: " + url) 
	_url = url
	_filename = filename
	
	# Ensure root directory exists
	if !DirAccess.dir_exists_absolute(root_directory):
		DirAccess.make_dir_absolute(root_directory)
	
	# Handle nested directories
	var full_directory = root_directory
	var dir = DirAccess.open(root_directory)
	
	# Split the download directory into parts to handle nested directories
	var dir_parts = download_directory.split("/", false)
	for part in dir_parts:
		if part.is_empty():
			continue
		
		if !dir.dir_exists(part):
			dir.make_dir(part)
		
		dir.change_dir(part)
		full_directory += part + "/"
	
	# Construct the final save path
	_save_path = full_directory + filename

	# Open file for writing
	print("[HTTPDownload] Opening file for writing: " + _save_path)
	_file = FileAccess.open(_save_path, FileAccess.WRITE)
	if _file == null:
		var error = FileAccess.get_open_error()
		push_error("Failed to open file for writing: " + _save_path + " (Error: " + str(error) + ")")
		return
	else:
		print("[HTTPDownload] File opened successfully: " + _save_path)

	# Start HTTP request
	download_completed.connect(on_download_completed)
	
	# Parse URL to separate host and endpoint
	var ssl = true
	var host = ""
	var port : int = 443  # Default to HTTPS port
	var endpoint = ""

	# Handle web.archive.org URLs properly
	if url.begins_with("https://web.archive.org/web/"):
		# For web.archive.org URLs, we need to keep the original host (web.archive.org)
		# and format the endpoint correctly
		host = "web.archive.org"
		ssl = true
		port = 443
		
		# Extract the timestamp and URL parts from the web.archive.org URL
		var parts = url.split("/web/", true, 1)
		if parts.size() > 1:
			# The endpoint should be /web/ followed by the rest of the URL
			endpoint = "/web/" + parts[1]
		else:
			# Fallback to original URL parsing if format is unexpected
			endpoint = "/" + url.split("/", false, 3)[3]
	elif url.begins_with("https://"):
		ssl = true
		port = 443
		var parts = url.substr(8).split("/", true, 1)
		host = parts[0]
		endpoint = "/" + parts[1] if parts.size() > 1 else "/"
	elif url.begins_with("http://"):
		ssl = false
		port = 80
		var parts = url.substr(7).split("/", true, 1)
		host = parts[0]
		endpoint = "/" + parts[1] if parts.size() > 1 else "/"
	else:
		# Fallback for URLs without protocol
		host = url.split("/")[0]
		endpoint = url.split(host)[1] if url.split(host).size() > 1 else "/"
	
	print("Connecting to: " + host + endpoint + " (SSL: " + str(ssl) + ", Port: " + str(port) + ")")
	
	# Connect to host with proper SSL configuration
	var err = connect_to_host(host, port)
	print("[HTTPDownload] Connection attempt result: " + str(err) + " (" + error_string(err) + ")")
	if err != OK:
		push_error("Failed to connect to host: " + host + " (Error: " + str(err) + ")")
		return
	
	# Wait for connection
	while get_status() == HTTPClient.STATUS_CONNECTING or get_status() == HTTPClient.STATUS_RESOLVING:
		var status = get_status()
		print("[HTTPDownload] Connection status: " + str(status) + " (" + _status_to_string(status) + ")")
		poll()
		OS.delay_msec(100)
	
	var final_status = get_status()
	print("[HTTPDownload] Final connection status: " + str(final_status) + " (" + _status_to_string(final_status) + ")")
	
	if final_status != HTTPClient.STATUS_CONNECTED:
		push_error("Could not connect to host: " + host)
		return
	
	# Make the request
	print("[HTTPDownload] Making GET request to: " + endpoint)
	print("[HTTPDownload] Headers: " + str(headers))
	err = request(HTTPClient.METHOD_GET, endpoint, headers)
	print("[HTTPDownload] Request result: " + str(err) + " (" + error_string(err) + ")")
	if err != OK:
		push_error("Failed to make request: " + endpoint)
		return
	
	# Wait for response headers
	while get_status() == HTTPClient.STATUS_REQUESTING:
		print("[HTTPDownload] Waiting for response headers...")
		poll()
		OS.delay_msec(100)
	
	# Check response code
	var response_code = get_response_code()
	print("[HTTPDownload] Response code: " + str(response_code))
	if response_code != 200:
		push_error("Received non-200 response code: " + str(response_code))
		return
	
	# Create a timer to handle polling
	_timer = Timer.new()
	_timer.wait_time = 0.1  # Poll every 100ms
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	
	# Add the timer to the scene tree
	var root = Engine.get_main_loop().root
	root.add_child(_timer)
	_timer.start()

	# Start polling.
	poll()

func poll():
	# Get file size if not already known
	if _total_size <= 0:
		_total_size = get_file_size()
	
	# Debug response headers
	var headers = get_response_headers_as_dictionary()
	print("[HTTPDownload] Poll - Response headers: " + str(headers))
	
	# Use a loop to continuously poll until download finishes or an error occurs.
	while true:
		var status = get_status()
		print("[HTTPDownload] Poll - Current status: " + str(status) + " (" + _status_to_string(status) + ")")
		
		match status:
			HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_REQUESTING:
				# The request is still being processed. Call poll() and yield briefly.
				print("[HTTPDownload] Poll - Still processing request...")
				poll()
				await OS.delay_msec(100)
			HTTPClient.STATUS_BODY:
				print("[HTTPDownload] Poll - Reading response body chunks...")
				# Read all available data chunks.
				while true:
					var chunk: PackedByteArray = read_response_body_chunk()
					print("[HTTPDownload] Poll - Chunk size: " + str(chunk.size()) + " bytes")
					if chunk.size() == 0:
						print("[HTTPDownload] Poll - No more data available in this poll cycle")
						break  # No more data immediately available.
					
					_downloaded_size += chunk.size()
					print("[HTTPDownload] Poll - Writing chunk to file: " + _save_path)
					_file.store_buffer(chunk)
					print("[HTTPDownload] Poll - File size after write: " + str(_file.get_length()) + " bytes")
					print("[HTTPDownload] Poll - Total downloaded: " + str(_downloaded_size) + " / " + str(_total_size if _total_size > 0 else "unknown") + " bytes")
					
					# Emit signal with current progress.
					# (If _total_size is unknown, use a fallback value like 1 to avoid division errors.)
					bytes_received.emit(_downloaded_size, _total_size if _total_size > 0 else 1)
				
				# If the response is fully received, then finish.
				# Check if we need to continue polling
				print("[HTTPDownload] Poll - Checking if response is complete: has_response=" + str(has_response()) + ", status=" + str(get_status()))
				if has_response() and get_status() != HTTPClient.STATUS_BODY:
					print("[HTTPDownload] Poll - Response complete, closing file and emitting completion signal")
					_file.close()
					download_completed.emit(_save_path, true)
					return
				else:
					print("[HTTPDownload] Poll - Response not complete yet, continuing polling")
				
				# Brief delay to avoid locking the engine
				OS.delay_msec(10)
			HTTPClient.STATUS_DISCONNECTED:
				# Finished (or closed by the server). Assume success if response exists.
				if _file:
					_file.close()
				download_completed.emit(_save_path, true)
				return
			HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
				# Error states – close file and emit failure.
				var error_status = "Unknown"
				match status:
					HTTPClient.STATUS_CANT_RESOLVE: error_status = "Cannot resolve hostname"
					HTTPClient.STATUS_CANT_CONNECT: error_status = "Cannot connect to host"
					HTTPClient.STATUS_CONNECTION_ERROR: error_status = "Connection error"
					HTTPClient.STATUS_TLS_HANDSHAKE_ERROR: error_status = "TLS handshake error"
				push_error("Download failed: " + error_status + " for URL: " + _url)
				if _file:
					_file.close()
				download_completed.emit(_save_path, false)
				return
			_:
				# Other statuses can be handled or simply ignored.
				poll()
				OS.delay_msec(100)
		
		# Brief delay to avoid locking the engine. Adjust the delay as needed.
		OS.delay_msec(10)

func get_file_size() -> int:
	print("[HTTPDownload] Attempting to get file size for: " + _url)
	var head_client = HTTPClient.new()
	
	# Parse URL to separate host and endpoint
	var ssl = true
	var host = ""
	var port : int
	var endpoint = ""
	
	# Handle web.archive.org URLs properly
	if _url.begins_with("https://web.archive.org/web/"):
		# For web.archive.org URLs, we need to keep the original host (web.archive.org)
		# and format the endpoint correctly
		host = "web.archive.org"
		ssl = true
		port = 443
		
		# Extract the timestamp and URL parts from the web.archive.org URL
		var parts = _url.split("/web/", true, 1)
		if parts.size() > 1:
			# The endpoint should be /web/ followed by the rest of the URL
			endpoint = "/web/" + parts[1]
		else:
			# Fallback to original URL parsing if format is unexpected
			endpoint = "/" + _url.split("/", false, 3)[3]
	else:
		# Standard URL parsing for non-archive URLs
		if _url.begins_with("https://"):
			ssl = true
			port = 443
			var parts = _url.substr(8).split("/", true, 1)
			host = parts[0]
			endpoint = "/" + parts[1] if parts.size() > 1 else "/"
		elif _url.begins_with("http://"):
			ssl = false
			port = 80
			var parts = _url.substr(7).split("/", true, 1)
			host = parts[0]
			endpoint = "/" + parts[1] if parts.size() > 1 else "/"
		else:
			# Fallback for URLs without protocol
			host = _url.split("/")[0]
			endpoint = _url.split(host)[1] if _url.split(host).size() > 1 else "/"
	
	# Connect to host with proper SSL configuration
	print("Connecting for file size check: " + host + " (SSL: " + str(ssl) + ", Port: " + str(port) + ")")
	var err = head_client.connect_to_host(host, port, ssl)
	if err != OK:
		push_error("Failed to connect to host for file size check: " + host + " (Error: " + str(err) + ")")
		return -1
	
	# Wait for connection
	while head_client.get_status() == HTTPClient.STATUS_CONNECTING or head_client.get_status() == HTTPClient.STATUS_RESOLVING:
		head_client.poll()
		OS.delay_msec(100)
	
	if head_client.get_status() != HTTPClient.STATUS_CONNECTED:
		push_error("Could not connect to host for file size check: " + host)
		return -1
	
	# Send a HEAD request
	err = head_client.request(HTTPClient.METHOD_HEAD, endpoint, [])
	if err != OK:
		push_error("Failed to make HEAD request: " + endpoint)
		return -1
	
	# Wait for the request to complete
	while head_client.get_status() == HTTPClient.STATUS_REQUESTING:
		head_client.poll()
		OS.delay_msec(100)
	
	# Wait for response
	while head_client.get_status() == HTTPClient.STATUS_BODY:
		head_client.poll()
		OS.delay_msec(100)
	
	# Extract content length
	var headers = head_client.get_response_headers_as_dictionary()
	print("[HTTPDownload] Response headers: " + str(headers))
	if "Content-Length" in headers:
		_total_size = int(headers["Content-Length"])
		print("[HTTPDownload] Content-Length found: " + str(_total_size) + " bytes")
	else:
		_total_size = -1  # Unknown size
		print("[HTTPDownload] Content-Length not found in headers, size unknown")
	
	head_client.close()
	return _total_size


func _update_progress():
	bytes_received.emit(_downloaded_size, _total_size if _total_size > 0 else 1)  # Avoid division by zero

func _on_timer_timeout():
	# Poll the connection
	var status = get_status()
	print("[HTTPDownload] Timer poll - Status: " + str(status) + " (" + _status_to_string(status) + ")")
	
	# Debug response headers
	var headers = get_response_headers_as_dictionary()
	print("[HTTPDownload] Response headers: " + str(headers))
	
	match status:
		HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_REQUESTING:
			# The request is still being processed
			print("[HTTPDownload] Still processing request...")
			poll()
		HTTPClient.STATUS_BODY:
			print("[HTTPDownload] Reading body data...")
			# Read available data chunks
			var chunk = read_response_body_chunk()
			print("[HTTPDownload] Chunk size: " + str(chunk.size()) + " bytes")
			if chunk.size() > 0:
				_downloaded_size += chunk.size()
				print("[HTTPDownload] Writing chunk to file: " + _save_path)
				_file.store_buffer(chunk)
				print("[HTTPDownload] File size after write: " + str(_file.get_length()) + " bytes")
				# Update progress
				bytes_received.emit(_downloaded_size, _total_size if _total_size > 0 else 1)
			
			# Check if download is complete
			if has_response() and get_status() != HTTPClient.STATUS_BODY:
				_file.close()
				download_completed.emit(_save_path, true)
		HTTPClient.STATUS_DISCONNECTED:
			# Finished or closed by server
			if _file:
				_file.close()
			download_completed.emit(_save_path, true)
		HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			# Error states
			if _file:
				_file.close()
			download_completed.emit(_save_path, false)
		_:
			# Other statuses
			poll()


func _status_to_string(status: int) -> String:
	match status:
		HTTPClient.STATUS_DISCONNECTED: return "DISCONNECTED"
		HTTPClient.STATUS_RESOLVING: return "RESOLVING"
		HTTPClient.STATUS_CANT_RESOLVE: return "CANT_RESOLVE"
		HTTPClient.STATUS_CONNECTING: return "CONNECTING"
		HTTPClient.STATUS_CANT_CONNECT: return "CANT_CONNECT"
		HTTPClient.STATUS_CONNECTED: return "CONNECTED"
		HTTPClient.STATUS_REQUESTING: return "REQUESTING"
		HTTPClient.STATUS_BODY: return "BODY"
		HTTPClient.STATUS_CONNECTION_ERROR: return "CONNECTION_ERROR"
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR: return "TLS_HANDSHAKE_ERROR"
		_: return "UNKNOWN"

func on_download_completed(path, success: bool):
	print("[HTTPDownload] Download completed for: " + path + " (Success: " + str(success) + ")")
	if _file:
		print("[HTTPDownload] Closing file: " + path + " (Final size: " + str(_file.get_length()) + " bytes)")
		_file.close()
		
		# Verify file exists and has content
		if FileAccess.file_exists(path):
			var check_file = FileAccess.open(path, FileAccess.READ)
			if check_file:
				var file_size = check_file.get_length()
				print("[HTTPDownload] Verified file exists with size: " + str(file_size) + " bytes")
				check_file.close()
			else:
				print("[HTTPDownload] WARNING: File exists but cannot be opened for verification")
		else:
			print("[HTTPDownload] WARNING: File does not exist after download completion")
		
	if _timer:
		_timer.stop()
		_timer.queue_free()
	free()
