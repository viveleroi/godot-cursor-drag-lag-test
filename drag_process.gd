extends TextureRect

const ITEM_OFFSET := Vector2(-54, 18)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	global_position = get_viewport().get_mouse_position() + ITEM_OFFSET
