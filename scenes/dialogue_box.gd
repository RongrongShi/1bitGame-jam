extends CanvasLayer

signal advanced

@export var font: Font
@export var text_size := 32
@export var small_size := 22
@export var chars_per_second := 40.0

var _root: Control
var _panel: Panel
var _speaker: Label
var _text: Label
var _hint: Label
var _tween: Tween
var _typing := false


func _ready() -> void:
	# Above the title card (layer 10) so the box shows over the black screen.
	layer = 11
	_root = Control.new()
	_root.visible = false
	# Modal: while the box is open, clicks must not reach the desk.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_input)
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = Panel.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.035, 0.94)
	style.border_color = Color(0.85, 0.82, 0.74)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)
	_panel.anchor_left = 0.05
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.72
	_panel.anchor_bottom = 0.95
	_panel.offset_left = 0.0
	_panel.offset_right = 0.0
	_panel.offset_top = 0.0
	_panel.offset_bottom = 0.0

	_speaker = _make_label(small_size, Color(0.85, 0.7, 0.4))
	_panel.add_child(_speaker)
	_speaker.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_speaker.offset_left = 24.0
	_speaker.offset_top = 12.0

	_text = _make_label(text_size, Color(0.92, 0.9, 0.85))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_text)
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = 24.0
	_text.offset_top = 52.0
	_text.offset_right = -24.0
	_text.offset_bottom = -36.0

	_hint = _make_label(small_size, Color(0.6, 0.58, 0.52))
	_hint.text = "CLICK TO CONTINUE"
	_hint.visible = false
	_panel.add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_right = -24.0
	_hint.offset_bottom = -10.0
	var blink := _hint.create_tween().set_loops()
	blink.tween_property(_hint, "modulate:a", 0.25, 0.6)
	blink.tween_property(_hint, "modulate:a", 1.0, 0.6)


func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if font != null:
		label.add_theme_font_override("font", font)
	return label


# Show lines one after another; the player clicks to finish a line, then clicks again to continue.
func show_lines(lines: Array, speaker := "") -> void:
	_speaker.text = speaker
	_speaker.visible = speaker != ""
	_root.visible = true
	for line in lines:
		await _show_line(line)
	_root.visible = false


func _show_line(line: String) -> void:
	_text.text = line
	_text.visible_ratio = 0.0
	_hint.visible = false
	_typing = true
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, maxf(line.length() / chars_per_second, 0.05))
	_tween.tween_callback(_finish_typing)
	await advanced


func _finish_typing() -> void:
	_typing = false
	_text.visible_ratio = 1.0
	_hint.visible = true


# First press completes the typing, the next press moves to the next line.
func _press() -> void:
	if _typing:
		_tween.kill()
		_finish_typing()
	else:
		advanced.emit()


func _on_root_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_press()
		_root.accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed("ui_accept"):
		_press()
		get_viewport().set_input_as_handled()
