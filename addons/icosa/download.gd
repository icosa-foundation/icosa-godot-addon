@tool
class_name IcosaDownload
extends HTTPRequest

var bytes_ticker := Timer.new()

signal files_downloaded(files, total_files)
signal download_progress(current_bytes, total_bytes)
signal download_queue_completed(model_file)
signal host_offline
signal file_downloaded_to_path(path)

var url_queue = []
var current_queue_index = 0
var total_queue_size = 0
var download_path = ""
var asset_name = ""
var asset_id = ""
var pending_download_file = ""  # Store the intended file path

@onready var root_directory = "res://" if Engine.is_editor_hint() else "user://"


func _ready():
	add_child(bytes_ticker)
	# This must be 0 for 302 redirects!
	max_redirects = 0
	request_completed.connect(on_request_completed)
	bytes_ticker.wait_time = 0.1
	bytes_ticker.timeout.connect(update_progress)
	
	# Create downloads directory if it doesn't exist
	var dir = DirAccess.open(root_directory)
	if not dir.dir_exists("icosa_downloads"):
		dir.make_dir("icosa_downloads")


func start():
	# Initialize the queue and start downloading
	total_queue_size = url_queue.size()
	
	# Reset the queue index if needed
	if current_queue_index >= total_queue_size:
		current_queue_index = 0
	
	# Start the download process if there are URLs in the queue
	if total_queue_size > 0:
		start_next_download()


func update_progress():
	var current_bytes = get_downloaded_bytes()
	var file_size_bytes = get_body_size()
	if file_size_bytes == -1:
		return
	
	# Emit signal with progress information
	emit_signal("download_progress", current_bytes, file_size_bytes)
	
	# Also emit the current file number and total files
	emit_signal("files_downloaded", current_queue_index, total_queue_size)


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
	if current_queue_index >= url_queue.size():
		# All downloads completed
		download_queue_completed.emit("")
		bytes_ticker.stop()
		return
	
	var url = url_queue[current_queue_index]
	var final_filename = file_from_url(url)
	
	# Create asset directory with format: {asset_name}_{asset_id}
	var asset_path = ""
	var sanitized_name = asset_name.to_lower().replace(" ", "_").validate_filename()
	asset_path = sanitized_name + "_" + asset_id

	
	var dir = DirAccess.open(root_directory + "icosa_downloads")
	if not dir.dir_exists(asset_path):
		dir.make_dir(asset_path)
	
	# Store the download file path (don't set download_file on HTTPRequest yet)
	pending_download_file = root_directory + "icosa_downloads/" + asset_path + "/" + final_filename

	# Request the URL
	var error = request(url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		# Skip to next file
		current_queue_index += 1
		start_next_download()
		return
	
	# Start the progress ticker
	bytes_ticker.start()


func on_request_completed(result, response_code, headers: Array[String], body):
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
				cancel_request()
				
				# Create a new HTTPRequest for the redirect
				var redirect_request = HTTPRequest.new()
				add_child(redirect_request)
				redirect_request.download_file = original_file_path
				
				redirect_request.request_completed.connect(func(res, code, hdrs, bdy):
					if res == HTTPRequest.RESULT_SUCCESS:
						print(bdy.size())
						print("Redirect download successful: ", original_file_path)
						file_downloaded_to_path.emit(original_file_path)
						current_queue_index += 1
						# Update progress
						emit_signal("files_downloaded", current_queue_index, total_queue_size)
						# Start the next download
						start_next_download()
					else:
						print("Redirect download failed with response code: ", code)
						# Skip to next file
						current_queue_index += 1
						start_next_download()
					
					# Remove the temporary request node
					redirect_request.queue_free()
				)
				
				# Make the redirect request
				var error = redirect_request.request(redirect_url)
				if error != OK:
					push_error("An error occurred in the redirect HTTP request.")
					current_queue_index += 1
					start_next_download()
					redirect_request.queue_free()
				return
		return

	print("### Handle successful download")
	# Handle successful download
	if result == HTTPRequest.RESULT_SUCCESS:
		if pending_download_file != "":
			var file = FileAccess.open(pending_download_file, FileAccess.WRITE)
			if file:
				file.store_buffer(body)
				file.close()
				print("File downloaded and saved successfully: ", pending_download_file)
				file_downloaded_to_path.emit(pending_download_file)
			else:
				push_error("Failed to open file for writing: ", pending_download_file)
		else:
			push_error("Download file path is empty")
		
		# Move to the next file in the queue
		current_queue_index += 1
		# Update progress
		emit_signal("files_downloaded", current_queue_index, total_queue_size)
		# Start the next download
		start_next_download()
	else:
		print("Download failed with response code: ", response_code)
		# Skip to next file
		current_queue_index += 1
		start_next_download()
