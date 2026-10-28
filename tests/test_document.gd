extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var paper = scene.get_node("Paper")
	paper.animate = false
	var document = paper.get_node("DocumentViewport/Document")
	var source_size := Vector2(1086, 1448)
	var impressions = document._impressions("AAAA", 420.6)
	assert(impressions == document._impressions("AAAA", 420.6), "Ink must remain stable across redraws")
	assert(impressions[0] != impressions[1], "Repeated letters must have distinct impressions")
	for impression in impressions:
		assert(absf(impression.x) <= 0.7 and absf(impression.y) <= 1.5)
		assert(impression.z >= 0.72 and impression.z <= 1.0)
	var top_width: float = paper.material.get_shader_parameter("top_width")
	for viewport_size in [Vector2i(1152, 648), Vector2i(1920, 1080), Vector2i(900, 900)]:
		root.size = viewport_size
		await process_frame
		var fitted: Vector2 = source_size * minf(paper.size.x / source_size.x, paper.size.y / source_size.y)
		for index in range(document.SENTENCES.size()):
			for line_index in range(3):
				var row := 4 + index * 3 + line_index
				var line: String = document.SENTENCES[index][line_index]
				var source_point: Vector2 = document._line_rect(line, row).get_center()
				var uv := source_point / source_size
				var divisor := 1.0 - (1.0 - top_width) * uv.y
				var projected := Vector2(0.5 + (uv.x - 0.5) * top_width / divisor, uv.y * top_width / divisor)
				var local_point: Vector2 = (paper.size - fitted) * 0.5 + projected * fitted
				assert(paper.document_position(local_point).distance_to(source_point) < 0.01)
				assert(document.sentence_at(paper.document_position(local_point)) == index)
				assert(document._line_rect(line, row).end.x < 960, "Text exceeds the paper margin")
				if line_index == 0:
					var click := InputEventMouseButton.new()
					click.position = local_point
					click.button_index = MOUSE_BUTTON_LEFT
					click.pressed = true
					paper._gui_input(click)
					paper._gui_input(click)
					assert(document.redacted.count(index) == 1, "Click must redact exactly one sentence")
		assert(document.sentence_at(paper.document_position(Vector2.ZERO)) == -1)
	assert(document.redacted.size() == 4)
	assert(document.sentence_at(Vector2(200, 140)) == -1, "Heading must not be clickable")
	print("PASS: stable varied typewriter impressions, perspective picking, margins and sentence redaction at three window sizes")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1152, 648)
		document.redacted.clear()
		document.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/document-preview.png")
		document.redact_sentence(1)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/document-redacted-preview.png")
	quit()
