@tool
class_name IcosaSearchTab
extends Control


var http = HTTPRequest.new()
const HEADER_AGENT := "User-Agent: Icosa Gallery Godot Engine / 1.0"
const HEADER_APP = 'accept: application/json'
var search_endpoint = 'https://api.icosa.gallery/v1/assets'
var thumbnail_scene = load("res://addons/icosa/thumbnail.tscn")

var up_icon = load("res://addons/icosa/icons/arrow_up.svg")
var down_icon = load("res://addons/icosa/icons/arrow_down.svg")


var current_assets = {}
var cached_assets : Array[IcosaAsset] = []

var keywords = ""
var browser : IcosaBrowser

# Create a Search object to manage search parameters
var current_search : Search

signal search_requested(tab_index : int, search_term : String)


class Search:
	var keywords: String = ""
	var curated: bool = true
	var category: String = ""
	var formats: Array[String] = ["GLTF"]
	var asset_name: String = ""
	var description: String = ""
	var tags: Array[String] = []
	var triangle_count_min: int = -1
	var triangle_count_max: int = -1
	var max_complexity: String = ""
	var author_name: String = ""
	var author_id: String = ""
	var license: String = "REMIXABLE"
	var page_token: String = ""
	var page_size: int = -1
	var order_by : OrderBy = OrderBy.BEST
	
	## MINUS = "Descending"
	enum OrderBy {
		EMPTY,
		NEWEST, 
		OLDEST,
		BEST,
		CREATE_TIME,
		MINUS_CREATE_TIME,
		UPDATE_TIME,
		MINUS_UPDATE_TIME,
		TRIANGLE_COUNT,
		MINUS_TRIANGLE_COUNT,
		LIKED_TIME,
		MINUS_LIKED_TIME,
		LIKES,
		MINUS_LIKES,
		DOWNLOADS,
		MINUS_DOWNLOADS,
		DISPLAY_NAME,
		MINUS_DISPLAY_NAME,
		AUTHOR_NAME,
		MINUS_AUTHOR_NAME
	}
	
	enum Category {
		EMPTY,
		MISCELLANEOUS,
		ANIMALS,
		ARCHITECTURE,
		ART,
		CULTURE,
		EVENTS,
		FOOD,
		HISTORY,
		HOME,
		NATURE,
		OBJECTS,
		PEOPLE,
		PLACES,
		SCIENCE,
		SPORTS,
		TECH,
		TRANSPORT,
		TRAVEL
	}
	
	enum MaxComplexity {
		COMPLEX,
		MEDIUM,
		SIMPLE
	}
	
	func build_query() -> String:
		var params: Array[String] = []
		
		if keywords != "":
			params.append("keywords=" + keywords.uri_encode())
		if curated:
			params.append("curated=true")
		if category != "":
			params.append("category=" + category)
		if formats.size() > 0:
			for format in formats:
				params.append("format=" + format)
		if asset_name != "":
			params.append("name=" + asset_name.uri_encode())
		if description != "":
			params.append("description=" + description.uri_encode())
		if tags.size() > 0:
			for tag in tags:
				params.append("tag=" + tag.uri_encode())
		if triangle_count_min > -1:
			params.append("triangleCountMin=" + str(triangle_count_min))
		if triangle_count_max > -1:
			params.append("triangleCountMax=" + str(triangle_count_max))
		if max_complexity != "":
			params.append("maxComplexity=" + max_complexity)
		if author_name != "":
			params.append("authorName=" + author_name.uri_encode())
		if author_id != "":
			params.append("authorId=" + author_id)
		if license != "":
			params.append("license=" + license)
		if page_token != "":
			params.append("pageToken=" + page_token)
		if page_size > -1:
			params.append("pageSize=" + str(page_size))
		if order_by != OrderBy.EMPTY:
			var filter = OrderBy.keys()[order_by]
			if filter.begins_with("MINUS_"):
				filter = "-" + filter.substr(6)
			params.append("orderBy=" + filter)
		
		if params.size() == 0:
			return ""
		return "?" + "&".join(params)



func _ready():
	add_child(http)
	http.request_completed.connect(on_search)
	browser = get_parent() as IcosaBrowser
	
	# Initialize the search object
	current_search = Search.new()
	
	# Populate the OrderBy dropdown with icons
	%OrderBy.clear()
	%OrderBy.add_item("Best", 0)
	%OrderBy.add_item("Newest", 1)
	%OrderBy.add_item("Oldest", 2)
	%OrderBy.add_icon_item(up_icon, "Create Time", 3)
	%OrderBy.add_icon_item(down_icon, "Create Time", 4)
	%OrderBy.add_icon_item(up_icon, "Update Time", 5)
	%OrderBy.add_icon_item(down_icon, "Update Time", 6)
	%OrderBy.add_icon_item(up_icon, "Triangle Count", 7)
	%OrderBy.add_icon_item(down_icon, "Triangle Count", 8)
	%OrderBy.add_icon_item(up_icon, "Liked Time", 9)
	%OrderBy.add_icon_item(down_icon, "Liked Time", 10)
	%OrderBy.add_icon_item(up_icon, "Likes", 11)
	%OrderBy.add_icon_item(down_icon, "Likes", 12)
	%OrderBy.add_icon_item(up_icon, "Downloads", 13)
	%OrderBy.add_icon_item(down_icon, "Downloads", 14)
	%OrderBy.add_icon_item(up_icon, "Display Name", 15)
	%OrderBy.add_icon_item(down_icon, "Display Name", 16)
	%OrderBy.add_icon_item(up_icon, "Author Name", 17)
	%OrderBy.add_icon_item(down_icon, "Author Name", 18)
	
	_on_keywords_text_submitted("")

func execute_search():
	"""Execute a search using the current_search object"""
	var query = current_search.build_query()
	print(query)
	http.request(search_endpoint + query, [HEADER_AGENT, HEADER_APP], HTTPClient.METHOD_GET)

func build_query(keywords):
	var query = "?"
	return query + "keywords=" + keywords

func on_search(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray):
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		json.parse(body.get_string_from_utf8())

	if json.data.has("detail"):
		printerr(json.data["detail"][0]["msg"])
		return
	
	current_assets = json.data
	
	
	
	if current_assets == null or not current_assets.has("assets"):
		return
	
	for asset in current_assets["assets"]:
		var serialized_asset = IcosaAsset.new(asset)
		
		var thumbnail = thumbnail_scene.instantiate() as IcosaThumbnail
		thumbnail.asset = serialized_asset
		thumbnail.pressed.connect(add_thumbnail_tab.bind(thumbnail, serialized_asset.display_name))
		%Assets.add_child(thumbnail)


func add_thumbnail_tab(thumbnail : IcosaThumbnail, title : String):
	thumbnail.is_preview = true
	browser.add_thumbnail_tab(thumbnail, title)


func clear_gallery():
	for child in %Assets.get_children():
		child.queue_free()


func _on_keywords_text_submitted(new_text : String):
	keywords = new_text
	current_search.keywords = new_text
	search_requested.emit(get_index(), keywords)
	clear_gallery()
	execute_search()


func _on_keywords_text_changed(new_text):
	pass


func _on_order_by_item_selected(index):
	# Map the dropdown index to the OrderBy enum
	var order_by_mapping = {
		0: Search.OrderBy.BEST,
		1: Search.OrderBy.NEWEST,
		2: Search.OrderBy.OLDEST,
		3: Search.OrderBy.CREATE_TIME,
		4: Search.OrderBy.MINUS_CREATE_TIME,
		5: Search.OrderBy.UPDATE_TIME,
		6: Search.OrderBy.MINUS_UPDATE_TIME,
		7: Search.OrderBy.TRIANGLE_COUNT,
		8: Search.OrderBy.MINUS_TRIANGLE_COUNT,
		9: Search.OrderBy.LIKED_TIME,
		10: Search.OrderBy.MINUS_LIKED_TIME,
		11: Search.OrderBy.LIKES,
		12: Search.OrderBy.MINUS_LIKES,
		13: Search.OrderBy.DOWNLOADS,
		14: Search.OrderBy.MINUS_DOWNLOADS,
		15: Search.OrderBy.DISPLAY_NAME,
		16: Search.OrderBy.MINUS_DISPLAY_NAME,
		17: Search.OrderBy.AUTHOR_NAME,
		18: Search.OrderBy.MINUS_AUTHOR_NAME
	}
	
	if order_by_mapping.has(index):
		current_search.order_by = order_by_mapping[index]
		clear_gallery()
		execute_search()


func _on_author_name_text_submitted(new_text):
	current_search.author_name = new_text
	clear_gallery()
	execute_search()


func _on_display_name_text_submitted(new_text):
	current_search.asset_name = new_text
	clear_gallery()
	execute_search()


func _on_curated_toggled(toggled_on):
	current_search.curated = toggled_on
	clear_gallery()
	execute_search()


func _on_gltf_toggled(toggled_on):
	if toggled_on:
		if not current_search.formats.has("GLTF"):
			current_search.formats.append("GLTF")
	else:
		current_search.formats.erase("GLTF")
	clear_gallery()
	execute_search()


func _on_obj_toggled(toggled_on):
	if toggled_on:
		if not current_search.formats.has("OBJ"):
			current_search.formats.append("OBJ")
	else:
		current_search.formats.erase("OBJ")
	clear_gallery()
	execute_search()


func _on_fbx_toggled(toggled_on):
	if toggled_on:
		if not current_search.formats.has("FBX"):
			current_search.formats.append("FBX")
	else:
		current_search.formats.erase("FBX")
	clear_gallery()
	execute_search()


func _on_tilt_toggled(toggled_on):
	if toggled_on:
		if not current_search.formats.has("TILT"):
			current_search.formats.append("TILT")
	else:
		current_search.formats.erase("TILT")
	clear_gallery()
	execute_search()


func _on_remixable_toggled(toggled_on):
	# Remixable typically means CC-BY or CC0 licenses
	if toggled_on:
		current_search.license = "REMIXABLE"
	else:
		if current_search.license == "REMIXABLE":
			current_search.license = ""
	clear_gallery()
	execute_search()


func _on_cc_0_toggled(toggled_on):
	if toggled_on:
		current_search.license = "CREATIVE_COMMONS_0"
	else:
		if current_search.license == "CREATIVE_COMMONS_0":
			current_search.license = ""
	clear_gallery()
	execute_search()


func _on_cc_by_toggled(toggled_on):
	if toggled_on:
		current_search.license = "CREATIVE_COMMONS_BY"
	else:
		if current_search.license == "CREATIVE_COMMONS_BY":
			current_search.license = ""
	clear_gallery()
	execute_search()


func _on_all_cc_toggled(toggled_on):
	# All Creative Commons licenses
	if toggled_on:
		current_search.license = "ALL_CC"
	else:
		if current_search.license == "ALL_CC":
			current_search.license = ""
	clear_gallery()
	execute_search()
