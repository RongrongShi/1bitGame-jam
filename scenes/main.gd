extends Node

signal work_started(page_index: int)
signal letter_finished(page_index: int)

@export var play_intro := true

const ZOOM_TIME := 1.0
const BLACK_PAUSE := 1.6
const DAY_BLACK_PAUSE := 3.0
const WIDE_PAUSE := 1.0
const ENDING_SILENCE := 4.0

const CALLBACK_LINES := [
	"The secrets will be buried.",
	"The Reich will prevail.",
	"Glory to the Reich.",
]
const INTRO_LINES := [
	"Sit down. Scheiße. I'm Major Lange. You answer to me here.",
	"Our army is making a strategic withdrawal. Those damned Allies will pay for every step.",
	"A desk, regular rations, a roof over your head.",
	"Do your work properly, and you'll be looked after.",
	"This office clears press extracts, public notices and outgoing letters.",
	"Military originals stay sealed. Work on the copies marked for release.",
	"Private letters go to their addressees. The press receives only what we clear.",
	"The marked passages are not for circulation. Black them out. Even you can manage that.",
	"Certain facts are not for the public. They breed panic. Panic serves the enemy.",
] + CALLBACK_LINES

const INTERLUDE_LINES := {
	3: [
		"Good work. You're getting the hang of it.",
		"Here. Something to pass the quiet hours.",
		"The morning paper. Read it when you like, so long as the work gets done.",
	],
	4: [
		"Our batteries have begun returning fire.",
		"Let the artillery do its work. You have yours.",
		"Keep the documents in order. We'll be needing them.",
	],
}

const ENDING_LINES := [
	"The files are ready for collection.",
	"You have served the Reich well.",
	"Your work here is complete.",
] + CALLBACK_LINES
const ENDING_POSES = [
	preload("res://assets/Officer_TakeGun1.png"),
	preload("res://assets/Officer_TakeGun2.png"),
	preload("res://assets/Officer_TakeGun3.png"),
]

var page_index := 0
var busy := true
var _awaiting_finish_click := false
var _paper_was_busy := true
var _ink_was_visible := true
var _camera_tween: Tween

@onready var top: TextureRect = $Paper
@onready var camera: Camera2D = $WorkCamera
@onready var article: TextureRect = $NewspaperArticle
@onready var folded_newspaper: TextureRect = $FoldedNewspaper
@onready var title_card = $TitleCard
@onready var dialogue_box = $DialogueBox


func _ready() -> void:
	top.busy = true
	var page_sounds := AudioStreamRandomizer.new()
	page_sounds.add_stream(-1, preload("res://assets/audio/paper-handling_1.mp3"))
	page_sounds.add_stream(-1, preload("res://assets/audio/paper-handling_2.mp3"))
	$PaperHandling.stream = page_sounds
	camera.position = get_viewport().get_visible_rect().size * 0.5
	top.target_redacted.connect(_on_target_redacted)
	$Bombardment.shake_changed.connect(_on_officer_shake)
	folded_newspaper.gui_input.connect(_on_newspaper_input)
	get_viewport().size_changed.connect(func() -> void: call_deferred("_fit_work_view"))
	title_card.cut_to_black()
	if play_intro:
		_play_intro()
	else:
		$BackgroundMusic.play()
		_start_letter()


func _play_intro() -> void:
	await title_card.show_headphones()
	get_tree().create_timer(2.0).timeout.connect($BackgroundMusic.play)
	await title_card.show_card("BERLIN, 1944")
	await dialogue_box.show_lines(INTRO_LINES)
	await get_tree().create_timer(BLACK_PAUSE).timeout
	await _start_letter()


func _start_letter() -> void:
	busy = true
	top.busy = true
	top.document.set_page(top.document.PAGES[page_index])
	top.show()
	folded_newspaper.visible = page_index >= 3
	if page_index >= 3:
		article.get_node("DocumentViewport/Document").set_page(preload("res://scenes/pages.gd").NEWSPAPERS[page_index - 3])
	$Bombardment.set_day(page_index + 1)
	$BackgroundMusic.volume_db = -19.0 if page_index >= 5 else -16.0
	if INTERLUDE_LINES.has(page_index):
		if page_index == 4:
			$Bombardment.countdown = 0.0
			await get_tree().create_timer(0.6).timeout
		if page_index == 3:
			await dialogue_box.show_lines(INTERLUDE_LINES[page_index], true, false,
				preload("res://assets/Officer_TakeNewspaper.png"), 0.81)
			$PaperHandling.play()
		else:
			await dialogue_box.show_lines(INTERLUDE_LINES[page_index])
		dialogue_box._root.get_node("OfficerBackground").set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await get_tree().create_timer(BLACK_PAUSE).timeout
	await title_card.reveal()
	await get_tree().create_timer(WIDE_PAUSE).timeout
	await _zoom(true)
	busy = false
	top.busy = false
	work_started.emit(page_index)


func _work_zoom(paper: TextureRect = top) -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var document_size := Vector2(paper.get_node("DocumentViewport").size)
	var fitted_size := document_size * minf(paper.size.x / document_size.x, paper.size.y / document_size.y)
	var amount := minf(viewport_size.x * 0.9 / fitted_size.x, viewport_size.y * 0.94 / fitted_size.y)
	return Vector2.ONE * amount


func _fit_work_view() -> void:
	if not busy:
		var paper: TextureRect = article if article.visible else top
		camera.position = _work_center(paper) if paper.visible else get_viewport().get_visible_rect().size * 0.5
		camera.zoom = _work_zoom(paper) if paper.visible else Vector2.ONE

func _work_center(paper: TextureRect) -> Vector2:
	var center := paper.get_global_rect().get_center()
	if paper == article:
		center.y -= get_viewport().get_visible_rect().size.y * 0.095 / _work_zoom(paper).y
	return center


func _zoom(working: bool, paper: TextureRect = top) -> void:
	var center := _work_center(paper) if working else get_viewport().get_visible_rect().size * 0.5
	var amount := _work_zoom(paper) if working else Vector2.ONE
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween = tween
	tween.tween_property(camera, "position", center, ZOOM_TIME)
	tween.tween_property(camera, "zoom", amount, ZOOM_TIME)
	# A newspaper close can interrupt its opening tween without leaving a suspended waiter.
	while tween.is_running():
		await get_tree().process_frame


func _on_target_redacted(_index: int) -> void:
	if busy or not top.document.is_complete():
		return
	top.busy = true
	_awaiting_finish_click = true


func _finish_letter() -> void:
	busy = true
	$PaperHandling.play()
	await _zoom(false)
	await get_tree().create_timer(WIDE_PAUSE).timeout
	await title_card.fade_to_black()
	if page_index + 1 < top.document.PAGES.size():
		$Bombardment.stop()
	letter_finished.emit(page_index)
	await get_tree().create_timer(DAY_BLACK_PAUSE).timeout
	if page_index + 1 < top.document.PAGES.size():
		page_index += 1
		await _start_letter()
	else:
		await _play_ending()


func _on_officer_shake(offset: Vector2) -> void:
	if not dialogue_box._root.visible:
		return
	var officer: TextureRect = dialogue_box._root.get_node("OfficerBackground")
	# Overscan keeps the doorway covering the screen throughout the strongest shake.
	officer.offset_left = -48.0 + offset.x
	officer.offset_top = -48.0 + offset.y
	officer.offset_right = 48.0 + offset.x
	officer.offset_bottom = 48.0 + offset.y


func _play_ending() -> void:
	dialogue_box.line_started.connect(_on_ending_line)
	await dialogue_box.show_lines(ENDING_LINES, false, true)
	dialogue_box.line_started.disconnect(_on_ending_line)
	dialogue_box._root.get_node("OfficerBackground").set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_card.cut_to_black()
	$BackgroundMusic.stop()
	$Bombardment.stop()
	$Gunshot.play()
	await get_tree().create_timer(ENDING_SILENCE).timeout
	await title_card.show_epilogue()
	await get_tree().create_timer(BLACK_PAUSE).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_ending_line(index: int) -> void:
	var pose := index - (ENDING_LINES.size() - CALLBACK_LINES.size())
	if pose >= 0:
		dialogue_box._root.get_node("OfficerBackground").texture = ENDING_POSES[pose]
		dialogue_box._root.get_node("OfficerBackground").self_modulate = Color(0.81, 0.81, 0.81)


func _on_newspaper_input(event: InputEvent) -> void:
	if not busy and (not top.busy or _awaiting_finish_click) and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		folded_newspaper.accept_event()
		_open_newspaper()


func _open_newspaper() -> void:
	busy = true
	$PaperHandling.play()
	_paper_was_busy = top.busy
	_ink_was_visible = $InkBottle.visible
	$InkBottle.hide()
	top.busy = true
	top.hide()
	folded_newspaper.hide()
	article.show()
	await _zoom(true, article)
	if article.visible:
		busy = false


func _input(event: InputEvent) -> void:
	if article.visible:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			_close_newspaper()
		return
	if _awaiting_finish_click and not busy and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var newspaper_point: Vector2 = folded_newspaper.get_global_transform_with_canvas().affine_inverse() * event.position
		if folded_newspaper.visible and Rect2(Vector2.ZERO, folded_newspaper.size).has_point(newspaper_point):
			return
		_awaiting_finish_click = false
		get_viewport().set_input_as_handled()
		_finish_letter()


func _close_newspaper() -> void:
	if not article.visible:
		return
	busy = true
	if _camera_tween and _camera_tween.is_running():
		_camera_tween.kill()
	$PaperHandling.play()
	article.hide()
	$InkBottle.visible = _ink_was_visible
	top.show()
	await _zoom(true)
	top.busy = _paper_was_busy
	folded_newspaper.show()
	busy = false
