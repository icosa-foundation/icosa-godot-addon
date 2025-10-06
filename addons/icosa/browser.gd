@tool
class_name IcosaBrowser
extends TabContainer

var plus_icon = preload("res://addons/icosa/icons/plus.svg")
var cross_icon = preload("res://addons/icosa/icons/cross.svg")
var key_icon = preload("res://addons/icosa/icons/key.svg")
var magnify_icon = preload("res://addons/icosa/icons/magnify.svg")

var search_tab_scene = preload("res://addons/icosa/search.tscn")
var add_tab_button = Control.new() # dummy node for tabs managment

var user_tab_scene = load("res://addons/icosa/user.tscn")
var user_tab : IcosaUserTab
#var upload_tab = load("res://addons/icosa/upload.tscn")
var is_setup = false

var access_token = ""
@onready var root_directory = "res://" if Engine.is_editor_hint() else "user://"
var token_path = "res://addons/icosa/cookie.cfg"

func save_token():
	if !access_token.is_empty():
		var file = ConfigFile.new()
		file.set_value("user", "token", access_token)
		file.save(token_path)

func load_token():
	if !FileAccess.file_exists(token_path):
		return
	var file = ConfigFile.new()
	file.load(token_path)
	access_token = file.get_value("user", "token")

func clear_saved_token():
	if !FileAccess.file_exists(token_path):
		return
	var file = FileAccess.open(token_path, FileAccess.WRITE)
	DirAccess.remove_absolute(file.get_path_absolute())
	access_token = ""
	
	
func _ready():
	setup_tabs()
	load_token()
	print("token: ", access_token)
	if access_token == null:
		return
	if !access_token.is_empty():
		user_tab.recieved_user_data.connect(on_logged_in)
		user_tab.user_token_too_old.connect(token_too_old)
		user_tab._user_request(access_token)
		user_tab.token = access_token

func on_logged_in(user_data):
	for tab in get_children():
		if tab.name == "Login":
			tab.name = user_data["displayName"]


func token_too_old():
	pass

func setup_tabs():
	# make it easier.
	drag_to_rearrange_enabled = false 
	
	tab_button_pressed.connect(on_tab_button_pressed)
	tab_selected.connect(on_tab_selected)
	tab_clicked.connect(on_tab_clicked)
	
	var search = search_tab_scene.instantiate()
	search.search_requested.connect(update_search_tab_title)
	add_child(search)
	set_tab_title(0, "Search")
	set_tab_button_icon(0, cross_icon)
	set_tab_icon(0, magnify_icon)
	var user = user_tab_scene.instantiate() as IcosaUserTab
	user.logged_in.connect(get_user_token)
	user_tab = user
	add_child(user)
	set_tab_title(1, "Login")
	set_tab_icon(1, key_icon)
	# this could contain an empty scene, to tell the user to add a tab to search. etc.
	add_child(add_tab_button) 
	set_tab_title(2, "")
	#set_tab_button_icon(1, plus_icon)
	set_tab_icon(2, plus_icon)
	is_setup = true

func get_user_token(token):
	access_token = token
	save_token()
	for tab in get_children():
		if tab.name == "Login":
			tab.name = "User"

func on_tab_button_pressed(tab):
	get_child(tab).queue_free()

func on_tab_selected(tab):
	pass

func on_tab_clicked(tab):
	get_previous_tab()
	
	if !is_setup:
		return
	
	var last_tab = get_tab_count()-1
	if tab == last_tab:
		var search = search_tab_scene.instantiate() as IcosaSearchTab
		search.search_requested.connect(update_search_tab_title)
		add_child(search)
		move_child(search, last_tab-1)
		set_tab_title(last_tab-1, "Search")
		set_tab_button_icon(last_tab-1, cross_icon)
		get_child(get_previous_tab()).show()
	
func update_search_tab_title(index, new_title):
	await get_tree().process_frame
	set_tab_title(index, "Search - " + new_title)

func add_thumbnail_tab(thumbnail : IcosaThumbnail, title : String):
	var selected_tab : Control
	for child in get_children():
		if child.visible:
			selected_tab = child
	
	var thumbnail_copy = thumbnail.duplicate()
	thumbnail_copy.asset = thumbnail.asset
	thumbnail_copy.is_preview = true
	add_child(thumbnail_copy)
	thumbnail_copy.disabled = true
	var place = selected_tab.get_index()+1
	move_child(thumbnail_copy, place)
	set_tab_title(place, title)
	set_tab_button_icon(place, cross_icon)


func _on_downloads_tree_exited():
	if Engine.is_editor_hint(): 
		var toaster = EditorInterface.get_editor_toaster()
		toaster.push_toast("Download Finished!")
