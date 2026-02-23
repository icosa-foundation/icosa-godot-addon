@tool
class_name IcosaCollectionEditor
extends PanelContainer

var collection: IcosaAssetCollection
var collection_manager: IcosaCollectionManager

var _pending_name: String = ""
var _pending_description: String = ""
var _pending_visibility: String = ""

const ThumbnailScene = preload("res://addons/icosa/browser/thumbnail.tscn")


func _ready():
	if collection == null:
		return
	_populate()
	collection_manager.collection_updated.connect(_on_collection_updated)
	collection_manager.collection_fetched.connect(_on_collection_fetched, CONNECT_ONE_SHOT)
	collection_manager.get_collection(collection.collection_id)


func _populate():
	%Title.text = "%s settings" % collection.collection_name
	%CollectionName.text = collection.collection_name
	%CollectionDescription.text = collection.description

	_pending_name = collection.collection_name
	_pending_description = collection.description
	_pending_visibility = _visibility_to_string(collection.visiblity)

	# Select current visibility in the list
	var vis_list = %Visibility
	match collection.visiblity:
		IcosaAssetCollection.Visibility.PRIVATE:
			vis_list.select(0)
		IcosaAssetCollection.Visibility.PUBLIC:
			vis_list.select(1)
		IcosaAssetCollection.Visibility.UNLISTED:
			vis_list.select(2)

	# Load asset thumbnails
	var assets_container = %Assets
	for child in assets_container.get_children():
		child.queue_free()

	for asset in collection.assets:
		var thumb = ThumbnailScene.instantiate() as IcosaThumbnail
		thumb.asset = asset
		thumb.asset.user_asset = true
		thumb.in_collection = true
		thumb.delete_requested.connect(_on_remove_asset_from_collection)
		assets_container.add_child(thumb)


func _visibility_to_string(vis: IcosaAssetCollection.Visibility) -> String:
	match vis:
		IcosaAssetCollection.Visibility.PUBLIC:
			return "PUBLIC"
		IcosaAssetCollection.Visibility.UNLISTED:
			return "UNLISTED"
		_:
			return "PRIVATE"


func _on_asset_name_text_changed(new_text: String):
	_pending_name = new_text


func _on_asset_description_text_changed():
	_pending_description = %CollectionDescription.text


func _on_visibility_item_selected(index: int):
	match index:
		0: _pending_visibility = "PRIVATE"
		1: _pending_visibility = "PUBLIC"
		2: _pending_visibility = "UNLISTED"




func _on_collection_fetched(fetched: IcosaAssetCollection):
	if fetched.collection_id != collection.collection_id:
		return
	collection = fetched
	_populate()

func _on_collection_updated(updated: IcosaAssetCollection):
	if updated.collection_id != collection.collection_id:
		return
	collection = updated
	_populate()


func _on_save_collection_pressed():
	if collection_manager == null or collection == null:
		return
	collection_manager.update_collection(
		collection.collection_id,
		_pending_name,
		_pending_description,
		_pending_visibility
	)


func _on_remove_asset_from_collection(asset_id: String):
	if collection_manager == null or collection == null:
		return
	var asset_urls = []
	for asset in collection.assets:
		if asset.id != asset_id:
			asset_urls.append(asset.id.trim_prefix("assets/"))
	collection_manager.set_collection_assets(collection.collection_id, asset_urls)


func _on_delete_collection_pressed():
	%DeleteCollectionConfirmation.show()


func _on_delete_collection_confirmation_confirmed():
	if collection_manager == null or collection == null:
		return
	collection_manager.collection_deleted.connect(_on_deleted_close_tab, CONNECT_ONE_SHOT)
	collection_manager.delete_collection(collection.collection_id)


func _on_delete_collection_confirmation_canceled():
	pass


func _on_deleted_close_tab(_collection_url: String):
	# Find our tab in the browser and close it
	var browser = get_tree().root.find_child("IcosaBrowser", true, false) as IcosaBrowser
	if not browser:
		return
	for i in range(browser.get_tab_count()):
		if browser.get_tab_control(i) == self:
			browser.on_tab_button_pressed(i)
			return
