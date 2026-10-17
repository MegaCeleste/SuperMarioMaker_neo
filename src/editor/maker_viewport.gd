class_name MakerViewport
extends SubViewportContainer
## 只处理画布矩形内的 GUI 输入，将屏幕位置转换为世界/网格位置。

signal hovered_cell_changed(cell: Vector2i)

@onready var camera: Camera2D = $SubViewport/World/Camera2D
@onready var world: MakerWorld = $SubViewport/World

var state: EditorState
## 200% at 1920x1080 gives the reference's 80px cells; logical zoom remains 1..4.
const REFERENCE_DENSITY: float = 2.5
var view_scale: float:
	get:
		var reference_scale: float = minf(size.x / 1920.0, size.y / 1080.0)
		return state.zoom * REFERENCE_DENSITY * reference_scale if state != null else 1.0
var input_blocked: bool = false
var _dragging: bool = false
var _pointer_inside: bool = false
var _last_point: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Input is owned by this Control; the SubViewport has no input recipients.
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	visibility_changed.connect(cancel_drag)
	get_window().focus_exited.connect(cancel_drag)


func bind(source: EditorState, catalog: EditorCatalog) -> void:
	state = source
	world.state = state
	world.catalog = catalog
	state.changed.connect(_on_state_changed)
	state.view_changed.connect(_apply_view)
	call_deferred("_initialize_view")


func _initialize_view() -> void:
	var half_view: Vector2 = size * 0.5 / view_scale
	_set_view(Vector2(half_view.x, EditorState.AREA_SIZE.y * EditorState.CELL_SIZE - half_view.y), state.zoom)
	_apply_view()


func screen_to_world(point: Vector2) -> Vector2:
	return state.view_center + (point - size * 0.5) / view_scale


func cell_at(point: Vector2) -> Vector2i:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return Vector2i(-1, -1)
	var pixel: Vector2 = screen_to_world(point)
	var cell: Vector2i = Vector2i(floori(pixel.x / EditorState.CELL_SIZE), floori(pixel.y / EditorState.CELL_SIZE))
	if cell.x < 0 or cell.y < 0 or cell.x >= EditorState.AREA_SIZE.x or cell.y >= EditorState.AREA_SIZE.y:
		return Vector2i(-1, -1)
	return cell


func set_input_blocked(value: bool) -> void:
	input_blocked = value
	if value:
		cancel_drag()
		_set_hover(Vector2i(-1, -1))
	else:
		_last_point = get_local_mouse_position()
		_pointer_inside = Rect2(Vector2.ZERO, size).has_point(_last_point)
		_refresh_hover()


func cancel_drag() -> void:
	_dragging = false


func suspend_pointer() -> void:
	# A full-window canvas does not geometrically exit when a toolbar covers it.
	_pointer_inside = false
	cancel_drag()
	_set_hover(Vector2i(-1, -1))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_drag()


func _gui_input(event: InputEvent) -> void:
	if state == null or input_blocked:
		return
	if get_viewport().gui_get_hovered_control() != self:
		suspend_pointer()
		return
	if event is InputEventMouseMotion:
		_last_point = event.position
		_pointer_inside = Rect2(Vector2.ZERO, size).has_point(_last_point)
		if _dragging:
			if not InputManager.pressed(&"editor_pan"):
				cancel_drag()
			else:
				_set_view(state.view_center - event.relative / view_scale, state.zoom)
		_refresh_hover()
	elif event is InputEventMouseButton:
		_last_point = event.position
		if event.is_action(&"editor_pan"):
			_dragging = event.pressed
		elif event.pressed and event.is_action(&"editor_zoom_in"):
			_zoom_at(_last_point, state.zoom * 1.25)
		elif event.pressed and event.is_action(&"editor_zoom_out"):
			_zoom_at(_last_point, state.zoom / 1.25)
		# All canvas clicks are consumed. This iteration never edits a document.
		accept_event()


func _zoom_at(point: Vector2, value: float) -> void:
	var new_zoom: float = clampf(value, EditorState.MIN_ZOOM, EditorState.MAX_ZOOM)
	var anchor: Vector2 = screen_to_world(point)
	var new_scale: float = view_scale * new_zoom / state.zoom
	_set_view(anchor - (point - size * 0.5) / new_scale, new_zoom)


func pan_horizontal(center_x: float, from_view_control: bool = false) -> void:
	if input_blocked and not from_view_control:
		return
	_set_view(Vector2(center_x, state.view_center.y), state.zoom)


func _set_view(center: Vector2, value: float) -> void:
	var bounded_zoom: float = clampf(value, EditorState.MIN_ZOOM, EditorState.MAX_ZOOM)
	var new_scale: float = view_scale * bounded_zoom / state.zoom
	var half_view: Vector2 = size * 0.5 / new_scale
	var area_pixels: Vector2 = Vector2(EditorState.AREA_SIZE) * EditorState.CELL_SIZE
	var bounded: Vector2 = center
	for axis_index: int in 2:
		if half_view[axis_index] * 2 >= area_pixels[axis_index]:
			bounded[axis_index] = area_pixels[axis_index] * 0.5
		else:
			bounded[axis_index] = clampf(center[axis_index], half_view[axis_index], area_pixels[axis_index] - half_view[axis_index])
	state.set_view(bounded, bounded_zoom)


func _apply_view() -> void:
	camera.position = state.view_center
	camera.zoom = Vector2.ONE * view_scale
	camera.force_update_scroll()
	world.visible_world = Rect2(screen_to_world(Vector2.ZERO), size / view_scale)
	_refresh_hover()
	world.queue_redraw()


func _on_resized() -> void:
	if state != null:
		_set_view(state.view_center, state.zoom)
		_apply_view()


func _on_state_changed() -> void:
	_refresh_hover()
	world.queue_redraw()


func _on_mouse_entered() -> void:
	_pointer_inside = true
	_last_point = get_local_mouse_position()
	_refresh_hover()


func _on_mouse_exited() -> void:
	_pointer_inside = false
	cancel_drag()
	_set_hover(Vector2i(-1, -1))


func _refresh_hover() -> void:
	var uncovered: bool = get_viewport().gui_get_hovered_control() == self
	_set_hover(cell_at(_last_point) if _pointer_inside and not input_blocked and uncovered else Vector2i(-1, -1))


func _set_hover(cell: Vector2i) -> void:
	if world.hovered_cell != cell:
		world.hovered_cell = cell
		hovered_cell_changed.emit(cell)
		world.queue_redraw()
