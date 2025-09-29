@tool
class_name IcosaGalleryThumbnail
extends Button

@onready var progress = %Progress
@onready var formats : MenuButton = %Formats 
var thumbnail_request := HTTPRequest.new()

var display_name : String : set = set_display_name
func set_display_name(new_name):
	display_name = new_name
	%AssetName.text = display_name

var author_name : String : set = set_author_name
func set_author_name(new_name):
	author_name = new_name
	%AuthorName.text = author_name

var license : String : set = set_license
func set_license(new_license):
	license = new_license
	%License.text = new_license

var description : String : set = set_description
func set_description(new_description):
	description = new_description
	%Description.text = new_description





func _on_pressed():
	pass
