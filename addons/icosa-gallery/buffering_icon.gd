@tool
# throbber
extends TextureProgressBar


var timer = Timer.new()

func _ready():
	add_child(timer)
	timer.wait_time = 0.1
	timer.timeout.connect(infinte_throbber)
	timer.start()
	
func infinte_throbber():
	value += 1
	if value == max_value:
		value = min_value
	
