@tool
class_name IcosaSearchTab
extends Control


var http = HTTPRequest.new()
const HEADER_AGENT := "User-Agent: Icosa Gallery Godot Engine / 1.0"
const HEADER_APP = 'accept: application/json'
var search_endpoint = 'https://api.icosa.gallery/v1/assets'
var thumbnail_scene = load("res://addons/icosa/thumbnail.tscn")

var current_assets = {}
var cached_assets : Array[IcosaAsset] = []

var keywords = ""
var browser : IcosaBrowser

signal search_requested(tab_index : int, search_term : String)


func _ready():
	add_child(http)
	http.request_completed.connect(on_search)
	browser = get_parent() as IcosaBrowser
	_on_keywords_text_submitted("")


func search(query):
	http.request(search_endpoint + query, [HEADER_AGENT, HEADER_APP], HTTPClient.METHOD_GET)

func build_query(keywords):
	var query = "?"
	return query + "orderBy=BEST&license=REMIXABLE&" + "keywords=" + keywords

func on_search(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray):
	#match response_code:
		#200:
			#print("Success!")
		#404:
			#print("not found?")

	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	current_assets = json.data
	for asset in current_assets["assets"]:
		var serialized_asset = IcosaAsset.new(asset)
		#print(JSON.stringify(asset, " " , false))
		
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

func _on_keywords_text_submitted(new_text):
	keywords = new_text
	search_requested.emit(get_index(), keywords)
	clear_gallery()
	search(
	build_query(keywords)
	)
