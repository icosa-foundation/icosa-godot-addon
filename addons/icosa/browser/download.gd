@tool
class_name IcosaDownload
extends HTTPRequest

@export var debug_print: bool = false  # Enable debug printing

var bytes_ticker := Timer.new()
var download_start_time: float = 0.0
var last_reported_bytes: int = 0
var content_length: int = -1
var last_request_end_time: float = 0.0  # Track when last request completed for rate limiting

signal files_downloaded(files: int, total_files: int)
signal download_progress(current_bytes: int, total_bytes: int, current_file_name: String)
signal download_queue_completed(model_file: String)
signal download_failed(error_message: String)
signal host_offline
signal file_downloaded_to_path(path: String)

var url_queue = []
var current_queue_index = 0
var total_queue_size = 0
var download_path = ""
var asset_name = ""
var asset_id = ""
var pending_download_file = ""  # Store the intended file path
var current_file_name = ""  # Current file being downloaded
var should_cancel = false  # Flag to cancel all downloads
var session_start_time: float = 0.0  # When user clicked download button (from queue)
var retry_count = 0  # Track retry attempts for current file
const MAX_RETRIES = 3  # Maximum number of retries per file

@onready var root_directory = "res://" if Engine.is_editor_hint() else "user://"


func _ready():
	add_child(bytes_ticker)
	# This must be 0 for 302 redirects!
	max_redirects = 0
	request_completed.connect(on_request_completed)
	bytes_ticker.wait_time = 0.1
	bytes_ticker.timeout.connect(update_progress)
	# Cleanup when node is freed
	tree_exited.connect(func(): bytes_ticker.stop())

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


## Retry the current download with exponential backoff
func retry_current_download():
	if retry_count >= MAX_RETRIES:
		return false

	retry_count += 1
	var backoff_time = pow(2.0, retry_count)  # 2^retry_count: 2s, 4s, 8s
	var session_elapsed = Time.get_ticks_msec() / 1000.0 - session_start_time
	if debug_print:
		print("[%6.1fs]   ⏳ Retry %d/%d: waiting %.1f seconds before retry" % [session_elapsed, retry_count, MAX_RETRIES, backoff_time])

	await get_tree().create_timer(backoff_time).timeout
	# Retry the same file without incrementing the queue index
	start_next_download()
	return true


func update_progress():
	# Safety check: don't emit signals if node is queued for deletion
	if is_queued_for_deletion():
		return

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
	retry_count = 0  # Reset retry counter for new file

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

	# Apply rate limiting: ensure 6 seconds between request starts (archive.org: 15 req/min)
	# Increased from 4s to account for server recovery time after large file downloads
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_queue_index > 0:
		var time_since_last = current_time - last_request_end_time
		var remaining_wait = 6.0 - time_since_last
		if remaining_wait > 0:
			var session_elapsed = current_time - session_start_time
			if debug_print:
				print("[%6.1fs]   ⏳ Rate limit: waiting %.1f seconds" % [session_elapsed, remaining_wait])
			await get_tree().create_timer(remaining_wait).timeout
			current_time = Time.get_ticks_msec() / 1000.0

	download_start_time = current_time
	var session_elapsed = download_start_time - session_start_time
	if debug_print:
		print("[%6.1fs] 📥 FILE START [%d/%d]: %s" % [session_elapsed, current_queue_index + 1, total_queue_size, final_filename])

	# Skip HEAD request and go straight to GET (download directly)
	if debug_print:
		print("[%6.1fs]   📤 GET: started" % [session_elapsed])
	var error = request(url)
	if error != OK:
		push_error("An error occurred in the GET request.")
		# Fail the entire asset download if GET request fails
		download_failed.emit("Failed to download: " + final_filename)
		return

	# Start the progress ticker
	bytes_ticker.start()


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
				var session_elapsed_redir = Time.get_ticks_msec() / 1000.0 - session_start_time
				if debug_print:
					print("[%6.1fs]   🔄 REDIRECT: %s" % [session_elapsed_redir, redirect_url])
				var original_file_path = pending_download_file
				pending_download_file = original_file_path  # Keep original path for streaming
				cancel_request()

				# Skip HEAD and go straight to GET (redirect is also streamed directly)
				var redirect_get_request = HTTPRequest.new()
				redirect_get_request.download_file = original_file_path
				redirect_get_request.download_chunk_size = 1048576  # 1 MB chunks
				add_child(redirect_get_request)

				redirect_get_request.request_completed.connect(func(res_get, code_get, hdrs_get, bdy_get):
					var redirect_get_end_time = Time.get_ticks_msec() / 1000.0
					var redirect_get_elapsed = redirect_get_end_time - download_start_time
					var session_elapsed_redirect_get = redirect_get_end_time - session_start_time

					if res_get == HTTPRequest.RESULT_SUCCESS:
						if debug_print:
							print("[%6.1fs]   ✓ REDIRECT GET: complete in %.1fs" % [session_elapsed_redirect_get, redirect_get_elapsed])
						file_downloaded_to_path.emit(original_file_path)
						current_queue_index += 1
						# Update progress
						emit_signal("files_downloaded", current_queue_index, total_queue_size)
						# Start the next download
						start_next_download()
					else:
						var result_str = {
							0: "success",
							1: "chunked_body_size_mismatch",
							2: "cant_connect",
							3: "body_size_mismatch",
							4: "redirect_limit_reached",
							5: "timeout",
							6: "failed"
						}.get(res_get, "unknown")
						if debug_print:
							print("[%6.1fs]   ❌ REDIRECT GET failed" % [session_elapsed_redirect_get])
							print("      Result: %s (%d)" % [result_str, res_get])
							print("      HTTP Code: %d" % [code_get])
							print("      File: %s" % [current_file_name])
						# Fail the entire asset if redirect download fails
						download_failed.emit("Failed to download %s from redirect (result: %s, HTTP: %d)" % [current_file_name, result_str, code_get])

					# Remove the temporary GET request node
					redirect_get_request.queue_free()
				)

				# Make the GET request with streaming (skip HEAD entirely)
				var error = redirect_get_request.request(redirect_url)
				if error != OK:
					push_error("An error occurred in redirect GET request.")
					download_failed.emit("Failed to initiate redirect download for %s" % current_file_name)
					redirect_get_request.queue_free()
				return
		return

	# When using download_file parameter, file is saved to disk directly
	# Check if file exists, which indicates successful download
	var file_exists = FileAccess.file_exists(pending_download_file)
	var get_end_time = Time.get_ticks_msec() / 1000.0
	var get_elapsed = get_end_time - download_start_time
	var session_elapsed_complete = get_end_time - session_start_time

	# Track when this request completed for rate limiting
	last_request_end_time = get_end_time

	if result == HTTPRequest.RESULT_SUCCESS or (response_code == 0 and file_exists):
		if debug_print:
			print("[%6.1fs]   ✓ GET: complete in %.1fs" % [session_elapsed_complete, get_elapsed])
		file_downloaded_to_path.emit(pending_download_file)

		# Move to the next file in the queue
		current_queue_index += 1
		# Update progress
		emit_signal("files_downloaded", current_queue_index, total_queue_size)
		# Start the next download
		start_next_download()
	else:
		var result_str = {
			0: "success",
			1: "chunked_body_size_mismatch",
			2: "cant_connect",
			3: "body_size_mismatch",
			4: "redirect_limit_reached",
			5: "timeout",
			6: "failed"
		}.get(result, "unknown")
		if debug_print:
			print("[%6.1fs]   ❌ GET: failed after %.1fs" % [session_elapsed_complete, get_elapsed])
			print("      Result: %s (%d)" % [result_str, result])
			print("      HTTP Code: %d" % [response_code])
			print("      File: %s" % [current_file_name])

		# Retry on connection failure (result code 2: RESULT_CANT_CONNECT)
		if result == HTTPRequest.RESULT_CANT_CONNECT:
			var should_retry = await retry_current_download()
			if should_retry:
				return  # Retry is in progress

		# Fail the entire asset if any file fails
		download_failed.emit("Failed to download %s (result: %s, HTTP: %d)" % [current_file_name, result_str, response_code])
