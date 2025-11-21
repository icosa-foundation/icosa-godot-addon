@tool
class_name IcosaBrowser
extends TabContainer

var plus_icon = preload("res://addons/icosa/icons/plus.svg")
var cross_icon = preload("res://addons/icosa/icons/cross.svg")
var key_icon = preload("res://addons/icosa/icons/key.svg")
var magnify_icon = preload("res://addons/icosa/icons/magnify.svg")

var search_tab_scene = preload("res://addons/icosa/browser/search.tscn")
var add_tab_button = Control.new() # dummy node for tabs managment

var user_tab_scene = load("res://addons/icosa/browser/user.tscn")
var user_tab : IcosaUserTab
#var upload_tab = load("res://addons/icosa/upload.tscn")
var is_setup = false

var download_queue: DownloadQueue
var current_downloading_asset_name = ""  # Track which asset is being downloaded

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

	# Initialize the master download queue
	download_queue = preload("res://addons/icosa/browser/download_queue.gd").new()
	add_child(download_queue)

	# Connect download queue signals
	download_queue.queue_progress_updated.connect(_on_queue_progress_updated)
	download_queue.download_progress.connect(_on_download_progress)
	download_queue.download_failed.connect(_on_download_failed)

	tab_button_pressed.connect(on_tab_button_pressed)
	tab_selected.connect(on_tab_selected)
	tab_clicked.connect(on_tab_clicked)

	var user = user_tab_scene.instantiate() as IcosaUserTab
	user.logged_in.connect(get_user_token)
	user_tab = user
	add_child(user)
	set_tab_title(0, "Login")
	set_tab_icon(0, key_icon)
	# User tab cannot be closed (no button icon)

	var search = search_tab_scene.instantiate() as IcosaSearchTab
	search.search_requested.connect(update_search_tab_title)
	add_child(search)
	search.owner = self
	search.tab_index = 1
	set_tab_title(1, "Search")
	set_tab_button_icon(1, cross_icon)
	set_tab_icon(1, magnify_icon)

	# this could contain an empty scene, to tell the user to add a tab to search. etc.
	add_child(add_tab_button)
	set_tab_title(2, "")
	set_tab_icon(2, plus_icon)

	# Default to showing the first Search tab
	current_tab = 1
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
		search.owner = self
		move_child(search, last_tab)
		search.tab_index = last_tab
		set_tab_title(last_tab, "Search")
		set_tab_icon(last_tab, magnify_icon)
		set_tab_button_icon(last_tab, cross_icon)
		# Move the "+" button to the end to maintain tab order invariant
		move_child(add_tab_button, get_child_count()-1)
		set_tab_icon(get_tab_count()-1, plus_icon)
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
	thumbnail_copy.owner = self
	thumbnail_copy.disabled = true
	var place = selected_tab.get_index()+1
	move_child(thumbnail_copy, place)
	set_tab_title(place, title)
	set_tab_button_icon(place, cross_icon)
	# Move the "+" button to the end to maintain tab order invariant
	move_child(add_tab_button, get_child_count()-1)


## Update overall download progress UI
func _on_queue_progress_updated(completed_files: int, total_files: int, completed_assets: int, total_assets: int, total_bytes: int, completed_bytes: int):
	var progress_container = get_parent().get_node("DownloadProgressBars")

	# Show progress container if there are downloads
	if total_assets > 0:
		progress_container.show()
	else:
		progress_container.hide()
		return

	# Update total progress label and bar
	var total_label = %TotalDownloadsLabel
	var total_progress = %TotalDownloadsProgress

	# Format total bytes for display
	var total_mb = total_bytes / (1024.0 * 1024.0)
	var completed_mb = completed_bytes / (1024.0 * 1024.0)

	# Show total size information with current asset name
	var asset_info = current_downloading_asset_name if current_downloading_asset_name != "" else "Preparing..."
	if total_bytes > 0:
		total_label.text = "%s: %d/%d assets - %d/%d files - %.1f/%.1f MB" % [asset_info, completed_assets, total_assets, completed_files, total_files, completed_mb, total_mb]
		total_progress.max_value = total_bytes
		total_progress.value = completed_bytes
	else:
		total_label.text = "%s: %d/%d assets - %d/%d files" % [asset_info, completed_assets, total_assets, completed_files, total_files]
		total_progress.max_value = total_files if total_files > 0 else 1
		total_progress.value = completed_files

	# Hide progress when all downloads complete
	if completed_files == total_files and total_files > 0:
		await get_tree().process_frame
		progress_container.hide()

## Update current file download progress (bytes)
func _on_download_progress(current_bytes: int, total_bytes: int, thumbnail: IcosaThumbnail, filename: String):
	var progress_bar = %CurrentDownloadProgress
	var label = %CurrentlDownloadLabel
	var progress_container = get_parent().get_node("DownloadProgressBars")

	var current_mb = current_bytes / (1024.0 * 1024.0)

	# Display asset and current file information
	var asset_name = thumbnail.asset.display_name if thumbnail else "Unknown"
	# Update the asset name being tracked for the total label
	current_downloading_asset_name = asset_name

	# Handle case where content length is unknown
	if total_bytes <= 0:
		# Show what's been downloaded so far without estimation
		if current_bytes > 0:
			label.text = "%s > %s: %.2f MB downloaded (size unknown)" % [asset_name, filename, current_mb]
			progress_bar.max_value = 1
			progress_bar.value = 0
		else:
			label.text = "%s > %s: 0.00 MB (connecting...)" % [asset_name, filename]
			progress_bar.max_value = 1
			progress_bar.value = 0
		return

	progress_bar.max_value = total_bytes
	progress_bar.value = current_bytes

	# Format bytes for display
	var total_mb = total_bytes / (1024.0 * 1024.0)
	var percent = (float(current_bytes) / float(total_bytes)) * 100.0
	label.text = "%s > %s: %.2f / %.2f MB (%.0f%%)" % [asset_name, filename, current_mb, total_mb, percent]

	# Reset progress bar color to normal
	progress_bar.self_modulate = Color.WHITE


func _on_download_failed(thumbnail: IcosaThumbnail, error_message: String):
	var progress_bar = %CurrentDownloadProgress
	var label = %CurrentlDownloadLabel
	var progress_container = get_parent().get_node("DownloadProgressBars")

	# Display error message with asset name
	var asset_name = thumbnail.asset.display_name if thumbnail else "Unknown"
	label.text = "❌ %s: %s" % [asset_name, error_message]

	# Modulate progress bar red to indicate error
	progress_bar.self_modulate = Color.RED

	print("Download failed for %s: %s" % [asset_name, error_message])


func _on_user_settings_do_not_show_delete_confirm_window_toggled(toggled_on):
	pass # Replace with function body.


func _on_cancel_all_downloads_pressed():
	if download_queue:
		download_queue.cancel_all_downloads()
		var label = %CurrentlDownloadLabel
		label.text = "Downloads cancelled"
		var progress_container = get_parent().get_node("DownloadProgressBars")
		await get_tree().process_frame
		progress_container.hide()
