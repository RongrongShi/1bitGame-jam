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
	_shade.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# Fade the text in over black, hold, fade it out. The screen stays black afterwards.
func show_card(text: String) -> void:
	_label.text = text
	_label.modulate.a = 0.0
	_shade.modulate.a = 1.0
	_shade.visible = true
	var tween := create_tween()
	tween.tween_property(_label, "modulate:a", 1.0, fade_time)
	tween.tween_interval(hold_time)
	tween.tween_property(_label, "modulate:a", 0.0, fade_time)
	await tween.finished


# Fade the black screen away to reveal the desk.
func reveal() -> void:
	var tween := create_tween()
	tween.tween_property(_shade, "modulate:a", 0.0, fade_time)
	await tween.finished
	_shade.visible = false
