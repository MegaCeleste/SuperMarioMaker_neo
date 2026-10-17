class_name EditorState
extends RefCounted
## 本次编辑器会话的 UI 状态；不拥有、也不修改 LevelManager.level_data。

signal changed
signal view_changed

enum Tool { DRAW, ERASE, SELECT }
enum PanelKind { NONE, PALETTE, SETTINGS, MENU, COURSEBOT }

const CELL_SIZE: int = 16
const AREA_SIZE: Vector2i = Vector2i(240, 27)
const MIN_ZOOM: float = 1.0
const MAX_ZOOM: float = 4.0

var tool: Tool = Tool.DRAW
var object_id: String = "smm.terrain.ground"
var panel: PanelKind = PanelKind.NONE
var grid_visible: bool = true
var view_center: Vector2 = Vector2(200, 320)
var zoom: float = 2.0


func select_tool(value: Tool) -> void:
	if tool == value:
		return
	tool = value
	changed.emit()


func select_object(value: String) -> void:
	object_id = value
	tool = Tool.DRAW
	panel = PanelKind.NONE
	changed.emit()


func toggle_panel(value: PanelKind) -> void:
	panel = PanelKind.NONE if panel == value else value
	changed.emit()


func close_panel() -> void:
	if panel == PanelKind.NONE:
		return
	panel = PanelKind.NONE
	changed.emit()


func set_grid_visible(value: bool) -> void:
	if grid_visible == value:
		return
	grid_visible = value
	changed.emit()


func set_view(center: Vector2, scale_value: float) -> void:
	var bounded_zoom: float = clampf(scale_value, MIN_ZOOM, MAX_ZOOM)
	if view_center.is_equal_approx(center) and is_equal_approx(zoom, bounded_zoom):
		return
	view_center = center
	zoom = bounded_zoom
	view_changed.emit()
