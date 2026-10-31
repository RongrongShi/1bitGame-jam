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
var redacted_words: Array[int] = []
var words: Array[Dictionary] = []
var hovered_word := -1
var word_progress: Dictionary = {}
var _word_tweens: Array[Tween] = []
# Partial redaction progress per row (row index -> 0.0..1.0).
var line_progress: Dictionary = {}
# Cached scribble paths per row, so the strokes stay identical across redraws.
var _scribbles: Dictionary = {}


func _ready() -> void:
	_build_words()


func _build_words() -> void:
	for sentence_index in range(sentences.size()):
		for line_index in range(sentences[sentence_index].size()):
			var line: String = sentences[sentence_index][line_index]
			var row := 4 + sentence_index * 3 + line_index
			var column := 0
			for word in line.split(" ", false):
				column = line.find(word, column)
				var bounds := _line_rect(word, row)
				bounds.position.x += column * FONT_SIZE * 0.6
				words.append({"text": word, "rect": bounds, "row": row, "sentence": sentence_index})
				column += word.length()


func set_page(new_page: Dictionary) -> void:
	for tween in _word_tweens:
		if tween.is_valid():
			tween.kill()
	_word_tweens.clear()
	word_progress.clear()
	redacted_words.clear()
	words.clear()
	hovered_word = -1
	page = new_page
	sentences = new_page.sentences
	_build_words()
	redacted.clear()
	line_progress.clear()
	_scribbles.clear()
	queue_redraw()


# True when every sentence the officer wants hidden has been redacted.
func is_complete() -> bool:
	for target in page.targets:
		if target not in redacted:
			return false
	return true


# Document-space point at the middle of a block of rows, used to aim the reading zoom.
func rows_center(first_row: int, last_row: int) -> Vector2:
	var y := FIRST_BASELINE + (first_row + last_row) * 0.5 * LINE_HEIGHT - 16.0
	return Vector2(get_viewport_rect().size.x * 0.5, y)


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
				# In scribble mode the typed text fades under the pen as it covers the line.
				var text_alpha := 1.0 - fraction * 0.85 if USE_SCRIBBLE else 1.0
				_write_line(line, row, FONT_SIZE, text_alpha)
			if fraction > 0.0:
				if USE_SCRIBBLE:
					_draw_scribble(_scribble_for(row, _line_rect(line, row)), fraction)
				else:
					var rect := _line_rect(line, row)
					rect.size.x *= fraction
					draw_rect(rect, Color.BLACK)
	for index in range(page.footer.size()):
		_write_line(page.footer[index], 17 + index, 32)
	for index in redacted_words:
		if words[index].sentence not in redacted:
			var bounds: Rect2 = words[index].rect
			bounds.size.x *= word_progress.get(index, 1.0)
			draw_rect(bounds, Color.BLACK)
	if hovered_word >= 0:
		var bounds: Rect2 = words[hovered_word].rect
		draw_line(Vector2(bounds.position.x, bounds.get_center().y),
			Vector2(bounds.end.x, bounds.get_center().y), Color.BLACK, 4.0)


func _write_line(text: String, row: int, font_size: int, alpha_scale := 1.0) -> void:
	_type_line(text, FIRST_BASELINE + row * LINE_HEIGHT, font_size, alpha_scale)


func _type_line(text: String, baseline: float, font_size: int, alpha_scale := 1.0) -> void:
	var impressions := _impressions(text, baseline)
	for index in range(text.length()):
		var impression := impressions[index]
		var position := Vector2(LEFT + index * font_size * 0.6, baseline) + Vector2(impression.x, impression.y)
		draw_string(body_font, position, text[index], HORIZONTAL_ALIGNMENT_LEFT, -1,
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


func _line_rect(text: String, row: int) -> Rect2:
	var width := text.length() * FONT_SIZE * 0.6
	return Rect2(LEFT - 4, FIRST_BASELINE + row * LINE_HEIGHT - body_font.get_ascent(FONT_SIZE) - 2,
		width + 8, body_font.get_height(FONT_SIZE) + 4)


# Public rect of one line in document space.
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


func word_at(point: Vector2) -> int:
	for index in range(words.size()):
		if index not in redacted_words and words[index].sentence not in redacted and words[index].rect.has_point(point):
			return index
	return -1


func set_hovered_word(index: int) -> void:
	if index in redacted_words:
		index = -1
	if hovered_word == index:
		return
	hovered_word = index
	queue_redraw()


func redact_stroke(from: Vector2, to: Vector2, duration := 0.0) -> void:
	for index in range(words.size()):
		if index not in redacted_words and _stroke_hits_rect(from, to, words[index].rect):
			redacted_words.append(index)
			if duration > 0.0:
				word_progress[index] = 0.0
				var tween := create_tween()
				_word_tweens.append(tween)
				tween.tween_method(_set_word_progress.bind(index), 0.0, 1.0, minf(duration, 0.2))
	_sync_sentence_completion()
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


func _set_word_progress(fraction: float, index: int) -> void:
	word_progress[index] = fraction
	_sync_sentence_completion()
	queue_redraw()


func _sync_sentence_completion() -> void:
	for sentence_index in range(sentences.size()):
		var complete := true
		for index in range(words.size()):
			if words[index].sentence == sentence_index and (index not in redacted_words or word_progress.get(index, 1.0) < 1.0):
				complete = false
				break
		if complete:
			redact_sentence(sentence_index)
