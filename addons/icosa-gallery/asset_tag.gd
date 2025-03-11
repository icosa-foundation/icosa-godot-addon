extends Button
class_name AssetTag

@export var color: Color : set = set_color
var style_box : StyleBoxFlat = StyleBoxFlat.new()
var _pending_color: Color

func _init():
	style_box.set_corner_radius_all(12)
	
	set("theme_override_styles/normal", style_box)
	if _pending_color:
		set_color(_pending_color)
	
func set_color(c: Color):
	if not is_node_ready():
		_pending_color = c
		return
	color = c
	style_box.set_bg_color(c)
	set("theme_override_styles/normal", style_box)
	set("theme_override_styles/hover", style_box)
	set("theme_override_styles/pressed", style_box)
	set("theme_override_styles/disabled", style_box)

func set_text(t: String):
	text = t

func setup(text: String, tag_color: Color) -> void:
	set_text(text)
	set_color(tag_color)
