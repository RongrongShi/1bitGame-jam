extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.play_intro = false
	scene.page_index = 6
	scene.get_node("TitleCard").fade_time = 0.01
	scene.get_node("DialogueBox").fade_time = 0.05
	root.add_child(scene)
	await scene.work_started
	var bombardment = scene.get_node("Bombardment")
	assert(scene.top.document.PAGES.size() == 7)
	assert(scene.ENDING_LINES.slice(3) == scene.CALLBACK_LINES)
	for index in range(scene.top.document.page.targets.size()):
		scene.top.document.redact_target(index)
	scene._on_target_redacted(0)
	assert(scene._awaiting_finish_click)
	var work_zoom: Vector2 = scene.camera.zoom
	await create_timer(0.3).timeout
	assert(scene.camera.zoom == work_zoom and not scene.dialogue_box._root.visible)
	var finish_click := InputEventMouseButton.new()
	finish_click.button_index = MOUSE_BUTTON_LEFT
	finish_click.pressed = true
	scene._input(finish_click)
	assert(not scene._awaiting_finish_click)
	await scene.letter_finished
	assert(scene.title_card._shade.visible and scene.camera.zoom == Vector2.ONE)
	assert(not scene.dialogue_box._root.visible and not scene.get_node("Gunshot").playing)
	var dialogue = scene.dialogue_box
	var officer: TextureRect = dialogue._root.get_node("OfficerBackground")
	for index in range(scene.ENDING_LINES.size()):
		var start := Time.get_ticks_msec()
		while not dialogue._accepting_input or dialogue._text.text != scene.ENDING_LINES[index]:
			assert(Time.get_ticks_msec() - start < 6000)
			await process_frame
		assert(dialogue._root.visible and dialogue._text_layer.visible)
		assert(not scene.get_node("Gunshot").playing)
		assert(officer.texture == (dialogue.backdrop if index < 3 else scene.ENDING_POSES[index - 3]))
		assert(officer.self_modulate == (Color(0.9, 0.9, 0.9) if index < 3 else Color(0.81, 0.81, 0.81)))
		assert(bombardment.day == 7 and bombardment.is_processing())
		bombardment.countdown = 0.0
		await process_frame
		assert(bombardment._players.any(func(player): return player.playing))
		assert(scene.get_node("OneBit/Screen").material.get_shader_parameter("pixel_size") == 1.0)
		if DisplayServer.get_name() != "headless" and (index == 0 or index >= 3):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/ending-line-%d.png" % index)
		if index < scene.ENDING_LINES.size() - 1:
			if dialogue._typing:
				dialogue._press()
			dialogue._press()
	var start := Time.get_ticks_msec()
	while dialogue._root.visible:
		assert(Time.get_ticks_msec() - start < 6000, "Final line must fire automatically without another click")
		await process_frame
	assert(scene.get_node("Gunshot").playing)
	assert(scene.get_node("Gunshot").stream.resource_path.ends_with("Gunshot.wav"))
	assert(scene.get_node("Gunshot").volume_db == 0.0)
	assert(not scene.get_node("BackgroundMusic").playing)
	assert(bombardment.day == 0 and not bombardment.is_processing())
	assert(bombardment._players.all(func(player): return not player.playing))
	assert(not dialogue._text_layer.visible and not dialogue._keystroke.playing)
	assert(scene.title_card._shade.modulate.a == 1.0)
	assert(scene.busy and scene.top.busy and scene.page_index == 6)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var frame: Image = root.get_texture().get_image()
		frame.save_png("res://.godot/ending-final-black.png")
		for y in range(0, frame.get_height(), 8):
			for x in range(0, frame.get_width(), 8):
				assert(frame.get_pixel(x, y).r == 0.0, "Shot frame must be entirely black")
	await create_timer(0.3).timeout
	assert(scene.page_index == 6 and scene.title_card._shade.visible)
	print("PASS: final-letter blackout, officer dialogue, identical callbacks with poses 1-3, automatic gunshot, music stop and persistent black ending")
	quit()
