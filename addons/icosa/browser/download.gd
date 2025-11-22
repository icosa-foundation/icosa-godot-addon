@tool
class_name IcosaDownload
extends HTTPRequest

var bytes_ticker := Timer.new()
var download_start_time: float = 0.0
var last_reported_bytes: int = 0
var content_length: int = -1
var head_request := HTTPRequest.new()

signal files_downloaded(files, total_files)
signal download_progress(current_bytes, total_bytes, current_file_name)
signal download_queue_completed(model_file)
signal download_failed(error_message)
signal host_offline
signal file_downloaded_to_path(path)

var url_queue = []
var current_queue_index = 0
var total_queue_size = 0
var download_path = ""
var asset_name = ""
var asset_id = ""
var pending_download_file = ""  # Store the intended file path
var current_file_name = ""  # Current file being downloaded
var should_cancel = false  # Flag to cancel all downloads

@onready var root_directory = "res://" if Engine.is_editor_hint() else "user://"


func _ready():
	add_child(bytes_ticker)
	add_child(head_request)
	# This must be 0 for 302 redirects!
	max_redirects = 0
	request_completed.connect(on_request_completed)
	head_request.request_completed.connect(on_head_request_completed)
	bytes_ticker.wait_time = 0.1
	bytes_ticker.timeout.connect(update_progress)

	# Create downloads directory if it doesn't exist
	var dir = DirAccess.open(root_directory)
	if not dir.dir_exists("icosa_downloads"):
		dir.make_dir("icosa_downloads")


func start():
	# Initialize the queue and start downloading
	total_queue_size = url_queue.size()
	should_cancel = false

	# Reset the queue index if needed
	if current_queue_index >= total_queue_size:
		current_queue_index = 0

	# Start the download process if there are URLs in the queue
	if total_queue_size > 0:
		start_next_download()


func cancel_all():
	should_cancel = true
	bytes_ticker.stop()
	cancel_request()
	head_request.cancel_request()


func update_progress():
	# Get actual file size from disk (like browsers do)
	var current_bytes = 0
	if pending_download_file != "":
		var file = FileAccess.open(pending_download_file, FileAccess.READ)
		if file:
			current_bytes = file.get_length()

	# Try to get Content-Length from header (use extracted value or get_body_size)
	var file_size_bytes = 0
	if content_length > 0:
		file_size_bytes = content_length
	else:
		# Try to get from HTTPRequest's body_size (may be available during download)
		var body_size = get_body_size()
		if body_size > 0:
			file_size_bytes = body_size

	# Debug: log progress
	if current_bytes > 0 or file_size_bytes > 0:
		print("Progress: %d / %d bytes, file exists: %s" % [current_bytes, file_size_bytes, FileAccess.file_exists(pending_download_file)])

	# Emit signal with progress information (including current filename)
	emit_signal("download_progress", current_bytes, file_size_bytes, current_file_name)

	# Also emit the current file number and total files
	emit_signal("files_downloaded", current_queue_index, total_queue_size)


# Extract Content-Length from response headers (case-insensitive)
func extract_content_length(headers: Array[String]) -> int:
	for header in headers:
		var lower_header = header.to_lower()
		if lower_header.begins_with("content-length: "):
			var length_str = header.split(": ")[1]
			if length_str.is_valid_int():
				return int(length_str)
	return -1


# Extract filename from URL, handling URL encoding
static func file_from_url(url):
	var filename = url.get_file()
	var extension = filename.get_extension()

	# No extension found, return as-is
	if extension == "":
		return filename

	# Extract filename from path (handle both / and %2F separators)
	var final_filename = filename
	var parts = filename.split("/")
	if parts.size() > 0:
		final_filename = parts[-1]
	else:
		parts = filename.split("%2F")
		if parts.size() > 0:
			final_filename = parts[-1]

	# Decode URL-encoded characters
	# For GLTF and related files, we must preserve the original filename
	# because GLTF files reference their resources by filename
	if "%" in final_filename:
		var base_parts = final_filename.split("%2F")
		if base_parts.size() > 0 and base_parts[-1].get_extension() != "":
			final_filename = base_parts[-1].uri_decode()
		elif "%" in final_filename:
			final_filename = final_filename.uri_decode()

	return final_filename


func start_next_download():
	# Check if we should cancel all downloads
	if should_cancel:
		download_queue_completed.emit("")
		bytes_ticker.stop()
		return

	if current_queue_index >= url_queue.size():
		# All downloads completed
		download_queue_completed.emit("")
		bytes_ticker.stop()
		return

	# Stop the ticker before starting a new download to prevent stale data reporting
	bytes_ticker.stop()

	var url = url_queue[current_queue_index]
	var final_filename = file_from_url(url)
	current_file_name = final_filename  # Track current file name

	# Create asset directory with format: {asset_name}_{asset_id}
	var asset_path = ""
	var sanitized_name = asset_name.to_lower().replace(" ", "_").validate_filename()
	asset_path = sanitized_name + "_" + asset_id


	var dir = DirAccess.open(root_directory + "icosa_downloads")
	if not dir.dir_exists(asset_path):
		dir.make_dir(asset_path)

	# Store the download file path and set it for streaming download
	pending_download_file = root_directory + "icosa_downloads/" + asset_path + "/" + final_filename
	download_file = pending_download_file

	# Reset content length for new download
	content_length = -1

	# Make HEAD request first to get Content-Length header
	var error = head_request.request(url, [], HTTPClient.METHOD_HEAD)
	if error != OK:
		push_error("An error occurred in the HEAD request.")
		# Fail the entire asset download if HEAD request fails
		download_failed.emit("Failed to get file information: " + final_filename)
		return


func on_request_completed(result, response_code, headers: Array[String], body):
	# Extract Content-Length from headers if available
	content_length = extract_content_length(headers)

	# In the rare case archive.org goes offline
	if response_code == 500:
		host_offline.emit()
		return

	# Handle 302 redirects
	# HACK: This is a workaround for a Godot bug:
	# https://github.com/godotengine/godot/issues/104651
	if response_code == 302:
		for header in headers:
			if header.begins_with("location: "):
				var redirect_url = header.split("location: ")[1]
				print("Location redirect found: ", redirect_url)
				var original_file_path = pending_download_file
				print("Original file path: ", original_file_path)
				pending_download_file = original_file_path  # Keep original path for streaming
				cancel_request()

				# Step 1: Make HEAD request to redirect URL to get Content-Length BEFORE streaming
				var head_redirect_request = HTTPRequest.new()
				add_child(head_redirect_request)

				head_redirect_request.request_completed.connect(func(res_head, code_head, hdrs_head, bdy_head):
					# Check if HEAD request to redirect URL was successful
					if res_head != HTTPRequest.RESULT_SUCCESS:
						print("❌ HEAD request to redirect URL FAILED!")
						print("   URL: ", redirect_url)
						print("   Result code: %d (0=success, 1=chunked, 2=body_size_exceeded, 3=body_size_mismatch, 4=redirect_limit, 5=timeout, 6=failed)" % res_head)
						print("   HTTP code: ", code_head)
						download_failed.emit("HEAD request failed (result: %d, HTTP: %d) for %s" % [res_head, code_head, current_file_name])
						head_redirect_request.queue_free()
						return

					# Extract Content-Length from HEAD response before streaming starts
					var redirect_content_length = extract_content_length(hdrs_head)
					if redirect_content_length > 0:
						content_length = redirect_content_length
						print("✓ Content-Length from redirect HEAD: ", content_length)
					else:
						print("⚠ No Content-Length header in redirect HEAD response")

					# Step 2: Now make GET request with streaming (content_length is already set)
					var redirect_get_request = HTTPRequest.new()
					add_child(redirect_get_request)
					redirect_get_request.download_file = original_file_path

					redirect_get_request.request_completed.connect(func(res_get, code_get, hdrs_get, bdy_get):
						if res_get == HTTPRequest.RESULT_SUCCESS:
							print("Redirect download successful: ", original_file_path)
							file_downloaded_to_path.emit(original_file_path)
							current_queue_index += 1
							# Update progress
							emit_signal("files_downloaded", current_queue_index, total_queue_size)
							# Start the next download
							start_next_download()
						else:
							print("Redirect GET request failed: result=%d, code=%d" % [res_get, code_get])
							# Fail the entire asset if redirect download fails
							download_failed.emit("Failed to download %s from redirect" % current_file_name)

						# Remove the temporary GET request node
						redirect_get_request.queue_free()
					)

					# Make the GET request with streaming
					var error = redirect_get_request.request(redirect_url)
					if error != OK:
						push_error("An error occurred in redirect GET request.")
						download_failed.emit("Failed to initiate redirect download for %s" % current_file_name)
						redirect_get_request.queue_free()

					# Remove HEAD request node
					head_redirect_request.queue_free()
				)

				# Make HEAD request to redirect URL first
				var error = head_redirect_request.request(redirect_url, [], HTTPClient.METHOD_HEAD)
				if error != OK:
					push_error("An error occurred in redirect HEAD request.")
					current_queue_index += 1
					start_next_download()
					head_redirect_request.queue_free()
				return
		return

	print("### Handle download completion - response code: ", response_code)
	# When using download_file parameter, file is saved to disk directly
	# Check if file exists, which indicates successful download
	var file_exists = FileAccess.file_exists(pending_download_file)

	if result == HTTPRequest.RESULT_SUCCESS or (response_code == 0 and file_exists):
		print("File downloaded and saved successfully: ", pending_download_file)
		file_downloaded_to_path.emit(pending_download_file)

		# Move to the next file in the queue
		current_queue_index += 1
		# Update progress
		emit_signal("files_downloaded", current_queue_index, total_queue_size)
		# Start the next download
		start_next_download()
	else:
		print("Download failed with response code: ", response_code)
		# Fail the entire asset if any file fails
		download_failed.emit("Failed to download %s (response code: %d)" % [current_file_name, response_code])


func on_head_request_completed(result, response_code, headers: Array[String], body):
	# Extract Content-Length from HEAD request response
	if result == HTTPRequest.RESULT_SUCCESS:
		content_length = extract_content_length(headers)
		if content_length > 0:
			print("Content-Length found: ", content_length)

	# Now make the actual GET request to download the file
	var url = url_queue[current_queue_index]
	download_start_time = Time.get_ticks_msec() / 1000.0
	var error = request(url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		current_queue_index += 1
		start_next_download()
		return

	# Start the progress ticker
	bytes_ticker.start()
