# SPDX-License-Identifier: AGPL-3.0-or-later
class_name DoorPart
extends Part
## SMW door (source obj_door_res). Doors come in pairs inside one world:
## entering either door brings Mario out of the other. Placing a door adds its
## partner two cells to the right; both move freely and are erased together.
## One source record holds the pair (x_pos/y_pos and door_x/door_y).

## The other door of this pair; set for both doors.
var partner: DoorPart
## The door whose source record stores the pair. Its partner is written as
## the record's door_x/door_y.
var primary := true
## The runtime door built for play; the partner's entry hands Mario to it.
var runtime: WarpDoor


static func create() -> DoorPart:
	return load("res://scenes/level/parts/door_part.tscn").instantiate()


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_gizmos.tres")


static func get_part_name(_area: SubArea) -> String:
	return "Door"


## A new door needs room for itself and for its partner two cells away.
static func is_placeable(grid_pos: Vector2i, world: World2D) -> bool:
	return _check_rect(Rect2i(grid_pos, Vector2i(1, 2)), world) \
			and _check_rect(Rect2i(grid_pos + Vector2i(2, 0), Vector2i(1, 2)), world)


static func get_part_icon(_area: SubArea) -> Texture2D:
	var icon := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	if SpriteLibrary.has_sprite(&"spr_door"):
		var image := SpriteLibrary.get_frames(&"spr_door").get_frame_texture(&"default", 0).get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(24, 48, Image.INTERPOLATE_NEAREST)
		icon.blit_rect(image, Rect2i(0, 0, 24, 48), Vector2i(18, 6))
	return ImageTexture.create_from_image(icon)


func _ready() -> void:
	super()
	$CollShape.shape = $CollShape.shape.duplicate()
	$CollShape.shape.size = Vector2(14, 30)


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_door").get_frame_texture(&"default", 0)
	if placed_from_editor and partner == null:
		_add_partner()


func _add_partner() -> void:
	var other := DoorPart.create()
	other.position = position + Vector2(32, 0)
	other.primary = false
	partner = other
	other.partner = self
	sub_area.add_part(other)
	other.load()
	other._anim_place()
	level.editor.history.record_place(other)


## The partner while both doors are in the course; erasing restores together.
func get_exit() -> DoorPart:
	if is_instance_valid(partner) and partner.partner == self and _placed(partner) and _placed(self):
		return partner
	return null


# Whether a door is in its area's Parts, i.e. not erased (undo keeps it aside).
static func _placed(door: DoorPart) -> bool:
	return door.sub_area != null and door.get_parent() == door.sub_area.get_parts()


## Small number badge shared by both doors of a pair.
func pair_number() -> int:
	var number := 0
	for part in get_parent().get_children():
		if part is DoorPart and part.primary:
			number += 1
			if part == (self if primary else partner):
				return number
	return number


func _draw() -> void:
	super()
	if level != null and level.status == Level.Status.EDITING and not held and get_exit() != null:
		var font := ThemeDB.fallback_font
		draw_circle(Vector2(8, -5), 6, Color(1, 1, 1, 0.9))
		draw_string(font, Vector2(4, -1), str(pair_number()), HORIZONTAL_ALIGNMENT_CENTER, 8, 9, Color.BLACK)


func _process(delta: float) -> void:
	super(delta)
	if level != null and level.status == Level.Status.EDITING:
		queue_redraw()


func _draw_highlight(at: Vector2, color: Color) -> void:
	draw_rect(Rect2(at, Vector2(16, 32)), color)


func _check_validity() -> void:
	_grid_pos = Level.to_grid(global_position + Vector2(8, 8))
	var query := PhysicsShapeQueryParameters2D.new()
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 1 << 8
	query.exclude = [get_rid()]
	query.transform.origin = Level.from_grid(_grid_pos) + Vector2(8, 16)
	query.shape = RectangleShape2D.new()
	query.shape.size = Vector2(14, 30)
	var at := Level.from_grid(_grid_pos)
	_valid_space = at.x >= 0 and at.y >= -Level.LEVEL_HEIGHT * Level.GRID_SIZE.y and at.y + 32 <= 0 \
			and at.x + 16 <= level.width \
			and get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func build() -> void:
	runtime = WarpDoor.new()
	runtime.part = self
	runtime.position = position
	sub_area.add(runtime)
