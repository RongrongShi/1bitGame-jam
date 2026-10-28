@tool
extends TextureRect

# Assign your hand node (Sprite2D / TextureRect / any CanvasItem) in the Inspector.
# It must be drawn above the paper. If it is a Control, set mouse_filter to Ignore.
@export var hand: CanvasItem
# Offset from the hand node's origin to the fingertip/pen tip, in pixels.
@export var hand_tip_offset := Vector2.ZERO
@export var animate := true
@export var move_time := 0.35
@export var sweep_time := 0.6

@onready var document = $DocumentViewport/Document

var busy := false
var _hand_rest := Vector2.ZERO


func _ready() -> void:
	if hand != null and not Engine.is_editor_hint():
		_hand_rest = hand.global_position


# Screen/local point -> document point (inverse perspective).
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


# Global position the hand node must have so its tip lands on a document point.
func _hand_global(doc_point: Vector2) -> Vector2:
	return get_global_transform() * document_to_local(doc_point) - hand_tip_offset


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouse:
		var index: int = document.sentence_at(document_position(event.position))
		var clickable: bool = index >= 0 and not busy and not document.is_redacted(index)
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if clickable else CURSOR_ARROW
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and clickable:
			if animate and hand != null:
				_redact_with_hand(index)
			else:
				document.redact_sentence(index)
			accept_event()


func _redact_with_hand(index: int) -> void:
	busy = true
	var line_count: int = document.SENTENCES[index].size()
	for line_index in range(line_count):
		var rect: Rect2 = document.line_rect(index, line_index)
		var start := Vector2(rect.position.x, rect.get_center().y)
		var end := Vector2(rect.end.x, rect.get_center().y)
		# 1) Move the hand to the start of the line.
		await _move_hand_to(_hand_global(start))
		# 2) Sweep along the line; the black bar grows with the hand.
		var tween := create_tween()
		tween.tween_method(func(t: float) -> void:
			document.set_line_progress(index, line_index, t)
			hand.global_position = _hand_global(start.lerp(end, t)),
			0.0, 1.0, sweep_time)
		await tween.finished
	document.redact_sentence(index)
	# 3) Return to rest, then unlock input for the next sentence.
	await _move_hand_to(_hand_rest)
	busy = false


func _move_hand_to(target: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(hand, "global_position", target, move_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
