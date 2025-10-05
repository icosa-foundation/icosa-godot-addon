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

## user page
# when the user is on a specific authors "profile"
var on_author_profile = false
var author_profile_id = ""
var author_profile_name = ""

## pagination
var current_page_tokens : Array[String] = [""]  # Start with empty token for first page
var current_page_index : int = 0


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
	var page_size: int = 20
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
	
	## Unused for now.
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
	
	# Hide author page elements initially
	%AuthorPage.hide()
	
	_on_keywords_text_submitted("")

func execute_search():
	%NoAssetsFound.hide()
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
	
	if current_assets["assets"].is_empty():
		%NoAssetsFound.show()
		update_pagination_ui()
		return
		
	for asset in current_assets["assets"]:
		var serialized_asset = IcosaAsset.new(asset)
		
		var thumbnail = thumbnail_scene.instantiate() as IcosaThumbnail
		thumbnail.asset = serialized_asset
		if on_author_profile:
			thumbnail.on_author_profile = true
			%AuthorPage.show()
			%AuthorPageTitle.text = author_profile_name if author_profile_name != "" else author_profile_id
			%AuthorPageAssetsFound.text = str(current_assets["totalSize"]) + " assets found"
		else:
			thumbnail.author_id_clicked.connect(search_author_id)
		thumbnail.pressed.connect(add_thumbnail_tab.bind(thumbnail, serialized_asset.display_name))
		%Assets.add_child(thumbnail)
	
	# Update pagination
	update_pagination_ui()

func update_pagination_ui():
	# Clear existing page buttons
	for child in %Pages.get_children():
		child.queue_free()
	
	if current_assets == null or not current_assets.has("totalSize"):
		%PagePrevious.disabled = true
		%PageNext.disabled = true
		return
	
	var total_size = current_assets["totalSize"]
	var page_size = current_search.page_size
	
	# Hide pagination if results fit on one page
	if total_size <= page_size:
		%PagePrevious.hide()
		%PageNext.hide()
		return
	else:
		%PagePrevious.show()
		%PageNext.show()
	
	# Enable/disable previous button
	%PagePrevious.disabled = current_page_index == 0
	
	# Enable/disable next button based on nextPageToken
	var has_next = current_assets.has("nextPageToken") and current_assets["nextPageToken"] != ""
	%PageNext.disabled = not has_next
	
	# Store next page token if available
	if has_next:
		var next_token = current_assets["nextPageToken"]
		# Only add if it's a new token
		if current_page_index + 1 >= current_page_tokens.size():
			current_page_tokens.append(next_token)
	
	# Calculate total pages (approximate)
	var total_pages = ceil(float(total_size) / float(page_size))
	
	# Create page number buttons (show current and nearby pages)
	var max_page_buttons = 5
	var start_page = max(0, current_page_index - 2)
	var end_page = min(total_pages - 1, start_page + max_page_buttons - 1)
	
	for i in range(start_page, min(end_page + 1, current_page_tokens.size())):
		var page_btn = Button.new()
		page_btn.text = str(i + 1)
		page_btn.toggle_mode = false
		page_btn.disabled = (i == current_page_index)
		
		if i == current_page_index:
			page_btn.modulate = Color.WHITE_SMOKE  # Highlight current page
		
		page_btn.pressed.connect(goto_page.bind(i))
		%Pages.add_child(page_btn)

func goto_page(page_index: int):
	if page_index < 0 or page_index >= current_page_tokens.size():
		return
	
	current_page_index = page_index
	current_search.page_token = current_page_tokens[page_index]
	clear_gallery()
	execute_search()

## for this state we want to display some information..
func search_author_id(id, author_name):
	var search = Search.new()
	search.author_id = id
	current_search = search
	on_author_profile = true
	author_profile_id = id
	author_profile_name = author_name
	
	# Reset pagination
	current_page_tokens = [""]
	current_page_index = 0
	
	clear_gallery()
	execute_search()

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
	
	# Reset pagination when starting new search
	current_page_tokens = [""]
	current_page_index = 0
	current_search.page_token = ""
	
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
		
		# Reset pagination when changing sort order
		current_page_tokens = [""]
		current_page_index = 0
		current_search.page_token = ""
		
		clear_gallery()
		execute_search()


func _on_author_name_text_submitted(new_text):
	current_search.author_name = new_text
	
	# Reset pagination
	current_page_tokens = [""]
	current_page_index = 0
	current_search.page_token = ""
	
	clear_gallery()
	execute_search()


func _on_display_name_text_submitted(new_text):
	current_search.asset_name = new_text
	
	# Reset pagination
	current_page_tokens = [""]
	current_page_index = 0
	current_search.page_token = ""
	
	clear_gallery()
	execute_search()


func _on_curated_toggled(toggled_on):
	current_search.curated = toggled_on
	
	# Reset pagination
	current_page_tokens = [""]
	current_page_index = 0
	current_search.page_token = ""
	
	clear_gallery()
	execute_search()


func _on_gltf_toggled(toggled_on):
	if toggled_on:
		if not current_search.formats.has("GLTF"):
			current_search.formats.append("GLTF")
	else:
		current_search.formats.erase("GLTF")
	
	# Reset pagination
	current_page_tokens = [""]
	current_page_index = 0
	current_search.page_token = ""
	
	clear_gallery()
	execute_search()


func _on_obj_toggled(toggled_on):
	if toggled_on:
		if not current_search.formats.has("OBJ"):
			current_search.formats.append("OBJ")
	else:
		current_search.formats.erase("OBJ")
	
	# Reset pagination
	current_page_tokens = [""]
	current_page_index = 0
	current_search.page_token = ""
	
	clear_gallery()
	execute_search()


func _on_fbx_toggled(toggled_on):
	if toggled_on:
		if not current_search.formats.has("FBX"):
			current_search.formats.append("FBX")
	else:
		current_search.formats.erase("FBX")
	
	# Reset pagination
	current_page_tokens = [""]
	current_page_index = 0
	current_search.page_token = ""
	
	clear_gallery()
	execute_search()


func _on_tilt_toggled(toggled_on):
	if toggled_on:
		if not current_search.formats.has("TILT"):
			current_search.formats.append("TILT")
	else:
		current_search.formats.erase("TILT")
	
	# Reset pagination
	current_page_tokens = [""]
	current_page_index = 0
	current_search.page_token = ""
	
	clear_gallery()
	execute_search()


func _on_remixable_toggled(toggled_on):
	# Remixable typically means CC-BY or CC0 licenses
	if toggled_on:
		current_search.license = "REMIXABLE"
	else:
		if current_search.license == "REMIXABLE":
			current_search.license = ""
	
	# Reset pagination
	current_page_tokens = [""]
	current_page_index = 0
	current_search.page_token = ""
	
	clear_gallery()
	execute_search()


func _on_cc_0_toggled(toggled_on):
	if toggled_on:
		current_search.license = "CREATIVE_COMMONS_0"
	else:
		if current_search.license == "CREATIVE_COMMONS_0":
			current_search.license = ""
	
	# Reset pagination
	current_page_tokens = [""]
	current_page_index = 0
	current_search.page_token = ""
	
	clear_gallery()
	execute_search()


func _on_cc_by_toggled(toggled_on):
	if toggled_on:
		current_search.license = "CREATIVE_COMMONS_BY"
	else:
		if current_search.license == "CREATIVE_COMMONS_BY":
			current_search.license = ""
	
	# Reset pagination
	current_page_tokens = [""]
	current_page_index = 0
	current_search.page_token = ""
	
	clear_gallery()
	execute_search()


func _on_all_cc_toggled(toggled_on):
	# All Creative Commons licenses
	if toggled_on:
		current_search.license = "ALL_CC"
	else:
		if current_search.license == "ALL_CC":
			current_search.license = ""
	
	# Reset pagination
	current_page_tokens = [""]
	current_page_index = 0
	current_search.page_token = ""
	
	clear_gallery()
	execute_search()


func _on_page_size_value_changed(value):
	current_search.page_size = int(value)
	
	# Reset pagination when page size changes
	current_page_tokens = [""]
	current_page_index = 0
	current_search.page_token = ""
	
	clear_gallery()
	execute_search()


func _on_page_previous_pressed():
	if current_page_index > 0:
		goto_page(current_page_index - 1)


func _on_page_next_pressed():
	if current_page_index + 1 < current_page_tokens.size():
		goto_page(current_page_index + 1)


func _on_author_page_go_back_pressed():
	# Exit author profile mode and return to normal search
	on_author_profile = false
	author_profile_id = ""
	author_profile_name = ""
	%AuthorPage.hide()
	
	# Create a fresh search with default parameters
	current_search = Search.new()
	
	# Reset pagination
	current_page_tokens = [""]
	current_page_index = 0
	
	clear_gallery()
	execute_search()
