extends Node

signal reading_finished

# Set to false to skip the intro (used by the test script).
@export var play_intro := true

const SLIDE_TIME := 0.9
const PILE_SCALE := 0.8
const PILE_TILT_DEG := 7.0
const PILE_JITTER := 14.0
const PILE_MAX := 4

# Reading animation: zoom in on the first stop, then pan slowly through the rest.
# Each stop is a block of layout rows [first, last]; 4 stops = 3 pans.
const READ_ZOOM := 2.5
const ZOOM_TIME := 1.2
const PAN_TIME := 2.2
const PAN_PAUSE := 0.4
const READ_STOPS := [[0, 3], [4, 8], [9, 13], [14, 18]]

const INTRO_SPEAKER := "COLONEL VOSS"
const INTRO_LINES := [
	"Sit down. Keep your voice low. This is the Records Section.",
	"The army of the Reich is resting and regrouping. Make no mistake: one day, we will return.",
	"Your task is simple. Every document carries passages marked by our officers. Black them out.",
	"Some things are not fit for the public to know. They would only cause panic.",
	"I expect you to do your duty, and to keep our secrets. Do not disappoint me.",
]

var top: TextureRect
var under: TextureRect
var page_index := 0
var busy := false
var _bottle_origin := Vector2.ZERO
var _pile: Array[TextureRect] = []
var _reading := false
var _reading_tween: Tween

@onready var ink_bottle: Control = $InkBottle
@onready var discard_spot: Node2D = $DiscardSpot
@onready var title_card = $TitleCard
@onready var dialogue_box = $DialogueBox


func _ready() -> void:
	top = $Paper
	under = $PaperNext
	_bottle_origin = ink_bottle.position
	# The bottle must receive mouse clicks.
	ink_bottle.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_page(top, 0)
	_load_page(under, 1)
	ink_bottle.gui_input.connect(_on_ink_bottle_input)
	if play_intro:
		_play_intro()


func _play_intro() -> void:
	# Looked up by path so this script still parses when the Game autoload is missing.
	var day: int = get_node("/root/Game").day
	await title_card.show_card("BERLIN, 1941")
	await dialogue_box.show_lines(INTRO_LINES, INTRO_SPEAKER)
	await title_card.show_card("DAY %d" % day)
	await title_card.reveal()
	await _maybe_read(top)


func _load_page(paper: TextureRect, index: int) -> void:
	paper.visible = index < paper.document.PAGES.size()
	if paper.visible:
		paper.document.set_page(paper.document.PAGES[index])


# Click or Enter/Space skips the reading animation.
func _input(event: InputEvent) -> void:
	if not _reading:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_accept")
	if pressed:
		_reading_tween.kill()
		reading_finished.emit()
		get_viewport().set_input_as_handled()


func _maybe_read(paper: TextureRect) -> void:
	if paper.document.page.get("read_animation", false):
		await _play_reading(paper)


# Zoom into the top of the paper, then slowly move the paper to simulate the eyes reading down it.
func _play_reading(paper: TextureRect) -> void:
	busy = true
	paper.busy = true
	_reading = true
	var rest_position := paper.position
	var rest_scale := paper.scale
	# Scale from the top-left corner so the position math stays simple.
	paper.pivot_offset = Vector2.ZERO

	var tween := create_tween()
	_reading_tween = tween
	tween.tween_property(paper, "scale", Vector2.ONE * READ_ZOOM, ZOOM_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(paper, "position", _read_position(paper, READ_STOPS[0]), ZOOM_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(ink_bottle, "modulate:a", 0.0, ZOOM_TIME)

	for stop_index in range(1, READ_STOPS.size()):
		tween.tween_interval(PAN_PAUSE)
		tween.tween_property(paper, "position", _read_position(paper, READ_STOPS[stop_index]), PAN_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(PAN_PAUSE)
	tween.tween_callback(reading_finished.emit)
	await reading_finished

	# Zoom back out to the normal desk view (also runs after a skip).
	_reading = false
	var back := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	back.tween_property(paper, "scale", rest_scale, ZOOM_TIME * 0.7)
	back.tween_property(paper, "position", rest_position, ZOOM_TIME * 0.7)
	back.tween_property(ink_bottle, "modulate:a", 1.0, ZOOM_TIME * 0.7)
	await back.finished
	paper.busy = false
	busy = false


# Paper position (at READ_ZOOM) that puts the middle of the given rows at the screen centre.
func _read_position(paper: TextureRect, stop: Array) -> Vector2:
	var doc_point: Vector2 = paper.document.rows_center(stop[0], stop[1])
	var local_point: Vector2 = paper.document_to_local(doc_point)
	return get_viewport().get_visible_rect().size * 0.5 - local_point * READ_ZOOM


func _on_ink_bottle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_use_ink()


func _use_ink() -> void:
	if busy or top.busy:
		return
	if not top.document.is_complete():
		_shake_bottle()
		return
	busy = true
	var old_top := top
	var new_top := under
	var start := old_top.position
	# Block clicks on both sheets while the top one is moved aside.
	old_top.busy = true
	new_top.busy = true
	# Snapshot the finished page now so the pile keeps showing the redactions.
	var snapshot := ImageTexture.create_from_image(
		old_top.get_node("DocumentViewport").get_texture().get_image())

	# Push the sheet gently to the discard spot, tilting and shrinking a little.
	old_top.pivot_offset = old_top.size * 0.5
	var jitter := Vector2(randf_range(-PILE_JITTER, PILE_JITTER), randf_range(-PILE_JITTER, PILE_JITTER))
	var target_center := discard_spot.global_position + jitter
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(old_top, "position", target_center - old_top.size * 0.5, SLIDE_TIME)
	tween.tween_property(old_top, "rotation", deg_to_rad(randf_range(-PILE_TILT_DEG, PILE_TILT_DEG)), SLIDE_TIME)
	tween.tween_property(old_top, "scale", Vector2.ONE * PILE_SCALE, SLIDE_TIME)
	await tween.finished

	# Leave a static copy of the finished page in the pile.
	_add_pile_sheet(old_top, snapshot, mini(old_top.get_index(), new_top.get_index()))

	if page_index + 1 >= old_top.document.PAGES.size():
		old_top.visible = false
		print("ALL FILES REVIEWED")
		return # Stay busy: there is nothing left to do.

	# Recycle the live sheet: reset it, send it to the bottom of the stack, load the page after next.
	page_index += 1
	top = new_top
	under = old_top
	move_child(old_top, new_top.get_index())
	old_top.position = start
	old_top.rotation = 0.0
	old_top.scale = Vector2.ONE
	old_top.busy = false
	new_top.busy = false
	_load_page(old_top, page_index + 1)
	busy = false
	await _maybe_read(top)


func _add_pile_sheet(source: TextureRect, texture: Texture2D, floor_index: int) -> void:
	var sheet := TextureRect.new()
	sheet.texture = texture
	sheet.material = source.material
	sheet.expand_mode = source.expand_mode
	sheet.stretch_mode = source.stretch_mode
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sheet)
	sheet.size = source.size
	sheet.pivot_offset = source.pivot_offset
	sheet.position = source.position
	sheet.rotation = source.rotation
	sheet.scale = source.scale
	# Keep the pile above the desk but below both live sheets and the ink bottle.
	move_child(sheet, floor_index)
	_pile.append(sheet)
	if _pile.size() > PILE_MAX:
		_pile.pop_front().queue_free()


func _shake_bottle() -> void:
	busy = true
	var tween := create_tween()
	for offset in [8.0, -8.0, 5.0, -5.0, 0.0]:
		tween.tween_property(ink_bottle, "position:x", _bottle_origin.x + offset, 0.05)
	await tween.finished
	busy = false
