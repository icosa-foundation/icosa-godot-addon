@tool
class_name Throbber
extends TextureProgressBar

@export var loop_time: float = 1.0 : set = set_loop_time      # Seconds for one full loop
@export var rotation_speed: float = 0.1 : set = set_rotation_speed
@export var throbber_size: int = 64 : set = set_throbber_size
@export var color: Color = Color(1, 1, 1, 1) : set = set_color
@export var background_color: Color = Color(1, 1, 1, 0.1) : set = set_background_color

func _ready() -> void:
	min_value = 0
	max_value = 100
	value = 0
	fill_mode = FILL_CLOCKWISE
	#pivot_offset = Vector2i(throbber_size, throbber_size)/2
	_refresh_textures()
	custom_minimum_size = Vector2i(throbber_size,throbber_size)

# TODO replace with tween.
func _process(delta: float) -> void:
	if visible:
		value += delta * (100.0 / loop_time)
		#rotation += rotation_speed
		if value >= max_value:
			value = min_value
	

# --- Setters ---

func set_rotation_speed(new_speed: float):
	rotation_speed = new_speed
	
func set_loop_time(t: float) -> void:
	loop_time = max(t, 0.01)  # prevent division by zero

func set_throbber_size(s: int) -> void:
	var sz = Vector2i(s,s)
	throbber_size = s
	custom_minimum_size = sz
	pivot_offset = sz/2
	_refresh_textures()

func set_color(c: Color) -> void:
	color = c
	_refresh_textures()

func set_background_color(c: Color) -> void:
	background_color = c
	_refresh_textures()


# --- Internal Helpers ---

func _refresh_textures() -> void:
	texture_under = _make_ring_texture(background_color)
	texture_progress = _make_ring_texture(color)


func _make_ring_texture(c: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(c.r, c.g, c.b, 0.0), # fade start
		Color(c.r, c.g, c.b, 0.8), # solid mid
		Color(c.r, c.g, c.b, 0.0)  # fade end
	])
	gradient.offsets = PackedFloat32Array([0.3, 0.5, 0.7])

	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = throbber_size
	tex.height = throbber_size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
