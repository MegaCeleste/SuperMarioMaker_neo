# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BridgePart
extends Part
## Editor bridge (source obj_puente_res): 3, 5, 7 or 9 cells wide, chosen in
## the Part window. The Part's top-left is one cell above the walking surface
## (the source y). Art follows the theme like obj_puente_res Step_2. Saved
## in PLATAFORMAS; builds a [Bridge].

const WIDTHS = [&"three", &"five", &"seven", &"nine"]

var width := 3


static func get_category() -> PaletteCategory:
	return load("uid://wtetnd7c3nmk")


static func get_part_name(_environment: SubArea) -> String:
	return "Bridge"


static func get_part_icon(environment: SubArea) -> Texture2D:
	var icon := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	if SpriteLibrary.has_sprite(&"spr_puente"):
		var art := texture_for(sprite_for(environment), 3).get_image()
		icon.blit_rect(art, Rect2i(0, 0, 48, 32), Vector2i(6, 14))
	return ImageTexture.create_from_image(icon)


## Source obj_puente_res Step_2 for SMW: snow keeps its own set, the darker
## themes and night use the night set.
static func sprite_for(area: SubArea) -> StringName:
	if area == null:
		return &"spr_puente"
	if area.level_theme == Level.LevelTheme.SNOW:
		return &"spr_puente_snow_night" if area.night_mode else &"spr_puente_snow"
	if area.night_mode or area.level_theme in [Level.LevelTheme.UNDERGROUND, Level.LevelTheme.UNDERWATER,
			Level.LevelTheme.MANSION, Level.LevelTheme.AIRSHIP, Level.LevelTheme.CASTLE]:
		return &"spr_puente_night"
	return &"spr_puente"


static func texture_for(sprite: StringName, cells: int) -> Texture2D:
	var frames := SpriteLibrary.get_frames(sprite)
	var image := Image.create(cells * 16, 32, false, Image.FORMAT_RGBA8)
	for cell in cells:
		var piece := frames.get_frame_texture(&"default", 0 if cell == 0 else 2 if cell == cells - 1 else 1).get_image()
		piece.convert(Image.FORMAT_RGBA8)
		image.blit_rect(piece, Rect2i(0, 0, 16, 32), Vector2i(cell * 16, 0))
	return ImageTexture.create_from_image(image)


static func is_placeable(grid_pos: Vector2i, world: World2D) -> bool:
	return _check_rect(Rect2i(grid_pos, Vector2i(3, 2)), world)


static func create() -> BridgePart:
	return load("res://scenes/level/parts/bridge_part.tscn").instantiate()


func _ready() -> void:
	super()
	$CollShape.shape = $CollShape.shape.duplicate()
	refresh_environment()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	refresh_environment()


func refresh_environment() -> void:
	if not is_node_ready() or sub_area == null:
		return
	$Graphics.position = Vector2.ZERO
	$Graphics/Sprite.centered = false
	$Graphics/Sprite.texture = texture_for(sprite_for(sub_area), width)
	$CollShape.shape.size = Vector2(width * 16 - 2, 30)
	$CollShape.position = Vector2(width * 8, 16)
	queue_redraw()


func get_variants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in WIDTHS.size():
		var icon := Image.create(60, 60, false, Image.FORMAT_RGBA8)
		var art := texture_for(sprite_for(sub_area), 3 + i * 2).get_image()
		art.resize(mini(art.get_width(), 56), 32 * mini(art.get_width(), 56) / art.get_width(), Image.INTERPOLATE_NEAREST)
		icon.blit_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i(2, 14))
		result.append({"id": WIDTHS[i], "label": "", "icon": ImageTexture.create_from_image(icon)})
	return result


func get_variant() -> StringName:
	return WIDTHS[clampi(roundi((width - 3) / 2.0), 0, WIDTHS.size() - 1)]


func set_variant(id: StringName) -> void:
	if id in WIDTHS:
		width = 3 + WIDTHS.find(id) * 2
		refresh_environment()


func _draw_highlight(at: Vector2, color: Color) -> void:
	draw_rect(Rect2(at, Vector2(width * 16, 32)), color)


func read_platform(entry: Dictionary, _id: String) -> void:
	position = Level.snap(Vector2(float(entry.get("x_pos", 0)), float(entry.get("y_pos", 448)) - 432 - 16))
	var cells: Variant = entry.get("width", 3)
	width = clampi(int(cells), 1, 20) if (cells is int or cells is float) else 3


func write_platform(entry: Dictionary) -> void:
	entry.object = "obj_puente_res"
	entry.x_pos = position.x
	entry.y_pos = position.y + 16 + 432
	entry.width = width
	entry.height = 1
	entry.sprite = String(sprite_for(sub_area))


func build() -> void:
	var bridge := Bridge.new()
	bridge.setup(width, sprite_for(sub_area))
	bridge.position = position + Vector2(0, 16)
	sub_area.add(bridge)
