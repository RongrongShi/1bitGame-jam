@tool
extends Control

@export var body_font: Font

const FONT_SIZE = 42
const LEFT = 126.0
const FIRST_BASELINE = 195.0
const LINE_HEIGHT = 56.4
const HEADER_SIZES = [32, 32, 34]

# Redaction look: false = solid black bar, true = hand-scribbled pen strokes.
const USE_SCRIBBLE = false
const PEN_WIDTH = 20.0
const PEN_STEP = 12.0
const PEN_PASSES = 3
const INK = Color.BLACK

# Page data lives in pages.gd.
const PAGES = preload("res://scenes/pages.gd").PAGES

var page: Dictionary = PAGES[0]
var sentences: Array = PAGES[0].sentences
var redacted: Array[int] = []
# Progress is keyed by target and its line segment.
var target_progress: Dictionary = {}
# Cached scribble paths per row, so the strokes stay identical across redraws.
var _scribbles: Dictionary = {}


func set_page(new_page: Dictionary) -> void:
	page = new_page
	sentences = new_page.sentences
	redacted.clear()
	target_progress.clear()
	get_parent().get_parent().get_node("PaperViewport/PaperImage").texture = new_page.paper
	get_parent().get_parent().get_node("PaperViewport/PressPhoto").visible = new_page.get("kind", "") == "newspaper" and new_page.has("photo")
	get_parent().get_parent().get_node("PaperViewport/PressPhoto").texture = new_page.get("photo", preload("res://assets/Newspaper_WestStation.png"))
	if new_page.get("kind", "") == "newspaper":
		var photo: TextureRect = get_parent().get_parent().get_node("PaperViewport/PressPhoto")
		photo.position = Vector2(180, 670 if new_page.edition % 2 == 0 else 580)
		photo.size = Vector2(550, 260)
	_scribbles.clear()
	queue_redraw()


func is_complete() -> bool:
	return not page.targets.is_empty() and redacted.size() == page.targets.size()


func _draw() -> void:
	if body_font == null:
		return
	if page.get("kind", "") == "newspaper":
		_draw_newspaper()
		return
	_type_line(page.get("title", "RESTRICTED"), 140, 52)
	for index in range(page.header.size()):
		_write_line(page.header[index], index, HEADER_SIZES[index])
	for sentence_index in range(sentences.size()):
		for line_index in range(sentences[sentence_index].size()):
			_write_line(sentences[sentence_index][line_index], _sentence_row(sentence_index) + line_index, text_size())
	for index in range(page.footer.size()):
		_write_line(page.footer[index], int(page.get("footer_row", 17)) + index, 32)
	for index in range(page.targets.size()):
		var rectangles := target_rects(index)
		for part in range(rectangles.size()):
			var bounds := rectangles[part]
			var fraction: float = 1.0 if index in redacted else target_progress.get(Vector2i(index, part), 0.0)
			draw_line(Vector2(bounds.position.x, bounds.get_center().y),
				Vector2(bounds.end.x, bounds.get_center().y), Color.BLACK, 4.0)
			if fraction == 0.0:
				continue
			if USE_SCRIBBLE:
				_draw_scribble(_scribble_for(index * 3 + part, bounds), fraction)
			else:
				draw_colored_polygon(_ink_outline(bounds, fraction, index * 17 + part), Color.BLACK)


func _ink_outline(bounds: Rect2, fraction: float, seed: int) -> PackedVector2Array:
	var random := RandomNumberGenerator.new()
	random.seed = seed * 7919 + int(bounds.position.x) * 17 + int(bounds.position.y) * 31
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var reach := bounds.position.x + bounds.size.x * fraction
	var x := bounds.position.x
	# Only the outside edge varies; the solid centre still completely conceals the letters.
	while true:
		top.append(Vector2(x, bounds.position.y - random.randf_range(0.5, 3.5)))
		bottom.append(Vector2(x, bounds.end.y + random.randf_range(0.5, 3.5)))
		if x >= reach:
			break
		x = minf(x + 8.0, reach)
	top.append(Vector2(reach + 1.0, bounds.position.y + 4.0))
	top.append(Vector2(reach + 2.0, bounds.get_center().y))
	top.append(Vector2(reach + 1.0, bounds.end.y - 4.0))
	bottom.reverse()
	top.append_array(bottom)
	top.append(Vector2(bounds.position.x - 1.0, bounds.end.y - 4.0))
	top.append(Vector2(bounds.position.x - 2.0, bounds.get_center().y))
	top.append(Vector2(bounds.position.x - 1.0, bounds.position.y + 4.0))
	return top


func _write_line(text: String, row: int, font_size: int, alpha_scale := 1.0) -> void:
	_type_line(text, FIRST_BASELINE + row * float(page.get("line_height", LINE_HEIGHT)), font_size, alpha_scale)


func _type_line(text: String, baseline: float, font_size: int, alpha_scale := 1.0) -> void:
	var impressions := _impressions(text, baseline)
	for index in range(text.length()):
		var impression := impressions[index]
		var position := Vector2(LEFT + character_offset(text, index, font_size), baseline) + Vector2(impression.x, impression.y)
		draw_string(page.get("font", body_font), position, text[index], HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, Color(0, 0, 0, impression.z * alpha_scale))


func _impressions(text: String, baseline: float) -> Array[Vector3]:
	# A fixed seed keeps worn ribbon marks unchanged when another sentence is redacted.
	var random := RandomNumberGenerator.new()
	random.seed = text.hash() + int(baseline)
	var result: Array[Vector3] = []
	for _character in text:
		result.append(Vector3(random.randf_range(-0.7, 0.7), random.randf_range(-1.5, 1.5),
			random.randf_range(0.72, 1.0)))
	return result


# One continuous pen path over a line: zigzag right, back left, right again.
func _scribble_for(row: int, rect: Rect2) -> PackedVector2Array:
	if _scribbles.has(row):
		return _scribbles[row]
	var random := RandomNumberGenerator.new()
	random.seed = row * 7919 + int(rect.size.x)
	var half := PEN_WIDTH * 0.5
	# Keep the stroke inside the line so it does not smear onto neighbouring lines.
	var top := rect.position.y + half
	var bottom := rect.end.y - half
	var left := rect.position.x - 2.0
	var right := rect.end.x + random.randf_range(-4.0, 10.0)
	var points := PackedVector2Array()
	var at_top := random.randf() < 0.5
	for pass_index in range(PEN_PASSES):
		var direction := 1.0 if pass_index % 2 == 0 else -1.0
		var x := left if direction > 0.0 else right
		while x >= left and x <= right:
			var y := (top if at_top else bottom) + random.randf_range(-3.0, 3.0)
			points.append(Vector2(x + random.randf_range(-2.0, 2.0), y))
			at_top = not at_top
			x += direction * PEN_STEP * random.randf_range(0.7, 1.3)
	_scribbles[row] = points
	return points


# Draw the pen path up to the given progress (0..1) with rounded joints.
func _draw_scribble(points: PackedVector2Array, fraction: float) -> void:
	if points.size() < 2:
		return
	var reach := fraction * (points.size() - 1)
	var whole := int(reach)
	var shown := points.slice(0, whole + 1)
	if whole < points.size() - 1:
		shown.append(points[whole].lerp(points[whole + 1], reach - whole))
	draw_polyline(shown, INK, PEN_WIDTH, true)
	for point in shown:
		draw_circle(point, PEN_WIDTH * 0.5, INK)


func text_size() -> int:
	return int(page.get("text_size", 52 if page.has("font") else FONT_SIZE))


func character_offset(text: String, column: int, font_size := 0) -> float:
	if font_size == 0:
		font_size = text_size()
	if page.has("font"):
		return page.font.get_string_size(text.left(column), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return column * font_size * 0.6


func _line_rect(text: String, row: int) -> Rect2:
	var font: Font = page.get("font", body_font)
	var size := text_size()
	var width := character_offset(text, text.length())
	return Rect2(LEFT - 4, FIRST_BASELINE + row * float(page.get("line_height", LINE_HEIGHT)) - font.get_ascent(size) - 2,
		width + 8, font.get_height(size) + 4)


func _sentence_row(sentence_index: int) -> int:
	# Editor tool instances may retain page data from before explicit paragraph rows were added.
	var rows: Array = page.get("sentence_rows", [])
	return int(page.get("body_row", 4)) + (int(rows[sentence_index]) if sentence_index < rows.size() else sentence_index * 3)


func line_rect(sentence_index: int, line_index: int) -> Rect2:
	return _line_rect(sentences[sentence_index][line_index], _sentence_row(sentence_index) + line_index)


func target_rects(index: int) -> Array[Rect2]:
	var target: Dictionary = page.targets[index]
	var result: Array[Rect2] = []
	if target.has("text"):
		var line: String = sentences[target.sentence][target.line]
		var column := line.find(target.text)
		assert(column >= 0 and line.count(target.text) == 1, "Redaction text must match exactly once")
		var bounds := line_rect(target.sentence, target.line)
		bounds.position.x = LEFT + character_offset(line, column) - 1
		bounds.size.x = character_offset(line, column + target.text.length()) - character_offset(line, column) + 2
		result.append(bounds)
	else:
		for part in range(sentences[target.sentence].size()):
			result.append(line_rect(target.sentence, part))
	return result


func set_target_progress(index: int, part: int, fraction: float) -> void:
	target_progress[Vector2i(index, part)] = clampf(fraction, 0.0, 1.0)
	queue_redraw()


func target_at(point: Vector2) -> int:
	for index in range(page.targets.size()):
		if index in redacted:
			continue
		for bounds in target_rects(index):
			if bounds.has_point(point):
				return index
	return -1


func redact_target(index: int) -> void:
	if index < 0 or index >= page.targets.size() or index in redacted:
		return
	redacted.append(index)
	queue_redraw()


func _news_block(text: String, position: Vector2, width: float, font_size: int) -> float:
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.add_string(text, preload("res://assets/fonts/Newsreader-Variable.ttf"), font_size)
	paragraph.draw(get_canvas_item(), position, Color.BLACK)
	return paragraph.get_size().y


func _news_paragraphs(lines: Array) -> PackedStringArray:
	return "\n".join(lines).split("\n\n", false)


func _draw_newspaper() -> void:
	var font: Font = preload("res://assets/fonts/Newsreader-Variable.ttf")
	draw_string(font, Vector2(180, 205), "BERLINER MORGENBLATT", HORIZONTAL_ALIGNMENT_LEFT, -1, 100, Color.BLACK)
	draw_string(font, Vector2(180, 270), page.date + " / MORNING EDITION / 10 PFENNIG", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.BLACK)
	draw_line(Vector2(180, 305), Vector2(2200, 305), Color.BLACK, 5)
	draw_line(Vector2(785, 345), Vector2(785, 1490), Color.BLACK, 2)
	draw_line(Vector2(1785, 345), Vector2(1785, 1490), Color.BLACK, 2)

	# Headlines and press images occupy the darker outside column.
	_news_block(page.headline, Vector2(180, 365), 550, 58 if page.edition % 2 == 0 else 54)
	var photo_y := 670.0 if page.edition % 2 == 0 else 580.0
	draw_rect(Rect2(180, photo_y, 550, 260), Color.BLACK, false, 2)
	var caption_height := _news_block(page.caption, Vector2(180, photo_y + 285), 550, 29)
	var left_y := photo_y + 320 + caption_height
	draw_line(Vector2(180, left_y), Vector2(730, left_y), Color.BLACK, 2)
	_news_block("OFFICIAL PRESS SERVICE", Vector2(180, left_y + 30), 550, 31)
	_news_block(page.lead_title + " / DISTRICT REPORT", Vector2(180, left_y + 90), 550, 29)

	# Keep the complete report and its revealing notice together in the light middle column.
	var y := 355.0
	y += _news_block(page.subtitle, Vector2(850, y), 880, 44) + 24.0
	draw_line(Vector2(850, y), Vector2(1730, y), Color.BLACK, 3)
	y += 28.0
	var paragraphs := PackedStringArray([" ".join(page.lead)])
	for column in page.columns:
		paragraphs.append_array(_news_paragraphs(column))
	for paragraph in paragraphs:
		y += _news_block(paragraph.replace("\n", " "), Vector2(850, y), 880, 38) + 16.0
	y += 10.0
	draw_line(Vector2(850, y), Vector2(1730, y), Color.BLACK, 3)
	y += 22.0
	y += _news_block(page.notice_title, Vector2(850, y), 880, 42) + 14.0
	y += _news_block(" ".join(page.notice), Vector2(850, y), 880, 38)

	var right_y := 365.0
	right_y += _news_block("CITY NOTICES", Vector2(1840, right_y), 360, 42) + 35.0
	var notices := [
		["BLACKOUT", "Keep street lamps shaded."],
		["IDENTITY PAPERS", "Carry identity papers. Present them when requested."],
		["RAILWAY ENQUIRIES", "Report railway delays to the station office."],
		["DISTRICT OFFICES", "Submit enquiries in writing to your registered district office."],
	]
	for notice in notices:
		right_y += _news_block(notice[0], Vector2(1840, right_y), 360, 32) + 12.0
		right_y += _news_block(notice[1], Vector2(1840, right_y), 360, 30) + 45.0
	draw_line(Vector2(180, 1470), Vector2(2200, 1470), Color.BLACK, 3)
	draw_string(font, Vector2(180, 1510), "BERLINER MORGENBLATT / DISTRICT EDITION", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.BLACK)
