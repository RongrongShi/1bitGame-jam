@tool
extends TextureRect

@export var animate := true
@export_range(1.0, 10000.0) var stroke_speed := 900.0
@export var line_pause := 0.08

@onready var document = $DocumentViewport/Document

signal target_redacted(index: int)

var busy := true
var _brush_audio: AudioStreamPlayer


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_brush_audio = AudioStreamPlayer.new()
	_brush_audio.name = "BrushStroke"
	_brush_audio.stream = preload("res://assets/audio/paper_strokes/02-soft-ink-brush-gentle/long.wav")
	add_child(_brush_audio)


# Local point -> document point (inverse perspective).
func document_position(point: Vector2) -> Vector2:
	var document_size := Vector2($DocumentViewport.size)
	var fitted_size := document_size * minf(size.x / document_size.x, size.y / document_size.y)
	if fitted_size.x <= 0.0 or fitted_size.y <= 0.0:
		return Vector2(-1, -1)
	var uv := (point - (size - fitted_size) * 0.5) / fitted_size
	if not Rect2(Vector2.ZERO, Vector2.ONE).has_point(uv):
		return Vector2(-1, -1)
	# Match the shader's inverse perspective, including aspect-fit margins.
	var top_width: float = material.get_shader_parameter("top_width")
	var width := lerpf(top_width, 1.0, uv.y)
	return Vector2((uv.x - 0.5) / width + 0.5, uv.y / width) * document_size


# Document point -> local point (forward perspective, the opposite of document_position).
func document_to_local(point: Vector2) -> Vector2:
	var document_size := Vector2($DocumentViewport.size)
	var fitted_size := document_size * minf(size.x / document_size.x, size.y / document_size.y)
	var uv := point / document_size
	var top_width: float = material.get_shader_parameter("top_width")
	var divisor := 1.0 - (1.0 - top_width) * uv.y
	var projected := Vector2(0.5 + (uv.x - 0.5) * top_width / divisor, uv.y * top_width / divisor)
	return (size - fitted_size) * 0.5 + projected * fitted_size


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or busy:
		mouse_default_cursor_shape = CURSOR_ARROW
		return
	if event is InputEventMouse:
		var index: int = document.target_at(document_position(event.position))
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if index >= 0 else CURSOR_ARROW
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and index >= 0:
			accept_event()
			if animate:
				_redact_animated(index)
			else:
				document.redact_target(index)
				target_redacted.emit(index)


# Sweep marked spans at a constant number of document pixels per second.
func _redact_animated(index: int) -> void:
	busy = true
	var rectangles: Array[Rect2] = document.target_rects(index)
	for line_index in range(rectangles.size()):
		var duration := rectangles[line_index].size.x / stroke_speed
		_brush_audio.volume_db = 0.0
		_brush_audio.pitch_scale = minf(1.0, _brush_audio.stream.get_length() / duration)
		_brush_audio.play()
		var tween := create_tween()
		tween.tween_method(func(t: float) -> void: document.set_target_progress(index, line_index, t),
			0.0, 1.0, duration)
		tween.parallel().tween_property(_brush_audio, "volume_db", -45.0, minf(0.035, duration)).set_delay(maxf(0.0, duration - 0.035))
		await tween.finished
		_brush_audio.stop()
		await get_tree().create_timer(line_pause).timeout
	document.redact_target(index)
	busy = false
	mouse_default_cursor_shape = CURSOR_ARROW
	target_redacted.emit(index)
