extends HTTPRequest
class_name DownloadAsset

var api := IcosaGalleryAPI.new()

signal progress_updated(progress_percentage)
signal download_completed(total_size)

var total_size: int = 0
var downloaded: int = 0
var url: String = ""

# Initialize with the download URL.
func _init(_url: String = ""):
	url = _url

# Start the download in chunked mode.
func start_download() -> void:
	# Connect signals using the new style.
	#request_chunked_body_received.connect(_on_chunk_received)
	request_completed.connect(_on_request_completed)
	# Start the request with chunked mode enabled (last argument true).
	var err = request(url, api.headers, HTTPClient.METHOD_GET, "")
	if err != OK:
		print("Error starting download: ", err)

# Called whenever a new chunk of data is received.
func _on_chunk_received(chunk: PackedByteArray) -> void:
	downloaded += chunk.size()
	if total_size > 0:
		var progress = (downloaded / total_size) * 100.0
		emit_signal("progress_updated", progress)
	else:
		# When total size is unknown, you might emit an indeterminate progress (e.g., 0).
		emit_signal("progress_updated", 0)
	print("Downloaded bytes so far: ", downloaded)

# Called when the request is complete.
func _on_request_completed(result, response_code, headers, body) -> void:
	# Loop through headers to extract "Content-Length", if available.
	for header in headers:
		if header.to_lower().begins_with("content-length:"):
			total_size = int(header.split(":")[1].strip())
			break
	
	# Update progress to 100% if the total size is known.
	if total_size > 0:
		emit_signal("progress_updated", 100)
	
	download_completed.emit(total_size)
	#print("Download complete. Total size: ", total_size)
