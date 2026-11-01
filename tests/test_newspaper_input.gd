extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)


func _wait_idle(scene: Node) -> void:
	var start := Time.get_ticks_msec()
	while scene.busy:
		assert(Time.get_ticks_msec() - start < 5000)
		await process_frame


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.play_intro = false
	scene.page_index = 3
	scene.get_node("TitleCard").fade_time = 0.01
	root.add_child(scene)
	await scene.work_started
	scene.top.document.redact_target(0)
	scene._open_newspaper()
	await create_timer(0.1).timeout
	assert(scene.article.visible and scene.busy)
	_click(Vector2(1, 1))
	assert(not scene.article.visible, "A click during opening must close the newspaper immediately")
	assert(scene.busy and scene.top.busy, "Keep the letter locked while the camera returns")
	await _wait_idle(scene)
	assert(scene.top.visible and not scene.top.busy and scene.top.document.redacted == [0])
	var audio: AudioStreamPlayer = scene.get_node("PaperHandling")
	assert(audio.stream is AudioStreamRandomizer and audio.stream.streams_count == 2)
	for index in range(2):
		assert(audio.stream.get_stream(index).get_length() > 0.0)
	for viewport_size in [Vector2i(1152, 648), Vector2i(900, 900)]:
		root.size = viewport_size
		await process_frame
		for point in [Vector2(1, 1), Vector2(viewport_size) * 0.5, Vector2(viewport_size) - Vector2(2, 2)]:
			audio.stop()
			scene._open_newspaper()
			assert(audio.playing, "Opening must play a handling sound")
			await _wait_idle(scene)
			audio.stop()
			_click(point)
			assert(not scene.article.visible and audio.playing, "Any screen position must close and play the handling sound")
			await _wait_idle(scene)
			assert(scene.top.document.redacted == [0] and not scene.top.busy)
	for index in range(scene.top.document.page.targets.size()):
		scene.top.document.redact_target(index)
	audio.stop()
	scene._on_target_redacted(0)
	assert(scene.busy and audio.playing, "Letter completion must play as the camera starts pulling back")
	await scene.letter_finished
	assert(scene.camera.zoom.is_equal_approx(Vector2.ONE))
	print("PASS: immediate close during opening, any-position clicks at two sizes, preserved progress and paper handling on all three actions")
	quit()
