extends Control

@export var viewport: SubViewport
@export var reference : Control
@export var render : Control

@export var label : RichTextLabel

@export var resolution_spin_box: SpinBox
@export var blur_spin_box: SpinBox

var metrics_previous : Dictionary

#
#func _ready() -> void:
	#set_process($CheckBox.button_pressed)
	#
func _ready() -> void:
	compare(resolution_spin_box.value, blur_spin_box.value)
	%PreviewPanel.hide()
	if %AutoCheckBox.button_pressed:
		%Timer.start()


func push_good():
	label.push_color(Color.BLACK)
	label.push_bgcolor(Color.GREEN)

func push_bad():
	label.push_color(Color.WHITE)
	label.push_bgcolor(Color.DARK_RED)
	
	
func push_neutral():
	label.push_color(Color.GHOST_WHITE)
	label.push_bgcolor(Color.DEEP_SKY_BLUE)


func compare(resolution: int, blur: float):
	reference.show()
	render.hide()
	render.modulate = Color(1, 1, 1, 1)
	#self.hide()
	await get_tree().process_frame
	await get_tree().process_frame
	var img1 = viewport.get_texture().get_image()
	render.show()
	reference.hide()
	await get_tree().process_frame
	var img2 = viewport.get_texture().get_image()
	# in theory trilinear resize should generate missing mipmaps anyway, but the results from this are smoother
	img1.generate_mipmaps()
	img2.generate_mipmaps()
	img1.resize(resolution, resolution, Image.INTERPOLATE_TRILINEAR)
	img2.resize(resolution, resolution, Image.INTERPOLATE_TRILINEAR)
	
	%Img1.texture = ImageTexture.create_from_image(img1)
	%Img2.texture = ImageTexture.create_from_image(img2)
	
	%PreviewPanel.show()
	
	label.clear()
	var metrics = img1.compute_image_metrics(img2, false)
	
	#if metrics_previous.hash() == metrics.hash():
		#print("No change!")
		#return
	
	# first run only
	if metrics_previous.is_empty():
		metrics_previous = metrics
	
	label.push_table(4)
	for i in metrics.keys():
		label.push_cell()
		label.push_mono()
		label.append_text("%s" % i)
		label.pop()
		label.pop()
		if metrics_previous.keys().has(i):
			label.push_cell()
			label.push_mono()
			label.push_color(Color(1,1,1,0.5))
			label.append_text("%2.1f" % metrics_previous[i])
			label.pop()
			label.pop()
			label.push_cell()
			label.append_text("   ")
			label.push_bold()
			label.push_mono()
			var invert = false
			if i == "peak_snr":
				invert = true
			if metrics_previous[i] > metrics[i] + 0.1:
				if not invert:
					push_good()
				else:
					push_bad()
				label.append_text(" ↓ ")
			elif metrics_previous[i] < metrics[i] - 0.1:
				if not invert:
					push_bad()
				else:
					push_good()
				label.append_text(" ↑ ")
			else:
				push_neutral()
				label.append_text(" ~ ")
			label.pop() # mono
			label.pop() # bgcolor
			label.pop() # color
			label.pop() # bold
			label.pop() # cell
			label.push_cell()
		label.pop()
		label.push_cell()
		label.push_mono()
		label.append_text("%2.1f" % metrics[i])
		label.pop()
		label.pop()
	label.pop() # table
	
	reference.show()
	render.show()
	render.modulate = Color(1, 1, 1, 0.5)
	
	metrics_previous = metrics



func _on_button_pressed() -> void:
	compare(resolution_spin_box.value, blur_spin_box.value)
	

#func _process(_delta) -> void:
	#compare()


func _on_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on:
		%Timer.start()
	else:
		%Timer.stop()


func _on_timer_timeout() -> void:
	compare(resolution_spin_box.value, blur_spin_box.value)


func _on_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		reference.show()
		render.hide()
		%CheckButton.text = "B"
	else:
		%CheckButton.text = "A"
		render.show()
		reference.hide()
		render.modulate = Color(1,1,1,1)

	%PreviewPanel.hide()
	hide()


func _on_check_button_mouse_exited() -> void:
	show()
