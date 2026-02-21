@tool
class_name IcosaUserTab
extends Control

const DEFAULT_MESSAGE := "You are not logged in. [url=https://icosa.gallery/device]Login Here.[/url]"
const INCORRECT_MESSAGE := "Code is incorrect, please check your web browser or [url=https://icosa.gallery/device]get a new code[/url]"

const UPLOAD_ENDPOINT := "https://api.icosa.gallery/v1/users/me/assets"
const LOGIN_ENDPOINT := "https://api.icosa.gallery/v1/login/device_login"
const USER_INFO_ENDPOINT := "https://api.icosa.gallery/v1/users/me"
const USER_ASSETS_ENDPOINT := "https://api.icosa.gallery/v1/users/me/assets"
const USER_LIKED_ASSETS_ENDPOINT := "https://api.icosa.gallery/v1/users/me/likedassets"

const HEADER_AGENT := "User-Agent: Icosa Gallery Godot Engine / 1.0"
const HEADER_APP := "accept: application/json"
const HEADER_AUTH := "Authorization: Bearer %s"

signal logged_in(token: String)
signal recieved_user_data(user_data)
signal user_token_too_old
signal logged_out

var user_data
var http_login = HTTPRequest.new()
var http_user = HTTPRequest.new()
var http_assets = HTTPRequest.new()
var http_liked_assets = HTTPRequest.new()

var token: String
var is_logged_in := false

var user_do_not_show_delete_prompt = false

# Collection management
var collection_manager: IcosaCollectionManager
var user_collections: Array[IcosaAssetCollection] = []

func _ready() -> void:
	add_child(http_login)
	add_child(http_user)
	add_child(http_assets)
	add_child(http_liked_assets)

	# Initialize collection manager
	collection_manager = IcosaCollectionManager.new()
	add_child(collection_manager)
	collection_manager.collections_loaded.connect(_on_collections_loaded)
	collection_manager.collection_created.connect(_on_collection_created)
	collection_manager.collection_updated.connect(_on_collection_updated)
	collection_manager.collection_deleted.connect(_on_collection_deleted)
	collection_manager.error_occurred.connect(_on_collection_error)

	%LoginStatus.text = DEFAULT_MESSAGE
	%LoggedInAs.text = ""


func load_thumbnails(assets_data: Array, add_to: Control, user = false) -> void:
	await get_tree().process_frame
	for asset_data in assets_data:
		await get_tree().process_frame
		var asset = IcosaAsset.new(asset_data)
		var thumbnail = load("res://addons/icosa/browser/thumbnail.tscn").instantiate() as IcosaThumbnail
		if user:
			asset.user_asset = true
			thumbnail.delete_requested.connect(_on_delete_request)
		thumbnail.asset = asset
		add_to.add_child(thumbnail)




func _on_login_code_text_changed(new_text: String) -> void:
	if new_text.length() == 5:
		%LoginCode.editable = false
		%LoginCode.selecting_enabled = false
		%LoginCode.modulate = Color.SEA_GREEN
		%Loading.visible = true
		%LoginStatus.text = "Connecting..."
		_login_request(new_text)
	else:
		%LoginStatus.text = INCORRECT_MESSAGE


func _login_request(device_code: String) -> void:
	var url = LOGIN_ENDPOINT + "?device_code=%s" % device_code
	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaUser] POST ", url)
	http_login.request_completed.connect(_on_login_request)
	http_login.request(
		url,
		[HEADER_APP],
		HTTPClient.METHOD_POST,
		" "
	)


func _on_login_request(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	http_login.request_completed.disconnect(_on_login_request)

	if response_code != 200:
		var response_body = body.get_string_from_utf8()
		print("Login error (HTTP %s): %s" % [response_code, response_body])
		print("Login response headers: ", headers)
		_reset_login_ui()
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		printerr("Failed to parse login response.")
		return

	if json.data.has("access_token"):
		token = json.data["access_token"]
		is_logged_in = true
		logged_in.emit(token)
		_login_success()


func _reset_login_ui() -> void:
	%LoginStatus.text = DEFAULT_MESSAGE
	%LoginCode.text = ""
	%LoginCode.editable = true
	%LoginCode.selecting_enabled = true
	%LoginCode.modulate = Color.WHITE
	%LoginCode.hide()
	%Loading.visible = false
	%CancelLogin.hide()


func _login_success() -> void:
	%LoginDetails.hide()
	%UserDetails.show()
	#print("token is: ", token)
	_user_request(token)
	_user_assets_request(token)
	_user_liked_assets_request(token)

	# Load user's collections
	collection_manager.access_token = token
	collection_manager.get_my_collections()

func logout():
	%LoginDetails.show()
	%UserDetails.hide()
	token = ""
func _user_request(access_token: String) -> void:
	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaUser] GET ", USER_INFO_ENDPOINT)
	http_user.request_completed.connect(_on_user_request)
	http_user.request(
		USER_INFO_ENDPOINT,
		[HEADER_AGENT, HEADER_APP, HEADER_AUTH % access_token],
		HTTPClient.METHOD_GET
	)


func _on_user_request(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	http_user.request_completed.disconnect(_on_user_request)

	if response_code != 200:
		print("User request error:", response_code)
		if response_code == 401:
			user_token_too_old.emit()
		return
	else:
		if is_logged_in == false:
			is_logged_in = true
			_reset_login_ui()
			_login_success()

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		user_data = json.data
		recieved_user_data.emit(user_data)
		%LoggedInAs.text = "Logged in as %s" % user_data["displayName"]


func _user_assets_request(access_token: String) -> void:
	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaUser] GET ", USER_ASSETS_ENDPOINT)
	http_assets.request_completed.connect(_on_user_assets_request)
	http_assets.request(
		USER_ASSETS_ENDPOINT,
		[HEADER_AGENT, HEADER_APP, HEADER_AUTH % access_token],
		HTTPClient.METHOD_GET
	)


func _on_user_assets_request(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	http_assets.request_completed.disconnect(_on_user_assets_request)

	if response_code != 200:
		print("Assets request error:", response_code)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		if !json.data["assets"].is_empty():
			%NoUserAssets.hide()
		load_thumbnails(json.data["assets"], %UserAssets, true)


func _user_liked_assets_request(access_token: String) -> void:
	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaUser] GET ", USER_LIKED_ASSETS_ENDPOINT)
	http_liked_assets.request_completed.connect(_on_user_liked_assets_request)
	http_liked_assets.request(
		USER_LIKED_ASSETS_ENDPOINT,
		[HEADER_AGENT, HEADER_APP, HEADER_AUTH % access_token],
		HTTPClient.METHOD_GET
	)


func _on_user_liked_assets_request(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	http_liked_assets.request_completed.disconnect(_on_user_liked_assets_request)

	if response_code != 200:
		print("Liked assets request error:", response_code)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		if !json.data["assets"].is_empty():
			%NoLikedAssets.hide()
		load_thumbnails(json.data["assets"], %UserLikedAssets, false)


func _on_login_status_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))
	%LoginStatus.text = "Please enter the code from your web browser:"
	if not %LoginCode.visible:
		%LoginCode.show()
	%CancelLogin.show()


func _on_cancel_login_pressed() -> void:
	if http_login.request_completed.is_connected(_on_login_request):
		http_login.request_completed.disconnect(_on_login_request)
	http_login.cancel_request()
	_reset_login_ui()


func _on_logout_pressed():
	var browser = get_parent() as IcosaBrowser
	browser.clear_saved_token()
	%UserDetails.hide()
	_reset_login_ui()
	%LoginDetails.show()
	logged_out.emit()

func _on_upload_pressed():
	%UploadAssetWindow.show()


## NOTE: this upload method is now deprecated, however it could be useful for later. do not remove.
func _on_upload_asset_file_selected(path):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open file: %s" % path)
		return
	var file_bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var upload_http := HTTPRequest.new()
	add_child(upload_http)
	var boundary := "----GodotFormBoundary" + str(Time.get_ticks_msec())
	var body := PackedByteArray()
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"files\"; filename=\"" + path.get_file() + "\"\r\n").to_utf8_buffer())
	body.append_array("Content-Type: application/zip\r\n\r\n".to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array("\r\n".to_utf8_buffer())
	body.append_array(("--" + boundary + "--\r\n").to_utf8_buffer())

	var err = upload_http.request_raw(
		UPLOAD_ENDPOINT,
		[HEADER_AGENT, HEADER_APP, HEADER_AUTH % token, "Content-Type: multipart/form-data; boundary=" + boundary],
		HTTPClient.METHOD_POST,
		body
	)
	
	if err != OK:
		printerr("Failed to send upload request: ", err)
		upload_http.queue_free()
		return
	
	var reply = await upload_http.request_completed
	var result = reply[0]
	var response_code = reply[1]
	var headers = reply[2]
	var response_body = reply[3]

	upload_http.queue_free()

	if response_code == 200 or response_code == 201:
		print("Successfully uploaded asset!")
		# Clear existing thumbnails
		for child in %UserAssets.get_children():
			child.queue_free()
		%NoUserAssets.show()
		# Reload user assets
		_user_assets_request(token)
	else:
		printerr("Upload error: ", response_code, " ", result)
		print("Response body: ", response_body.get_string_from_utf8())

func _on_delete_request(asset_id):
	if !user_do_not_show_delete_prompt:
		%DeleteAssetWindow.show()
		%DeleteAssetWindow.set_meta("id", asset_id)
	else:
		# Delete immediately without confirmation
		_delete_asset(asset_id)

func _delete_asset(asset_id: String):
	var id = asset_id.replace("assets/", "")
	
	# Make sure we have a proper URL - add "/" if USER_ASSETS_ENDPOINT doesn't end with one
	var delete_url = USER_ASSETS_ENDPOINT
	if not delete_url.ends_with("/"):
		delete_url += "/"
	delete_url += id
	
	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaUser] DELETE ", delete_url)
	var error = http_user.request(
		delete_url,
		[HEADER_AGENT, HEADER_APP, HEADER_AUTH % token],
		HTTPClient.METHOD_DELETE
	)
	
	if error != OK:
		printerr("Failed to send delete request: ", error)
		return
	
	var response = await http_user.request_completed
	var result = response[0]
	var response_code = response[1]
	
	if response_code == 200 or response_code == 204:
		print("Successfully deleted asset: ", id)
		# Remove the thumbnail from the UI
		for thumbnail in %UserAssets.get_children():
			var thumb = thumbnail as IcosaThumbnail
			if thumb and thumb.asset.id.replace("assets/", "") == id:
				thumbnail.queue_free()
				break
	else:
		printerr("Failed to delete asset. Response code: ", response_code)

func _on_delete_asset_window_confirmed():
	var asset_id = %DeleteAssetWindow.get_meta("id") as String
	_delete_asset(asset_id)


var cookie_path = "res://addons/icosa/cookie.cfg"

func _on_do_not_show_delete_confirm_window_toggled(toggled_on):
	user_do_not_show_delete_prompt = toggled_on
	
	if !token.is_empty():
		var cookie = ConfigFile.new()
		cookie.load(cookie_path)
		cookie.set_value("user", "delete_confirm", toggled_on)
		cookie.save(cookie_path)


func _on_settings_pressed():
	pass # settings have been moved to top level of browser..
	
	#var cookie = ConfigFile.new()
	#cookie.load(cookie_path)
	#var delete_confirm_value = cookie.get_value("user", "delete_confirm")
	#%UserSettingsDoNotShowDeleteConfirmWindow.set_pressed_no_signal(delete_confirm_value)
	#%UserSettingsWindow.show()

func _on_settings_window_confirmed():
	pass # Replace with function body.

func _on_settings_window_canceled():
	pass # Replace with function body.

# Collection handlers

func _on_collections_loaded(collections: Array[IcosaAssetCollection]):
	user_collections = collections
	_display_collections()

func _display_collections():
	for child in %UserCollections.get_children():
		child.queue_free()

	var thumb_scene = load("res://addons/icosa/browser/collection_thumbnail.tscn")
	if thumb_scene == null:
		return
	for collection in user_collections:
		var thumb = thumb_scene.instantiate()
		thumb.collection = collection
		thumb.collection_manager = collection_manager
		thumb.pressed.connect(_on_collection_clicked.bind(collection))
		%UserCollections.add_child(thumb)

func _on_collection_clicked(collection: IcosaAssetCollection):
	var browser = get_parent() as IcosaBrowser
	if not browser:
		return
	var editor_scene = load("res://addons/icosa/browser/collection_editor.tscn")
	if editor_scene == null:
		return
	var editor = editor_scene.instantiate()
	editor.name = collection.collection_name
	editor.collection = collection
	editor.collection_manager = collection_manager
	var tab_index = browser.add_content_tab(editor, collection.collection_name, browser.folder_stack)
	browser._suppress_tab_selection = true
	browser.current_tab = tab_index
	browser._suppress_tab_selection = false

func _on_collection_created(collection: IcosaAssetCollection):
	print("Collection created: ", collection.collection_name)
	user_collections.append(collection)
	_display_collections()

func _on_collection_updated(collection: IcosaAssetCollection):
	print("Collection updated: ", collection.collection_name)
	# Find and update the collection in the list
	for i in range(user_collections.size()):
		if user_collections[i].collection_id == collection.collection_id:
			user_collections[i] = collection
			break
	_display_collections()

func _on_collection_deleted(collection_url: String):
	print("Collection deleted: ", collection_url)
	# Remove from list
	for i in range(user_collections.size()):
		if user_collections[i].collection_id == collection_url:
			user_collections.remove_at(i)
			break
	_display_collections()

func _on_collection_error(error_message: String):
	printerr("Collection error: ", error_message)
	if Engine.is_editor_hint():
		EditorInterface.get_editor_toaster().push_toast(error_message, EditorToaster.SEVERITY_WARNING)

## Get user collections for populating menus (called from thumbnails)
func get_user_collections() -> Array[IcosaAssetCollection]:
	return user_collections

## Add an asset to a collection (called from thumbnails)
func add_asset_to_collection(asset_id: String, collection: IcosaAssetCollection):
	var already_in := false
	for asset in collection.assets:
		if asset.id == asset_id:
			already_in = true
			break
	if not already_in:
		var asset_urls = []
		for asset in collection.assets:
			asset_urls.append(asset.id.trim_prefix("assets/"))
		asset_urls.append(asset_id.trim_prefix("assets/"))
		collection_manager.set_collection_assets(collection.collection_id, asset_urls)


func _on_create_collection_pressed():
	collection_manager.create_collection("%s's Collection" % user_data["displayName"])


func _on_user_tabs_tab_clicked(tab):
	pass # Replace with function body.
