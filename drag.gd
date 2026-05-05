extends TextureRect

const ITEM_OFFSET := Vector2(14, 18)
var _pointer: TextureRect
var _use_os_mouse: bool = false

func _ready() -> void:
	Input.use_accumulated_input = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_pointer = TextureRect.new()
	_pointer.texture = texture
	_pointer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pointer.size = Vector2(20, 20)
	_pointer.custom_minimum_size = Vector2(20, 20)
	_pointer.modulate = Color(1, 0.3, 0.3)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_pointer)

	var os_mouse_toggle: CheckBox = get_node("../Settings/OSMouse")
	var vsync_toggle: CheckBox = get_node("../Settings/VSync")
	os_mouse_toggle.toggled.connect(_apply_mouse_mode)
	vsync_toggle.toggled.connect(_apply_vsync_mode)
	_apply_mouse_mode(os_mouse_toggle.button_pressed)
	_apply_vsync_mode(vsync_toggle.button_pressed)

func _apply_mouse_mode(use_os: bool) -> void:
	_use_os_mouse = use_os
	if use_os:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_pointer.visible = false
	else:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_pointer.visible = true

func _apply_vsync_mode(enabled: bool) -> void:
	var mode := DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not _use_os_mouse:
			_pointer.position = event.global_position
		global_position = event.global_position + ITEM_OFFSET
