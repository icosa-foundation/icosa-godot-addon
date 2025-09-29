
class_name IcosaAsset 
extends Resource

var asset_data : Dictionary = {} # entire asset json/dict from icosa.
## construction
## id of the asset known as "name" in the api
var id: String = ""
var display_name: String = ""
var thumbnail_url: String = ""
var thumbnail_image: Image
var description: String
var author_name: String
var author_id: String
var license: String
var formats: Dictionary[String, Array] = {}
## download & directory
var root_directory = "res://" #if Engine.is_editor_hint() else "user://"

var user_asset = false
## get a single asset json/dict and pass it in here
func _init(asset_data : Dictionary):
	build(asset_data)

func build(asset_data):
	## store the entire asset json/dict
	asset_data = asset_data
	## get the properties from the json/dict
	if "displayName" in asset_data: 
		display_name = asset_data["displayName"]
	if "thumbnail" in asset_data and "url" in asset_data["thumbnail"]: 
		thumbnail_url = asset_data["thumbnail"]["url"]
	if "description" in asset_data:
		description = asset_data["description"]
	if "authorName" in asset_data: 
		author_name = asset_data["authorName"]
	if "name" in asset_data: 
		id = asset_data["name"]
	if "license" in asset_data: 
		license = asset_data["license"]
	if "formats" in asset_data:
			for format in asset_data["formats"]:
				var format_type = format["formatType"]
				var urls = []
				var root = format["root"]
				var resources = format["resources"]
				if "url" in root: # get the model file
					urls.append(root["url"])
				for resource in resources: # get any resources. textures, bin, etc
					if "url" in resource: # there may be multiple
						urls.append(resource["url"])	
				formats.get_or_add(format_type, urls)

func cache_asset(path_to_cache):
	if thumbnail_image != null:
		ResourceSaver.save(self, path_to_cache + id + ".res", ResourceSaver.FLAG_COMPRESS) 
	else:
		## human readable.
		ResourceSaver.save(self, path_to_cache + id + ".tres") 
