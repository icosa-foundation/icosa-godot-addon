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
var download_session_start_time: float = 0.0  # When user clicked download button

signal download_progress(current_bytes: int, total_bytes: int, asset_name: String, filename: String)
signal file_downloaded(asset_name: String, path: String)
signal download_completed(asset_name: String)
signal download_failed(asset_name: String, error_message: String)
signal queue_progress_updated(completed_files: int, total_files: int, completed_assets: int, total_assets: int, total_bytes: int, completed_bytes: int)

func _ready():
	name = "DownloadQueue"
	# Ensure downloads are cancelled when this node leaves the tree
	tree_exited.connect(cancel_all_downloads)

## Add a download request to the queue
func queue_download(thumbnail: IcosaThumbnail, urls: Array, asset_name: String, asset_id: String):
	var item = {
		"thumbnail": thumbnail,
		"urls": urls,
		"asset_name": asset_name,
		"asset_id": asset_id
	}
	queue.append(item)

	# Record session start time on first queue
	if total_assets == 0:
		download_session_start_time = Time.get_ticks_msec() / 1000.0
		print("\n⏱️  DOWNLOAD SESSION STARTED")

	# Update total counts
	total_assets += 1
	total_files += urls.size()
	queue_progress_updated.emit(completed_files, total_files, completed_assets, total_assets, total_bytes_to_download, completed_bytes)

	# Start processing if not already downloading
	if not is_downloading:
		_process_queue()


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
	current_download.session_start_time = download_session_start_time

	# Connect signals (pass asset_id instead of thumbnail to avoid stale references)
	current_download.download_queue_completed.connect(_on_download_completed.bind(asset_id))
	current_download.file_downloaded_to_path.connect(_on_file_downloaded.bind(asset_id))
	current_download.download_progress.connect(_on_download_progress.bind(asset_id))
	current_download.download_failed.connect(_on_download_failed.bind(asset_id))

	# Start the download
	current_download.start()

func _on_download_completed(model_file: String, asset_id: String):
	var elapsed = Time.get_ticks_msec() / 1000.0 - download_session_start_time
	print("[%6.1fs] ✓ ASSET COMPLETE: %s" % [elapsed, asset_id])
	# Emit with asset_id - UI can look up thumbnail if needed
	if current_download and is_instance_valid(current_download):
		download_completed.emit(current_download.asset_name)
	completed_assets += 1
	queue_progress_updated.emit(completed_files, total_files, completed_assets, total_assets, total_bytes_to_download, completed_bytes)
	current_download.queue_free()
	current_download = null
	_process_queue()

func _on_file_downloaded(path: String, asset_id: String):
	var elapsed = Time.get_ticks_msec() / 1000.0 - download_session_start_time
	print("[%6.1fs]   ✓ FILE WRITTEN: %s" % [elapsed, path.get_file()])
	completed_files += 1
	# Get file size to add to completed_bytes
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		completed_bytes += file.get_length()
	queue_progress_updated.emit(completed_files, total_files, completed_assets, total_assets, total_bytes_to_download, completed_bytes)
	# Emit with asset_id instead of thumbnail
	if current_download and is_instance_valid(current_download):
		file_downloaded.emit(current_download.asset_name, path)

func _on_download_progress(current_bytes: int, total_bytes: int, filename: String, asset_id: String):
	# Emit progress with asset info (no stale thumbnail reference)
	if current_download and is_instance_valid(current_download):
		download_progress.emit(current_bytes, total_bytes, current_download.asset_name, filename)

func _on_download_failed(error_message: String, asset_id: String):
	var elapsed = Time.get_ticks_msec() / 1000.0 - download_session_start_time
	print("[%6.1fs] ❌ ASSET FAILED: %s - %s" % [elapsed, asset_id, error_message])
	# Emit with asset_id instead of stale thumbnail
	if current_download and is_instance_valid(current_download):
		download_failed.emit(current_download.asset_name, error_message)
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
