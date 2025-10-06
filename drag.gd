extends TextureRect

func _ready() -> void:
	Input.use_accumulated_input = false

func _get_drag_data(pos):
	var data = {}

	set_drag_preview(duplicate())
	
	return data
