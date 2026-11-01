extends Node2D

@export var paper: TextureRect
@export var title_card: CanvasLayer
@export var dialogue_box: CanvasLayer

var _image: TextureRect


func _ready() -> void:
	_image = TextureRect.new()
	_image.texture = paper.get_node("DocumentViewport").get_texture()
	_image.material = paper.material
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)
	_process(0.0)


func _process(_delta: float) -> void:
	# Match the paper's camera transform; only its image passes through dithering.
	transform = paper.get_global_transform_with_canvas()
	_image.size = paper.size
	visible = paper.is_visible_in_tree() and not dialogue_box._root.visible
	modulate.a = 1.0 - title_card._shade.modulate.a if title_card._shade.visible else 1.0
