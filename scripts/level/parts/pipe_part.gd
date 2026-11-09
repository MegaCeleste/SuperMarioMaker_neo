# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PipePart
extends Part
## SMW-style pipe, following SMM2: a solid, 32px-wide pipe that may float.
## Dragging the opening along the pipe lengthens or shortens it; dragging it
## sideways turns the pipe a quarter about its far end. The window offers four
## colours (how fast a pipe with contents lets them out) and the exit button,
## which pairs the pipe with a new exit pipe placed in the other world. A pair
## carries Mario both ways; deleting one end leaves the other a plain pipe.

## Which way the opening faces; the source direct_t values.
enum Facing { UP, RIGHT, DOWN, LEFT }

## Longest pipe, in 16px body segments after the 32px head. SMM2's limit is
## not measured yet; this is a placeholder.
const MAX_SEGMENTS := 24
## Stable color IDs in source frame order (spr_pipes image_index).
const COLORS = [&"green", &"red", &"blue", &"yellow"]
## Seconds between things let out, per colour. SMM2's window marks the speed
## with arrows (blue 1, green 2, yellow 3, red 4); the timings are not
## measured yet, so these are placeholders in that order.
const SPAWN_INTERVALS = [3.0, 1.2, 4.0, 2.0]
## At most this many let-out things are around at once (placeholder).
const MAX_SPAWNED := 3
## What a pipe can hold: SMM2 takes items and walking enemies.
const HOLDABLE = [&"MushroomPart", &"FireFlowerPart", &"StarPart", &"OneUpPart", &"GoombaPart",
		&"KoopaPart", &"BuzzyPart", &"SpinyPart", &"BobOmbPart", &"DryBonesPart", &"MontyPart"]

static var _textures: Dictionary = {}

var facing := Facing.UP
## Source size: 16px body segments after the head.
var segments := 0
var color := 0
## The paired pipe in the other world; see [method get_exit].
var link: PipePart
## Whether this end of a pair was the one whose exit button made the pair.
## SMM2 marks it with a down arrow and its partner with an up arrow.
var entrance := false
## The Part this pipe lets out in play, kept out of the course; null if empty.
var content: Part
## Whether an opening drag currently owns the editor's held-part slot.
var resizing := false
## The runtime pipe built for play; the partner's entry hands Mario to it.
var runtime: WarpPipe
var _resize_before: Dictionary
var _overlay: Node2D


static func can_hold(part: Part) -> bool:
	return part != null and can_hold_type(part.get_script())


static func can_hold_type(script: Script) -> bool:
	return script != null and script.get_global_name() in HOLDABLE


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
	_overlay = Node2D.new()
	_overlay.name = "Overlay"
	_overlay.z_index = 2
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
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
## length while the far end stays. Dragging it well to one side turns the
## pipe a quarter toward that side about its far end, as SMM2's curved arrows
## do, keeping the length.
func resize_to(mouse: Vector2) -> void:
	var base := base_center()
	var offset := mouse - base
	var along := offset.dot(axis(facing))
	var across := offset.dot(axis(facing).orthogonal())
	if absf(across) > maxf(24.0, along):
		var toward := _side_facing(across)
		var next := size_for(toward, segments)
		var at := (base + axis(toward) * (next.dot(axis(toward).abs()) / 2 - 16) - next / 2) \
				.snapped(Level.GRID_SIZE)
		_set_geometry(toward, segments, at)
		return
	var body := clampi(roundi((along + 16 - 32) / 16), 0, MAX_SEGMENTS)
	var next := size_for(facing, body)
	var at := (base + axis(facing) * (next.dot(axis(facing).abs()) / 2 - 16) - next / 2) \
			.snapped(Level.GRID_SIZE)
	if body != segments:
		_set_geometry(facing, body, at)


## Centre of the far end's last 32x32 cell pair, which stays put while the
## opening is dragged.
func base_center() -> Vector2:
	var size := get_size()
	var length := size.dot(axis(facing).abs())
	return position + size / 2 - axis(facing) * (length / 2 - 16)


# The facing a quarter turn toward the side the mouse is on.
func _side_facing(across: float) -> Facing:
	var side := (axis(facing).orthogonal() * signf(across)).round()
	for way in 4:
		if axis(way as Facing) == side:
			return way as Facing
	return facing


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
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()


# Markers and handles go on a child drawn over the pipe sprite.
func _draw_overlay() -> void:
	if level == null or level.status != Level.Status.EDITING or held:
		return
	# The contents peek out of the opening, as in SMM2's editor.
	if content != null:
		var icon := content.get_part_icon(sub_area)
		if icon != null:
			var at := mouth_rect().get_center() - position + axis(facing) * 16
			_overlay.draw_texture_rect(icon, Rect2(at - Vector2(10, 10), Vector2(20, 20)), false)
	# SMM2 marks a pair on the body: a down arrow on the end whose exit button
	# made the pair, an up arrow on its exit.
	if get_exit() != null:
		_draw_pair_marker(get_size() / 2 if segments > 0 else mouth_rect().get_center() - position)
	# SMM2's opening handles: straight arrows along the pipe for its length,
	# curved arrows to either side for turning.
	if (_mouse_in or resizing) and level.editor != null and level.editor.erasing == Editor.EraseMode.NONE:
		_draw_handles()


func _draw_pair_marker(at: Vector2) -> void:
	var box := Rect2(at - Vector2(7, 7), Vector2(14, 14))
	_overlay.draw_rect(box.grow(1), Color(0.95, 0.95, 0.95))
	_overlay.draw_rect(box, Color(0.22, 0.55, 0.27))
	var way := Vector2.DOWN if entrance else Vector2.UP
	var side := way.orthogonal()
	_overlay.draw_line(at - way * 4, at + way * 2, Color.WHITE, 2)
	_overlay.draw_colored_polygon(PackedVector2Array([at + way * 5, at + way * 1 + side * 4, at + way * 1 - side * 4]),
			Color.WHITE)


func _draw_handles() -> void:
	var mouth := mouth_rect().get_center() - position
	var out := axis(facing)
	var side := out.orthogonal()
	var yellow := Color(1.0, 0.82, 0.1)
	var dark := Color(0.15, 0.1, 0.1, 0.85)
	_overlay.draw_circle(mouth, 5, dark)
	_overlay.draw_circle(mouth, 3, Color(0.75, 0.2, 0.1))
	for way in [out, -out]:
		var tip: Vector2 = mouth + way * 18
		_overlay.draw_line(mouth + way * 6, tip - way * 4, yellow, 3)
		_overlay.draw_colored_polygon(PackedVector2Array([tip, tip - way * 6 + side * 5, tip - way * 6 - side * 5]), yellow)
	for turn in [1.0, -1.0]:
		var points := PackedVector2Array()
		for i in 7:
			var angle := lerpf(0.15, 1.2, i / 6.0)
			points.append(mouth + (out * cos(angle) + side * turn * sin(angle)) * 14)
		_overlay.draw_polyline(points, dark, 2)
		var end: Vector2 = points[points.size() - 1]
		var back: Vector2 = (points[points.size() - 2] - end).normalized()
		_overlay.draw_colored_polygon(PackedVector2Array([end - back * 3, end + back * 3 + back.orthogonal() * 3,
				end + back * 3 - back.orthogonal() * 3]), dark)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(content) and not content.is_inside_tree():
		content.free()


func build() -> void:
	runtime = WarpPipe.new()
	runtime.part = self
	runtime.position = position
	sub_area.add(runtime)
