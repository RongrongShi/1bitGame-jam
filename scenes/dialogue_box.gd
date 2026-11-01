extends CanvasLayer

signal advanced
signal line_started(index: int)

@export var font: Font
@export var backdrop: Texture2D
@export var text_size := 30
@export var fade_time := 1.8
@export_range(1.0, 120.0) var characters_per_second := 28.0

var _root: Control
var _text: Label
var _accepting_input := false
var _text_layer: CanvasLayer
var _typing := false
var _until_next_character := 0.0
var _letters_since_strike := 0
var _keystroke: AudioStreamPlayer


func _ready() -> void:
	layer = 11
	_keystroke = AudioStreamPlayer.new()
	_keystroke.name = "Typewriter"
	_keystroke.volume_db = -8.0
	_keystroke.max_polyphony = 4
	var sounds := AudioStreamRandomizer.new()
	for sound in [
		preload("res://assets/audio/typewriter_synth/variants/01-low-mechanical/key-1.wav"),
		preload("res://assets/audio/typewriter_synth/variants/01-low-mechanical/key-2.wav"),
		preload("res://assets/audio/typewriter_synth/variants/01-low-mechanical/key-3.wav"),
	]:
		sounds.add_stream(-1, sound)
	_keystroke.stream = sounds
	add_child(_keystroke)
	_root = Control.new()
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_input)
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if backdrop != null:
		var image := TextureRect.new()
		image.name = "OfficerBackground"
		image.texture = backdrop
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(image)
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_text = Label.new()
	_text.name = "Subtitles"
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_override("font", font)
	_text.add_theme_font_size_override("font_size", text_size)
	_text.add_theme_color_override("font_color", Color.WHITE)
	_text.add_theme_color_override("font_outline_color", Color.BLACK)
	_text.add_theme_constant_override("outline_size", 6)
	_text_layer = CanvasLayer.new()
	_text_layer.layer = 103
	_text_layer.visible = false
	add_child(_text_layer)
	_text_layer.add_child(_text)
	_root.visibility_changed.connect(func() -> void: _text_layer.visible = _root.visible)
	_text.anchor_left = 0.1
	_text.anchor_right = 0.9
	_text.anchor_top = 0.79
	_text.anchor_bottom = 0.95


func show_lines(lines: Array, fade_out := true, finish_last := false, image: Texture2D = null, brightness := 0.9) -> void:
	_accepting_input = false
	_keystroke.stop()
	_text.text = ""
	_root.get_node("OfficerBackground").self_modulate = Color(brightness, brightness, brightness)
	_root.get_node("OfficerBackground").texture = image if image != null else backdrop
	_root.modulate.a = 0.0
	_text.modulate.a = 0.0
	_root.visible = true
	await _fade(1.0)
	_accepting_input = true
	for index in range(lines.size()):
		var line: String = lines[index]
		_text.text = line
		_text.visible_characters = 0
		_until_next_character = 0.0
		_letters_since_strike = 0
		_typing = not line.is_empty()
		line_started.emit(index)
		if finish_last and index == lines.size() - 1:
			while _typing:
				await get_tree().process_frame
			_accepting_input = false
			await get_tree().create_timer(0.65).timeout
		else:
			await advanced
	_accepting_input = false
	_keystroke.stop()
	if fade_out:
		await _fade(0.0)
	_root.visible = false


func _fade(alpha: float) -> void:
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_root, "modulate:a", alpha, fade_time)
	tween.tween_property(_text, "modulate:a", alpha, fade_time)
	await tween.finished


func _process(delta: float) -> void:
	if not _typing:
		return
	_until_next_character -= delta
	var strike := false
	while _typing and _until_next_character <= 0.0:
		var character: String = _text.text[_text.visible_characters]
		if character.to_lower() != character.to_upper() or character.is_valid_int():
			strike = strike or _letters_since_strike % 2 == 0
			_letters_since_strike += 1
		_text.visible_characters += 1
		_until_next_character += _character_delay(character)
		_typing = _text.visible_characters < _text.text.length()
	if strike:
		_keystroke.play()


func _character_delay(character: String) -> float:
	if character in [".", "!", "?", "。", "！", "？"]:
		return 0.38
	if character in [",", ";", ":", "，", "；", "："]:
		return 0.18
	return 1.0 / characters_per_second


func _press() -> void:
	if not _accepting_input:
		return
	_keystroke.stop()
	if _typing:
		_text.visible_characters = -1
		_typing = false
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
