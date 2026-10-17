class_name PaletteWheel
extends Control
## Ten reference slots. Visible art is separate from selectable Registry objects.

signal object_chosen(object_id: String)
signal page_changed

const SLOT_COUNT: int = 10
const START_ANGLE: float = -PI / 2.0
const STEP: float = TAU / SLOT_COUNT
const CATEGORY_COLORS: Dictionary = {
	"terrain": Color("10c9df"), "item": Color("cf47de"),
	"enemy": Color("6bfa12"), "gizmo": Color("f5e800"),
}

var catalog: EditorCatalog
var entries: Array[Dictionary] = []
var category: String = "terrain"
var selected_id: String = "smm.terrain.ground"
var hovered_slot: int = -1
var page: int = 0
var _all_entries: Array[Dictionary] = []
var _tile: Texture2D = EditorCatalog.load_optional("res://textures/ui/editor/palette/item.svg")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	mouse_exited.connect(func() -> void: _set_hover(-1))


func configure(source: EditorCatalog, category_value: String, current_id: String) -> void:
	catalog = source
	category = category_value
	selected_id = current_id
	_all_entries = catalog.palette_entries(category)
	page = 0
	for index: int in _all_entries.size():
		if _all_entries[index].get("id", "") == selected_id:
			page = int(index / float(SLOT_COUNT))
	_refresh_page()


func page_count() -> int:
	return maxi(1, ceili(_all_entries.size() / float(SLOT_COUNT)))


func turn_page(direction: int) -> void:
	page = posmod(page + direction, page_count())
	_refresh_page()


func _refresh_page() -> void:
	entries.assign(_all_entries.slice(page * SLOT_COUNT, (page + 1) * SLOT_COUNT))
	_set_hover(-1)
	page_changed.emit()


func slot_at(point: Vector2) -> int:
	var delta: Vector2 = point - size * 0.5
	if delta.length() < _radius() * 0.40 or delta.length() >= _radius():
		return -1
	var slot: int = int(floorf(fposmod(delta.angle() - START_ANGLE + STEP * 0.5, TAU) / STEP))
	return slot if slot < entries.size() else -1


func slot_center(slot: int) -> Vector2:
	return size * 0.5 + Vector2.from_angle(START_ANGLE + slot * STEP) * _radius() * 0.80


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover(slot_at(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var slot: int = slot_at(event.position)
		if event.pressed and slot >= 0:
			var object_id: String = String(entries[slot].get("id", ""))
			if not object_id.is_empty() and Registry.has_object(object_id):
				object_chosen.emit(object_id)
		accept_event()


func _set_hover(slot: int) -> void:
	hovered_slot = slot
	queue_redraw()


func _radius() -> float:
	return minf(size.x, size.y) * 0.5


func _draw_sector(center: Vector2, radius: float, slot: int, color: Color) -> void:
	var start: float = START_ANGLE + (slot - 0.5) * STEP
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in 65:
		points.append(center + Vector2.from_angle(start + STEP * index / 64.0) * radius)
	for index: int in range(64, -1, -1):
		points.append(center + Vector2.from_angle(start + STEP * index / 64.0) * radius * 0.40)
	draw_colored_polygon(points, color)


func _draw_tile(center: Vector2, extent: float, texture: Texture2D) -> void:
	var rect: Rect2 = Rect2(center - Vector2.ONE * extent * 0.5, Vector2.ONE * extent)
	if _tile != null:
		draw_texture_rect(_tile, rect, false)
	if texture != null:
		var art_size: Vector2 = texture.get_size() * (extent * 0.90 / maxf(texture.get_width(), texture.get_height()))
		draw_texture_rect(texture, Rect2(center - art_size * 0.5, art_size), false)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = _radius()
	var category_color: Color = CATEGORY_COLORS.get(category, Color("cf47de"))
	draw_circle(center + Vector2(0, 10), radius, Color(0, 0, 0, 0.20), true, -1, true)
	draw_circle(center, radius, category_color.lerp(Color.WHITE, 0.78), true, -1, true)
	for slot: int in SLOT_COUNT:
		if hovered_slot == slot or hovered_slot == (slot + 1) % SLOT_COUNT:
			continue
		var direction: Vector2 = Vector2.from_angle(START_ANGLE + (slot + 0.5) * STEP)
		var distance: float = radius * 0.40
		while distance < radius:
			draw_line(center + direction * distance, center + direction * minf(distance + 20, radius), category_color.lerp(Color.WHITE, 0.45), 5.0)
			distance += 35
	if hovered_slot >= 0:
		_draw_sector(center, radius, hovered_slot, category_color)
	for slot: int in entries.size():
		if catalog != null:
			var icon: Texture2D = catalog.palette_icon(entries[slot])
			_draw_tile(slot_center(slot), radius * 0.324, icon)
	draw_circle(center, radius * 0.40, category_color, true, -1, true)
	if catalog != null:
		_draw_tile(center, radius * 0.40, catalog.icon_for(selected_id))
