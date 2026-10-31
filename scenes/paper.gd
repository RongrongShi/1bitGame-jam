@tool
extends TextureRect

@onready var document = $DocumentViewport/Document
var dragging := false
var previous_point := Vector2(-1, -1)


func _ready() -> void:
	mouse_exited.connect(_clear_hover)


func _clear_hover() -> void:
	document.set_hovered_word(-1)
	previous_point = Vector2(-1, -1)
	mouse_default_cursor_shape = CURSOR_ARROW


func _input(event: InputEvent) -> void:
	# A release outside the paper must also end the brush stroke.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
		previous_point = Vector2(-1, -1)
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		dragging = false


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


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouse:
		var point := document_position(event.position)
		var index: int = document.word_at(point)
		document.set_hovered_word(index)
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if index >= 0 else CURSOR_ARROW
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			previous_point = point if dragging else Vector2(-1, -1)
			accept_event()
		elif event is InputEventMouseMotion and dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var page := Rect2(Vector2.ZERO, Vector2($DocumentViewport.size))
			if page.has_point(previous_point) and page.has_point(point) and not point.is_equal_approx(previous_point):
				document.redact_stroke(previous_point, point)
			previous_point = point
			accept_event()
