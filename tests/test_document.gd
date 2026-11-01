extends SceneTree

const RELEASED = [
	["At [X] on [X], the bridge", "remained open to road traffic.", "Routine inspections continue.", "At the western bridgehead,", "[X]", "[X]", "Losses: [X] dead, [X] wounded.", "Remaining strength: [X] men.", "Roll calls are still under way.", "Supply vehicles use the east road.", "Bridge traffic is restricted.", "Next inspection: 03 NOV."],
	["Transport order: 03 NOV, [X].", "Available trucks: [X].", "Fuel allocation: [X] barrels.", "Load manifests include records,", "medical stores and liaison staff.", "Escort details are enclosed.", "Passenger list: [X].", "[X]", "[X]", "Vehicles will use Route [X].", "Departure remains on schedule.", "Receipt of this report required."],
	["Your scarf still smells of home.", "I keep it beside me at night.", "How is our stubborn kitchen lamp?", "I shall be home later than I said.", "Do not come to West Station", "with your supper basket again.", "[X]", "[X]", "[X]", "If anyone asks, say you heard", "nothing. I cannot write more.", "I hope the soup was good.", "When I return, I will mend", "that draughty kitchen window.", "Until then, leave the lamp on."],
	["Flour from the western depots is", "being transferred to military", "bakeries under the new allocation.", "Civilian stocks will last [X].", "[X]", "Replacement coupons remain valid.", "[X]", "[X]", "Queues outside Depot 6 were", "dispersed by police on the orders", "of [X].", "The public notice will confirm", "that military production continues", "and replacement coupons are valid.", "Next stock review: 07 NOV.", "Retain the original inventory."],
	["Shelter No. 14 remains listed", "as available in the public", "register dated 01 FEB.", "[X]", "[X]", "[X]", "The annex has a separate entrance.", "Its cellar is reserved for", "[X].", "Residents were directed to", "Shelter No. 9 on the next street.", "[X]", "The old register is still in use.", "[X]", "This report awaits press clearance.", "For the public bulletin, use", "the entries cleared by this office.", "Keep the inspection report sealed."],
	["Residents awaiting transfer shall", "assemble at the western goods yard", "at 1800. Bring identity papers.", "Traffic report, 1600: the western", "passage is [X].", "[X]", "[X]", "No countersigned withdrawal", "has reached the district office.", "Transport allocation: two trucks.", "Both are assigned to [X]", "and [X].", "Until a withdrawal is signed,", "the assembly notice remains posted.", "Leave military traffic unobstructed.", "Retain the signed traffic report.", "Send only the cleared notice", "to district boards and the press."],
	["Selected files will be moved", "to the inner district office.", "Collection: rear courtyard, 1800.", "Prepare an anonymous transfer copy.", "Remove names and service numbers", "from the records listed below.", "Shelter register, 20 APR:", "clearance signed by [X].", "Inspection: Warden [X].", "Goods yard notice, 21 APR:", "release signed by [X].", "[X]", "After collection, destroy the", "signed originals and carbon copies.", "No duplicate register is to remain.", "All remaining personnel shall", "continue work until individually", "relieved."],
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
