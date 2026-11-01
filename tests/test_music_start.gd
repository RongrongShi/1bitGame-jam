extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var music: AudioStreamPlayer = scene.get_node("BackgroundMusic")
	assert(not music.autoplay and not music.playing)
	assert(scene.title_card._label.text == "Headphones recommended.")
	assert(scene.title_card._shade.has_node("HeadphonesIcon"))
	assert(scene.title_card._shade.get_node("HeadphonesIcon").offset_top == -128.0)
	assert(scene.title_card._label.offset_top == 64.0)
	await create_timer(2.0).timeout
	assert(not music.playing and not scene.dialogue_box._root.visible)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/headphones-intro.png")
	var hint_start := Time.get_ticks_msec()
	while scene.title_card._label.text != "BERLIN, 1944":
		assert(Time.get_ticks_msec() - hint_start < 6000)
		await process_frame
	assert(not scene.title_card._shade.has_node("HeadphonesIcon"))
	assert(scene.title_card._label.offset_top == 0.0 and scene.title_card._label.offset_bottom == 0.0)
	var start := Time.get_ticks_msec()
	await create_timer(1.6).timeout
	assert(not music.playing, "Music must not start before the two-second delay")
	while not music.playing:
		assert(Time.get_ticks_msec() - start < 4000)
		await process_frame
	assert(Time.get_ticks_msec() - start >= 1800)
	assert(not scene.dialogue_box._root.visible, "Music should begin while the Berlin title is still showing")
	scene.queue_free()
	await process_frame
	scene = load("res://scenes/main.tscn").instantiate()
	scene.play_intro = false
	root.add_child(scene)
	assert(scene.get_node("BackgroundMusic").playing, "Skipping the intro must still start music")
	scene.queue_free()
	await process_frame
	print("PASS: silent headphone hint with icon, Berlin title follows, music starts two seconds later, intro-skip music preserved")
	quit()
