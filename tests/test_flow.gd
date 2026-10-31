extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.play_intro = false
	root.add_child(scene)
	await process_frame
	assert(root.has_node("Game"), "Game autoload must load without a pre-existing UID cache")
	for label in [scene.dialogue_box._speaker, scene.dialogue_box._text, scene.dialogue_box._hint, scene.title_card._label]:
		var color: Color = label.get_theme_color("font_color")
		assert(color.r == color.g and color.g == color.b, "Intro UI must stay monochrome")
	await scene._use_ink()
	await create_timer(0.3).timeout
	assert(scene.page_index == 0 and not scene.busy, "Incomplete files must not advance")
	for page_index in range(3):
		var paper = scene.top
		var document = paper.document
		assert(document.page == document.PAGES[page_index])
		assert(document.redacted_words.is_empty() and document.redacted.is_empty())
		for word in document.words:
			assert(word.rect.end.x < 960, "Every page must fit the paper")
		var center: Vector2 = document.words[0].rect.get_center()
		paper.busy = true
		var click := InputEventMouseButton.new()
		click.position = paper.document_to_local(center)
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		paper._gui_input(click)
		assert(not paper.dragging, "Reading and page-turn animations must block painting")
		paper.busy = false
		document.redact_stroke(center, center + Vector2(1, 0), 0.08)
		assert(document.word_progress[0] == 0.0)
		await create_timer(0.12).timeout
		assert(document.word_progress[0] == 1.0, "Animated word redaction must finish")
		document.redact_stroke(document.words[1].rect.get_center(), document.words[1].rect.get_center() + Vector2(1, 0), 0.2)
		document.set_page(document.PAGES[page_index])
		await create_timer(0.25).timeout
		assert(document.redacted_words.is_empty() and document.word_progress.is_empty(), "Page reset must cancel old ink animations")
		paper.sweep_time = 0.01
		paper.line_pause = 0.0
		await paper._redact_animated(document.page.targets[0])
		assert(document.is_redacted(document.page.targets[0]), "Existing sentence animation must still work")
		document.set_page(document.PAGES[page_index])
		for word in document.words:
			if word.sentence in document.page.targets:
				var point: Vector2 = word.rect.get_center()
				document.redact_stroke(point, point + Vector2(1, 0), 0.03)
		assert(not document.is_complete(), "Submission must wait for the ink animation")
		await create_timer(0.08).timeout
		assert(document.is_complete(), "Word painting must satisfy existing sentence targets")
		await RenderingServer.frame_post_draw
		await scene._use_ink()
		assert(scene._pile.size() == page_index + 1, "Finished pages must enter the discard pile")
		if page_index < 2:
			assert(scene.page_index == page_index + 1 and not scene.busy)
			assert(scene.top.visible and not scene.top.busy)
		else:
			assert(scene.busy and not scene.top.visible, "Final file must end the review")
	scene.queue_free()
	await process_frame
	scene = load("res://scenes/main.tscn").instantiate()
	scene.play_intro = false
	root.add_child(scene)
	await process_frame
	scene.title_card.fade_time = 0.01
	scene.title_card.hold_time = 0.01
	scene._play_intro()
	var saw_dialogue := false
	var saw_reading := false
	for frame in range(300):
		await create_timer(0.01).timeout
		if scene.dialogue_box._root.visible:
			saw_dialogue = true
			scene.dialogue_box._press()
		if scene._reading:
			saw_reading = true
			assert(scene.top.busy)
			var skip := InputEventKey.new()
			skip.keycode = KEY_ENTER
			skip.pressed = true
			scene._input(skip)
		if saw_reading and not scene.busy:
			break
	assert(saw_dialogue and saw_reading and not scene.busy, "Intro, dialogue and reading skip must reach playable desk")
	assert(not scene.title_card._shade.visible and not scene.dialogue_box._root.visible)
	print("PASS: animated words, sentence animation, page reset, all three submissions, discard pile, intro, dialogue and reading skip")
	quit()
