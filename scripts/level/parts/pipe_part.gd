# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PipePart
extends Part
## SMW pipe (source obj_tuberia_res, obj_tuberia). A solid, 32px-wide obstacle;
## dragging its opening lengthens it, and a head-only pipe turns when the
## opening is dragged sideways. SMMneo rule: a pipe linked to a pipe in the
## other world carries Mario between the main world and the sub-world. An
## unlinked pipe is only an obstacle. Same-world travel is the doors' job.

## Which way the opening faces; the source direct_t values.
enum Facing { UP, RIGHT, DOWN, LEFT }

## Source size limit: body segments after the 32px head.
const MAX_SEGMENTS := 24
## Stable color IDs in source frame order (spr_pipes image_index).
const COLORS = [&"green", &"red", &"blue", &"yellow"]

static var _textures: Dictionary = {}

var facing := Facing.UP
## Source size: 16px body segments after the head.
var segments := 0
var color := 0
## The paired pipe in the other world; see [method get_exit].
var link: PipePart
## Whether an opening drag currently owns the editor's held-part slot.
var resizing := false
## The runtime pipe built for play; the partner's entry hands Mario to it.
var runtime: WarpPipe
var _resize_before: Dictionary


static func create() -> PipePart:
	return load("res://scenes/level/parts/pipe_part.tscn").instantiate()


static func get_part_name(_area: SubArea) -> String:
	return "Pipe"


## Pipes may not overlap other objects; checks the default 2x2 head.
static func is_placeable(grid_pos: Vector2i, world: World2D) -> bool:
	return _check_rect(Rect2i(grid_pos, Vector2i(2, 2)), world)


static func get_part_icon(_area: SubArea) -> Texture2D:
	return icon_for(0)


static func icon_for(color_index: int) -> Texture2D:
	if not SpriteLibrary.has_sprite(&"spr_pipes"):
		return preload("uid://cjuqthhe8eq86")
	var image := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	var head := texture_for(color_index, Facing.UP, 0).get_image()
	head.resize(48, 48, Image.INTERPOLATE_NEAREST)
	image.blit_rect(head, Rect2i(0, 0, 48, 48), Vector2i(6, 6))
	return ImageTexture.create_from_image(image)


## Composes the source head and body frames, then turns them like the source
## draw call: right rotates clockwise, down flips, left also mirrors.
static func texture_for(color_index: int, way: Facing, body: int) -> Texture2D:
	var key := "%d:%d:%d" % [color_index, way, body]
	if not _textures.has(key):
		var head := SpriteLibrary.get_frames(&"spr_pipes").get_frame_texture(&"default", color_index).get_image()
		var piece := SpriteLibrary.get_frames(&"spr_pipes_part").get_frame_texture(&"default", color_index).get_image()
		head.convert(Image.FORMAT_RGBA8)
		piece.convert(Image.FORMAT_RGBA8)
		var image := Image.create(32, 32 + body * 16, false, Image.FORMAT_RGBA8)
		image.blit_rect(head, Rect2i(0, 0, 32, 32), Vector2i.ZERO)
		for i in body:
			image.blit_rect(piece, Rect2i(0, 0, 32, 16), Vector2i(0, 32 + i * 16))
		match way:
			Facing.RIGHT:
				image.rotate_90(CLOCKWISE)
			Facing.DOWN:
				image.flip_y()
			Facing.LEFT:
				image.rotate_90(CLOCKWISE)
				image.flip_x()
		if _textures.size() >= 64:
			_textures.erase(_textures.keys()[0])
		_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]


## Unit vector from the pipe's base toward its opening.
static func axis(way: Facing) -> Vector2:
	return [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][way]


## Size in pixels for a facing and segment count.
static func size_for(way: Facing, body: int) -> Vector2:
	var length := 32 + body * 16
	return Vector2(32, length) if way in [Facing.UP, Facing.DOWN] else Vector2(length, 32)


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
	var size := get_size()
	$Graphics.position = size / 2
	$Graphics/Sprite.texture = texture_for(color, facing, segments)
	$CollShape.shape.size = size - Vector2(2, 2)
	$CollShape.position = size / 2
	queue_redraw()


func get_size() -> Vector2:
	return size_for(facing, segments)


## Area-space rectangle of the opening's last 16px, which Mario passes through.
func mouth_rect() -> Rect2:
	var size := get_size()
	match facing:
		Facing.UP:
			return Rect2(position, Vector2(32, 16))
		Facing.DOWN:
			return Rect2(position + Vector2(0, size.y - 16), Vector2(32, 16))
		Facing.RIGHT:
			return Rect2(position + Vector2(size.x - 16, 0), Vector2(16, 32))
		_:
			return Rect2(position, Vector2(16, 32))


## The partner pipe Mario arrives at, or null when unlinked or the partner was
## removed. Erasing a pipe keeps the reference, so undoing the erase relinks.
func get_exit() -> PipePart:
	if is_instance_valid(link) and link.link == self and _placed(link) and _placed(self):
		return link
	return null


# Whether a Part is in its world's Parts, i.e. not erased (undo keeps it aside).
static func _placed(part: Part) -> bool:
	return part.sub_area != null and part.get_parent() == part.sub_area.get_parts()


func get_variants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in COLORS.size():
		result.append({"id": COLORS[i], "label": "", "icon": icon_for(i)})
	return result


func get_variant() -> StringName:
	return COLORS[color]


func set_variant(id: StringName) -> void:
	if id in COLORS:
		color = COLORS.find(id)
		refresh_environment()


## The exit toggle; the editor turns it on through a pick in the other world.
func get_modifiers() -> Array[Dictionary]:
	return [{"id": &"link", "label": "EDITOR_PIPE_EXIT", "icon": preload("uid://cjuqthhe8eq86")}]


func has_modifier(id: StringName) -> bool:
	return id == &"link" and get_exit() != null


func get_variant_state() -> Dictionary:
	return {"id": get_variant(), "facing": facing, "segments": segments, "position": position}


func restore_variant_state(state: Dictionary) -> void:
	color = maxi(0, COLORS.find(state.id))
	facing = state.facing
	segments = clampi(state.segments, 0, MAX_SEGMENTS)
	position = state.position
	_grid_pos = Level.to_grid(position)
	refresh_environment()


func _draw_highlight(at: Vector2, color_value: Color) -> void:
	draw_rect(Rect2(at, get_size()), color_value)


func _check_validity() -> void:
	_grid_pos = Level.to_grid(global_position + Vector2(8, 8))
	_valid_space = fits(Level.from_grid(_grid_pos), facing, segments)


## Whether this pipe's footprint at [param at] stays in the room and clear of
## other objects (this pipe excluded).
func fits(at: Vector2, way: Facing, body: int) -> bool:
	var size := size_for(way, body)
	if at.x < 0 or at.y < -Level.LEVEL_HEIGHT * Level.GRID_SIZE.y or at.y + size.y > 0 \
			or at.x + size.x > level.width:
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 1 << 8
	query.exclude = [get_rid()]
	query.transform.origin = to_global(at - position) + size / 2
	query.shape = RectangleShape2D.new()
	query.shape.size = size - Vector2(2, 2)
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
			and not _is_placing_press() and is_instance_valid(level) and is_instance_valid(level.editor) \
			and level.editor.part_interact and level.editor.held_part == null \
			and level.editor.erasing == Editor.EraseMode.NONE \
			and mouth_rect().has_point(get_parent().get_local_mouse_position()):
		begin_resize()
		return
	super(viewport, event, shape_idx)


## Starts an opening drag (source poder_girar) with one history snapshot.
func begin_resize() -> void:
	if held or resizing:
		return
	resizing = true
	_resize_before = get_variant_state()
	level.editor.held_part = self
	level.editor.part_interact = false
	Cursor.down = true


## Follows the mouse. Dragging the opening outward or inward changes the
## length while the far end stays (source crecer). A head-only pipe turns in
## place when the opening is dragged to a side (source left/right).
func resize_to(mouse: Vector2) -> void:
	if segments == 0:
		var offset := mouse - (position + Vector2(16, 16))
		if maxf(absf(offset.x), absf(offset.y)) > 24:
			var toward: Facing = (Facing.RIGHT if offset.x > 0 else Facing.LEFT) \
					if absf(offset.x) > absf(offset.y) else (Facing.DOWN if offset.y > 0 else Facing.UP)
			var opposite := ((facing + 2) % 4) as Facing
			if toward != facing and toward != opposite:
				_set_geometry(toward, 0, position)
				return
	var size := get_size()
	var length := size.dot(axis(facing).abs())
	var base := position + size / 2 - axis(facing) * length / 2
	var body := clampi(roundi(((mouse - base).dot(axis(facing)) - 32) / 16), 0, MAX_SEGMENTS)
	var next := size_for(facing, body)
	var at := (base + axis(facing) * next.dot(axis(facing).abs()) / 2 - next / 2).snapped(Level.GRID_SIZE)
	if body != segments:
		_set_geometry(facing, body, at)


func _set_geometry(way: Facing, body: int, at: Vector2) -> void:
	if not fits(at, way, body):
		return
	UISoundPlayer.stream = SoundLibrary.stream("snd_rieles")
	UISoundPlayer.play()
	facing = way
	segments = body
	position = at
	_grid_pos = Level.to_grid(position)
	refresh_environment()


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
		resize_to(get_parent().get_local_mouse_position())


func _input(event: InputEvent) -> void:
	if resizing and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		end_resize()
		return
	super(event)


func _draw() -> void:
	super()
	# The editor marks linked pipes so pairs can be read at a glance.
	if level != null and level.status == Level.Status.EDITING and get_exit() != null and not held:
		var mouth := mouth_rect()
		draw_circle(mouth.get_center() - position, 5, Color(1, 1, 1, 0.9))
		draw_circle(mouth.get_center() - position, 3, Color(0.1, 0.6, 1.0))


func build() -> void:
	runtime = WarpPipe.new()
	runtime.part = self
	runtime.position = position
	sub_area.add(runtime)
