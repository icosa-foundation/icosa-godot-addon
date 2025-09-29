## icosa browser.
@tool
extends Control

var current_page = 1
const DEFAULT_COLUMN_SIZE = 5
@export var api : IcosaGalleryAPI
@onready var thumbnail_scene := preload("res://addons/icosa-gallery/thumbnail.tscn")
@onready var tab_scene := preload("res://addons/icosa-gallery/icosa_gallery_tab.tscn")

var current_search : IcosaGalleryAPI.Search = IcosaGalleryAPI.create_default_search()
var chosen_thumbnail : Control
var asset_size = 250

var token_path = "user://icosa_token.cfg"  # Changed to user:// for write permissions
var access_token = ""

const LOGGED_OUT_MESSAGE = "You are not logged in. [url=https://icosa.gallery/device]Login Here.[/url]"

# Login variables
var is_logged_in = false
var user_info = {}

signal model_downloaded(model_file)
var plus_icon = load("res://addons/icosa-gallery/icons/plus.svg")

# Tab management
var search_tabs = {}  # Store search data per tab: {tab_index: {search: Search, page: int}}
var current_tab_index = 0


func _ready():
	_load_token()  # Load token at start
	_update_ui_for_login()
	
	# Create initial search tab
	_create_new_search_tab("Search")
	
	# Add plus tab for new searches
	var add_tab = MarginContainer.new()
	add_tab.name = "AddTab"
	%Tabs.add_child(add_tab)
	%Tabs.set_tab_title(%Tabs.get_tab_count() - 1, "")
	%Tabs.set_tab_icon(%Tabs.get_tab_count() - 1, plus_icon)
	
	# Load initial search
	_on_search_bar_text_submitted("")

func _load_token():
	var config = ConfigFile.new()
	var err = config.load(token_path)
	if err == OK:
		access_token = config.get_value("auth", "access_token", "")
		if access_token != "":
			# Verify token is still valid
			_verify_token_validity()
		else:
			is_logged_in = false
	else:
		is_logged_in = false

func _save_token():
	var config = ConfigFile.new()
	config.set_value("auth", "access_token", access_token)
	config.save(token_path)

func _verify_token_validity():
	if access_token == "":
		is_logged_in = false
		return
		
	# Make a test request to verify token
	api.current_request = IcosaGalleryAPI.RequestType.USER_GET
	var error = api.request(
		api.url + api.endpoints["get_user_me"],
		[
			'accept: application/json',
			'Authorization: Bearer %s' % access_token,
		],
		HTTPClient.METHOD_GET, 
        ""
	)
	
	if error != OK:
		is_logged_in = false
		access_token = ""
		_save_token()  # Clear invalid token

func login(device_code):
	device_code = device_code.strip_edges()
	
	if device_code.length() != 5:
		%LoginStatus.text = "Device code must be exactly 5 characters"
		return
	
	else:
		%LoginStatus.text = "Logging in..."
		
		# Build the URL with device_code as query parameter
		var url = api.url + api.endpoints["login"] + "?device_code=" + device_code
		
		api.current_request = IcosaGalleryAPI.RequestType.LOGIN
		var error = api.request(
			url,
			PackedStringArray(["Content-Type: application/json", "accept: application/json"]),
			HTTPClient.METHOD_POST,
			""  # Empty body as shown in the API example
		)
		
		if error != OK:
			%LoginStatus.text = "Failed to send login request"
			push_error("An error occurred in the login request.")

func logout():
	is_logged_in = false
	user_info = {}
	access_token = ""
	if api.has_method("clear_access_token"):
		api.clear_access_token()
	
	# Clear saved token
	var config = ConfigFile.new()
	config.set_value("auth", "access_token", "")
	config.save(token_path)
	
	_update_ui_for_login()
	%LoginStatus.text = "Logged out"
	
	# Send logout request to API if endpoint exists
	if api.endpoints.has("logout"):
		api.request(
			api.url + api.endpoints["logout"],
			PackedStringArray(["Content-Type: application/json"]),
			HTTPClient.METHOD_POST,
            "{}"
		)

func _update_ui_for_login():
	if is_logged_in:
		%LoginCode.hide()
		%LogoutButton.show()
		%UserInfo.show()
		%UserInfo.text = "Loading user info..."
		
		# Request user info - will be updated when response arrives
		api.current_request = IcosaGalleryAPI.RequestType.USER_GET
		api.request(
			api.url + api.endpoints["get_user_me"],
			[
			'accept: application/json',
			'Authorization: Bearer %s' % access_token,
			],
			HTTPClient.METHOD_GET, 
            ""
		)
	else:
		%LoginCode.show()
		%LogoutButton.hide()
		%UserInfo.hide()
		%UserInfo.text = LOGGED_OUT_MESSAGE

func _on_search_bar_text_submitted(new_text):
	var current_tab_data = _get_current_tab_data()
	if not current_tab_data:
		return
		
	current_tab_data.search.keywords = new_text
	current_tab_data.page = 1
	current_tab_data.search.page_token = current_tab_data.page
	
	if not chosen_thumbnail == null:
		_on_go_back_pressed()
	
	var url = api.build_query_url_from_search_object(current_tab_data.search)
	api.current_request = IcosaGalleryAPI.RequestType.SEARCH
	var error = api.request(url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
	
	%Tabs.set_tab_title(current_tab_index, "Search: " + current_tab_data.search.keywords)

func _on_api_request_completed(result, response_code, headers, body):
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		push_error("Failed to parse API response")
		return
		
	var response = json.get_data()
	
	# Handle login response
	if api.current_request == IcosaGalleryAPI.RequestType.LOGIN:
		_handle_login_response(response, response_code)
		return
		
	# Handle user info response
	if api.current_request == IcosaGalleryAPI.RequestType.USER_GET:
		_handle_user_info_response(response, response_code)
		return
	
	# Handle search responses
	if api.current_request == IcosaGalleryAPI.RequestType.SEARCH:
		_handle_search_response(response)

func _handle_login_response(response, response_code):
	if response_code == 200:
		if response and response.has("access_token"):
			is_logged_in = true
			%LoginStatus.text = "Logged in successfully!"
			access_token = response["access_token"]
			_save_token()  # Save the token
			
			# Store the access token in the API
			if api.has_method("set_access_token"):
				api.set_access_token(response["access_token"])
			
			# Get user info after successful login
			_update_ui_for_login()
		else:
			%LoginStatus.text = "Login failed: Invalid response"
	else:
		var error_msg = "Login failed: " + str(response_code)
		if response and response.has("error"):
			error_msg += " - " + response["error"]
		%LoginStatus.text = error_msg

func _handle_user_info_response(response, response_code):
	if response_code == 200:
		user_info = response
		var user_text = "Logged in as: [b]" + user_info.get("username", "User") + "[/b]"
		if user_info.get("email"):
			user_text += "\nEmail: " + user_info.get("email")
		%UserInfo.text = user_text
	else:
		%UserInfo.text = "Failed to load user info"
		# Token might be invalid, force logout
		if response_code == 401:
			logout()

func _on_go_back_pressed():
	%PreviewLayer.hide()


# Pagination Button Logic
func _refresh_pagination_buttons(current, total_pages):
	# Clear previous pagination buttons
	for child in %PageNumbers.get_children():
		child.queue_free()
	
	# Get the page labels to show (numbers or "...")
	var page_buttons = get_pagination_buttons(current, total_pages)
	for page_label in page_buttons:
		var page_button = Button.new()
		# If the label is a number, configure button to be clickable
		if typeof(page_label) == TYPE_INT:
			page_button.text = str(page_label)
			page_button.toggle_mode = true
			# Disable button if it's the current page
			page_button.disabled = (page_label == current)
			page_button.toggled.connect(on_page_number_pressed.bind(page_label, page_button))
		else:
			# If it's a string (i.e. "..."), show a disabled button
			page_button.text = "..."
			page_button.disabled = true
		
		%PageNumbers.add_child(page_button)

func get_pagination_buttons(current, total_pages):
	var pages = []
	
	if total_pages <= 6:
		# If there are 6 or fewer pages, show all pages
		for i in range(1, total_pages + 1):
			pages.append(i)
	else:
		# When there are more than 6 pages, dynamically choose which pages to show
		if current <= 3:
			# Show first four pages, ellipsis, and last page
			pages = [1, 2, 3, 4, "...", total_pages]
		elif current >= total_pages - 2:
			# Show first page, ellipsis, and last four pages
			pages = [1, "...", total_pages - 3, total_pages - 2, total_pages - 1, total_pages]
		else:
			# Show first page, ellipsis, current -1, current, current +1, ellipsis, and last page
			pages = [1, "...", current - 1, current, current + 1, "...", total_pages]
			
	return pages

func on_page_number_pressed(toggled, page_number, page_button):
	var current_tab_data = _get_current_tab_data()
	if not current_tab_data:
		return
		
	current_tab_data.page = page_number
	current_tab_data.search.page_token = page_number
	
	# Refresh pagination buttons so the current page is highlighted
	var total_pages = api.get_pages_from_total_assets(current_tab_data.search.page_size, api.total_size)
	_refresh_pagination_buttons(current_tab_data.page, total_pages)
	
	request_new_page()

func _on_previous_page_pressed():
	var current_tab_data = _get_current_tab_data()
	if not current_tab_data:
		return
		
	if current_tab_data.page > 1:
		current_tab_data.page -= 1
		current_tab_data.search.page_token = current_tab_data.page
		request_new_page()

func _on_next_page_pressed():
	var current_tab_data = _get_current_tab_data()
	if not current_tab_data:
		return
		
	var total_pages = api.get_pages_from_total_assets(current_tab_data.search.page_size, api.total_size)
	if current_tab_data.page < total_pages:
		current_tab_data.page += 1
		current_tab_data.search.page_token = current_tab_data.page
		request_new_page()

func request_new_page():
	var current_tab_data = _get_current_tab_data()
	if not current_tab_data:
		return
		
	var url = api.build_query_url_from_search_object(current_tab_data.search)
	api.current_request = IcosaGalleryAPI.RequestType.SEARCH
	var error = api.request(url)
	if error != OK:
		push_error("Failed to load new page.")

func show_host_offline_popup():
	%HostOffline.show()

## Help menu, also about.
func _on_help_pressed():
	%Help.show()

func _on_search_options_toggled(toggled_on):
	if toggled_on:
		%SearchOptionsMenu.show()
	else:
		%SearchOptionsMenu.hide()

##### search gui options.

func _on_search_author_text_changed(new_text):
	var current_tab_data = _get_current_tab_data()
	if current_tab_data:
		current_tab_data.search.author_name = new_text

func _on_search_description_text_changed(new_text):
	var current_tab_data = _get_current_tab_data()
	if current_tab_data:
		current_tab_data.search.description = new_text

func _on_gltf_2_toggled(toggled_on):
	var current_tab_data = _get_current_tab_data()
	if not current_tab_data:
		return
		
	if toggled_on:
		current_tab_data.search.formats.append("GLTF2")
		current_tab_data.search.formats.erase("-GLTF2")
	else:
		current_tab_data.search.formats.append("-GLTF2")
		current_tab_data.search.formats.erase("GLTF2")

func _on_obj_toggled(toggled_on):
	var current_tab_data = _get_current_tab_data()
	if not current_tab_data:
		return
		
	if toggled_on:
		current_tab_data.search.formats.append("OBJ")
		current_tab_data.search.formats.erase("-OBJ")
	else:
		current_tab_data.search.formats.append("-OBJ")
		current_tab_data.search.formats.erase("OBJ")

func _on_fbx_toggled(toggled_on):
	var current_tab_data = _get_current_tab_data()
	if not current_tab_data:
		return
		
	if toggled_on:
		current_tab_data.search.formats.append("FBX")
		current_tab_data.search.formats.erase("-FBX")
	else:
		current_tab_data.search.formats.append("-FBX")
		current_tab_data.search.formats.erase("FBX")

## other model formats. no support for these yet. (TILT, BLOCKS, etc)
func _on_other_toggled(toggled_on):
	pass # Replace with function body.

func _on_remixable_toggled(toggled_on):
	var current_tab_data = _get_current_tab_data()
	if current_tab_data:
		current_tab_data.search.license.append("REMIXABLE")

## non derivative works are off by default. not really the idea here.
func _on_nd_toggled(toggled_on):
	var current_tab_data = _get_current_tab_data()
	if current_tab_data:
		current_tab_data.search.license.append("ALL_CC")

func _on_min_triangles_value_changed(value):
	var current_tab_data = _get_current_tab_data()
	if current_tab_data:
		current_tab_data.search.triangle_count_min = value

func _on_max_triangles_value_changed(value):
	var current_tab_data = _get_current_tab_data()
	if current_tab_data:
		current_tab_data.search.triangle_count_max = value

## the array `IcosaGalleryAPI.order_by` handles ordering. will make GUI later. 
func _on_best_toggled(toggled_on):
	#current_search. ?? no api for this yet.
	pass 
	refresh_search()

func _on_curated_toggled(toggled_on):
	var current_tab_data = _get_current_tab_data()
	if current_tab_data:
		current_tab_data.search.curated = toggled_on
	refresh_search()

func _on_page_size_value_changed(value):
	var current_tab_data = _get_current_tab_data()
	if current_tab_data:
		current_tab_data.search.page_size = value

func _on_search_author_text_submitted(new_text):
	refresh_search()

func _on_search_description_text_submitted(new_text):
	refresh_search()

func refresh_search():
	var current_tab_data = _get_current_tab_data()
	if current_tab_data:
		_on_search_bar_text_submitted(current_tab_data.search.keywords)

## FIXME, do this more gracefully.
func _on_order_pressed():
	if %ORDER.item_count < 1:
		for ordering in IcosaGalleryAPI.order_by:
			%ORDER.add_item(ordering)

func _on_order_item_selected(index):
	var current_tab_data = _get_current_tab_data()
	if current_tab_data:
		current_tab_data.search.order.append(%ORDER.get_item_text(index))

func _on_focus_entered():
	pass # Replace with function body.

func _on_dim_pressed():
	%PreviewLayer.hide()

func _on_preview_author_pressed():
	%PreviewLayer.hide()
	var search = IcosaGalleryAPI.create_default_search()
	search.author_name = %PreviewAuthor.text
	current_search = search
	refresh_search()

func _on_tabs_tab_button_pressed(tab):
	# Don't allow closing the add tab or if it's the last search tab
	if tab < %Tabs.get_tab_count() - 1 and %Tabs.get_tab_count() > 2:
		# Remove from our tab data storage
		if search_tabs.has(tab):
			search_tabs.erase(tab)
		
		# Update indices for remaining tabs
		var new_search_tabs = {}
		for i in range(tab + 1, %Tabs.get_tab_count() - 1):
			if search_tabs.has(i):
				new_search_tabs[i - 1] = search_tabs[i]
		search_tabs = new_search_tabs
		
		%Tabs.get_child(tab).queue_free()

var is_adding_tab = false

func _on_tabs_tab_changed(tab):
	if is_adding_tab:
		return

	current_tab_index = tab

	# If the add tab was clicked, create a new search tab
	if tab == %Tabs.get_tab_count() - 1:
		is_adding_tab = true
		_create_new_search_tab("New Search")
		%Tabs.current_tab = %Tabs.get_tab_count() - 2  # Switch to the new tab
		is_adding_tab = false
	#else:
		## Update UI for the selected tab
		#var tab_data = _get_current_tab_data()
		#if tab_data:
			## Update search bar and other UI elements to match the tab's search
			#%SearchBar.text = tab_data.search.keywords
			## You'll need to update other UI elements here as well

func _create_new_search_tab(title):
	var new_tab_index = %Tabs.get_tab_count() - 1  # Insert before add tab
	
	var new_tab = tab_scene.instantiate() as IcosaTab
	new_tab.mode = IcosaTab.TabMode.SEARCH
	%Tabs.add_child(new_tab)
	%Tabs.move_child(new_tab, new_tab_index)
	
	# Store search data for this tab
	search_tabs[new_tab_index] = {
		"search": IcosaGalleryAPI.create_default_search(),
		"page": 1
	}
	
	%Tabs.set_tab_title(new_tab_index, title)
	%Tabs.set_tab_button_icon(new_tab_index, cross_icon)

func _get_current_tab_data():
	if search_tabs.has(current_tab_index):
		return search_tabs[current_tab_index]
	return null

func _on_user_info_meta_clicked(meta):
	OS.shell_open(str(meta))

func _on_login_code_text_changed(new_text):
	if len(new_text) == 5:
		login(new_text)

# Add logout button connection (call this from your UI setup)
func _on_logout_button_pressed():
	logout()

# New functions for user endpoints
func load_user_assets():
	if not is_logged_in:
		%LoginStatus.text = "Please log in to view your assets"
		return
	
	# Create a new tab for user assets
	_create_new_search_tab("My Assets")
	var new_tab_index = %Tabs.get_tab_count() - 2
	%Tabs.current_tab = new_tab_index
	
	# Set up search for user assets
	var tab_data = search_tabs[new_tab_index]
	# You'll need to modify this based on your API's user assets endpoint
	api.current_request = IcosaGalleryAPI.RequestType.USER_ASSETS
	var error = api.request(
		api.url + api.endpoints["get_user_assets"],
		[
			'accept: application/json',
			'Authorization: Bearer %s' % access_token,
		],
		HTTPClient.METHOD_GET, 
        ""
	)
	
	if error != OK:
		push_error("Failed to load user assets")

func load_user_liked_assets():
	if not is_logged_in:
		%LoginStatus.text = "Please log in to view liked assets"
		return
	
	# Create a new tab for liked assets
	_create_new_search_tab("Liked Assets")
	var new_tab_index = %Tabs.get_tab_count() - 2
	%Tabs.current_tab = new_tab_index
	
	# Set up search for liked assets
	var tab_data = search_tabs[new_tab_index]
	api.current_request = IcosaGalleryAPI.RequestType.USER_LIKED_ASSETS
	var error = api.request(
		api.url + api.endpoints["get_user_likedassets"],
		[
			'accept: application/json',
			'Authorization: Bearer %s' % access_token,
		],
		HTTPClient.METHOD_GET, 
        ""
	)
	
	if error != OK:
		push_error("Failed to load liked assets")

## issues:
## store login token to a file, loading file to keep session (sortof cookie)
## using a + in the tabs, so that we can add new search tabs. (with gallery_scene.instantiate()) 
## sorting the addtab + so it stays at the end
## making sure the user information is loaded at the right time, rather than before the request completes.
## adding all the user endpoints, and using tabs to display results. 
