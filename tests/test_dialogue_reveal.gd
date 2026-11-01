extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.set_script(null)
	root.add_child(scene)
	await process_frame
	var dialogue = scene.get_node("DialogueBox")
	for index in range(3):
		var sound: AudioStream = dialogue._keystroke.stream.get_stream(index)
		assert(sound.resource_path.contains("01-low-mechanical") and sound.get_length() > 0.0)
	dialogue.set_process(false)
	dialogue.fade_time = 0.01
	dialogue.show_lines(["A,B.", "Second line."])
	await create_timer(0.05).timeout
	assert(dialogue._typing and dialogue._text.visible_characters == 0)
	dialogue._process(0.0)
	assert(dialogue._text.visible_characters == 1)
	assert(dialogue._keystroke.playing, "Revealing letters must play the selected sound")
	dialogue._keystroke.stop()
	dialogue._process(1.0 / dialogue.characters_per_second + 0.00001)
	assert(dialogue._text.visible_characters == 2)
	assert(not dialogue._keystroke.playing, "Punctuation must not trigger a strike")
	dialogue._process(0.1)
	assert(dialogue._text.visible_characters == 2, "A comma must pause longer than a letter")
	dialogue._process(0.081)
	assert(dialogue._text.visible_characters == 3)
	assert(not dialogue._keystroke.playing, "Sound cadence is every second letter, not every character")
	dialogue._process(0.04)
	assert(not dialogue._typing and dialogue._text.visible_characters == 4)
	assert(dialogue._character_delay(".") > dialogue._character_delay(","))
	dialogue._press()
	assert(dialogue._text.text == "Second line." and dialogue._typing)
	dialogue._process(0.1)
	assert(dialogue._text.visible_characters > 0 and dialogue._text.visible_characters < 12)
	assert(dialogue._keystroke.playing)
	dialogue._press()
	assert(not dialogue._typing and dialogue._text.visible_characters == -1)
	assert(not dialogue._keystroke.playing, "Clicking to reveal must stop all typing voices")
	assert(dialogue._text.text == "Second line.", "First click reveals the rest without skipping the line")
	dialogue._press()
	await create_timer(0.05).timeout
	assert(not dialogue._root.visible and not dialogue._text_layer.visible)
	assert(not dialogue._keystroke.playing)
	print("PASS: selected low-mechanical sounds, subtitle cadence, silent punctuation, click-to-reveal stop and dialogue cleanup")
	quit()
