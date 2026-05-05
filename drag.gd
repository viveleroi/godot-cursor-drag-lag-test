extends TextureRect

const ITEM_OFFSET := Vector2(14, 18)
const VSYNC_NAMES := ["Disabled", "Enabled", "Adaptive", "Mailbox"]
const VSYNC_MODES := [
	DisplayServer.VSYNC_DISABLED,
	DisplayServer.VSYNC_ENABLED,
	DisplayServer.VSYNC_ADAPTIVE,
	DisplayServer.VSYNC_MAILBOX,
]
const MOUSE_MODE_CUSTOM := 0
const MOUSE_MODE_OS := 1
const MOUSE_MODE_HARDWARE := 2

var _pointer: TextureRect
var _mouse_mode: int = MOUSE_MODE_CUSTOM
var _process_dragged: TextureRect
var _stats_label: Label

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

	_process_dragged = get_node("../ProcessDragged")
	_stats_label = get_node("../Stats")

	var mouse_picker: OptionButton = get_node("../Settings/MouseMode")
	mouse_picker.clear()
	mouse_picker.add_item("Custom drawn")
	mouse_picker.add_item("OS cursor")
	mouse_picker.add_item("Hardware cursor")
	mouse_picker.select(MOUSE_MODE_CUSTOM)
	mouse_picker.item_selected.connect(_apply_mouse_mode)

	var vsync_picker: OptionButton = get_node("../Settings/VSync")
	vsync_picker.clear()
	for vsync_name in VSYNC_NAMES:
		vsync_picker.add_item(vsync_name)
	vsync_picker.select(3)
	vsync_picker.item_selected.connect(_apply_vsync_mode)

	var fullscreen_toggle: CheckBox = get_node("../Settings/Fullscreen")
	fullscreen_toggle.toggled.connect(_apply_fullscreen)

	_apply_mouse_mode(mouse_picker.selected)
	_apply_vsync_mode(vsync_picker.selected)

func _apply_mouse_mode(index: int) -> void:
	_mouse_mode = index
	Input.set_custom_mouse_cursor(null)
	match index:
		MOUSE_MODE_CUSTOM:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			_pointer.visible = true
			visible = true
			_process_dragged.visible = true
		MOUSE_MODE_OS:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_pointer.visible = false
			visible = true
			_process_dragged.visible = true
		MOUSE_MODE_HARDWARE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			Input.set_custom_mouse_cursor(texture)
			_pointer.visible = false
			visible = false
			_process_dragged.visible = false

func _apply_vsync_mode(index: int) -> void:
	DisplayServer.window_set_vsync_mode(VSYNC_MODES[index])

func _apply_fullscreen(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _mouse_mode == MOUSE_MODE_CUSTOM:
			_pointer.position = event.global_position
		global_position = event.global_position + ITEM_OFFSET

func _process(_delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / fps if fps > 0 else 0.0
	var current_vsync := DisplayServer.window_get_vsync_mode()
	var window_mode := DisplayServer.window_get_mode()
	var fs := window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN
	var screen := DisplayServer.window_get_current_screen()
	var refresh := DisplayServer.screen_get_refresh_rate(screen)
	var refresh_text := "%.1f Hz" % refresh if refresh > 0.0 else "unknown"
	_stats_label.text = "FPS: %d\nFrame: %.2f ms\nMonitor: %s\nVSync: %s\nFullscreen: %s" % [
		fps, frame_ms, refresh_text, VSYNC_NAMES[current_vsync], "Yes" if fs else "No"
	]
