#@tool
class_name HTTPDownload
extends HTTPRequest

var bytes_ticker := Timer.new()

signal files_downloaded(files, total_files)
signal download_progress(current_bytes, total_bytes)
signal download_queue_completed()
signal host_offline

var url_queue = []
var current_queue_index = 0
var total_queue_size = 0
var download_path = ""
var asset_name = ""

func _ready():
	add_child(bytes_ticker)
	## this must be 0 for 302 redirects!
	max_redirects = 0
	request_completed.connect(on_request_completed)
	bytes_ticker.wait_time = 0.1
	bytes_ticker.timeout.connect(update_progress)
	
	# Create downloads directory if it doesn't exist
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("downloads"):
		dir.make_dir("downloads")

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

func start_next_download():
	if current_queue_index < url_queue.size():
		var url = url_queue[current_queue_index]
		
		# Extract filename from URL and simplify it
		var filename = url.get_file()
		
		# First, check if the filename contains a real file extension
		var extension = filename.get_extension()
		var simple_filename = ""
		
		# If we have a valid extension, extract just the base filename
		if extension != "":
			# Look for the actual filename at the end of the path (after last slash or %2F)
			var parts = filename.split("/")
			if parts.size() > 0:
				simple_filename = parts[-1]
			else:
				# Try with URL encoded slash
				parts = filename.split("%2F")
				if parts.size() > 0:
					simple_filename = parts[-1]
				else:
					simple_filename = filename
			
			# If the filename is still complex, extract just the base name
			if "%" in simple_filename:
				# Try to get just the actual filename (like model.bin)
				var base_parts = simple_filename.split("%2F")
				if base_parts.size() > 0 and base_parts[-1].get_extension() != "":
					simple_filename = base_parts[-1]
				else:
					# Last resort: check if it ends with a known extension pattern
					var known_extensions = [".gltf", ".bin", ".glb", ".obj", ".fbx", ".png", ".jpg"]
					for ext in known_extensions:
						if simple_filename.ends_with(ext):
							var ext_pos = simple_filename.rfind(ext)
							var name_start = simple_filename.rfind("%2F", ext_pos)
							if name_start != -1:
								simple_filename = simple_filename.substr(name_start + 3)
							break
			
			# If we still have URL encoding in the filename, try to decode it
			if "%" in simple_filename:
				# If it's a common file type, use just the extension name
				if extension in ["gltf", "bin", "glb", "obj", "fbx", "png", "jpg"]:
					simple_filename = "model." + extension
		else:
			# No extension found, use the original filename
			simple_filename = filename
		
		print("Original filename: ", filename)
		print("Simplified to: ", simple_filename)
		
		# Create asset directory if it doesn't exist
		var dir = DirAccess.open("res://downloads")
		if not dir.dir_exists(asset_name):
			dir.make_dir(asset_name)
		
		# Set the download file path with simplified filename
		download_file = "res://downloads/" + asset_name + "/" + simple_filename
		
		# Request the URL
		var error = request(url)
		if error != OK:
			push_error("An error occurred in the HTTP request.")
			# Skip to next file
			current_queue_index += 1
			start_next_download()
		
		# Start the progress ticker
		bytes_ticker.start()
	else:
		# All downloads completed
		emit_signal("download_queue_completed")
		
		bytes_ticker.stop()
		
		
		## quirks: dont scan while scanning!
		## very strange stuff happens!!!!!
		## can only work in editor!!!!!!!!!!!!!
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().scan()
			EditorInterface.get_resource_filesystem().resources_reimported.connect(resources_updated)

# For handling redirects
func next_download(url : String):
	# Store the original file path before clearing it
	var original_file_path = download_file
	
	# Clear the previous download file path to avoid saving redirects
	download_file = ""
	
	var error = request(url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		# Restore the original file path if the request fails
		download_file = original_file_path

func on_request_completed(result, response_code, headers : Array[String], body):
	if response_code == 500:
		host_offline.emit()
	# Handle 302 redirects
	if response_code == 302:
		for header in headers:
			if header.begins_with("location: "):
				var redirect_url = header.split("location: ")[1]
				print("Location redirect found: ", redirect_url)
				
				# Store the original file path
				var original_file_path = download_file
				print("Original file path: ", original_file_path)
				
				# Cancel the current request
				cancel_request()
				
				# Create a new HTTPRequest for the redirect
				var redirect_request = HTTPRequest.new()
				add_child(redirect_request)
				
				# Configure the redirect request
				# Make sure we're using a simplified filename for redirects too
				var redirect_file_path = original_file_path
				redirect_request.download_file = redirect_file_path
				redirect_request.request_completed.connect(func(res, code, hdrs, bdy):
					if res == HTTPRequest.RESULT_SUCCESS:
						print("Redirect download successful: ", original_file_path)
						# Move to the next file in the queue
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
					# If request fails, continue to next download
					current_queue_index += 1
					start_next_download()
					# Remove the temporary request node
					redirect_request.queue_free()
				return
		return
	
	# Handle successful download
	if result == HTTPRequest.RESULT_SUCCESS:
		if download_file != "":
			# Save the downloaded content to the file
			var file = FileAccess.open(download_file, FileAccess.WRITE)
			if file:
				file.store_buffer(body)
				file.close()
				print("File downloaded and saved successfully: ", download_file)
				

				
			else:
				push_error("Failed to open file for writing: ", download_file)
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
	
			


			
func resources_updated(stuff):
	print(stuff)
