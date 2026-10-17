class_name MakerWorld
extends Node2D
## 静态编辑画布：背景、网格和预览，没有 gameplay 实例。

var state: EditorState
var catalog: EditorCatalog
var visible_world: Rect2 = Rect2()
var hovered_cell: Vector2i = Vector2i(-1, -1)
var _backgrounds: Array[Texture2D] = []
const BACKGROUND_PHASE: float = 128.0


func _ready() -> void:
	# CanvasItem inheritance stops at a SubViewport: set pixel sampling here too.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for path: String in ["background"]:
		_backgrounds.append(EditorCatalog.load_optional("res://textures/smw/background/%s.png" % path))


func _draw() -> void:
	if state == null:
		return
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(EditorState.AREA_SIZE) * EditorState.CELL_SIZE)
	draw_rect(bounds, Color("9ce1e2"))
	for texture: Texture2D in _backgrounds:
		if texture == null:
			continue
		var first: int = maxi(0, int(floorf((visible_world.position.x + BACKGROUND_PHASE) / texture.get_width())))
		var last: int = mini(int(ceilf((bounds.size.x + BACKGROUND_PHASE) / texture.get_width())), int(ceilf((visible_world.end.x + BACKGROUND_PHASE) / texture.get_width())))
		for index: int in range(first, last):
			draw_texture(texture, Vector2(index * texture.get_width() - BACKGROUND_PHASE, bounds.size.y - texture.get_height()))
	var visible_bounds: Rect2 = visible_world.intersection(bounds)
	if state.grid_visible and visible_bounds.has_area():
		var start_x: int = int(ceilf(visible_bounds.position.x / EditorState.CELL_SIZE))
		var end_x: int = int(floorf(visible_bounds.end.x / EditorState.CELL_SIZE))
		var start_y: int = int(ceilf(visible_bounds.position.y / EditorState.CELL_SIZE))
		var end_y: int = int(floorf(visible_bounds.end.y / EditorState.CELL_SIZE))
		var grid_color: Color = Color(0.35, 0.52, 0.49, 0.22)
		for x: int in range(start_x, end_x + 1):
			draw_line(Vector2(x * 16, visible_bounds.position.y), Vector2(x * 16, visible_bounds.end.y), grid_color, 1.0)
		for y: int in range(start_y, end_y + 1):
			draw_line(Vector2(visible_bounds.position.x, y * 16), Vector2(visible_bounds.end.x, y * 16), grid_color, 1.0)
	draw_rect(bounds, Color("fff6c1"), false, 2.0 / state.zoom)
	if hovered_cell.x < 0 or catalog == null:
		return
	var cell_rect: Rect2 = Rect2(Vector2(hovered_cell) * EditorState.CELL_SIZE, Vector2.ONE * EditorState.CELL_SIZE)
	var tint: Color = Color("fff1a5")
	if state.tool == EditorState.Tool.ERASE:
		tint = Color("ff6b78")
	elif state.tool == EditorState.Tool.SELECT:
		tint = Color("78e8ff")
	draw_rect(cell_rect, Color(tint, 0.24))
	if state.tool == EditorState.Tool.DRAW:
		var preview: Texture2D = catalog.preview_for(state.object_id)
		if preview != null:
			draw_texture_rect(preview, cell_rect, false, Color(1, 1, 1, 0.65))
	draw_rect(cell_rect, tint, false, 2.0 / state.zoom)
