## This class can be used like:
## GET 'https://api.icosa.gallery/v1/collections'
## GET' 'https://api.icosa.gallery/v1/users/me/collections'
class_name IcosaAssetCollection
extends Resource

## content
var assets : Array[IcosaAsset]

## metadata
var collection_id : String = ""
var collection_name : String = ""
var description : String = ""
var imageUrl : String = ""
var create_time : String = ""
var update_time : String = ""

## access
enum Visibility {PRIVATE, PUBLIC, UNLISTED}
var visiblity : Visibility
