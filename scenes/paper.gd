@tool
extends TextureRect

@export var animate := true
@export var sweep_time := 0.6
@export var line_pause := 0.08

@onready var document = $DocumentViewport/Document

var busy := false


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
	if Engine.is_editor_hint():
		return
	if event is InputEventMouse:
		var index: int = document.sentence_at(document_position(event.position))
		var clickable: bool = index >= 0 and not busy and not document.is_redacted(index)
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if clickable else CURSOR_ARROW
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and clickable:
			if animate:
				_redact_animated(index)
			else:
				document.redact_sentence(index)
			accept_event()


# Sweep a black bar across each line of the sentence, one line after another.
func _redact_animated(index: int) -> void:
	busy = true
	var line_count: int = document.sentences[index].size()
	for line_index in range(line_count):
		var tween := create_tween()
		tween.tween_method(func(t: float) -> void: document.set_line_progress(index, line_index, t),
			0.0, 1.0, sweep_time)
		await tween.finished
		await get_tree().create_timer(line_pause).timeout
	document.redact_sentence(index)
	busy = false
