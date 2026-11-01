extends CanvasLayer

@export var font: Font
@export var font_size := 64
@export var fade_time := 0.8
@export var hold_time := 1.6

var _shade: ColorRect
var _label: Label


func _ready() -> void:
	# Draw above everything, including the desk shading.
	layer = 10
	_shade = ColorRect.new()
	_shade.color = Color.BLACK
	# Stop mouse clicks from reaching the desk while the screen is black.
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.visible = false
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_font_size_override("font_size", font_size)
	if font != null:
		_label.add_theme_font_override("font", font)
	var text_layer := CanvasLayer.new()
	text_layer.layer = 102
	text_layer.visible = false
	add_child(text_layer)
	text_layer.add_child(_label)
	_shade.visibility_changed.connect(func() -> void: text_layer.visible = _shade.visible)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# Fade the text in over black, hold, fade it out. The screen stays black afterwards.
func show_card(text: String) -> void:
	_label.offset_top = 0.0
	_label.offset_bottom = 0.0
	_label.add_theme_font_size_override("font_size", font_size)
	_label.text = text
	_label.modulate.a = 0.0
	_shade.modulate.a = 1.0
	_shade.visible = true
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_label, "modulate:a", 1.0, fade_time)
	tween.tween_interval(hold_time)
	tween.tween_property(_label, "modulate:a", 0.0, fade_time)
	await tween.finished


func show_headphones() -> void:
	cut_to_black()
	_label.text = "Headphones recommended."
	_label.offset_top = 64.0
	_label.offset_bottom = 64.0
	_label.add_theme_font_size_override("font_size", 28)
	_label.modulate.a = 0.0
	var icon := TextureRect.new()
	icon.name = "HeadphonesIcon"
	icon.texture = preload("res://assets/Headphones_Icon.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icon.offset_left = -56.0
	icon.offset_right = 56.0
	icon.offset_top = -128.0
	icon.offset_bottom = -16.0
	icon.modulate.a = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_label, "modulate:a", 1.0, fade_time)
	tween.parallel().tween_property(icon, "modulate:a", 1.0, fade_time)
	tween.tween_interval(hold_time)
	tween.tween_property(_label, "modulate:a", 0.0, fade_time)
	tween.parallel().tween_property(icon, "modulate:a", 0.0, fade_time)
	await tween.finished
	icon.queue_free()


func show_epilogue() -> void:
	_label.text = "You did your job."
	_label.add_theme_font_size_override("font_size", 36)
	_label.offset_top = -36.0
	_label.offset_bottom = -36.0
	_label.modulate.a = 0.0
	var question := Label.new()
	question.name = "EndingQuestion"
	question.text = "At what price?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question.mouse_filter = Control.MOUSE_FILTER_IGNORE
	question.add_theme_color_override("font_color", Color.WHITE)
	question.add_theme_font_size_override("font_size", 36)
	if font != null:
		question.add_theme_font_override("font", font)
	_label.get_parent().add_child(question)
	question.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	question.offset_top = 36.0
	question.offset_bottom = 36.0
	question.modulate.a = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_label, "modulate:a", 1.0, fade_time)
	tween.tween_interval(hold_time)
	tween.tween_property(question, "modulate:a", 1.0, fade_time)
	tween.tween_interval(3.0)
	tween.tween_property(_label, "modulate:a", 0.0, fade_time)
	tween.parallel().tween_property(question, "modulate:a", 0.0, fade_time)
	await tween.finished
	_label.text = ""
	question.queue_free()


# Fade the black screen away to reveal the desk.
func reveal() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_shade, "modulate:a", 0.0, fade_time)
	await tween.finished
	_shade.visible = false


func cut_to_black() -> void:
	_label.text = ""
	_shade.modulate.a = 1.0
	_shade.visible = true


func fade_to_black() -> void:
	_label.text = ""
	_shade.modulate.a = 0.0
	_shade.visible = true
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_shade, "modulate:a", 1.0, fade_time)
	await tween.finished
