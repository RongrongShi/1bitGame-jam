extends SceneTree

const RELEASED = [
	["At [X] on [X], the bridge", "remained open to road traffic.", "Routine inspections continue.", "At the western bridgehead,", "[X]", "[X]", "Losses: [X] dead, [X] wounded.", "Remaining strength: [X] men.", "Roll calls are still under way.", "Supply vehicles use the bridge", "without interruption.", "Next inspection: 03 NOV."],
	["Transport order: 03 NOV, [X].", "Available trucks: [X].", "Fuel allocation: [X] barrels.", "Priority passengers:", "[X].", "Escort details are enclosed.", "Evacuation covers [X].", "[X]", "[X]", "Vehicles will use Route [X].", "Departure remains on schedule.", "Receipt of this order required."],
	["Your scarf still smells of home.", "I keep it beside me at night.", "How is our stubborn kitchen lamp?", "I shall be home later than I said.", "Do not come to West Station", "with your supper basket again.", "[X]", "[X]", "[X]", "If anyone asks, say you heard", "nothing. I cannot write more.", "I hope the soup was good.", "When I return, I will mend", "that draughty kitchen window.", "Until then, leave the lamp on."],
	["Effective immediately, flour at", "western district depots is", "reserved for military transport.", "Existing civilian stocks are", "[X] to maintain", "the current bread ration.", "Local offices shall [X] issue", "replacement ration coupons", "until further notice.", "Military bakery deliveries will", "continue. [X]", "[X]", "Residents are to be informed", "that the revised arrangements", "will prevent shortages."],
	["Shelter No. 14 remains on the", "public shelter list.", "It can [X] receive civilians.", "[X]", "[X]", "The adjoining cellar remains in", "use, but admission is restricted", "to [X].", "Residents waiting outside were", "directed to the next shelter.", "[X]", "The public shelter list is", "awaiting clearance."],
	["The western passage is [X]", "open to civilian traffic.", "[X]", "[X]", "Residents awaiting transfer are to", "assemble there at 1800.", "[X]", "[X]", "Bring identity papers and one", "piece of hand luggage. Leave the", "road clear for military vehicles.", "The movement order remains in", "force until formally withdrawn."],
	["Selected records will be collected", "from the rear courtyard at 1800.", "Transport: [X].", "[X]", "[X]", "Before transfer, remove identifying", "particulars from these files:", "Civilian shelter exclusions:", "authorised by [X].", "Western goods yard movement order:", "authorised by [X].", "Destroy original instructions", "and duplicate copies afterwards.", "All remaining personnel shall", "continue work until individually", "relieved."],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.set_script(null)
	scene.get_node("WorkCamera").enabled = false
	root.add_child(scene)
	await process_frame
	var paper = scene.get_node("Paper")
	var document = paper.document
	var notifications: Array[int] = [0]
	paper.target_redacted.connect(func(_index: int) -> void: notifications[0] += 1)
	paper.animate = false
	paper.busy = false
	for page_index in range(document.PAGES.size()):
		var page: Dictionary = document.PAGES[page_index]
		var released: Array = []
		for sentence in page.sentences:
			released.append_array(sentence.duplicate())
		for target in page.targets:
			assert(target.has("text") and target.has("line"), "Each click must redact only one marked line")
			var offset := 0
			for sentence_index in range(target.sentence):
				offset += page.sentences[sentence_index].size()
			if target.has("text"):
				var row: int = offset + target.line
				assert(released[row].count(target.text) == 1)
				released[row] = released[row].replace(target.text, "[X]")
			else:
				for line_index in range(page.sentences[target.sentence].size()):
					released[offset + line_index] = "[X]"
		assert(released == RELEASED[page_index], "The fully redacted report must match the planned meaning")
	for viewport_size in [Vector2i(1152, 648), Vector2i(1920, 1080), Vector2i(900, 900)]:
		root.size = viewport_size
		await process_frame
		for page_index in range(document.PAGES.size()):
			var page: Dictionary = document.PAGES[page_index]
			document.set_page(page)
			assert(paper.get_node("PaperViewport/PaperImage").texture == page.paper)
			if page.get("kind", "") == "newspaper":
				assert(document.target_at(Vector2(500, 500)) == -1 and not document.is_complete())
				continue
			if page_index >= 4:
				for sentence_index in range(page.sentences.size()):
					for line_index in range(page.sentences[sentence_index].size()):
						var bounds: Rect2 = document.line_rect(sentence_index, line_index)
						assert(bounds.end.x < 970 and bounds.end.y < 1390, "Late letters must fit the paper")
			for target_index in range(page.targets.size()):
				assert(document.target_rects(target_index).size() == 1, "A marked line must require its own click")
				for bounds in document.target_rects(target_index):
					assert(bounds.end.x < 960)
					var local: Vector2 = paper.document_to_local(bounds.get_center())
					assert(paper.document_position(local).distance_to(bounds.get_center()) < 0.01)
					assert(document.target_at(paper.document_position(local)) == target_index)
					var motion := InputEventMouseMotion.new()
					motion.position = local
					motion.button_mask = MOUSE_BUTTON_MASK_LEFT
					paper._gui_input(motion)
					assert(document.redacted.is_empty())
				var point: Vector2 = paper.document_to_local(document.target_rects(target_index)[0].get_center())
				_click(paper, point, MOUSE_BUTTON_RIGHT)
				assert(document.redacted.is_empty())
				var before := notifications[0]
				_click(paper, point)
				assert(document.redacted == [target_index] and notifications[0] == before + 1)
				_click(paper, point)
				assert(notifications[0] == before + 1)
				document.set_page(page)
			# Every unmarked character centre must stay unclickable, including neighbours of a target.
			for sentence_index in range(page.sentences.size()):
				for line_index in range(page.sentences[sentence_index].size()):
					var text: String = page.sentences[sentence_index][line_index]
					for column in range(text.length()):
						var expected := -1
						for index in range(page.targets.size()):
							var target: Dictionary = page.targets[index]
							if target.sentence == sentence_index:
								if not target.has("text"):
									expected = index
								elif target.line == line_index:
									var start := text.find(target.text)
									if column >= start and column < start + target.text.length():
										expected = index
						var bounds: Rect2 = document.line_rect(sentence_index, line_index)
						var source := Vector2(document.LEFT + (document.character_offset(text, column) + document.character_offset(text, column + 1)) * 0.5, bounds.get_center().y)
						assert(document.target_at(source) == expected, "Only the exact marked characters can be clicked")
			document.redact_target(-1)
			document.redact_target(page.targets.size())
			assert(document.redacted.is_empty())
			for index in range(page.targets.size()):
				document.redact_target(index)
			assert(document.is_complete())
			document.set_page(page)
			assert(not document.is_complete() and document.target_progress.is_empty())
	root.size = Vector2i(1152, 648)
	var camera: Camera2D = scene.get_node("WorkCamera")
	camera.enabled = true
	await process_frame
	camera.position = paper.get_global_rect().get_center()
	camera.zoom = Vector2.ONE * 1.32
	camera.force_update_scroll()
	paper.animate = true
	paper.stroke_speed = 90000.0
	paper.line_pause = 0.0
	document.set_page(document.PAGES[0])
	var target: Vector2 = paper.get_global_transform_with_canvas() * paper.document_to_local(document.target_rects(0)[0].get_center())
	var click := InputEventMouseButton.new()
	click.position = target
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	assert(paper.busy and document.redacted.is_empty())
	await paper.target_redacted
	assert(not paper.busy and document.redacted == [0])
	assert(document.target_progress[Vector2i(0, 0)] == 1.0)
	if DisplayServer.get_name() != "headless":
		for page_index in range(document.PAGES.size()):
			document.set_page(document.PAGES[page_index])
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/file-%d-before.png" % (page_index + 1))
			for index in range(document.page.targets.size()):
				document.redact_target(index)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/file-%d-after.png" % (page_index + 1))
	print("PASS: planned before/after text, exact marked spans, protected adjacent characters, blank papers, target animation and perspective at three sizes")
	quit()


func _click(paper: TextureRect, point: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = true
	paper._gui_input(event)
