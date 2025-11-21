## Master Download Queue
## Manages all downloads sequentially to avoid rate limiting
class_name DownloadQueue
extends Node

var queue: Array = []
var current_download: IcosaDownload = null
var is_downloading = false
var total_assets = 0
var completed_assets = 0
var total_files = 0
var completed_files = 0
var total_bytes_to_download = 0  # Total size of all files
var completed_bytes = 0  # Bytes downloaded so far

signal download_progress(current_bytes: int, total_bytes: int, thumbnail: IcosaThumbnail, filename: String)
signal file_downloaded(thumbnail: IcosaThumbnail, path: String)
signal download_completed(thumbnail: IcosaThumbnail)
signal download_failed(thumbnail: IcosaThumbnail, error_message: String)
signal queue_progress_updated(completed_files: int, total_files: int, completed_assets: int, total_assets: int, total_bytes: int, completed_bytes: int)

func _ready():
	name = "DownloadQueue"

## Add a download request to the queue
func queue_download(thumbnail: IcosaThumbnail, urls: Array, asset_name: String, asset_id: String):
	var item = {
		"thumbnail": thumbnail,
		"urls": urls,
		"asset_name": asset_name,
		"asset_id": asset_id
	}
	queue.append(item)

	# Update total counts
	total_assets += 1
	total_files += urls.size()
	queue_progress_updated.emit(completed_files, total_files, completed_assets, total_assets, total_bytes_to_download, completed_bytes)

	# Fetch file sizes in parallel to get total upfront
	_fetch_file_sizes_for_urls(urls)

	# Start processing if not already downloading
	if not is_downloading:
		_process_queue()


## Fetch all file sizes in parallel (non-blocking)
func _fetch_file_sizes_for_urls(urls: Array):
	for url in urls:
		var head_request = HTTPRequest.new()
		add_child(head_request)

		head_request.request_completed.connect(func(result, code, headers, body):
			if result == HTTPRequest.RESULT_SUCCESS:
				# Extract Content-Length from headers
				for header in headers:
					if header.to_lower().begins_with("content-length: "):
						var length_str = header.split(": ")[1]
						if length_str.is_valid_int():
							var file_size = int(length_str)
							total_bytes_to_download += file_size
							queue_progress_updated.emit(completed_files, total_files, completed_assets, total_assets, total_bytes_to_download, completed_bytes)
						break
			head_request.queue_free()
		)

		# Make HEAD request to get Content-Length
		head_request.request(url, [], HTTPClient.METHOD_HEAD)

## Process the next item in the queue
func _process_queue():
	if queue.is_empty():
		is_downloading = false
		return

	is_downloading = true
	var item = queue.pop_front()
	var thumbnail = item["thumbnail"]
	var urls = item["urls"]
	var asset_name = item["asset_name"]
	var asset_id = item["asset_id"]

	# Create a new download instance
	current_download = IcosaDownload.new()
	add_child(current_download)

	current_download.url_queue = urls
	current_download.asset_name = asset_name
	current_download.asset_id = asset_id

	# Connect signals
	current_download.download_queue_completed.connect(_on_download_completed.bind(thumbnail))
	current_download.file_downloaded_to_path.connect(_on_file_downloaded.bind(thumbnail))
	current_download.download_progress.connect(_on_download_progress.bind(thumbnail))
	current_download.download_failed.connect(_on_download_failed.bind(thumbnail))

	# Start the download
	current_download.start()

func _on_download_completed(model_file: String, thumbnail: IcosaThumbnail):
	print("Download completed for: ", thumbnail.asset.display_name)
	download_completed.emit(thumbnail)
	completed_assets += 1
	queue_progress_updated.emit(completed_files, total_files, completed_assets, total_assets, total_bytes_to_download, completed_bytes)
	current_download.queue_free()
	current_download = null
	_process_queue()

func _on_file_downloaded(path: String, thumbnail: IcosaThumbnail):
	print("File downloaded: ", path)
	completed_files += 1
	# Get file size to add to completed_bytes
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		completed_bytes += file.get_length()
	queue_progress_updated.emit(completed_files, total_files, completed_assets, total_assets, total_bytes_to_download, completed_bytes)
	file_downloaded.emit(thumbnail, path)

func _on_download_progress(current_bytes: int, total_bytes: int, filename: String, thumbnail: IcosaThumbnail):
	download_progress.emit(current_bytes, total_bytes, thumbnail, filename)

func _on_download_failed(error_message: String, thumbnail: IcosaThumbnail):
	print("Download failed for: ", thumbnail.asset.display_name, " - ", error_message)
	download_failed.emit(thumbnail, error_message)
	completed_assets += 1
	queue_progress_updated.emit(completed_files, total_files, completed_assets, total_assets, total_bytes_to_download, completed_bytes)
	current_download.queue_free()
	current_download = null
	_process_queue()

## Cancel all downloads in the queue
func cancel_all_downloads():
	# Clear the queue
	queue.clear()
	# Cancel current download if active
	if current_download:
		current_download.cancel_all()
		current_download.queue_free()
		current_download = null
	is_downloading = false
	total_assets = 0
	completed_assets = 0
	total_files = 0
	completed_files = 0
	total_bytes_to_download = 0
	completed_bytes = 0
	queue_progress_updated.emit(completed_files, total_files, completed_assets, total_assets, total_bytes_to_download, completed_bytes)

## Get the count of remaining downloads in queue
func get_queue_size() -> int:
	return queue.size() + (1 if is_downloading else 0)

## Get current thumbnail being downloaded
func get_current_thumbnail() -> IcosaThumbnail:
	return current_download.asset_name if current_download else null
