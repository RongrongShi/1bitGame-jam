extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.play_intro = false
	root.add_child(scene)
	await process_frame
	var paper = scene.get_node("Paper")
	paper.animate = false
	var document = paper.get_node("DocumentViewport/Document")
	var impressions = document._impressions("AAAA", 420.6)
	assert(impressions == document._impressions("AAAA", 420.6), "Ink must remain stable across redraws")
	assert(impressions[0] != impressions[1], "Repeated letters must have distinct impressions")
	var no_index := -1
	for index in range(document.words.size()):
		if document.words[index].row == 4:
			no_index = index
	assert(no_index >= 0)
	for viewport_size in [Vector2i(1152, 648), Vector2i(1920, 1080), Vector2i(900, 900)]:
		root.size = viewport_size
		await process_frame
		document.redacted_words.clear()
		for index in range(document.words.size()):
			var bounds: Rect2 = document.words[index].rect
			var point := _project(paper, bounds.get_center())
			assert(paper.document_position(point).distance_to(bounds.get_center()) < 0.01)
			assert(document.word_at(paper.document_position(point)) == index)
			assert(bounds.end.x < 960, "Text exceeds paper margin")
		var no_point := _project(paper, document.words[no_index].rect.get_center())
		_motion(paper, no_point)
		assert(document.hovered_word == no_index and document.redacted_words.is_empty(), "Hover only previews")
		_button(paper, no_point, true)
		_button(paper, no_point, false)
		assert(document.redacted_words.is_empty(), "A click without dragging must not redact")
		_button(paper, no_point, true)
		_motion(paper, no_point + Vector2(1, 0), MOUSE_BUTTON_MASK_LEFT)
		assert(document.redacted_words == [no_index], "Only the selected word must be removed")
		_motion(paper, no_point, MOUSE_BUTTON_MASK_LEFT)
		assert(document.redacted_words.size() == 1, "Repainting must not duplicate words")
		assert(document.hovered_word == -1, "Redacted words must not show a hover line")
		var outside_release := InputEventMouseButton.new()
		outside_release.button_index = MOUSE_BUTTON_LEFT
		paper._input(outside_release)
		_motion(paper, _project(paper, document.words[0].rect.get_center()))
		assert(not paper.dragging and document.redacted_words.size() == 1, "Outside release ends painting")
		document.redacted_words.clear()
		var first: Rect2 = document.words[0].rect
		var last: Rect2 = document.words[no_index].rect
		_button(paper, _project(paper, Vector2(first.position.x - 12, first.get_center().y)), true)
		_motion(paper, _project(paper, Vector2(last.end.x + 12, last.get_center().y)), MOUSE_BUTTON_MASK_LEFT)
		assert(document.redacted_words.size() == no_index + 1, "Fast drag must hit intermediate words")
		_button(paper, no_point, false)
		document.redacted_words.clear()
		_button(paper, no_point, true)
		paper._clear_hover()
		_motion(paper, _project(paper, document.words[0].rect.get_center()), MOUSE_BUTTON_MASK_LEFT)
		assert(document.redacted_words.is_empty(), "Re-entry must not paint a chord across the page")
		_button(paper, no_point, false)
		_motion(paper, no_point)
		paper._clear_hover()
		assert(document.hovered_word == -1, "Leaving paper clears the preview")
		var right_click := InputEventMouseButton.new()
		right_click.button_index = MOUSE_BUTTON_RIGHT
		right_click.pressed = true
		right_click.position = no_point
		paper._gui_input(right_click)
		_motion(paper, no_point + Vector2(2, 0), MOUSE_BUTTON_MASK_RIGHT)
		assert(document.redacted_words.is_empty(), "Right button must not paint")
		assert(document.word_at(Vector2(200, 140)) == -1, "Heading is not redactable")
		assert(document.word_at(paper.document_position(Vector2.ZERO)) == -1)
	# Dispatch through Godot itself to check that the hand and shade do not swallow input.
	var target: Vector2 = paper.get_global_transform() * _project(paper, document.words[0].rect.get_center())
	var hover := InputEventMouseMotion.new()
	hover.position = target
	hover.global_position = target
	root.push_input(hover, true)
	assert(document.hovered_word == 0, "Viewport must deliver hover through visual overlays")
	var press := InputEventMouseButton.new()
	press.position = target
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	assert(document.redacted_words.is_empty())
	hover.position += Vector2(1, 0)
	hover.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(hover, true)
	assert(document.redacted_words == [0], "Viewport must deliver the brush drag")
	var release := InputEventMouseButton.new()
	release.position = Vector2.ZERO
	release.button_index = MOUSE_BUTTON_LEFT
	root.push_input(release, true)
	assert(not paper.dragging)
	document.redacted_words.clear()
	paper._clear_hover()
	print("PASS: word hover, drag-only painting, fast strokes, outside release, re-entry, viewport input and perspective at three sizes")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1152, 648)
		document.set_hovered_word(no_index)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/document-hover-preview.png")
		var no_center: Vector2 = document.words[no_index].rect.get_center()
		document.redact_stroke(no_center, no_center + Vector2(2, 0))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/document-word-redacted-preview.png")
	quit()


func _project(paper: TextureRect, source_point: Vector2) -> Vector2:
	var source_size := Vector2(1086, 1448)
	var fitted: Vector2 = source_size * minf(paper.size.x / source_size.x, paper.size.y / source_size.y)
	var top_width: float = paper.material.get_shader_parameter("top_width")
	var uv := source_point / source_size
	var divisor := 1.0 - (1.0 - top_width) * uv.y
	return (paper.size - fitted) * 0.5 + Vector2(0.5 + (uv.x - 0.5) * top_width / divisor, uv.y * top_width / divisor) * fitted


func _motion(paper: TextureRect, point: Vector2, buttons: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.button_mask = buttons
	paper._input(event)
	paper._gui_input(event)


func _button(paper: TextureRect, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	paper._input(event)
	paper._gui_input(event)
