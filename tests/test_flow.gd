extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.play_intro = false
	root.add_child(scene)
	assert(scene.title_card.fade_time == 1.8 and scene.dialogue_box.fade_time == 1.8)
	await _check_entry_hold(scene)
	await scene.work_started
	assert(scene.INTRO_LINES.slice(scene.INTRO_LINES.size() - scene.CALLBACK_LINES.size()) == scene.CALLBACK_LINES)
	assert(not scene.has_node("PaperNext") and not scene.has_node("DiscardSpot"))
	assert(scene.top.document.PAGES.size() == 7)
	for page_index in range(7):
		print("Checking work session ", page_index + 1)
		scene.get_node("Bombardment").stop()
		assert(scene.page_index == page_index and not scene.busy and not scene.top.busy)
		assert(scene.top.visible and scene.top.document.redacted.is_empty())
		assert(scene.folded_newspaper.visible == (page_index >= 3))
		assert(scene.camera.zoom.x > 1.0)
		var focused: Vector2 = scene.top.get_global_transform_with_canvas() * (scene.top.size * 0.5)
		assert(focused.distance_to(Vector2(root.size) * 0.5) < 2.0)
		if page_index >= 3:
			assert(scene.article.get_node("DocumentViewport/Document").page.edition == page_index + 1)
			var newspaper_click := InputEventMouseButton.new()
			newspaper_click.button_index = MOUSE_BUTTON_LEFT
			newspaper_click.pressed = true
			scene.top.busy = true
			scene._on_newspaper_input(newspaper_click)
			assert(not scene.article.visible and not scene.busy, "Let an active brush stroke finish before opening the newspaper")
			scene.top.busy = false
			scene.top.document.redact_target(0)
			scene.top.document.set_target_progress(1, 0, 0.4)
			for viewport_size in [Vector2i(1152, 648), Vector2i(900, 900)]:
				root.size = viewport_size
				await process_frame
				await process_frame
				scene._open_newspaper()
				await _wait_idle(scene)
				assert(scene.article.visible and scene.top.busy and not scene.top.visible)
				assert(scene.camera.zoom.x > 1.0)
				_click_screen(Vector2(30, 30), MOUSE_BUTTON_RIGHT)
				assert(scene.article.visible)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/newspaper-day-%d-%d.png" % [page_index + 1, viewport_size.x])
				_click_screen(Vector2(30, 30))
				await _wait_idle(scene)
				assert(scene.top.visible and not scene.top.busy and scene.folded_newspaper.visible)
				assert(scene.top.document.redacted == [0])
				assert(scene.top.document.target_progress[Vector2i(1, 0)] == 0.4)
			scene.top.document.set_page(scene.top.document.PAGES[page_index])
		root.size = Vector2i(1152, 648)
		await process_frame
		await process_frame
		var paper = scene.top
		paper.stroke_speed = 90000.0
		paper.line_pause = 0.0
		for target_index in range(paper.document.page.targets.size()):
			var click := InputEventMouseButton.new()
			click.position = paper.document_to_local(paper.document.target_rects(target_index)[0].get_center())
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			paper._gui_input(click)
			if target_index < paper.document.page.targets.size() - 1:
				await paper.target_redacted
				assert(not scene.busy and scene.page_index == page_index)
		await _check_pullback_hold(scene)
		await scene.letter_finished
		assert(paper.document.is_complete() and scene.busy and paper.busy)
		assert(scene.camera.zoom.is_equal_approx(Vector2.ONE))
		assert(scene.get_node("Bombardment").day == 0)
		assert(scene.camera.offset == Vector2.ZERO)
		assert(scene.title_card._shade.modulate.a == 1.0)
		assert(scene.title_card._label.text.is_empty())
		if page_index < 6:
			await _check_entry_hold(scene)
			await scene.work_started
		else:
			await create_timer(scene.BLACK_PAUSE + 0.2).timeout
			assert(scene.page_index == 6 and scene.busy and scene.title_card._shade.visible)
			assert(scene.dialogue_box._root.visible and not scene.get_node("Gunshot").playing)
	scene.queue_free()
	await process_frame
	scene = load("res://scenes/main.tscn").instantiate()
	scene.play_intro = false
	root.add_child(scene)
	scene.title_card.fade_time = 0.01
	await scene.work_started
	scene.busy = true
	scene.top.busy = true
	scene.title_card.hold_time = 0.01
	scene._play_intro()
	var saw_dialogue := false
	for frame in range(1500):
		await create_timer(0.01).timeout
		assert(not scene.title_card._label.text.begins_with("DAY"))
		if scene.dialogue_box._root.visible and scene.dialogue_box._accepting_input:
			assert(scene.get_node("OneBit/Screen").material.get_shader_parameter("pixel_size") == 2.0)
			if not saw_dialogue:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/cinematic-subtitles-preview.png")
			saw_dialogue = true
			scene.dialogue_box._press()
			assert(scene.dialogue_box._root.get_child_count() == 1, "Only the background is below dithering; subtitles use their own layer")
			assert(scene.dialogue_box._text.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
			assert(scene.dialogue_box._text.get_theme_constant("outline_size") == 6)
			assert(scene.dialogue_box._text.get_theme_font("font").resource_path.ends_with("SourceSans3-Bold.tres"))
			await RenderingServer.frame_post_draw
			assert(scene.dialogue_box._text.get_minimum_size().y <= scene.dialogue_box._text.size.y, "Subtitles must fit their safe area")
		if saw_dialogue and not scene.busy:
			break
	assert(saw_dialogue and not scene.busy and not scene.top.busy)
	assert(scene.get_node("OneBit/Screen").material.get_shader_parameter("pixel_size") == 1.0)
	assert(scene.camera.zoom.x > 1.0 and not scene.title_card._shade.visible)
	print("PASS: one-second wide holds, slow transitions, cinematic subtitles, marked targets, seven letters, four optional newspapers, click to read/close at two sizes and final officer entrance")
	quit()


func _check_entry_hold(scene: Node) -> void:
	var start := Time.get_ticks_msec()
	while scene.title_card._shade.visible:
		assert(Time.get_ticks_msec() - start < 10000, "Reveal must finish")
		await process_frame
	assert(scene.busy and scene.top.busy and scene.camera.zoom.is_equal_approx(Vector2.ONE))
	await create_timer(0.8).timeout
	assert(scene.camera.zoom.is_equal_approx(Vector2.ONE), "Stay wide for a full second before zooming in")
	assert(scene.busy and scene.top.busy)


func _check_pullback_hold(scene: Node) -> void:
	var start := Time.get_ticks_msec()
	while not scene.camera.zoom.is_equal_approx(Vector2.ONE):
		assert(Time.get_ticks_msec() - start < 10000, "Pullback must finish")
		await process_frame
	assert(not scene.title_card._shade.visible)
	await create_timer(0.8).timeout
	assert(not scene.title_card._shade.visible, "Stay wide for a full second before fading to black")
	assert(scene.busy and scene.top.busy)


func _click_screen(point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)


func _wait_idle(scene: Node) -> void:
	assert(scene.busy, "Newspaper interaction must begin")
	var start := Time.get_ticks_msec()
	while scene.busy:
		assert(Time.get_ticks_msec() - start < 5000)
		await process_frame
