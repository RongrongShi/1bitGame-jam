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
			if sentence_index in redacted:
				draw_rect(_line_rect(line, row), Color.BLACK)
			else:
				_write_line(line, row, FONT_SIZE)
	_write_line("FILED BY: LT. E. WARD", 17, 32)
	_write_line("RESTRICTED / COPY 01 OF 03", 18, 32)


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


func sentence_at(point: Vector2) -> int:
	for sentence_index in range(SENTENCES.size()):
		for line_index in range(SENTENCES[sentence_index].size()):
			if _line_rect(SENTENCES[sentence_index][line_index], 4 + sentence_index * 3 + line_index).has_point(point):
				return sentence_index
	return -1


func redact_sentence(index: int) -> void:
	if index < 0 or index >= SENTENCES.size() or index in redacted:
		return
	redacted.append(index)
	queue_redraw()
