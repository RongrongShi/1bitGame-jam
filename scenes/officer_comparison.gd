extends Control

@onready var _pictures := [$Standing, $DrawGun, $RaiseGun, $AimGun, $TakeNewspaper]
var _index := 0


func _ready() -> void:
	_show_picture()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_index = (_index + 1) % _pictures.size()
		_show_picture()
		get_viewport().set_input_as_handled()


func _show_picture() -> void:
	for index in range(_pictures.size()):
		_pictures[index].visible = index == _index
	$Labels/Current.text = "%d / %d — %s" % [_index + 1, _pictures.size(), _pictures[_index].name]
