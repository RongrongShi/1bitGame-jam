extends RefCounted


static func play(tree: SceneTree, scene: Node, page_index: int) -> void:
	var dialogue = scene.dialogue_box
	var lines: Array = scene.INTERLUDE_LINES[page_index]
	if page_index == 4:
		var start := Time.get_ticks_msec()
		while scene.get_node("Bombardment").day != 5:
			assert(Time.get_ticks_msec() - start < 10000)
			await tree.process_frame
		await tree.process_frame
		assert(not dialogue._root.visible and scene.title_card._shade.visible)
		assert(scene.get_node("Bombardment")._players.any(func(player): return player.playing))
	for index in range(lines.size()):
		var start := Time.get_ticks_msec()
		while not dialogue._accepting_input or dialogue._text.text != lines[index]:
			assert(Time.get_ticks_msec() - start < 10000, "Interlude line must appear before work starts")
			await tree.process_frame
		assert(scene.busy and scene.top.busy and scene.title_card._shade.visible)
		assert(scene.page_index == page_index and scene.camera.zoom.is_equal_approx(Vector2.ONE))
		var officer: TextureRect = dialogue._root.get_node("OfficerBackground")
		assert(officer.texture == (preload("res://assets/Officer_TakeNewspaper.png") if page_index == 3 else dialogue.backdrop))
		var brightness := 0.81 if page_index == 3 else 0.9
		assert(officer.self_modulate == Color(brightness, brightness, brightness))
		var bombardment = scene.get_node("Bombardment")
		assert(bombardment.day == page_index + 1 and bombardment.is_processing())
		bombardment._play_explosion(2)
		await tree.process_frame
		await tree.process_frame
		assert(officer.position.is_equal_approx(Vector2(-48, -48) + scene.camera.offset * scene.camera.zoom))
		assert(officer.position != Vector2(-48, -48), "Both interlude officer scenes must shake")
		if dialogue._typing:
			dialogue._press()
		dialogue._press()
	while dialogue._root.visible:
		await tree.process_frame
	if page_index == 3:
		assert(scene.folded_newspaper.visible and scene.get_node("PaperHandling").playing)
