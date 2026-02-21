@tool
class_name IcosaBrowser
extends TabContainer

var plus_icon = preload("res://addons/icosa/icons/plus.svg")
var cross_icon = preload("res://addons/icosa/icons/cross.svg")
var key_icon = preload("res://addons/icosa/icons/key.svg")
var magnify_icon = preload("res://addons/icosa/icons/magnify.svg")
var user_icon = preload("res://addons/icosa/icons/person.svg") # for user self
var user_search_icon = preload("res://addons/icosa/icons/person_search.svg") # for other users
var document_search = preload("res://addons/icosa/icons/document_search.svg")
var folder = preload("res://addons/icosa/icons/folder.svg")
var folder_stack = preload("res://addons/icosa/icons/folder_copy.svg")
var search_tab_scene = preload("res://addons/icosa/browser/search.tscn")
var add_tab_button: Control

var user_tab_scene = load("res://addons/icosa/browser/user.tscn")
var user_tab : IcosaUserTab
#var upload_tab = load("res://addons/icosa/upload.tscn")
var is_setup = false

var download_queue: DownloadQueue
var current_downloading_asset_name = ""  # Track which asset is being downloaded

# Tab structure: [0: User] [1...n: Content] [n+1: Plus Button]
const USER_TAB_INDEX = 0
var plus_button_index: int = -1  # Will be set during setup
var _suppress_tab_selection = false  # Prevent recursive selection

var access_token = ""
@onready var root_directory = "res://" if Engine.is_editor_hint() else "user://"
var token_path = "res://addons/icosa/cookie.cfg"
var downloads_path = ""

# ============================================================================
# TAB HELPER FUNCTIONS - Safe tab management
# ============================================================================

## Check if a tab index is the reserved user tab
func is_user_tab(index: int) -> bool:
	return index == USER_TAB_INDEX

## Check if a tab index is the reserved plus button tab
func is_plus_button_tab(index: int) -> bool:
	return index == plus_button_index

## Check if a tab index is a content tab (between user and plus button)
func is_content_tab(index: int) -> bool:
	return index > USER_TAB_INDEX and index < plus_button_index

## Get the index of the first content tab (or -1 if none exist)
func get_first_content_tab() -> int:
	if plus_button_index > USER_TAB_INDEX + 1:
		return USER_TAB_INDEX + 1
	return -1

## Get the last content tab index (or -1 if none exist)
func get_last_content_tab() -> int:
	if plus_button_index > USER_TAB_INDEX + 1:
		return plus_button_index - 1
	return -1

## Switch to a safe content tab (used when reserved tabs are accidentally selected)
## Never shows the user tab; creates a new tab if needed
func switch_to_safe_tab():
	var safe_tab = get_first_content_tab()
	if safe_tab >= 0:
		_suppress_tab_selection = true
		current_tab = safe_tab
		_suppress_tab_selection = false
	else:
		# No content tabs exist - create one (shouldn't happen with tab closing guards)
		on_add_tab_pressed()

## Add a content tab before the plus button and return its index
func add_content_tab(node: Node, title: String, icon: Texture2D = null) -> int:
	add_child(node)
	node.owner = self

	# Move plus button to the very end (only if it exists)
	if add_tab_button:
		move_child(add_tab_button, -1)
		plus_button_index = get_tab_count() - 1

	# New tab is now before plus button (or at the end if plus button doesn't exist yet)
	var tab_index = get_tab_count() - 1
	if add_tab_button:
		tab_index = plus_button_index - 1

	set_tab_title(tab_index, title)
	set_tab_button_icon(tab_index, cross_icon)
	if icon:
		set_tab_icon(tab_index, icon)

	return tab_index

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

func get_default_downloads_path() -> String:
	if Engine.is_editor_hint():
		# In editor - use a folder in the project root
		return "res://Downloads"
	else:
		# In running project - use user:// directory
		return "user://Downloads"

func save_downloads_path():
	if !downloads_path.is_empty():
		var file = ConfigFile.new()
		# Load existing config to preserve other values
		if FileAccess.file_exists(token_path):
			file.load(token_path)
		file.set_value("downloads", "path", downloads_path)
		file.save(token_path)

func load_downloads_path():
	if !FileAccess.file_exists(token_path):
		downloads_path = get_default_downloads_path()
		return
	var file = ConfigFile.new()
	file.load(token_path)
	downloads_path = file.get_value("downloads", "path", get_default_downloads_path())

	
func _ready():
	setup_tabs()
	load_token()
	load_downloads_path()

	# Update downloads path UI
	%DownloadsPath.text = downloads_path

	# Connect downloads path UI signals
	var select_button = get_node_or_null("SettingsWindow/TabContainer/Downloads/MarginContainer/VBoxContainer/DownloadsPath/SelectDownloadsPath")
	if select_button:
		select_button.pressed.connect(_on_select_downloads_path_pressed)
	%DownloadsPath.text_changed.connect(_on_downloads_path_text_changed)

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
	clear_saved_token()
	user_tab.logout()

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

	# Connect tab signals
	tab_button_pressed.connect(on_tab_button_pressed)
	tab_selected.connect(on_tab_selected)

	# Setup user tab at index 0
	var user = user_tab_scene.instantiate() as IcosaUserTab
	user.logged_in.connect(get_user_token)
	user_tab = user
	add_child(user)
	set_tab_title(USER_TAB_INDEX, "Login")
	set_tab_icon(USER_TAB_INDEX, user_icon)
	# User tab cannot be closed (no button icon)

	# Setup first search tab at index 1
	var search = search_tab_scene.instantiate() as IcosaSearchTab
	search.search_requested.connect(update_search_tab_title)
	search.tab_index = 1
	add_content_tab(search, "Search", magnify_icon)

	# Setup plus button (will be at the end after add_content_tab)
	add_tab_button = Control.new()
	add_tab_button.name = "AddTabButton"
	add_child(add_tab_button)
	plus_button_index = get_tab_count() - 1
	set_tab_title(plus_button_index, "")  # Empty title for + button
	set_tab_icon(plus_button_index, plus_icon)

	# Default to showing the first Search tab
	_suppress_tab_selection = true
	current_tab = get_first_content_tab()
	_suppress_tab_selection = false
	is_setup = true

func get_user_token(token):
	access_token = token
	save_token()
	for tab in get_children():
		if tab.name == "Login":
			tab.name = "User"

func on_tab_button_pressed(tab: int):
	# Don't allow closing the user tab or plus button
	if is_user_tab(tab) or is_plus_button_tab(tab):
		return

	# Save reference to node BEFORE doing anything
	var node_to_remove = get_tab_control(tab)

	# Remove the node
	remove_child(node_to_remove)
	node_to_remove.queue_free()

	# Recalculate plus_button_index since indices have shifted
	plus_button_index = get_tab_count() - 1

	# After removal, ensure current_tab points to a valid tab
	# If we removed the current tab, switch to a valid one
	if current_tab >= get_tab_count():
		_suppress_tab_selection = true
		var safe_tab = get_first_content_tab()
		if safe_tab >= 0:
			current_tab = safe_tab
		else:
			# No content tabs left, switch to user tab
			current_tab = USER_TAB_INDEX
		_suppress_tab_selection = false

func on_tab_selected(tab: int):
	# Ignore tab selection if we're programmatically changing tabs
	if _suppress_tab_selection:
		return

	# If the plus button tab was selected, create a new tab instead
	if is_plus_button_tab(tab):
		on_add_tab_pressed()
		return

	# User tab and content tabs can be selected normally - no special handling needed

## Called when the "+" button is pressed to add a new search tab
func on_add_tab_pressed():
	if !is_setup:
		return

	var search = search_tab_scene.instantiate() as IcosaSearchTab
	search.search_requested.connect(update_search_tab_title)

	var tab_index = add_content_tab(search, "Search", magnify_icon)
	search.tab_index = tab_index
	_suppress_tab_selection = true
	current_tab = tab_index
	_suppress_tab_selection = false

func update_search_tab_title(index, new_title):
	await get_tree().process_frame
	set_tab_title(index, "Search - " + new_title)

func add_thumbnail_tab(thumbnail : IcosaThumbnail, title : String):
	var thumbnail_copy = thumbnail.duplicate()
	thumbnail_copy.name = title
	thumbnail_copy.asset = thumbnail.asset
	thumbnail_copy.is_preview = true
	thumbnail_copy.disabled = true

	var tab_index = add_content_tab(thumbnail_copy, title, document_search)
	# Switch to the newly created tab
	_suppress_tab_selection = true
	current_tab = tab_index
	_suppress_tab_selection = false

func create_author_tab(search_tab: IcosaSearchTab, author_id: String, author_name: String, is_self: bool) -> int:
	"""Create a new tab for browsing an author's profile"""
	# Configure the search tab for author browsing
	search_tab.author_profile_id = author_id
	search_tab.author_profile_name = author_name
	search_tab.on_author_profile = true

	var tab_index = add_content_tab(search_tab, author_name, user_icon if is_self else user_search_icon)
	search_tab.tab_index = tab_index

	# Switch to the new tab
	_suppress_tab_selection = true
	current_tab = tab_index
	_suppress_tab_selection = false

	return tab_index


## Update overall download progress UI
func _on_queue_progress_updated(completed_files: int, total_files: int, completed_assets: int, total_assets: int, total_bytes: int, completed_bytes: int):
	if not has_node("%DownloadProgressBars"):
		return

	var progress_container = %DownloadProgressBars

	if not progress_container:
		return

	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaBrowser] Progress update: assets=%d/%d files=%d/%d" % [completed_assets, total_assets, completed_files, total_files])

	# Show progress container if there are downloads
	if total_assets > 0:
		if ProjectSettings.get_setting("icosa/debug_print_requests", false):
			print("[IcosaBrowser] Showing progress container (total_assets=%d)" % total_assets)
		progress_container.show()
	else:
		if ProjectSettings.get_setting("icosa/debug_print_requests", false):
			print("[IcosaBrowser] Hiding progress container (total_assets=%d)" % total_assets)
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
func _on_download_progress(current_bytes: int, total_bytes: int, asset_name: String, filename: String):
	if not has_node("%DownloadProgressBars"):
		return

	var progress_bar = %CurrentDownloadProgress
	var label = %CurrentlDownloadLabel
	var progress_container = %DownloadProgressBars

	if ProjectSettings.get_setting("icosa/debug_print_requests", false):
		print("[IcosaBrowser] Download progress: %s > %s: %d/%d bytes" % [asset_name, filename, current_bytes, total_bytes])

	var current_mb = current_bytes / (1024.0 * 1024.0)

	# Display asset and current file information
	# asset_name is now passed directly as a String
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


func _on_download_failed(asset_name: String, error_message: String):
	if not has_node("%DownloadProgressBars"):
		return

	var progress_bar = %CurrentDownloadProgress
	var label = %CurrentlDownloadLabel
	var progress_container = %DownloadProgressBars

	# Display error message with asset name
	label.text = "❌ %s: %s" % [asset_name, error_message]

	# Modulate progress bar red to indicate error
	progress_bar.self_modulate = Color.RED

	print("Download failed for %s: %s" % [asset_name, error_message])



func _on_cancel_all_downloads_pressed():
	if download_queue:
		download_queue.cancel_all_downloads()
		if has_node("%CurrentlDownloadLabel"):
			var label = %CurrentlDownloadLabel
			label.text = "Downloads cancelled"
		if has_node("%DownloadProgressBars"):
			var progress_container = %DownloadProgressBars
			await get_tree().process_frame
			progress_container.hide()


########################################
## Settings ############################

func _on_settings_toggled(toggled_on):
	%SettingsWindow.show()

func _on_user_settings_do_not_show_delete_confirm_window_toggled(toggled_on):
	pass # Replace with function body.

func _on_settings_window_confirmed():
	%Settings.set_pressed_no_signal(false)

func _on_settings_window_canceled():
	%Settings.set_pressed_no_signal(false)
	


func _on_downloads_path_dialog_dir_selected(dir: String):
	downloads_path = dir
	%DownloadsPath.text = downloads_path
	save_downloads_path()

func _on_select_downloads_path_pressed():
	var downloads_dialog = %DownloadsPathDialog as FileDialog
	if downloads_dialog:
		downloads_dialog.current_dir = downloads_path
		downloads_dialog.popup_centered_ratio(0.7)

func _on_downloads_path_text_changed(new_text: String):
	downloads_path = new_text
