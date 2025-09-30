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

var http_login = HTTPRequest.new()
var http_user = HTTPRequest.new()
var http_assets = HTTPRequest.new()
var http_liked_assets = HTTPRequest.new()

var token: String
var is_logged_in := false

var user_do_not_show_delete_prompt = false

func _ready() -> void:
	add_child(http_login)
	add_child(http_user)
	add_child(http_assets)
	add_child(http_liked_assets)

	%LoginStatus.text = DEFAULT_MESSAGE


func load_thumbnails(assets_data: Array, add_to: Control, user = false) -> void:
	await get_tree().process_frame
	for asset_data in assets_data:
		await get_tree().process_frame
		var asset = IcosaAsset.new(asset_data)
		var thumbnail = load("res://addons/icosa/thumbnail.tscn").instantiate() as IcosaThumbnail
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
	http_login.request_completed.connect(_on_login_request)
	http_login.request(
		LOGIN_ENDPOINT + "?device_code=%s" % device_code,
		[HEADER_APP],
		HTTPClient.METHOD_POST
	)


func _on_login_request(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	http_login.request_completed.disconnect(_on_login_request)

	if response_code != 200:
		print("Login error:", response_code)
		if response_code == 401:
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
	%LoginCode.editable = true
	%LoginCode.selecting_enabled = true
	%LoginCode.modulate = Color.WHITE
	%Loading.visible = false


func _login_success() -> void:
	%LoginDetails.hide()
	%UserDetails.show()
	#print("token is: ", token)
	_user_request(token)
	_user_assets_request(token)
	_user_liked_assets_request(token)

func logout():
	%LoginDetails.show()
	%UserDetails.hide()
	token = ""
func _user_request(access_token: String) -> void:
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
		var user_data = json.data
		print("Logged in as:", user_data["displayName"])
		recieved_user_data.emit(user_data)
		%LoggedInAs.text = "Logged in as %s" % user_data["displayName"]


func _user_assets_request(access_token: String) -> void:
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


func _on_logout_pressed():
	var browser = get_parent() as IcosaBrowser
	browser.clear_saved_token()
	%UserDetails.hide()
	_reset_login_ui()
	%LoginDetails.show()
	logged_out.emit()

func _on_upload_pressed():
	%UploadAssetWindow.show()

func _on_upload_asset_file_selected(path):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Could not open file: %s" % path)
		return

	# Read entire file as bytes
	var file_bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()

	# Create HTTPRequest node (must be in the scene tree!)
	var upload_http := HTTPRequest.new()
	add_child(upload_http)  # Important: needs to be inside the tree

	print(
		UPLOAD_ENDPOINT,
		[HEADER_AGENT, HEADER_APP, HEADER_AUTH % token, "Content-Type: application/zip"],
	)
	"""
	
	https://api.icosa.gallery/v1/users/me/assets
	[
curl -X POST 
-H "Content-Type: multipart/form-data" 
-H "Authorization: Bearer <token>" 
-F "files=@teapot.zip" https://api.icosa.gallery/v1/users/me/assets
	]

	"""
	var err = upload_http.request_raw(
		UPLOAD_ENDPOINT,
		[HEADER_AGENT, HEADER_APP, HEADER_AUTH % token, "Content-Type: application/zip"],
		HTTPClient.METHOD_POST,
		file_bytes
	)
	
	
	var reply = await upload_http.request_completed
	var result = reply[0]
	var response_code = reply[1]
	var headers = reply[2]
	var body = reply[3]

	if response_code != 200: printerr("error: ", response_code," ", result)
	else: print(body)
	##   ERROR: error: 201 0


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

func _on_do_not_show_delete_confirm_window_toggled(toggled_on):
	user_do_not_show_delete_prompt = toggled_on
