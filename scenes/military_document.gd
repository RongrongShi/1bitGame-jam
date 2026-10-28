@tool
extends Control

@export var body_font: Font

const FONT_SIZE = 42
const LEFT = 126.0
const FIRST_BASELINE = 195.0
const LINE_HEIGHT = 56.4
const HEADER_SIZES = [32, 32, 34]
const PAGES = preload("res://scenes/pages.gd").PAGES

var page: Dictionary = PAGES[0]
var sentences: Array = PAGES[0].sentences
var redacted: Array[int] = []
# Partial redaction progress per row (row index -> 0.0..1.0), used by the hand animation.
var line_progress: Dictionary = {}


func set_page(new_page: Dictionary) -> void:
	page = new_page
	sentences = new_page.sentences
	redacted.clear()
	line_progress.clear()
	queue_redraw()


# True when every sentence the officer wants hidden has been redacted.
func is_complete() -> bool:
	for target in page.targets:
		if target not in redacted:
			return false
	return true


func _draw() -> void:
	if body_font == null:
		return
	_type_line("RESTRICTED", 140, 52)
	for index in range(page.header.size()):
		_write_line(page.header[index], index, HEADER_SIZES[index])
	for sentence_index in range(sentences.size()):
		for line_index in range(sentences[sentence_index].size()):
			var line: String = sentences[sentence_index][line_index]
			var row := 4 + sentence_index * 3 + line_index
			var fraction: float = 1.0 if sentence_index in redacted else line_progress.get(row, 0.0)
			if fraction < 1.0:
				_write_line(line, row, FONT_SIZE)
			if fraction > 0.0:
				var rect := _line_rect(line, row)
				rect.size.x *= fraction
				draw_rect(rect, Color.BLACK)
	for index in range(page.footer.size()):
		_write_line(page.footer[index], 17 + index, 32)


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


# Public rect of one line in document space, used to aim the hand.
func line_rect(sentence_index: int, line_index: int) -> Rect2:
	return _line_rect(sentences[sentence_index][line_index], 4 + sentence_index * 3 + line_index)


func set_line_progress(sentence_index: int, line_index: int, fraction: float) -> void:
	line_progress[4 + sentence_index * 3 + line_index] = clampf(fraction, 0.0, 1.0)
	queue_redraw()


func sentence_at(point: Vector2) -> int:
	for sentence_index in range(sentences.size()):
		for line_index in range(sentences[sentence_index].size()):
			if _line_rect(sentences[sentence_index][line_index], 4 + sentence_index * 3 + line_index).has_point(point):
				return sentence_index
	return -1


func is_redacted(index: int) -> bool:
	return index in redacted


func redact_sentence(index: int) -> void:
	if index < 0 or index >= sentences.size() or index in redacted:
		return
	redacted.append(index)
	queue_redraw()
