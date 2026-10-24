# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SemisolidPart
extends Part
## Source obj_semisolid_platform1: overlapping scenery, one-way top, fixed
## bottom-left during right/top resizing, three theme-specific appearances.

## Effective source width/height limits, in cells, before room-bound clipping.
const MAX_SIZE := Vector2i(21, 27)
## Stable appearance identifiers used by the native window, palette card and history.
const VARIANTS = [&"first", &"second", &"third"]

static var _textures: Dictionary = {}

## Authored width/height in 16px cells; both axes have a minimum of three cells.
var dimensions := Vector2i(3, 3)
## Zero-based appearance index within [constant VARIANTS].
var appearance := 0
## Whether a top-right drag currently owns the editor's held-part slot.
var resizing := false
var _resize_before: Dictionary
var _bottom := 0.0
var _handle: AnimatedSprite2D
var _ordered_y := INF


## Instantiates the native editor scene; the area supplies context when inserting it.
static func create() -> SemisolidPart:
	return load("res://scenes/parts/semisolid_part.tscn").instantiate()


## Returns the palette/search name shared by the three appearances.
static func get_part_name(_area: SubArea) -> String:
	return "Semisolid Platform"


## Allows overlapping decorations; the editor separately checks initial room bounds.
static func is_placeable(_grid_pos: Vector2i, _world: World2D) -> bool:
	return true  # Source resource collision event intentionally exits.


## Resolves the original twelve-frame atlas for an area's theme and appearance 0..2.
static func sprite_name(area: SubArea, style: int) -> StringName:
	var theme: String = SMWTheme.info(area.level_theme).get("key", "overworld")
	return StringName("spr_ssp%d_%s" % [style + 1, theme])


## Returns the default appearance icon, with a native fallback before sprite readiness.
static func get_part_icon(area: SubArea) -> Texture2D:
	return icon_for(area, 0)


## Draws a 3x3 panel on the palette's 60px canvas for appearance 0..2.
static func icon_for(area: SubArea, style: int) -> Texture2D:
	if not SpriteLibrary.has_sprite(sprite_name(area, style)):
		return preload("uid://dgm5dxxcvt7rq")
	var image := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	image.blit_rect(
		texture_for(area, style, Vector2i(3, 3)).get_image(), Rect2i(0, 0, 48, 48), Vector2i(6, 6)
	)
	return ImageTexture.create_from_image(image)


## Maps a cell inside size to its source frame, retaining even-width row parity.
static func frame_at(cell: Vector2i, size: Vector2i) -> int:
	var column := 0 if cell.x == 0 else 2 if cell.x == size.x - 1 else 1
	if cell.y == 0:
		return column
	if cell.y == size.y - 1:
		return 9 + column
	# Source toggles after EVERY tile and again after each row, including
	# top/bottom tiles; even-width panels therefore change row parity.
	return 3 + column + 3 * posmod(cell.y * (size.x + 1) + cell.x, 2)


## Composes exact source tiles for a valid appearance/size; caches at most 64 textures.
static func texture_for(area: SubArea, style: int, size: Vector2i) -> Texture2D:
	var name := sprite_name(area, style)
	var key := "%s:%s" % [name, size]
	if not _textures.has(key):
		var source := SpriteLibrary.get_frames(name)
		var cells: Array[Image] = []
		for i in 12:
			cells.append(source.get_frame_texture(&"default", i).get_image())
		var image := Image.create(size.x * 16, size.y * 16, false, Image.FORMAT_RGBA8)
		for y in size.y:
			for x in size.x:
				image.blit_rect(
					cells[frame_at(Vector2i(x, y), size)], Rect2i(0, 0, 16, 16), Vector2i(x, y) * 16
				)
		if _textures.size() >= 64:
			_textures.erase(_textures.keys()[0])
		_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]


func _ready() -> void:
	super()
	collision_layer = 16  # Pickable, but never ordinary one-cell occupancy.
	$CollShape.shape = $CollShape.shape.duplicate()
	_handle = AnimatedSprite2D.new()
	_handle.name = "GrabberSprite"  # Existing PixelShadows excludes editor aids.
	_handle.centered = false
	_handle.sprite_frames = SpriteLibrary.get_animations(
		{"default": ["spr_move_semisolid", 3.6, true]}
	)
	_handle.offset = -SpriteLibrary.get_origin(&"spr_move_semisolid")
	_handle.z_as_relative = false
	_handle.z_index = GameConstants.Layers.Z_HELD_GRAPHICS
	add_child(_handle)
	refresh_environment()


## Applies ordinary placement state, then refreshes the panel's derived art and bounds.
func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	refresh_environment()


## Rebuilds theme art, editor pick bounds and the handle without altering authored cells.
func refresh_environment() -> void:
	if not is_node_ready():
		return
	$Graphics.position = Vector2.ZERO
	$Graphics.z_index = 0
	z_index = -1
	_queue_sort(get_parent())
	_ordered_y = position.y
	$Graphics/Sprite.texture = texture_for(sub_area, appearance, dimensions)
	$CollShape.shape.size = Vector2(dimensions * 16)
	$CollShape.position = Vector2(dimensions * 8)
	_handle.position = Vector2((dimensions.x - 1) * 16, 0)
	queue_redraw()


## Supplies the three stable IDs and theme-specific icons to the existing type window.
func get_variants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in 3:
		result.append({"id": VARIANTS[i], "label": "", "icon": icon_for(sub_area, i)})
	return result


## Returns the current appearance ID for palette memory and history.
func get_variant() -> StringName:
	return VARIANTS[appearance]


## Selects a known appearance and refreshes art; an unknown ID leaves state unchanged.
func set_variant(id: StringName) -> void:
	if id in VARIANTS:
		appearance = VARIANTS.find(id)
		refresh_environment()


## Captures appearance, size and position together for atomic undo/redo.
func get_variant_state() -> Dictionary:
	return {"id": get_variant(), "dimensions": dimensions, "position": position}


## Restores a snapshot from [method get_variant_state] and clamps its dimensions.
func restore_variant_state(state: Dictionary) -> void:
	appearance = maxi(0, VARIANTS.find(state.id))
	dimensions = Vector2i(state.dimensions).clamp(Vector2i(3, 3), MAX_SIZE)
	position = state.position
	_grid_pos = Level.to_grid(position)
	refresh_environment()


## Checks the whole panel against playable room bounds at an area-local top-left point.
func fits_bounds(at: Vector2) -> bool:
	return (
		at.x >= 0
		and at.y >= -432
		and at.x + dimensions.x * 16 <= level.width
		and at.y + dimensions.y * 16 <= 0
	)


func _check_validity() -> void:
	_grid_pos = Level.to_grid(global_position + Vector2(8, 8))
	_valid_space = fits_bounds(Level.from_grid(_grid_pos))


func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and is_instance_valid(level)
		and is_instance_valid(level.editor)
		and level.editor.part_interact
		and level.editor.erasing == Editor.EraseMode.NONE
	):
		if Rect2(Vector2((dimensions.x - 1) * 16, 0), Vector2(16, 16)).has_point(
			get_local_mouse_position()
		):
			begin_resize()
			return
		if foreground_at(get_global_mouse_position()) != null:
			return  # A background decoration must not steal another Part's drag.
	super(viewport, event, shape_idx)


## Finds a foreground Part at a world-space point, preserving slope picking priority.
func foreground_at(at: Vector2) -> Part:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = at
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1 << 8
	var found: Part
	for hit in get_world_2d().direct_space_state.intersect_point(query, 16):
		if hit.collider is SlopePart:
			return hit.collider  # Preserve the existing ramp-over-ground priority.
		if hit.collider is Part:
			found = hit.collider
	return found


func _mouse_update(state: bool) -> void:
	super(state)
	if state and is_instance_valid(level) and is_instance_valid(level.editor):
		var front := foreground_at(get_global_mouse_position())
		if front != null:
			level.editor.hovered_part = front


## Starts one editor gesture, retaining the lower-left anchor and a history snapshot.
func begin_resize() -> void:
	if held or resizing or level.editor.held_part != null:
		return
	resizing = true
	_resize_before = get_variant_state()
	_bottom = position.y + dimensions.y * 16
	level.editor.held_part = self
	level.editor.part_interact = false
	Cursor.down = true


## Moves the top/right edges toward an area-local mouse point within size/room limits.
func resize_to(mouse: Vector2) -> void:
	var top := clampf(
		floorf(mouse.y / 16) * 16, maxf(-432, _bottom - MAX_SIZE.y * 16), _bottom - 48
	)
	var width := clampi(floori((mouse.x - position.x) / 16) + 1, 3, MAX_SIZE.x)
	width = mini(width, floori((level.width - position.x) / 16))
	dimensions = Vector2i(width, roundi((_bottom - top) / 16))
	position.y = top
	_grid_pos = Level.to_grid(position)
	refresh_environment()


## Releases editor ownership and records the whole completed gesture as one action.
func end_resize() -> void:
	if not resizing:
		return
	resizing = false
	level.editor.held_part = null
	level.editor.part_interact = true
	level.editor.history.record_geometry(self, _resize_before, get_variant_state())
	Cursor.down = false


func _process(delta: float) -> void:
	super(delta)
	if resizing:
		resize_to(get_global_mouse_position())
	_handle.visible = (
		level.status == Level.Status.EDITING
		and not held
		and (_mouse_in or resizing)
		and level.editor.erasing == Editor.EraseMode.NONE
	)
	if resizing:
		_handle.play()
	else:
		_handle.pause()
		_handle.frame = 0
	if not held and not resizing:
		$Graphics.z_index = 0
		z_index = -1
		if _ordered_y != position.y:
			_queue_sort(get_parent())
			_ordered_y = position.y


func _input(event: InputEvent) -> void:
	if (
		resizing
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		end_resize()
		return
	super(event)


func _draw_highlight(at: Vector2, color: Color) -> void:
	draw_rect(Rect2(at, Vector2(dimensions * 16)), color)


## Builds one area-owned decorative body with a 5px one-way top, leaving sides passable.
func build() -> void:
	var body := StaticBodyExt.new()
	body.name = "SemisolidPlatform"
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	body.z_index = 0
	body.set_meta(&"semisolid", true)
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(dimensions.x * 16, 5)
	shape.position = Vector2(dimensions.x * 8, 2.5)
	shape.one_way_collision = true
	shape.one_way_collision_margin = 0.5
	body.add_child(shape)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture_for(sub_area, appearance, dimensions)
	body.add_child(sprite)
	sub_area.add(body)
	_queue_sort(body.get_parent())


static func _queue_sort(parent: Node) -> void:
	if parent.get_meta(&"semisolid_sort_pending", false):
		return
	parent.set_meta(&"semisolid_sort_pending", true)
	_sort_layer.call_deferred(parent)


## Preserve exact source top-y ordering inside the existing gap between
## shadows(-1) and terrain(20), without quantizing 27 rows into a few z slots.
static func _sort_layer(parent: Node) -> void:
	if not is_instance_valid(parent):
		return
	parent.remove_meta(&"semisolid_sort_pending")
	var panels: Array[Node2D] = []
	for child in parent.get_children():
		if child is SemisolidPart or child.has_meta(&"semisolid"):
			panels.append(child)
	panels.sort_custom(
		func(a: Node2D, b: Node2D):
			return (
				a.position.y < b.position.y
				if a.position.y != b.position.y
				else a.get_index() < b.get_index()
			)
	)
	for index in panels.size():
		parent.move_child(panels[index], index)
