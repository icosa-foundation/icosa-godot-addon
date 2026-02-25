@tool
class_name IcosaCollectionManager
extends Node

## Manages Icosa Gallery collections - listing, creating, updating, deleting, and managing assets

const COLLECTIONS_ENDPOINT := "https://api.icosa.gallery/v1/collections"
const USER_COLLECTIONS_ENDPOINT := "https://api.icosa.gallery/v1/users/me/collections"

const HEADER_AGENT := "User-Agent: Icosa Gallery Godot Engine / 1.0"
const HEADER_APP := "accept: application/json"
const HEADER_AUTH := "Authorization: Bearer %s"

signal collections_loaded(collections: Array[IcosaAssetCollection])
signal collection_created(collection: IcosaAssetCollection)
signal collection_updated(collection: IcosaAssetCollection)
signal collection_deleted(collection_url: String)
signal thumbnail_uploaded(image_url: String)
signal error_occurred(error_message: String)

var access_token: String = ""
var http_request: HTTPRequest

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)

## Get all public collections
func get_public_collections(page_token: String = "", page_size: int = 50):
	var url = COLLECTIONS_ENDPOINT
	var params = []
	if not page_token.is_empty():
		params.append("pageToken=" + page_token)
	if page_size > 0:
		params.append("pageSize=" + str(page_size))

	if not params.is_empty():
		url += "?" + "&".join(params)

	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaCollections] GET ", url)
	http_request.request_completed.connect(_on_collections_loaded)
	var err = http_request.request(url, [HEADER_AGENT, HEADER_APP], HTTPClient.METHOD_GET)

	if err != OK:
		error_occurred.emit("Failed to send request: " + str(err))

## Get user's collections (requires authentication)
func get_my_collections(page_token: String = "", page_size: int = 50):
	if access_token.is_empty():
		error_occurred.emit("Not authenticated. Please log in first.")
		return

	var url = USER_COLLECTIONS_ENDPOINT
	var params = []
	if not page_token.is_empty():
		params.append("pageToken=" + page_token)
	if page_size > 0:
		params.append("pageSize=" + str(page_size))

	if not params.is_empty():
		url += "?" + "&".join(params)

	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaCollections] GET ", url)
	http_request.request_completed.connect(_on_collections_loaded)
	var err = http_request.request(
		url,
		[HEADER_AGENT, HEADER_APP, HEADER_AUTH % access_token],
		HTTPClient.METHOD_GET
	)

	if err != OK:
		error_occurred.emit("Failed to send request: " + str(err))

## Create a new collection
func create_collection(name: String, description: String = "", visibility: String = "PRIVATE", asset_urls: Array = []):
	if access_token.is_empty():
		error_occurred.emit("Not authenticated. Please log in first.")
		return

	var body = {
		"name": name,
		"description": description,
		"visibility": visibility
	}

	if not asset_urls.is_empty():
		body["asset_url"] = asset_urls

	var json_body = JSON.stringify(body)

	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaCollections] POST ", USER_COLLECTIONS_ENDPOINT)
	http_request.request_completed.connect(_on_collection_created)
	var err = http_request.request(
		USER_COLLECTIONS_ENDPOINT,
		[HEADER_AGENT, HEADER_APP, HEADER_AUTH % access_token, "Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		json_body
	)

	if err != OK:
		error_occurred.emit("Failed to send request: " + str(err))

## Get a single collection by ID (returns full asset list)
signal collection_fetched(collection: IcosaAssetCollection)

func get_collection(collection_id: String):
	if access_token.is_empty():
		error_occurred.emit("Not authenticated. Please log in first.")
		return

	var url = USER_COLLECTIONS_ENDPOINT + "/" + collection_id
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, response_code, headers, body):
		http.queue_free()
		if response_code != 200:
			error_occurred.emit("Failed to fetch collection. Response code: " + str(response_code))
			return
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) != OK:
			error_occurred.emit("Failed to parse collection JSON")
			return
		var collection = IcosaAssetCollection.new()
		_populate_collection_from_data(collection, json.data)
		collection_fetched.emit(collection)
	)
	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaCollections] GET ", url)
	http.request(url, [HEADER_AGENT, HEADER_APP, HEADER_AUTH % access_token], HTTPClient.METHOD_GET)

## Update an existing collection
func update_collection(collection_url: String, name: String = "", description: String = "", visibility: String = ""):
	if access_token.is_empty():
		error_occurred.emit("Not authenticated. Please log in first.")
		return

	var body = {}
	if not name.is_empty():
		body["name"] = name
	if not description.is_empty():
		body["description"] = description
	if not visibility.is_empty():
		body["visibility"] = visibility

	var json_body = JSON.stringify(body)
	var url = USER_COLLECTIONS_ENDPOINT + "/" + collection_url

	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaCollections] PATCH ", url)
	http_request.request_completed.connect(_on_collection_updated)
	var err = http_request.request(
		url,
		[HEADER_AGENT, HEADER_APP, HEADER_AUTH % access_token, "Content-Type: application/json"],
		HTTPClient.METHOD_PATCH,
		json_body
	)

	if err != OK:
		error_occurred.emit("Failed to send request: " + str(err))

## Delete a collection
func delete_collection(collection_url: String):
	if access_token.is_empty():
		error_occurred.emit("Not authenticated. Please log in first.")
		return

	var url = USER_COLLECTIONS_ENDPOINT + "/" + collection_url

	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaCollections] DELETE ", url)
	http_request.request_completed.connect(_on_collection_deleted.bind(collection_url))
	var err = http_request.request(
		url,
		[HEADER_AGENT, HEADER_APP, HEADER_AUTH % access_token],
		HTTPClient.METHOD_DELETE
	)

	if err != OK:
		error_occurred.emit("Failed to send request: " + str(err))

## Set/replace all assets in a collection
func set_collection_assets(collection_url: String, asset_urls: Array):
	if access_token.is_empty():
		error_occurred.emit("Not authenticated. Please log in first.")
		return

	var body = {
		"asset_url": asset_urls
	}

	var json_body = JSON.stringify(body)
	var url = USER_COLLECTIONS_ENDPOINT + "/" + collection_url + "/set_assets"

	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaCollections] PUT ", url)
	http_request.request_completed.connect(_on_collection_updated)
	var err = http_request.request(
		url,
		[HEADER_AGENT, HEADER_APP, HEADER_AUTH % access_token, "Content-Type: application/json"],
		HTTPClient.METHOD_PUT,
		json_body
	)

	if err != OK:
		error_occurred.emit("Failed to send request: " + str(err))

## Upload a thumbnail image for a collection
func set_collection_thumbnail(collection_url: String, image_path: String):
	if access_token.is_empty():
		error_occurred.emit("Not authenticated. Please log in first.")
		return

	var file = FileAccess.open(image_path, FileAccess.READ)
	if not file:
		error_occurred.emit("Could not open image file: " + image_path)
		return

	var file_bytes = file.get_buffer(file.get_length())
	file.close()

	var boundary = "----GodotFormBoundary" + str(Time.get_ticks_msec())
	var body = PackedByteArray()
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"image\"; filename=\"" + image_path.get_file() + "\"\r\n").to_utf8_buffer())
	body.append_array("Content-Type: image/png\r\n\r\n".to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array("\r\n".to_utf8_buffer())
	body.append_array(("--" + boundary + "--\r\n").to_utf8_buffer())

	var url = USER_COLLECTIONS_ENDPOINT + "/" + collection_url + "/set_thumbnail"

	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaCollections] POST ", url)
	http_request.request_completed.connect(_on_thumbnail_uploaded)
	var err = http_request.request_raw(
		url,
		[HEADER_AGENT, HEADER_APP, HEADER_AUTH % access_token, "Content-Type: multipart/form-data; boundary=" + boundary],
		HTTPClient.METHOD_POST,
		body
	)

	if err != OK:
		error_occurred.emit("Failed to send request: " + str(err))
	
# Response handlers

func _on_collections_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	http_request.request_completed.disconnect(_on_collections_loaded)

	if response_code != 200:
		error_occurred.emit("Failed to load collections. Response code: " + str(response_code))
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		error_occurred.emit("Failed to parse response JSON")
		return

	var data = json.data
	var collections: Array[IcosaAssetCollection] = []

	if data.has("collections"):
		for collection_data in data["collections"]:
			var collection = IcosaAssetCollection.new()
			_populate_collection_from_data(collection, collection_data)
			collections.append(collection)

	collections_loaded.emit(collections)

func _on_collection_created(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	http_request.request_completed.disconnect(_on_collection_created)

	if response_code != 200 and response_code != 201:
		error_occurred.emit("Failed to create collection. Response code: " + str(response_code))
		print("Response body: ", body.get_string_from_utf8())
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		error_occurred.emit("Failed to parse response JSON")
		return

	var collection = IcosaAssetCollection.new()
	_populate_collection_from_data(collection, json.data)

	collection_created.emit(collection)

func _on_collection_updated(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	http_request.request_completed.disconnect(_on_collection_updated)

	if response_code != 200:
		error_occurred.emit("Failed to update collection. Response code: " + str(response_code))
		print("Response body: ", body.get_string_from_utf8())
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		error_occurred.emit("Failed to parse response JSON")
		return

	# set_assets and update_collection return { "collection": {...}, "rejectedAssetUrls": [...] }
	var data = json.data
	if data.has("rejectedAssetUrls") and data["rejectedAssetUrls"] and not data["rejectedAssetUrls"].is_empty():
		error_occurred.emit("Some assets could not be added (you may only add your own assets to a collection).")
	if data.has("collection"):
		data = data["collection"]

	var collection = IcosaAssetCollection.new()
	_populate_collection_from_data(collection, data)

	collection_updated.emit(collection)

func _on_collection_deleted(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, collection_url: String):
	http_request.request_completed.disconnect(_on_collection_deleted)

	if response_code != 200 and response_code != 204:
		error_occurred.emit("Failed to delete collection. Response code: " + str(response_code))
		return

	collection_deleted.emit(collection_url)

func _on_thumbnail_uploaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	http_request.request_completed.disconnect(_on_thumbnail_uploaded)

	if response_code != 200:
		error_occurred.emit("Failed to upload thumbnail. Response code: " + str(response_code))
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		error_occurred.emit("Failed to parse response JSON")
		return

	if json.data.has("url"):
		thumbnail_uploaded.emit(json.data["url"])

func _populate_collection_from_data(collection: IcosaAssetCollection, data: Dictionary):
	"""Helper to populate a collection object from API response data"""
	if data.has("collectionId"):
		collection.collection_id = data["collectionId"]
	elif data.has("url"):
		# Fall back to extracting the ID from the URL path
		collection.collection_id = data["url"].get_file()
	if data.has("name"):
		collection.collection_name = data["name"]
	if data.has("description"):
		collection.description = data["description"]
	if data.has("imageUrl"):
		collection.imageUrl = data["imageUrl"]
	if data.has("createTime"):
		collection.create_time = data["createTime"]
	if data.has("updateTime"):
		collection.update_time = data["updateTime"]
	if data.has("visibility"):
		match data["visibility"]:
			"PRIVATE":
				collection.visiblity = IcosaAssetCollection.Visibility.PRIVATE
			"PUBLIC":
				collection.visiblity = IcosaAssetCollection.Visibility.PUBLIC
			"UNLISTED":
				collection.visiblity = IcosaAssetCollection.Visibility.UNLISTED

	if data.has("assets"):
		collection.assets.clear()
		for asset_data in data["assets"]:
			var asset = IcosaAsset.new(asset_data)
			collection.assets.append(asset)
