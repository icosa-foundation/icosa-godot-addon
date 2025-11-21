## Master Download Queue
## Manages all downloads sequentially to avoid rate limiting
class_name DownloadQueue
extends Node

var queue: Array = []
var current_download: IcosaDownload = null
var is_downloading = false

signal download_progress(current_bytes: int, total_bytes: int)
signal file_downloaded(thumbnail: IcosaThumbnail, path: String)
signal download_completed(thumbnail: IcosaThumbnail)

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

	# Connect signals
	current_download.download_queue_completed.connect(_on_download_completed.bind(thumbnail))
	current_download.file_downloaded_to_path.connect(_on_file_downloaded.bind(thumbnail))
	current_download.download_progress.connect(_on_download_progress.bind(thumbnail))

	# Start the download
	current_download.start()

func _on_download_completed(model_file: String, thumbnail: IcosaThumbnail):
	print("Download completed for: ", thumbnail.asset.display_name)
	download_completed.emit(thumbnail)
	current_download.queue_free()
	current_download = null
	_process_queue()

func _on_file_downloaded(path: String, thumbnail: IcosaThumbnail):
	print("File downloaded: ", path)
	file_downloaded.emit(thumbnail, path)

func _on_download_progress(current_bytes: int, total_bytes: int, thumbnail: IcosaThumbnail):
	download_progress.emit(current_bytes, total_bytes)

## Get the count of remaining downloads in queue
func get_queue_size() -> int:
	return queue.size() + (1 if is_downloading else 0)

## Get current thumbnail being downloaded
func get_current_thumbnail() -> IcosaThumbnail:
	return current_download.asset_name if current_download else null
