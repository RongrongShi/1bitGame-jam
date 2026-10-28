extends Node

const SLIDE_OFFSET := Vector2(-1400.0, 300.0)
const SLIDE_TIME := 0.7

var top: TextureRect
var under: TextureRect
var page_index := 0
var busy := false
var _bottle_origin := Vector2.ZERO

@onready var ink_bottle: Control = $InkBottle


func _ready() -> void:
	top = $Paper
	under = $PaperNext
	_bottle_origin = ink_bottle.position
	ink_bottle.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_page(top, 0)
	_load_page(under, 1)
	ink_bottle.gui_input.connect(_on_ink_bottle_input)


func _load_page(paper: TextureRect, index: int) -> void:
	paper.visible = index < paper.document.PAGES.size()
	if paper.visible:
		paper.document.set_page(paper.document.PAGES[index])


func _on_ink_bottle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Ink bottle clicked")
		_use_ink()


func _use_ink() -> void:
	print("use_ink: busy=", busy, " top.busy=", top.busy, " complete=", top.document.is_complete())
	# The hand must be done and the officer's targets all blacked out.
	if busy or top.busy:
		return
	if not top.document.is_complete():
		_shake_bottle()
		return
	busy = true
	var old_top := top
	var new_top := under
	var start := old_top.position
	# Block clicks on both sheets while the top one slides away.
	old_top.busy = true
	new_top.busy = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(old_top, "position", start + SLIDE_OFFSET, SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(old_top, "modulate:a", 0.0, SLIDE_TIME)
	await tween.finished

	if page_index + 1 >= old_top.document.PAGES.size():
		print("ALL FILES REVIEWED")
		return # Stay busy: there is nothing left to do.

	# The finished sheet goes to the bottom of the stack and gets the page after next.
	page_index += 1
	top = new_top
	under = old_top
	move_child(old_top, new_top.get_index())
	old_top.position = start
	old_top.modulate.a = 1.0
	old_top.busy = false
	new_top.busy = false
	_load_page(old_top, page_index + 1)
	busy = false


func _shake_bottle() -> void:
	busy = true
	var tween := create_tween()
	for offset in [8.0, -8.0, 5.0, -5.0, 0.0]:
		tween.tween_property(ink_bottle, "position:x", _bottle_origin.x + offset, 0.05)
	await tween.finished
	busy = false
