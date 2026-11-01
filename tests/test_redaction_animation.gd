extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.set_script(null)
	root.add_child(scene)
	await process_frame
	var paper = scene.get_node("Paper")
	var document = paper.document
	assert(paper._brush_audio.stream.resource_path.ends_with("02-soft-ink-brush-gentle/long.wav"))
	paper.line_pause = 0.0
	var durations: Array[float] = []
	for index in [0, 2]:
		document.set_page(document.PAGES[0])
		var bounds: Rect2 = document.target_rects(index)[0]
		var outline: PackedVector2Array = document._ink_outline(bounds, 1.0, index * 17)
		assert(outline == document._ink_outline(bounds, 1.0, index * 17), "Ink edges must remain stable across redraws")
		assert(outline != document._ink_outline(bounds, 1.0, index * 17 + 1))
		for x in range(1, int(bounds.size.x), 3):
			for y in range(1, int(bounds.size.y), 3):
				assert(Geometry2D.is_point_in_polygon(bounds.position + Vector2(x, y), outline), "Rough edges must not leave holes over the text")
		paper._redact_animated(index)
		assert(paper._brush_audio.playing, "Brush sound must begin with the stroke")
		var tween: Tween = get_processed_tweens().back()
		tween.pause()
		tween.custom_step(0.05)
		var distance: float = document.target_progress[Vector2i(index, 0)] * bounds.size.x
		assert(is_equal_approx(distance, paper.stroke_speed * 0.05), "Short and long spans must cover the same distance in the same time")
		durations.append(bounds.size.x / paper.stroke_speed)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = paper.get_node("DocumentViewport").get_texture().get_image()
		var point := Vector2i(bounds.position.x + bounds.size.x * 0.85, bounds.get_center().y)
		assert(image.get_pixelv(point).get_luminance() < 0.01, "The unpainted end must retain its strike-through during the sweep")
		tween.custom_step(10.0)
		await paper.target_redacted
		assert(document.redacted == [index] and not paper.busy)
		assert(not paper._brush_audio.playing, "Brush sound must end before the next stroke")
	assert(durations[1] > durations[0] * 4.0, "Long spans must take longer to redact")
	print("PASS: constant stroke speed, persistent strike-through and gentle brush audio starting/stopping with animation")
	quit()

