# SPDX-License-Identifier: AGPL-3.0-or-later
class_name DoorPart
extends Part
## SMW door (source obj_door_res). Doors come in pairs inside one world:
## entering either door brings Mario out of the other. A door stands on the
## clicked cell and its partner is placed right beside it; both move freely and
## are erased together. An area holds at most [constant MAX_DOORS] doors.
## One source record holds the pair (x_pos/y_pos and door_x/door_y).

## Most doors one area may hold; each placement adds a pair. Source limit:
## four pairs, one per spr_door_symbols frame (door_symbol_1..4).
const MAX_DOORS := 8

## The other door of this pair; set for both doors.
var partner: DoorPart
## The door whose source record stores the pair. Its partner is written as
## the record's door_x/door_y.
var primary := true
## Editor symbol index of the pair, kept on the primary door; see [method get_symbol].
var symbol := -1
## The runtime door built for play; the partner's entry hands Mario to it.
var runtime: WarpDoor
var _symbol_sprite: Sprite2D


static func create() -> DoorPart:
	return load("res://scenes/level/parts/door_part.tscn").instantiate()


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_gizmos.tres")


static func get_part_name(_area: SubArea) -> String:
	return "Door"


## A new pair needs a free 2x2 block: the clicked cell and the cell above it,
## for this door and its partner beside it.
static func is_placeable(grid_pos: Vector2i, world: World2D) -> bool:
	var top = grid_pos - Vector2i(0, 1)
	return _check_rect(Rect2i(top, Vector2i(2, 2)), world)


## Whether another pair still fits under [constant MAX_DOORS]. Erased doors
## leave the Parts node, so erasing or undoing frees the slots again.
static func can_place_more(area: SubArea) -> bool:
	var count := 0
	for part in area.get_parts().get_children():
		if part is DoorPart:
			count += 1
	return count + 2 <= MAX_DOORS


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
	_symbol_sprite = Sprite2D.new()
	_symbol_sprite.name = "DoorSymbol"  # PixelShadows skips editor aids by name.
	_symbol_sprite.visible = false
	$Graphics.add_child(_symbol_sprite)


func load(placed_from_editor := false) -> void:
	if placed_from_editor and partner == null:
		position.y -= Level.GRID_SIZE.y
	super(placed_from_editor)
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_door").get_frame_texture(&"default", 0)
	if placed_from_editor and partner == null:
		symbol = _free_symbol()
		_add_partner()


func _add_partner() -> void:
	var other := DoorPart.create()
	other.position = position + Vector2(16, 0)
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


## The pair's editor symbol, a spr_door_symbols frame shared by both doors.
## Source door_symbol_1..4: a pair takes the first symbol free when it is
## placed and keeps it; loaded pairs take theirs in order when first drawn.
func get_symbol() -> int:
	var keeper := self if primary or get_exit() == null else partner
	if keeper.symbol < 0:
		keeper.symbol = keeper._free_symbol()
	return keeper.symbol


func _free_symbol() -> int:
	var used: Array[int] = []
	for part in get_parent().get_children():
		if part is DoorPart and part != self and part.primary and part.symbol >= 0:
			used.append(part.symbol)
	for candidate in SpriteLibrary.get_frames(&"spr_door_symbols").get_frame_count(&"default"):
		if candidate not in used:
			return candidate
	return 0


func _process(delta: float) -> void:
	super(delta)
	# Source obj_door_res Draw: the symbol overlay shares the door's 16x32 frame,
	# so its art sits in the lower-right corner. It lives in Graphics, above the
	# door sprite (a Part's own drawing is below it), and moves with a held door.
	var paired := level != null and level.status == Level.Status.EDITING and get_exit() != null
	_symbol_sprite.visible = paired
	if paired:
		_symbol_sprite.texture = SpriteLibrary.get_frames(&"spr_door_symbols") \
				.get_frame_texture(&"default", get_symbol())


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
