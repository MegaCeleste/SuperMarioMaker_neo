# SPDX-License-Identifier: AGPL-3.0-or-later
class_name FireBarPart
extends Part
## Editor Fire Bar (source obj_firebar_res): one base cell; the Part window
## chooses 4, 6, 8 or 10 fireballs (source size_x, in steps of 2) and a
## clockwise toggle (source direct_t). Saved in PLATAFORMAS with the start
## angle in color; builds a [FireBar].

const LENGTHS = [&"four", &"six", &"eight", &"ten"]

var length := 4
var clockwise := false
## Source color: the start angle in degrees.
var start_angle := 0.0


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_gizmos.tres")


static func get_part_name(_environment: SubArea) -> String:
	return "Fire Bar"


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return icon_for(4)


static func icon_for(balls: int) -> Texture2D:
	var icon := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	if SpriteLibrary.has_sprite(&"spr_firebar"):
		var base := SpriteLibrary.get_frames(&"spr_firebar_base").get_frame_texture(&"default", 2).get_image()
		var ball := SpriteLibrary.get_frames(&"spr_firebar").get_frame_texture(&"default", 2).get_image()
		base.convert(Image.FORMAT_RGBA8)
		ball.convert(Image.FORMAT_RGBA8)
		var step := 40 / maxi(1, balls - 1)
		icon.blend_rect(base, Rect2i(0, 0, 16, 16), Vector2i(2, 22))
		for i in balls:
			icon.blend_rect(ball, Rect2i(0, 0, 10, 10), Vector2i(5 + i * step, 25))
	return ImageTexture.create_from_image(icon)


static func create() -> FireBarPart:
	return load("res://scenes/level/parts/fire_bar_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_firebar_base").get_frame_texture(&"default", 2)
	queue_redraw()


func _draw() -> void:
	super()
	# Editor preview of the bar at its start angle, like obj_firebar_res Draw.
	if level != null and level.status == Level.Status.EDITING and SpriteLibrary.has_sprite(&"spr_firebar"):
		var ball := SpriteLibrary.get_frames(&"spr_firebar").get_frame_texture(&"default", 2)
		var step := Vector2(cos(deg_to_rad(start_angle)), -sin(deg_to_rad(start_angle))) * 8
		for i in range(1, length):
			draw_texture(ball, Vector2(8, 8) + step * i - Vector2(5, 5), Color(1, 1, 1, 0.7))


func get_variants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in LENGTHS.size():
		result.append({"id": LENGTHS[i], "label": "", "icon": icon_for(4 + i * 2)})
	return result


func get_variant() -> StringName:
	return LENGTHS[clampi(roundi((length - 4) / 2.0), 0, LENGTHS.size() - 1)]


func set_variant(id: StringName) -> void:
	if id in LENGTHS:
		length = 4 + LENGTHS.find(id) * 2
		queue_redraw()


func get_modifiers() -> Array[Dictionary]:
	return [{"id": &"clockwise", "label": "EDITOR_CLOCKWISE", "icon": load("res://textures/ui/editor/btn_clockwise.svg")}]


func has_modifier(id: StringName) -> bool:
	return id == &"clockwise" and clockwise


func set_modifier(id: StringName, enabled: bool) -> void:
	if id == &"clockwise":
		clockwise = enabled


## Source PLATAFORMAS row: x_pos/y_pos is the base centre, width the ball
## count, color the start angle and direct_t 1 for clockwise.
func read_platform(entry: Dictionary, _id: String) -> void:
	position = Level.snap(Vector2(float(entry.get("x_pos", 8)) - 8, float(entry.get("y_pos", 440)) - 432 - 8))
	var balls: Variant = entry.get("width", 4)
	length = clampi(int(balls), 2, 19) if (balls is int or balls is float) else 4
	var angle: Variant = entry.get("color", 0)
	start_angle = float(angle) if (angle is int or angle is float) else 0.0
	clockwise = int(entry.get("direct_t", 0)) == 1


func write_platform(entry: Dictionary) -> void:
	entry.object = "obj_firebar_res"
	entry.x_pos = position.x + 8
	entry.y_pos = position.y + 432 + 8
	entry.width = length
	entry.height = 1
	entry.color = start_angle
	entry.direct_t = int(clockwise)
	entry.sprite = "spr_firebar_editor"


func build() -> void:
	var bar := FireBar.new()
	bar.setup(sub_area, length, clockwise, start_angle)
	bar.position = position + Vector2(8, 8)
	sub_area.add(bar)
