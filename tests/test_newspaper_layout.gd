extends SceneTree

const FONT = preload("res://assets/fonts/Newsreader-Variable.ttf")


func _initialize() -> void:
	call_deferred("_run")


func _height(text: String, width: float, font_size: int) -> float:
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.add_string(text, FONT, font_size)
	return paragraph.get_size().y


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.play_intro = false
	scene.page_index = 3
	scene.get_node("TitleCard").fade_time = 0.01
	root.add_child(scene)
	await preload("res://tests/interlude_driver.gd").play(self, scene, 3)
	await scene.work_started
	scene.top.document.redact_target(0)
	var ink_visible: bool = scene.get_node("InkBottle").visible
	scene._open_newspaper()
	await create_timer(1.2).timeout
	assert(scene.camera.position.is_equal_approx(scene._work_center(scene.article)))
	assert(scene.camera.position.y < scene.article.get_global_rect().get_center().y)
	assert(not scene.get_node("InkBottle").visible, "Desk tools must not cover the wider sheet")
	assert(scene.article.size.x > scene.top.size.x * 2.0)
	assert(scene.article.material != scene.top.material)
	var document = scene.article.get_node("DocumentViewport/Document")
	assert(scene.article.get_node("DocumentViewport").size == Vector2i(2400, 1600))
	assert(scene.top.get_node("DocumentViewport").size == Vector2i(1086, 1448))
	for edition in preload("res://scenes/pages.gd").NEWSPAPERS:
		document.set_page(edition)
		var photo: TextureRect = scene.article.get_node("PaperViewport/PressPhoto")
		assert(photo.position.x == 180 and photo.get_rect().end.x < 785)
		var headline_bottom := 365 + _height(edition.headline, 550, 58 if edition.edition % 2 == 0 else 54)
		assert(headline_bottom < photo.position.y - 20)
		var bottom := 355 + _height(edition.subtitle, 880, 44) + 24 + 28
		bottom += _height(" ".join(edition.lead), 880, 38) + 16
		for column in edition.columns:
			for paragraph in document._news_paragraphs(column):
				bottom += _height(paragraph.replace("\n", " "), 880, 38) + 16
		bottom += 10 + 22 + _height(edition.notice_title, 880, 42) + 14
		bottom += _height(" ".join(edition.notice), 880, 38)
		assert(bottom < 1450, "The full central report and key notice must fit above the footer")
		for viewport_size in [Vector2i(1152, 648), Vector2i(900, 900)]:
			root.size = viewport_size
			await process_frame
			await process_frame
			assert(scene.camera.position.is_equal_approx(scene._work_center(scene.article)), "Resize must preserve the upward newspaper framing")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.godot/newspaper-wide-%d-%d.png" % [edition.edition, viewport_size.x])
	scene._close_newspaper()
	await create_timer(1.2).timeout
	assert(scene.top.visible and not scene.top.busy and scene.top.document.redacted == [0])
	assert(scene.get_node("InkBottle").visible == ink_visible)
	print("PASS: larger independent broadsheet, four layouts fit, central reports and notices fit, desk tools restored and letter progress preserved")
	quit()
