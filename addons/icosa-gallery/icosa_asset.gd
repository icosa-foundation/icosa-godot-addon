"""
Asset class.
- Stores ALL asset data from the request in full and in properties.
- Can be saved to disk as a .res (binary) or a.tres (text), can be cached to disk.
- download the thumbnail image into the resource for cache storage also.
"""
class_name IcosaAsset 
extends Resource

var asset_data : Dictionary = {} # entire asset json/dict from icosa.
## construction
## id of the asset known as "name" in the api
var id: String = ""
var display_name: String
var thumbnail_url: String 
var thumbnail_image: Image
var description: String
var author_name: String
var author_id: String
var license: String
var formats: Dictionary[String, Array] = {}

## download & directory
var root_directory = "res://" if Engine.is_editor_hint() else "user://"

## get a single asset json/dict and pass it in here
func _init(asset_data : JSON):
	build(asset_data)
	download_thumbnail_image()

func build(asset_data):
	## store the entire asset json/dict
	asset_data = asset_data
	## get the properties from the json/dict
	if "displayName" in asset_data: 
		display_name = asset_data["displayName"]
	if "thumbnail" in asset_data and asset_data["thumbnail"] is Dictionary and "url" in asset_data["thumbnail"]: 
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

## this class is a resource.
## we cant use HTTPRequest because its a node, but we can use HTTPClient..
func download_thumbnail_image():
	var download = HTTPClient.new()
	## we would have to get hostname "aws.s3.us-east" and then add the /content/stuff.obj
	var hostname = thumbnail_url.split("/")[2] # not tested! example code
	var connect_error = download.connect_to_host(hostname, 445)
	var status = download.get_status()
	if connect_error:
		print("Failure.")
	else:
		match status:
			HTTPClient.STATUS_CONNECTING:
				print("connecting..")
		#● STATUS_DISCONNECTED = 0
		#Status: Disconnected from the server.
		#● STATUS_RESOLVING = 1
		#Status: Currently resolving the hostname for the given URL into an IP.
		#● STATUS_CANT_RESOLVE = 2
		#Status: DNS failure: Can't resolve the hostname for the given URL.
		#● STATUS_CONNECTING = 3
		#Status: Currently connecting to server.
		#● STATUS_CANT_CONNECT = 4
		#Status: Can't connect to the server.
		#● STATUS_CONNECTED = 5
		#Status: Connection established.
		#● STATUS_REQUESTING = 6
		#Status: Currently sending request.
		#● STATUS_BODY = 7
		#Status: HTTP body received.
		#● STATUS_CONNECTION_ERROR = 8
		#Status: Error in HTTP connection.
		#● STATUS_TLS_HANDSHAKE_ERROR = 9
		#Status: Error in TLS handshake.

## stub
func create_asset_directory():
	pass

## another example
func cache_asset(path_to_cache):
	if thumbnail_image != null:
		ResourceSaver.save(self, path_to_cache + id + ".res", ResourceSaver.FLAG_COMPRESS) 
	else:
		## human readable.
		ResourceSaver.save(self, path_to_cache + id + ".tres") 
