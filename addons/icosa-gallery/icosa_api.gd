@tool
class_name IcosaGalleryAPI
extends HTTPRequest

var web_safe_headers : Array[String] = [
		#"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
		"Accept: */*",
		#"Connection: keep-alive"
	]

var headers = [
	"Content-Type: application/json",
	"User-Agent: Godot Icosa Browser"
]

var url = "https://api.icosa.gallery/v1/"

var token_path = "user://icosa_token.cfg"

var endpoints = {
	"get_asset" : "assets/%s",
	"delete_asset" : "assets/%s",
	"unpublish_asset" : "assets/%s/unpublish",
	"get_user_asset": "assets/%s/%s",
	"get_assets" : "assets",
	"login" : "login/device_login",
	"login_status" : "login/device_status",
	"logout" : "logout",
	"oembed" : "oembed",
	"poly" : "poly",
	"get_user_me" : "users/me",
	"update_user_me" : "users/me",
	"get_user_assets" : "users/me/assets",
	"get_user_likedassets" : "users/me/likedassets"
}

const PAGE_SIZE_DEFAULT = 20

enum MaxComplexity {
	NONE, 
	COMPLEX,
	MEDIUM,
	SIMPLE,
}

const categories = [
	 "MISCELLANEOUS",
	 "ANIMALS",
	 "ARCHITECTURE",
	 "ART",
	 "CULTURE",
	 "EVENTS",
	 "FOOD",
	 "HISTORY",
	 "HOME",
	 "NATURE",
	 "OBJECTS",
	 "PEOPLE",
	 "PLACES",
	 "SCIENCE",
	 "SPORTS",
	 "TECH",
	 "TRANSPORT",
	 "TRAVEL"
]

const formats = [
	"TILT",
	"BLOCKS",
	"GLTF",
	"GLTF1",
	"GLTF2",
	"OBJ",
	"FBX",
	"-TILT",
	"-BLOCKS",
	"-GLTF",
	"-GLTF1",
	"-GLTF2",
	"-OBJ",
	"-FBX",
]

static var order_by = [
	"NEWEST",
	"OLDEST",
	"BEST",
	"CREATE_TIME",
	"-CREATE_TIME",
	"UPDATE_TIME",
	"-UPDATE_TIME",
	"TRIANGLE_COUNT",
	"-TRIANGLE_COUNT",
	"LIKED_TIME",
	"-LIKED_TIME",
	"LIKES",
	"-LIKES",
	"DOWNLOADS",
	"-DOWNLOADS",
	"DISPLAY_NAME",
	"-DISPLAY_NAME",
	"AUTHOR_NAME",
	"-AUTHOR_NAME"
]

var licenses = [
	## these can be derivative. good for default search
	"REMIXABLE", 
	"CREATIVE_COMMONS_BY_3_0", 
	"CREATIVE_COMMONS_BY_4_0", 
	"CREATIVE_COMMONS_BY", 
	"CREATIVE_COMMONS_0",
	## advanced search to see copyrighted assets
	"ALL_CC", 
	"CREATIVE_COMMONS_BY_ND_4_0", 
	"CREATIVE_COMMONS_BY_ND_3_0", 
	"CREATIVE_COMMONS_BY_ND", 
]

enum RequestType {
	NONE, SEARCH, DOWNLOAD, DOWNLOAD_THUMBNAIL, 
	LOGIN, LOGIN_STATUS, LOGOUT, USER_GET, USER_ASSETS, USER_LIKED_ASSETS
}

var current_request = RequestType.NONE

# Login-related variables
var access_token: String = ""
var device_code: String = ""
var is_authenticated: bool = false

class Search:
	var keywords: String = ""
	var author_name: String = ""
	var asset_name: String = ""
	var description: String = ""
	var page_token: int = 1
	var page_size: int 
	var order: Array = []
	var curated: bool = false
	var categories: Array = []
	var formats: Array
	var complexity = IcosaGalleryAPI.MaxComplexity.NONE
	var triangle_count_min: int = -1
	var triangle_count_max: int = -1
	var license : Array = []

## this is what an asset looks like
class Asset:
	var display_name: String = ""
	var thumbnail: String = ""
	var description: String = ""
	var author_id: String = ""
	var author_name: String = ""
	var license: String = ""
	# urls to download gltf, fbx, usd
	var formats: Dictionary[String, Array] = {}
	# id of the asset known as "name"
	var id: String = ""

func build_request(endpoint: String, args: Array = []) -> String: 
	return url + endpoints[endpoint] % args

func _encode(value: String) -> String: 
	return value.uri_encode()

func build_query_url_from_search_object(search: Search) -> String:
	var url = build_request("get_assets")
	var query_params = []
	if search.keywords: query_params.append("keywords=%s" % _encode(search.keywords))
	if search.author_name: query_params.append("author_name=%s" % _encode(search.author_name))
	if search.asset_name: query_params.append("name=%s" % _encode(search.asset_name))
	if search.description: query_params.append("description=%s" % _encode(search.description))
	if search.page_token > 1: query_params.append("pageToken=%d" % search.page_token)
	if search.triangle_count_min >= 0: query_params.append("triangleCountMin=%d" % search.triangle_count_min)
	if search.triangle_count_max >= 0: query_params.append("triangleCountMax=%d" % search.triangle_count_max)
	if search.curated: query_params.append("curated=true")
	if search.categories.size() > 0: query_params.append("categories=%s" % ",".join(search.categories))
	if search.formats.size() > 0: query_params.append("formats=%s" % ",".join(search.formats))
	if search.complexity != MaxComplexity.NONE: query_params.append("complexity=%s" % MaxComplexity.keys()[search.complexity])
	if search.order.size() > 0: query_params.append("orderBy=%s" % ",".join(search.order))
	if search.license.size() > 0: query_params.append("license=%s" % ",".join(search.license))
	if search.page_size != PAGE_SIZE_DEFAULT: query_params.append("pageSize=%d" % search.page_size)
	if query_params.size() > 0:
		url += "?" + "&".join(query_params)
	return url

## all the items in the gallery.
var total_size : int = 0

func get_asset_objects_from_response(response) -> Array[Asset]:
	total_size = response["totalSize"]
	
	var assets : Array[Asset] = []
	if not response is Dictionary or not "assets" in response:
		push_error("Invalid response format: missing 'assets' key")
		return []
	for asset_data in response["assets"]:
		var asset = Asset.new()
		if "displayName" in asset_data: asset.display_name = asset_data["displayName"]
		if "thumbnail" in asset_data and asset_data["thumbnail"] is Dictionary and "url" in asset_data["thumbnail"]: asset.thumbnail = asset_data["thumbnail"]["url"]
		if "description" in asset_data: asset.description = asset_data["description"]
		if "authorName" in asset_data: asset.author_name = asset_data["authorName"]
		if "name" in asset_data: asset.id = asset_data["name"]
		if "license" in asset_data: asset.license = asset_data["license"]
		if "formats" in asset_data:
			var formats : Dictionary[String, Array] = {}
			
			for format in asset_data["formats"]:
				var format_type = format["formatType"]
				var urls = []
				var root = format["root"]
				var resources = format["resources"]
				# get the model file
				if "url" in root:
					urls.append(root["url"])
				# get any resources. textures, bin, etc
				for resource in resources:
					# there may be multiple
					if "url" in resource:
						urls.append(resource["url"])
						
				formats.get_or_add(format_type, urls)
			asset.formats = formats
			
		assets.append(asset)
	return assets

## a basic helper function
static func create_default_search() -> Search:
	var search = Search.new()
	search.order = ["BEST"]
	#search.formats = ["-TILT"]
	#search.license = ["REMIXABLE"]
	search.curated = true
	search.page_size = PAGE_SIZE_DEFAULT
	return search

func get_pages_from_total_assets(page_size : int, total_assets : int):
	var page_amount = total_assets/page_size
	return page_amount

# Login-related methods
func login_with_device_code(device_code: String) -> int:
	self.device_code = device_code
	current_request = RequestType.LOGIN
	
	var login_data = JSON.stringify({"device_code": device_code})
	var custom_headers = headers.duplicate()
	custom_headers.append("Content-Type: application/json")
	
	return request(build_request("login"), custom_headers, HTTPClient.METHOD_POST, login_data)

func check_login_status() -> int:
	if device_code.is_empty():
		push_error("No device code available for status check")
		return ERR_INVALID_PARAMETER
	
	current_request = RequestType.LOGIN_STATUS
	var status_data = JSON.stringify({"device_code": device_code})
	var custom_headers = headers.duplicate()
	custom_headers.append("Content-Type: application/json")
	
	return request(build_request("login_status"), custom_headers, HTTPClient.METHOD_POST, status_data)

func logout() -> int:
	current_request = RequestType.LOGOUT
	var custom_headers = headers.duplicate()
	
	# Include access token if available
	if not access_token.is_empty():
		custom_headers.append("Authorization: Bearer " + access_token)
	
	var result = request(build_request("logout"), custom_headers, HTTPClient.METHOD_POST, "{}")
	
	# Clear login state regardless of request result
	clear_access_token()
	
	return result

func clear_access_token():
	access_token = ""
	device_code = ""
	is_authenticated = false

func set_access_token(token: String):
	access_token = token
	is_authenticated = not token.is_empty()

func is_logged_in() -> bool:
	return is_authenticated and not access_token.is_empty()

# Helper method to add authentication headers to requests
func get_authenticated_headers() -> Array[String]:
	var auth_headers = headers.duplicate()
	if is_logged_in():
		auth_headers.append("Authorization: Bearer " + access_token)
	return auth_headers

# Override the request method to automatically include auth headers
func authenticated_request(url: String, custom_headers: PackedStringArray = [], method: int = HTTPClient.METHOD_GET, request_data: String = "") -> int:
	var final_headers = get_authenticated_headers()
	final_headers.append_array(custom_headers)
	return request(url, final_headers, method, request_data)

# Method to get user profile
func get_user_profile() -> int:
	if not is_logged_in():
		push_error("Not logged in")
		return ERR_UNCONFIGURED
	
	current_request = RequestType.SEARCH  # Reusing SEARCH type for user data
	return authenticated_request(build_request("get_user_me"))

# Method to get user's assets
func get_user_assets() -> int:
	if not is_logged_in():
		push_error("Not logged in")
		return ERR_UNCONFIGURED
	
	current_request = RequestType.SEARCH
	return authenticated_request(build_request("get_user_assets"))

# Method to get user's liked assets
func get_user_liked_assets() -> int:
	if not is_logged_in():
		push_error("Not logged in")
		return ERR_UNCONFIGURED
	
	current_request = RequestType.SEARCH
	return authenticated_request(build_request("get_user_likedassets"))
