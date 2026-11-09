# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BillBlasterPart
extends Part
## Editor Bill Blaster (source obj_bullebill_base_res): a 1-cell-wide column,
## 2 to 5 cells tall, chosen in the Part window. Saved in PLATAFORMAS with
## its height (source size_y); builds a [BillBlaster].

const HEIGHTS = [&"two", &"three", &"four", &"five"]

var height := 2


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_gizmos.tres")


static func get_part_name(_environment: SubArea) -> String:
	return "Bill Blaster"


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return icon_for(2)


static func icon_for(cells: int) -> Texture2D:
	var icon := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	if SpriteLibrary.has_sprite(&"spr_bullebill_base"):
		var column := texture_for(cells).get_image()
		var scale := 3 if cells <= 3 else 2
		column.resize(16 * scale, mini(cells * 16 * scale, 48), Image.INTERPOLATE_NEAREST)
		icon.blit_rect(column, Rect2i(Vector2i.ZERO, column.get_size()), Vector2i((60 - column.get_width()) / 2, 6))
	return ImageTexture.create_from_image(icon)


static func texture_for(cells: int) -> Texture2D:
	var frames := SpriteLibrary.get_frames(&"spr_bullebill_base")
	var image := Image.create(16, cells * 16, false, Image.FORMAT_RGBA8)
	for cell in cells:
		var piece := frames.get_frame_texture(&"default", mini(cell, 2)).get_image()
		piece.convert(Image.FORMAT_RGBA8)
		image.blit_rect(piece, Rect2i(0, 0, 16, 16), Vector2i(0, cell * 16))
	return ImageTexture.create_from_image(image)


static func is_placeable(grid_pos: Vector2i, world: World2D) -> bool:
	return _check_rect(Rect2i(grid_pos, Vector2i(1, 2)), world)


static func create() -> BillBlasterPart:
	return load("res://scenes/level/parts/bill_blaster_part.tscn").instantiate()


func _ready() -> void:
	super()
	$CollShape.shape = $CollShape.shape.duplicate()
	refresh_environment()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	refresh_environment()


func refresh_environment() -> void:
	if not is_node_ready():
		return
	$Graphics/Sprite.texture = texture_for(height)
	$Graphics/Sprite.centered = false
	$Graphics.position = Vector2.ZERO
	$CollShape.shape.size = Vector2(14, height * 16 - 2)
	$CollShape.position = Vector2(8, height * 8)
	queue_redraw()


func get_variants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in HEIGHTS.size():
		result.append({"id": HEIGHTS[i], "label": "", "icon": icon_for(i + 2)})
	return result


func get_variant() -> StringName:
	return HEIGHTS[clampi(height - 2, 0, HEIGHTS.size() - 1)]


func set_variant(id: StringName) -> void:
	if id in HEIGHTS:
		height = HEIGHTS.find(id) + 2
		refresh_environment()


## Source PLATAFORMAS row: x_pos/y_pos is the head's top-left, height size_y.
func read_platform(entry: Dictionary, _id: String) -> void:
	position = Level.snap(Vector2(float(entry.get("x_pos", 0)), float(entry.get("y_pos", 432)) - 432))
	var cells: Variant = entry.get("height", 2)
	height = clampi(int(cells), 2, 18) if (cells is int or cells is float) else 2


func write_platform(entry: Dictionary) -> void:
	entry.object = "obj_bullebill_base_res"
	entry.x_pos = position.x
	entry.y_pos = position.y + 432
	entry.width = 1
	entry.height = height
	entry.sprite = "spr_bullebill_base"


func _draw_highlight(at: Vector2, color: Color) -> void:
	draw_rect(Rect2(at, Vector2(16, height * 16)), color)


func build() -> void:
	var blaster := BillBlaster.new()
	blaster.setup(sub_area, height)
	blaster.position = position
	sub_area.add(blaster)
