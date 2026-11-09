# SPDX-License-Identifier: AGPL-3.0-or-later
class_name LiftPart
extends Part
## Editor lift (source obj_platform_res / obj_platform_blue_res). The Part
## window picks a moving lift's first direction, or the falling (blue) lift.
## Width is the source default of 4 cells; loaded rows keep their own width.
## Saved in PLATAFORMAS; builds a [Lift].

const KINDS = [&"down", &"right", &"up", &"left", &"falling"]

var kind := Lift.Kind.RIGHT
var width := 4


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_gizmos.tres")


static func get_part_name(_environment: SubArea) -> String:
	return "Lift"


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return icon_for(Lift.Kind.RIGHT)


static func texture_for(lift_kind: int, cells: int) -> Texture2D:
	var frames := SpriteLibrary.get_frames(&"spr_platform_blue" if lift_kind == Lift.Kind.FALLING else &"spr_platform")
	var image := Image.create(cells * 16, 16, false, Image.FORMAT_RGBA8)
	for cell in cells:
		var piece := frames.get_frame_texture(&"default", 0 if cell == 0 else 2 if cell == cells - 1 else 1).get_image()
		piece.convert(Image.FORMAT_RGBA8)
		image.blit_rect(piece, Rect2i(0, 0, 16, 16), Vector2i(cell * 16, 0))
	return ImageTexture.create_from_image(image)


## The lift with a small arrow for its first direction (none when falling).
static func icon_for(lift_kind: int) -> Texture2D:
	var icon := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	if SpriteLibrary.has_sprite(&"spr_platform"):
		var lift := texture_for(lift_kind, 3).get_image()
		lift.resize(48, 16, Image.INTERPOLATE_NEAREST)
		icon.blit_rect(lift, Rect2i(0, 0, 48, 16), Vector2i(6, 36))
		if lift_kind != Lift.Kind.FALLING:
			var axis: Vector2 = [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT][lift_kind]
			var center := Vector2(30, 18)
			for step in 9:
				var at := center + axis * (step - 4) * 2
				icon.fill_rect(Rect2i(Vector2i(at) - Vector2i(2, 2), Vector2i(4, 4)), Color(0.23, 0.23, 0.23))
			var tip := center + axis * 10
			var side := Vector2(axis.y, -axis.x)
			for back in 6:
				for spread in range(-back, back + 1):
					var at := tip - axis * back + side * spread
					icon.set_pixelv(Vector2i(at), Color(0.23, 0.23, 0.23))
	return ImageTexture.create_from_image(icon)


static func is_placeable(grid_pos: Vector2i, world: World2D) -> bool:
	return _check_rect(Rect2i(grid_pos, Vector2i(4, 1)), world)


static func create() -> LiftPart:
	return load("res://scenes/level/parts/lift_part.tscn").instantiate()


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
	$Graphics.position = Vector2.ZERO
	$Graphics/Sprite.centered = false
	$Graphics/Sprite.texture = texture_for(kind, width)
	$CollShape.shape.size = Vector2(width * 16 - 2, 14)
	$CollShape.position = Vector2(width * 8, 8)
	queue_redraw()


func get_variants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in KINDS.size():
		result.append({"id": KINDS[i], "label": "", "icon": icon_for(i)})
	return result


func get_variant() -> StringName:
	return KINDS[kind]


func set_variant(id: StringName) -> void:
	if id in KINDS:
		kind = KINDS.find(id) as Lift.Kind
		refresh_environment()


func _draw_highlight(at: Vector2, color: Color) -> void:
	draw_rect(Rect2(at, Vector2(width * 16, 16)), color)


## Source rows: obj_platform_res with direct_t, or obj_platform_blue_res;
## x_pos/y_pos is the top-left and width size_x.
func read_platform(entry: Dictionary, id: String) -> void:
	position = Level.snap(Vector2(float(entry.get("x_pos", 0)), float(entry.get("y_pos", 432)) - 432))
	var cells: Variant = entry.get("width", 4)
	width = clampi(int(cells), 1, 20) if (cells is int or cells is float) else 4
	kind = Lift.Kind.FALLING if id == "obj_platform_blue_res" else clampi(int(entry.get("direct_t", 1)), 0, 3) as Lift.Kind


func write_platform(entry: Dictionary) -> void:
	entry.object = "obj_platform_blue_res" if kind == Lift.Kind.FALLING else "obj_platform_res"
	entry.x_pos = position.x
	entry.y_pos = position.y + 432
	entry.width = width
	entry.height = 1
	entry.direct_t = 0 if kind == Lift.Kind.FALLING else int(kind)
	entry.sprite = "spr_platform_blue" if kind == Lift.Kind.FALLING else "spr_platform"


func build() -> void:
	var lift := Lift.new()
	lift.setup(sub_area, kind, width)
	lift.position = position
	sub_area.add(lift)
