extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.set_script(null)
	root.add_child(scene)
	await process_frame
	var subtitles: Label = scene.get_node("DialogueBox")._text
	var title: Label = scene.get_node("TitleCard")._label
	assert(title.get_theme_font("font").resource_path.ends_with("SpecialElite-Regular.ttf"))
	assert(scene.get_node("Paper/DocumentViewport/Document").body_font == title.get_theme_font("font"))
	var weight := TextServerManager.get_primary_interface().name_to_tag("wght")
	assert(scene.get_node("Paper/DocumentViewport/Document").PAGES[2].font.resource_path.ends_with("Caveat-Variable.ttf"))
	assert(subtitles.get_theme_font("font").variation_opentype[weight] == 700.0)
	assert(subtitles.get_theme_font("font") == load("res://assets/fonts/SourceSans3-Bold.tres"))
	assert(subtitles.get_theme_constant("outline_size") == 6)
	assert(subtitles.get_theme_color("font_outline_color") == Color.BLACK)
	scene.get_node("DialogueBox")._root.show()
	for viewport_size in [Vector2i(1152, 648), Vector2i(900, 900), Vector2i(1920, 1080)]:
		root.size = viewport_size
		await process_frame
		for line in load("res://scenes/main.gd").INTRO_LINES:
			subtitles.text = line
			await process_frame
			assert(subtitles.get_minimum_size().y <= subtitles.size.y, "Bold subtitles must fit the cinematic safe area")
		subtitles.text = "Certain facts are not for the public. They breed panic. Panic serves the enemy."
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/bold-subtitles-%d.png" % viewport_size.x)
	await _check_exclusion(scene)
	print("PASS: original document fonts, bold subtitles, black subtitle outline and all intro lines at three sizes, text pixels unchanged by dithering")
	quit()


func _check_exclusion(scene: Node) -> void:
	scene.get_node("DialogueBox")._root.hide()
	scene.get_node("WorkCamera").enabled = false
	root.size = Vector2i(1152, 648)
	var background := CanvasLayer.new()
	background.layer = 90
	root.add_child(background)
	var white := ColorRect.new()
	white.color = Color.WHITE
	background.add_child(white)
	white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var effect: CanvasLayer = scene.get_node("OneBit")
	assert(scene.get_node("DocumentText").layer > effect.layer)
	assert(scene.get_node("TitleCard")._label.get_parent().layer > effect.layer)
	assert(scene.get_node("DialogueBox")._text.get_parent().layer > effect.layer)
	var document = scene.get_node("Paper/DocumentViewport/Document")
	for page_index in [0, 2, 3]:
		document.set_page(document.PAGES[page_index])
		effect.show()
		await process_frame
		await RenderingServer.frame_post_draw
		var with_effect := root.get_texture().get_image().get_data()
		effect.hide()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(with_effect == root.get_texture().get_image().get_data(), "Document text must keep identical pixels with dithering on or off")
	effect.show()
