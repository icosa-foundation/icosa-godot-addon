extends Control

@onready var assets = %Assets
@onready var loading_animation = %Loading
@onready var page_numbers = %PageNumbers
@onready var categories = %Categories


var request = HTTPRequest.new()
var current_page = 1
var total_pages = 0  # Will be calculated once
var items_per_page = 20
var all_assets = []
var next_page_token = null
var total_size = 0
var page_tokens = {}  # Add this to store tokens for each page
var current_search = ""  # Add this at the top with other variables
var tags_list = []  # Replace categories_list with tags_list
var is_curated = false
var selected_tags = []  # Add this to track selected tags

func _ready():
	var tween = get_tree().create_tween()
	tween.tween_property(loading_animation, "value", 100, 10)
		
	add_child(request)
	request.request_completed.connect(_on_initial_tags_fetch)
	_fetch_initial_tags()

func _fetch_initial_tags():
	# Make a request to get some initial assets to extract tags
	var url = "https://api.icosa.gallery/v1/assets?page_size=100"  # Larger page to get tag variety
	var headers = ["Content-Type: application/json"]
	request.request(url, headers, HTTPClient.METHOD_GET)

func _on_initial_tags_fetch(result, response_code, headers, body):
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("assets"):
			# Extract unique tags
			var unique_tags = {}
			for asset in json["assets"]:
				if asset.has("tags"):
					for tag in asset["tags"]:
						unique_tags[tag] = true
			
			tags_list = unique_tags.keys()
			tags_list.sort()
			
			# Clear existing children
			for child in categories.get_children():
				child.queue_free()
			
			# Create CheckButton for each tag
			for tag in tags_list:
				var check = CheckButton.new()
				check.text = tag
				check.toggled.connect(_on_tag_toggled.bind(tag))
				categories.add_child(check)
	
	# Disconnect this handler and connect the regular one
	request.request_completed.disconnect(_on_initial_tags_fetch)
	request.request_completed.connect(_on_request_completed)
	
	# Now fetch the actual first page of assets
	fetch_assets()

func _on_tag_toggled(button_pressed: bool, tag: String):
	if button_pressed:
		if not tag in selected_tags:
			selected_tags.append(tag)
	else:
		selected_tags.erase(tag)
	
	# Refresh the assets with new tag selection
	current_page = 1
	next_page_token = null
	loading_animation.show()
	assets.hide()
	fetch_assets()

func fetch_assets():
	# Cancel any existing request first
	if request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		request.cancel_request()
	
	print("Fetching assets for page ", current_page)
	var url = "https://api.icosa.gallery/v1/assets?page_size=%d" % [items_per_page]
	
	if current_search.length() > 0:
		url += "&keywords=" + current_search.uri_encode()
	
	# Add all selected tags to the query
	for tag in selected_tags:
		url += "&tag=" + tag.uri_encode()
	
	if is_curated:
		url += "&curated=true"
	
	if current_page > 1 and next_page_token:
		url += "&pageToken=" + next_page_token
	
	print("Requesting URL: ", url)
	var headers = ["Content-Type: application/json"]
	request.request(url, headers, HTTPClient.METHOD_GET)

func _on_request_completed(result, response_code, headers, body):
	print("Asset list response received. Code: ", response_code)
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json:
			# Print the full nextPageToken from response
			print("API Response nextPageToken: ", json.get("nextPageToken"))
			
			if total_size == 0:
				total_size = json.get("totalSize", 0)
				total_pages = ceil(float(total_size) / items_per_page)
				print("Total assets: ", total_size, ", Pages: ", total_pages)
			
			all_assets = json.get("assets", [])
			next_page_token = json.get("nextPageToken")
			
			print("Received ", all_assets.size(), " assets for page ", current_page)
			# Print first asset name to verify content is different
			if all_assets.size() > 0:
				print("First asset name: ", all_assets[0].get("name", "unknown"))
			
			display_page()
			update_page_numbers()
			loading_animation.hide()
			assets.show()

func display_page():
	# Clear existing thumbnails
	print("Clearing existing thumbnails...")
	for child in assets.get_children():
		child.queue_free()
	assets.get_children().clear()  # Make sure we clear all children
	
	print("Displaying assets for page ", current_page)
	print("Number of assets to display: ", all_assets.size())
	
	for i in range(all_assets.size()):
		var asset = all_assets[i]
		if asset.has("thumbnail"):
			display_thumbnail(asset)
		else:
			print("Asset missing thumbnail: ", asset)

func update_page_numbers():
	# Only update the UI elements, don't recalculate total pages
	for child in page_numbers.get_children():
		child.queue_free()
	
	var visible_pages = 5
	var start_page = max(1, current_page - visible_pages/2)
	var end_page = min(total_pages, start_page + visible_pages - 1)
	
	# Add first page button if not in range
	if start_page > 1:
		var first_button = Button.new()
		first_button.text = "1"
		first_button.toggle_mode = true
		first_button.pressed.connect(func(): go_to_page(1))
		page_numbers.add_child(first_button)
		
		if start_page > 2:
			var ellipsis = Label.new()
			ellipsis.text = "..."
			page_numbers.add_child(ellipsis)
	
	# Add page number buttons
	for i in range(start_page, end_page + 1):
		var button = Button.new()
		button.text = str(i)
		button.toggle_mode = true
		button.button_pressed = (i == current_page)
		button.pressed.connect(func(): go_to_page(i))
		page_numbers.add_child(button)
	
	# Add last page button if not in range
	if end_page < total_pages:
		if end_page < total_pages - 1:
			var ellipsis = Label.new()
			ellipsis.text = "..."
			page_numbers.add_child(ellipsis)
		
		var last_button = Button.new()
		last_button.text = str(total_pages)
		last_button.toggle_mode = true
		last_button.pressed.connect(func(): go_to_page(total_pages))
		page_numbers.add_child(last_button)

func go_to_page(page):
	if page < 1 or page > total_pages:
		print("Page", page, "is out of bounds")
		return
	
	current_page = page
	loading_animation.show()
	assets.hide()
	fetch_assets()

func display_thumbnail(asset_data):
	var thumbnail_scene = preload("res://addons/icosa-gallery/thumbnail.tscn")
	var thumbnail = thumbnail_scene.instantiate()
	assets.add_child(thumbnail)
	
	# Debug print
	print("Setting up thumbnail for asset: ", asset_data.get("name"))
	
	# Initial setup without texture
	thumbnail.setup(asset_data)
	
	# Verify thumbnail URL exists and is valid
	if not asset_data.has("thumbnail"):
		push_error("Asset has no thumbnail data: ", asset_data.get("name"))
		return
	if not asset_data["thumbnail"].has("url"):
		push_error("Thumbnail has no URL: ", asset_data.get("name"))
		return
		
	var thumb_url = asset_data["thumbnail"]["url"]
	print("Thumbnail URL: ", thumb_url)
	
	# Create HTTP request node
	var thumb_loader = HTTPRequest.new()
	thumbnail.add_child(thumb_loader)
	
	# Wait for the node to be ready and in the scene tree
	await get_tree().process_frame
	
	# Connect the completion signal
	thumb_loader.request_completed.connect(
		func(result, code, headers, body):
			print("Thumbnail download completed. Result: ", result, " Code: ", code)
			
			if result != HTTPRequest.RESULT_SUCCESS:
				push_error("Failed to download thumbnail: ", result)
				thumb_loader.queue_free()
				return
				
			if code != 200:
				push_error("HTTP Error: ", code)
				thumb_loader.queue_free()
				return
			
			var image = Image.new()
			var error = image.load_png_from_buffer(body)
			if error != OK:
				push_error("Failed to load image: ", error)
				thumb_loader.queue_free()
				return
			
			var texture = ImageTexture.create_from_image(image)
			# Update thumbnail with texture
			if is_instance_valid(thumbnail):
				thumbnail.setup(asset_data, texture)
			
			thumb_loader.queue_free()
	)
	
	# Make the request
	var error = thumb_loader.request(thumb_url)
	if error != OK:
		push_error("Failed to start thumbnail request: ", error, " URL: ", thumb_url)
		thumb_loader.queue_free()

func _on_first_pressed():
	print("First button pressed")
	go_to_page(1)

func _on_previous_pressed():
	print("Previous button pressed")
	go_to_page(current_page - 1)

func _on_next_pressed():
	print("Next button pressed, current_page:", current_page, " total_pages:", total_pages)
	go_to_page(current_page + 1)

func _on_last_pressed():
	print("Last button pressed")
	go_to_page(total_pages)


func _on_search_bar_text_submitted(new_text):
	current_search = new_text
	current_page = 1  # Reset to first page
	next_page_token = null  # Reset page token
	loading_animation.show()
	assets.hide()
	fetch_assets()


func _on_categories_item_activated(index):
	current_page = 1
	next_page_token = null
	loading_animation.show()
	assets.hide()
	fetch_assets()


func _on_curated_pressed():
	is_curated = !is_curated  # Toggle curated state
	current_page = 1
	next_page_token = null
	loading_animation.show()
	assets.hide()
	fetch_assets()
