@tool
class_name IcosaCollectionThumbnail
extends Button

var collection: IcosaAssetCollection
var collection_manager: IcosaCollectionManager
var thumbnail_request := HTTPRequest.new()

func _ready():
	if collection == null:
		return

	%AssetName.text = collection.collection_name
	%AuthorName.hide()

	add_child(thumbnail_request)
	thumbnail_request.request_completed.connect(_on_thumbnail_completed)

	if not collection.imageUrl.is_empty():
		disabled = false
		thumbnail_request.request(collection.imageUrl)
	else:
		%MissingImage.show()
		disabled = false


func _on_thumbnail_completed(result, response_code, headers, body: PackedByteArray):
	thumbnail_request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		%MissingImage.show()
		return

	var image := Image.new()
	var is_png := true
	for header in headers:
		if header.begins_with("Content-Type: image/jpeg"):
			is_png = false
			break

	var err := image.load_png_from_buffer(body) if is_png else image.load_jpg_from_buffer(body)
	if err != OK:
		%MissingImage.show()
		return

	%ThumbnailImage.texture = ImageTexture.create_from_image(image)


func _on_delete_collection_pressed():
	%ConfirmDelete.popup_centered()

func _on_confirm_delete_confirmed():
	if collection_manager and collection:
		collection_manager.delete_collection(collection.collection_id)
