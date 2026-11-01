extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var music: AudioStreamPlayer = scene.get_node("BackgroundMusic")
	assert(not music.autoplay and not music.playing)
	assert(scene.title_card._label.text == "BERLIN, 1944")
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
	print("PASS: music starts about two seconds into the Berlin title, intro-skip music preserved")
	quit()
