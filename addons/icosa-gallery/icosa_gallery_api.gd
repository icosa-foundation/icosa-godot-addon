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

var endpoints = {
	"get_asset" : "assets/%s",
	"delete_asset" : "assets/%s",
	"unpublish_asset" : "assets/%s/unpublish",
	"get_user_asset": "assets/%s/%s",
	"get_assets" : "assets",
	"device_login" : "login/device_login",
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

var order_by = [
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

enum RequestType {NONE, SEARCH, DOWNLOAD, DOWNLOAD_THUMBNAIL}
var current_request = RequestType.NONE


class Search:
	var keywords: String = ""
	var author_name: String = ""
	var asset_name: String = ""
	var description: String = ""
	var page_token: int = 1
	var page_size: int = IcosaGalleryAPI.PAGE_SIZE_DEFAULT
	var order: Array = []
	var curated: bool = false
	var categories: Array = []
	var formats: Array = ["-TILT"]
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
	#search.order = ["BEST"]
	#search.formats = ["-TILT"]
	#search.license = ["REMIXABLE"]
	search.curated = true
	search.page_size = PAGE_SIZE_DEFAULT
	return search


func get_pages_from_total_assets(page_size : int, total_assets : int):
	var page_amount = total_assets/page_size
	return page_amount























## why here?
func fade_in(node):
	node.show()
	node.modulate = 0
	var tween = create_tween()
	tween.tween_property(node, "modulate", Color(1,1,1,1), 1.0)
	tween.finished.connect(kill_tween.bind(tween))

func fade_out(node):
	node.modulate = 1
	var tween = create_tween()
	tween.tween_property(node, "modulate", Color(1,1,1,0.0), 0.25)
	tween.finished.connect(kill_tween.bind(tween))

func kill_tween(tween : Tween):
	tween.kill()
