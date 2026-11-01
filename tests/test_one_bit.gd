extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.set_script(null)
	scene.get_node("WorkCamera").enabled = false
	root.add_child(scene)
	scene.get_node("DocumentText").hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check_binary(image)
	image.save_png("res://.godot/one-bit-desk.png")
	scene.get_node("OneBit").hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var original := root.get_texture().get_image()
	assert(original.get_data() != image.get_data(), "Post-processing must change the grayscale scene")
	original.save_png("res://.godot/grayscale-desk.png")
	scene.get_node("OneBit").show()
	var ramp := CanvasLayer.new()
	ramp.layer = 90
	root.add_child(ramp)
	for index in range(5):
		var swatch := ColorRect.new()
		swatch.position = Vector2(index * 64, 0)
		swatch.size = Vector2(64, 64)
		swatch.color = Color(index * 0.25, index * 0.25, index * 0.25)
		ramp.add_child(swatch)
	await process_frame
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	_check_binary(image)
	var previous := -1
	for index in range(5):
		var white := 0
		for y in range(64):
			for x in range(index * 64, (index + 1) * 64):
				if image.get_pixel(x, y).r > 0.5:
					white += 1
		assert(white > previous, "Brighter inputs must produce more white pixels")
		if index == 0:
			assert(white == 0)
		if index == 4:
			assert(white == 4096)
		previous = white
	await process_frame
	await RenderingServer.frame_post_draw
	var next := root.get_texture().get_image()
	next.convert(Image.FORMAT_RGB8)
	assert(image.get_data() == next.get_data(), "Static dithering must not shimmer")
	print("PASS: dithered background pure black/white output, layered overlays, ordered brightness and stable pixels")
	quit()


func _check_binary(image: Image) -> void:
	image.convert(Image.FORMAT_RGB8)
	var bytes := image.get_data()
	for offset in range(0, bytes.size(), 3):
		assert(bytes[offset] == 0 or bytes[offset] == 255, "No grayscale pixels may remain")
		assert(bytes[offset] == bytes[offset + 1] and bytes[offset] == bytes[offset + 2], "No colored pixels may remain")
