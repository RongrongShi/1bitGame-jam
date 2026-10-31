@tool
extends Control

@export var body_font: Font

const FONT_SIZE = 42
const LEFT = 126.0
const FIRST_BASELINE = 195.0
const LINE_HEIGHT = 56.4
const SENTENCES = [
	["Forward observers report no", "armed resistance in the village", "of Greyford."],
	["Thirty-two civilians remain", "inside the schoolhouse, awaiting", "transport before nightfall."],
	["The northern bridge is unsafe;", "medical vehicles must use the", "river road to reach the village."],
	["Command has ordered the public", "bulletin to omit all references", "to civilian casualties."],
]

var redacted: Array[int] = []
var words: Array[Dictionary] = []
var hovered_word := -1


func _ready() -> void:
	for sentence_index in range(SENTENCES.size()):
		for line_index in range(SENTENCES[sentence_index].size()):
			var line: String = SENTENCES[sentence_index][line_index]
			var row := 4 + sentence_index * 3 + line_index
			var column := 0
			for word in line.split(" ", false):
				column = line.find(word, column)
				var bounds := _line_rect(word, row)
				bounds.position.x += column * FONT_SIZE * 0.6
				words.append({"text": word, "rect": bounds, "row": row})
				column += word.length()


func _draw() -> void:
	if body_font == null:
		return
	_type_line("RESTRICTED", 140, 52)
	_write_line("INTELLIGENCE SECTION / FILE 07-41", 0, 32)
	_write_line("17 OCT 1941 / NORTHERN SECTOR", 1, 32)
	_write_line("SUBJECT: EVACUATION OF GREYFORD", 2, 34)
	for sentence_index in range(SENTENCES.size()):
		for line_index in range(SENTENCES[sentence_index].size()):
			var line: String = SENTENCES[sentence_index][line_index]
			var row := 4 + sentence_index * 3 + line_index
			_write_line(line, row, FONT_SIZE)
	_write_line("FILED BY: LT. E. WARD", 17, 32)
	_write_line("RESTRICTED / COPY 01 OF 03", 18, 32)
	for index in redacted:
		draw_rect(words[index].rect, Color.BLACK)
	if hovered_word >= 0:
		var bounds: Rect2 = words[hovered_word].rect
		draw_line(Vector2(bounds.position.x, bounds.get_center().y),
			Vector2(bounds.end.x, bounds.get_center().y), Color.BLACK, 4.0)


func _write_line(text: String, row: int, font_size: int) -> void:
	_type_line(text, FIRST_BASELINE + row * LINE_HEIGHT, font_size)


func _type_line(text: String, baseline: float, font_size: int) -> void:
	var impressions := _impressions(text, baseline)
	for index in range(text.length()):
		var impression := impressions[index]
		var position := Vector2(LEFT + index * font_size * 0.6, baseline) + Vector2(impression.x, impression.y)
		draw_string(body_font, position, text[index], HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, Color(0, 0, 0, impression.z))


func _impressions(text: String, baseline: float) -> Array[Vector3]:
	# A fixed seed keeps worn ribbon marks unchanged when another sentence is redacted.
	var random := RandomNumberGenerator.new()
	random.seed = text.hash() + int(baseline)
	var result: Array[Vector3] = []
	for _character in text:
		result.append(Vector3(random.randf_range(-0.7, 0.7), random.randf_range(-1.5, 1.5),
			random.randf_range(0.72, 1.0)))
	return result


func _line_rect(text: String, row: int) -> Rect2:
	var width := text.length() * FONT_SIZE * 0.6
	return Rect2(LEFT - 4, FIRST_BASELINE + row * LINE_HEIGHT - body_font.get_ascent(FONT_SIZE) - 2,
		width + 8, body_font.get_height(FONT_SIZE) + 4)


func word_at(point: Vector2) -> int:
	for index in range(words.size()):
		if index not in redacted and words[index].rect.has_point(point):
			return index
	return -1


func set_hovered_word(index: int) -> void:
	if index in redacted:
		index = -1
	if hovered_word == index:
		return
	hovered_word = index
	queue_redraw()


func redact_stroke(from: Vector2, to: Vector2) -> void:
	for index in range(words.size()):
		if index not in redacted and _stroke_hits_rect(from, to, words[index].rect):
			redacted.append(index)
	set_hovered_word(word_at(to))
	queue_redraw()


func _stroke_hits_rect(from: Vector2, to: Vector2, bounds: Rect2) -> bool:
	if bounds.has_point(from) or bounds.has_point(to):
		return true
	var corners := [bounds.position, Vector2(bounds.end.x, bounds.position.y),
		bounds.end, Vector2(bounds.position.x, bounds.end.y)]
	for side in range(4):
		if Geometry2D.segment_intersects_segment(from, to, corners[side], corners[(side + 1) % 4]) != null:
			return true
	return false
