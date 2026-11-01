extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var initial_buses := AudioServer.bus_count
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.set_script(null)
	root.add_child(scene)
	await process_frame
	scene.get_node("BackgroundMusic").stop()
	var bombardment = scene.get_node("Bombardment")
	AudioServer.set_bus_mute(AudioServer.get_bus_index(bombardment._bus_name), true)
	bombardment._random.seed = 1945
	for index in range(4):
		assert(bombardment.SOUNDS[index].get_length() > 0.0)
		print("Explosion ", index, " duration: ", bombardment.SOUNDS[index].get_length())
	for day in range(1, 5):
		bombardment.set_day(day)
		assert(not bombardment.is_processing())
	var previous_volume := -100.0
	var previous_cutoff := 0.0
	var previous_interval := 100.0
	var previous_shake := 0.0
	for day in range(5, 8):
		bombardment.set_day(day)
		bombardment.set_process(false)
		assert(bombardment.PROFILES[day].volume > previous_volume)
		assert(bombardment._filter.cutoff_hz > previous_cutoff)
		assert(bombardment.PROFILES[day].interval.x < previous_interval)
		assert(bombardment.PROFILES[day].shake[3] > previous_shake)
		previous_volume = bombardment.PROFILES[day].volume
		previous_cutoff = bombardment._filter.cutoff_hz
		previous_interval = bombardment.PROFILES[day].interval.x
		previous_shake = bombardment.PROFILES[day].shake[3]
		var saw_shake := false
		for sample in range(40):
			bombardment.countdown = 0.0
			bombardment._process(0.016)
			saw_shake = saw_shake or scene.get_node("WorkCamera").offset != Vector2.ZERO
			assert(bombardment.countdown >= bombardment.PROFILES[day].interval.x)
			assert(bombardment.countdown <= bombardment.PROFILES[day].interval.y)
		assert(saw_shake)
		assert(bombardment.PROFILES[5].interval == Vector2(6, 14))
		assert(bombardment.PROFILES[5].volume == -11.0)
	bombardment.set_day(7)
	bombardment.set_process(false)
	bombardment.countdown = 100.0
	bombardment._play_explosion(3)
	assert(bombardment._shake_pixels == 42.0 and bombardment._big_cooldown == 7.0)
	bombardment._process(0.016)
	var camera: Camera2D = scene.get_node("WorkCamera")
	assert(absf(camera.offset.x * camera.zoom.x) <= 42.0)
	assert(absf(camera.offset.y * camera.zoom.y) <= 42.0)
	var paper = scene.get_node("Paper")
	camera.position = paper.get_global_rect().get_center()
	camera.zoom = Vector2.ONE * 1.32
	camera.force_update_scroll()
	paper.document.set_page(paper.document.PAGES[6])
	paper.busy = false
	paper.stroke_speed = 90000.0
	paper.line_pause = 0.0
	await process_frame
	var click := InputEventMouseButton.new()
	click.position = paper.get_global_transform_with_canvas() * paper.document_to_local(paper.document.target_rects(0)[0].get_center())
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	await paper.target_redacted
	assert(paper.document.redacted == [0], "Camera shake must preserve visible target hit testing")
	bombardment._process(2.0)
	assert(camera.offset == Vector2.ZERO, "Shake must decay back to the exact reading position")
	bombardment._players[3].stop()
	for sample in range(40):
		bombardment.countdown = 0.0
		bombardment._process(0.016)
		assert(not bombardment._players[3].playing, "Large blasts must respect their cooldown")
	bombardment.stop()
	for player in bombardment._players:
		assert(not player.playing)
	assert(not bombardment.is_processing() and camera.offset == Vector2.ZERO)
	scene.queue_free()
	await process_frame
	assert(AudioServer.bus_count == initial_buses, "Scene cleanup must remove its private audio bus")
	print("PASS: explosion assets, progressive profiles, no early bombardment, shake decay, target click during shake and audio cleanup")
	quit()
