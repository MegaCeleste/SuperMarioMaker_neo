# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SlopePart
extends Part
## Fixed-angle, endpoint-edited terrain. Ordinary cells still use GroundPart's
## original atlas decision tree. Only the diagonal surface has its own sampler.

var gentle := false
var rise := 1
var rises_right := true
var trim_left := false
var trim_right := false
var resizing := false
var _resize_before: Dictionary
var _fixed_end: Vector2
var _polygon: CollisionPolygon2D
var _art: Node2D
var _handles: Node2D
static var _surfaces: Dictionary = {}
var _art_key: Array = []
var _fusion_floors: Dictionary[int, float] = {}
const GROUND = preload("res://textures/styles/smw/tiles/ground/overworld.png")
const MAX_RISE := 11


static func get_part_name(_environment: SubArea) -> String:
	return "Steep Slope"


static func get_part_icon(_environment: SubArea) -> Texture2D:
	if SMWTheme.atlas(_environment) == GROUND:
		return preload("res://textures/ui/editor/parts/smw/slope.png")
	var image := Image.create(60, 60, false, Image.FORMAT_RGBA8)
	var texture := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	for lower in [false, true]:
		texture.blit_rect(surface_texture(false, true, lower, false, SMWTheme.atlas(_environment)).get_image(), Rect2i(0, 0, 16, 16), Vector2i(0, 16 if lower else 0))
	texture.resize(27, 54, Image.INTERPOLATE_NEAREST)
	image.blit_rect(texture, Rect2i(0, 0, 27, 54), Vector2i(16, 3))
	return ImageTexture.create_from_image(image)


static func create() -> SlopePart:
	return load("res://scenes/level/parts/slope_part.tscn").instantiate()


static func is_placeable(grid_pos: Vector2i, world: World2D) -> bool:
	return space_free(Level.from_grid(grid_pos), polygon_for(1, false, true), world)


static func space_free(at: Vector2, points: PackedVector2Array, world: World2D, exclude: Array[RID] = []) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.transform.origin = at
	query.collision_mask = 1 << 8
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = exclude
	# A convex hull fills the space between the caps, blocking distant actors.
	# Query the same convex pieces as CollisionPolygon2D's solid ribbon instead.
	for piece: PackedVector2Array in Geometry2D.decompose_polygon_in_convex(points):
		var shape := ConvexPolygonShape2D.new()
		shape.points = piece
		query.shape = shape
		for hit in world.direct_space_state.intersect_shape(query, 256):
			var part: Node = hit.collider
			if not (part is GroundPart or part is StartingGround or part is SlopePart or part is EditorPlayer):
				return false
	return true


static func polygon_for(height: int, shallow: bool, right: bool, left_cut := false, right_cut := false) -> PackedVector2Array:
	var w := float((height * (2 if shallow else 1) + 2) * 16)
	var h := float(height * 16)
	var left_y := h if right else 0.0
	var right_y := 0.0 if right else h
	var top := PackedVector2Array()
	if not left_cut:
		top.append(Vector2(0, left_y))
	top.append(Vector2(16, left_y))
	top.append(Vector2(w - 16, right_y))
	if not right_cut:
		top.append(Vector2(w, right_y))
	var result := top.duplicate()
	for i in range(top.size() - 1, -1, -1):
		result.append(top[i] + Vector2(0, 16))
	return result


func width_cells() -> int:
	return rise * (2 if gentle else 1) + 2


func endpoints() -> PackedVector2Array:
	return PackedVector2Array([Vector2(8, (rise * 16 if rises_right else 0) + 8),
		Vector2(width_cells() * 16 - 8, (0 if rises_right else rise * 16) + 8)])


func ramp_ends() -> PackedVector2Array:
	return PackedVector2Array([position + Vector2(16, rise * 16 if rises_right else 0),
		position + Vector2(width_cells() * 16 - 16, 0 if rises_right else rise * 16)])


func surface_y(x: float) -> float:
	var t := clampf((x - 16) / float((width_cells() - 2) * 16), 0, 1)
	return rise * 16 * (1 - t if rises_right else t)


func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(1 if trim_left else 0, width_cells() - (1 if trim_right else 0)):
		var top := floori(minf(surface_y(x * 16), surface_y((x + 1) * 16)) / 16 + 0.0001)
		var lower := maxf(surface_y(x * 16), surface_y((x + 1) * 16)) + 16
		var bottom := ceili(maxf(lower, _fusion_floors.get(x, -INF)) / 16 - 0.0001) - 1
		for y in range(top, bottom + 1):
			result.append(Level.to_grid(position) + Vector2i(x, y))
	return result


func covers_cell(cell: Vector2i) -> bool:
	var local := cell - Level.to_grid(position)
	if local.x < (1 if trim_left else 0) or local.x >= width_cells() - (1 if trim_right else 0):
		return false
	var a := surface_y(local.x * 16) / 16
	var b := surface_y((local.x + 1) * 16) / 16
	var lower := maxf(maxf(a, b) + 1, _fusion_floors.get(local.x, -INF) / 16)
	return local.y >= floori(minf(a, b) + 0.0001) and local.y < ceili(lower - 0.0001)


func polygon() -> PackedVector2Array:
	return _polygon_with_fusion(_fusion_floors)


func _polygon_with_fusion(floors: Dictionary[int, float]) -> PackedVector2Array:
	var base := polygon_for(rise, gentle, rises_right, trim_left, trim_right)
	if floors.is_empty():
		return base
	var points := PackedVector2Array()
	for i in base.size() / 2:
		points.append(base[i])
	for x in range(width_cells() - (2 if trim_right else 1), (0 if trim_left else -1), -1):
		var floor_y: float = floors.get(x, -INF)
		for edge in [x + 1, x]:
			var point := Vector2(edge * 16, maxf(surface_y(edge * 16) + 16, floor_y))
			if points.is_empty() or not points[-1].is_equal_approx(point):
				points.append(point)
	# Redundant collinear vertices interfere with convex decomposition at joins.
	var changed := true
	while changed and points.size() > 3:
		changed = false
		for i in points.size():
			var incoming := points[i] - points[(i + points.size() - 1) % points.size()]
			var outgoing := points[(i + 1) % points.size()] - points[i]
			if absf(incoming.cross(outgoing)) < 0.001 and incoming.dot(outgoing) >= 0:
				points.remove_at(i)
				changed = true
				break
	return points


## Once a terrain component meets the ribbon, its visible top is projected to
## the slope across the whole footprint, including deeper U-shaped profiles.
## Independent islands cannot activate fusion just by sitting below a slope.
func fusion_at(at: Vector2, terrain: Dictionary[Vector2i, bool], groups: Dictionary[Vector2i, int] = {}) -> Dictionary[int, float]:
	if groups.is_empty():
		groups = GroundPart.terrain_components(terrain)
	var contacts: Dictionary[int, bool] = {}
	var origin := Level.to_grid(at)
	var first := 1 if trim_left else 0
	var last := width_cells() - (2 if trim_right else 1)
	for cell: Vector2i in terrain:
		var local := cell - origin
		if local.x < first - 1 or local.x > last + 1:
			continue
		var left := clampi(local.x * 16, first * 16, (last + 1) * 16)
		var right := clampi((local.x + 1) * 16, first * 16, (last + 1) * 16)
		var upper := minf(surface_y(left), surface_y(right))
		var lower := maxf(surface_y(left), surface_y(right)) + 16
		if (local.y + 1) * 16 >= upper - 0.001 and local.y * 16 <= lower + 0.001:
			contacts[groups[cell]] = true
	var floors: Dictionary[int, float] = {}
	for cell: Vector2i in terrain:
		var local := cell - origin
		if local.x < first or local.x > last or not contacts.has(groups[cell]):
			continue
		var lower := maxf(surface_y(local.x * 16), surface_y((local.x + 1) * 16)) + 16
		if (local.y + 1) * 16 >= lower - 0.001:
			floors[local.x] = minf(floors.get(local.x, INF), local.y * 16.0)
	return floors


func refresh_fusion(terrain: Dictionary[Vector2i, bool], groups: Dictionary[Vector2i, int] = {}) -> void:
	_fusion_floors = fusion_at(position, terrain, groups)


func _ready() -> void:
	super()
	$CollShape.disabled = true
	_polygon = CollisionPolygon2D.new()
	add_child(_polygon)
	_art = Node2D.new()
	_art.position = Vector2(-8, -8)
	_art.z_index = 1 # Fused grass must cover terrain regardless of placement order.
	$Graphics.add_child(_art)
	_handles = Node2D.new()
	_handles.name = "EndpointHandles"
	_handles.z_as_relative = false
	_handles.z_index = 50
	_handles.draw.connect(_draw_handles)
	add_child(_handles)
	_polygon.polygon = polygon()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	GroundPart.refresh_all(get_parent())


func update_connections(parts: Node) -> void:
	trim_left = false
	trim_right = false
	var ends := ramp_ends()
	for other in parts.get_children():
		if other == self or not other is SlopePart or other.held or other.is_queued_for_deletion():
			continue
		for point: Vector2 in other.ramp_ends():
			trim_left = trim_left or point.is_equal_approx(ends[0])
			trim_right = trim_right or point.is_equal_approx(ends[1])


func refresh_art(occupied: Dictionary[Vector2i, bool]) -> void:
	if not is_node_ready():
		return
	var ground := SMWTheme.atlas(sub_area)
	var key: Array = [position, rise, gentle, rises_right, trim_left, trim_right, _fusion_floors.duplicate(), ground]
	var native_atlas: Dictionary[Vector2i, Vector2i] = {}
	for cell in cells():
		var neighbours := GroundPart.neighbours_at(cell, occupied)
		key.append(neighbours)
		native_atlas[cell] = GroundPart.atlas_for(cell, neighbours) * 16
	if key == _art_key:
		return
	_art_key = key
	_polygon.polygon = polygon()
	for child in _art.get_children():
		child.free()
	var origin := Level.to_grid(position)
	var ratio := 2 if gentle else 1
	var ground_pixels := ground.get_image()
	# Only caps are square tiles. Drawing partial cells with the square atlas
	# produced the detached corner at particular lengths (5x5 and6x6).
	for x in [0, width_cells() - 1]:
		if (x == 0 and trim_left) or (x > 0 and trim_right):
			continue
		var local := Vector2i(x, roundi(surface_y(x * 16) / 16))
		var cell := origin + local
		var atlas := GroundPart.atlas_for(cell, GroundPart.neighbours_at(cell, occupied))
		var texture := AtlasTexture.new()
		texture.atlas = ground
		texture.region = Rect2(Vector2(atlas * 16), Vector2(16, 16))
		_add_sprite(_art, texture, Vector2(local * 16))
	for step in rise:
		var at := Vector2i((1 + step * ratio) * 16, (rise - 1 - step if rises_right else step) * 16)
		for lower in [false, true]:
			var image := surface_texture(gentle, rises_right, lower, false, ground).get_image()
			var filled := surface_texture(gentle, rises_right, lower, true, ground).get_image()
			for px in 16 * ratio:
				for py in 16:
					var pixel := at + Vector2i(px, py + (16 if lower else 0))
					if _fusion_floors.has(pixel.x / 16):
						var depth := pixel.y - surface_y(pixel.x + 0.5)
						if depth < 12:
							image.set_pixel(px, py, filled.get_pixel(px, py))
						else:
							# Square exterior edges still use the original53 atlas
							# rules; only the diagonal grass owns the upper fringe.
							var cell := origin + Vector2i(pixel.x / 16, pixel.y / 16)
							image.set_pixel(px, py, ground_pixels.get_pixelv(native_atlas[cell] + Vector2i(pixel.x % 16, pixel.y % 16)))
			_add_sprite(_art, ImageTexture.create_from_image(image), Vector2(at + Vector2i(0, 16 if lower else 0)))
	# Connected terrain may lie several rows below the ribbon. Render every
	# derived bridge cell, with the same atlas neighbours as authored terrain.
	for cell in cells():
		var local := cell - origin
		if local.x == 0 or local.x == width_cells() - 1:
			if local.y == roundi(surface_y(local.x * 16) / 16):
				continue
		else:
			var step := (local.x - 1) / ratio
			var row := rise - 1 - step if rises_right else step
			if local.y >= row and local.y <= row + 1:
				continue
		var texture := AtlasTexture.new()
		texture.atlas = ground
		texture.region = Rect2(Vector2(native_atlas[cell]), Vector2(16, 16))
		_add_sprite(_art, texture, Vector2(local * 16))
	queue_redraw()


## Resample only the grass edge onto a 2:1 pixel staircase. Soil pixels keep
## their original 1:1 scale; stretching the complete 45-degree tile distorts it.
static func surface_texture(shallow: bool, right: bool, lower := false, filled := false, ground: Texture2D = GROUND) -> Texture2D:
	var key := "%s:%d" % [Vector4i(int(shallow), int(right), int(lower), int(filled)), ground.get_instance_id()]
	if _surfaces.has(key):
		return _surfaces[key]
	var source := ground.get_image()
	var ratio := 2 if shallow else 1
	var canvas := Image.create(16 * ratio, 16, false, Image.FORMAT_RGBA8)
	var filename := "%s_%s%s.png" % ["gentle" if shallow else "steep", "up" if right else "down", "_filled" if filled else ""]
	var custom := "res://textures/tiles/slopes/%s/%s" % [ground.get_meta(&"course_theme", "overworld"), filename]
	# Preserve the original four ground-theme gentle filenames as aliases.
	if not ResourceLoader.exists(custom) and ground == GROUND:
		custom = "res://textures/tiles/slopes/%s" % filename
	if ResourceLoader.exists(custom):
		var supplied := (load(custom) as Texture2D).get_image()
		if supplied.get_size() == Vector2i(16 * ratio, 32):
			canvas.blit_rect(supplied, Rect2i(0, 16 if lower else 0, 16 * ratio, 16), Vector2i.ZERO)
			var provided := ImageTexture.create_from_image(canvas)
			_surfaces[key] = provided
			return provided
	for x in 16 * ratio:
		var sx := x / ratio
		var edge := 15 - sx if right else sx
		for y in 16:
			var sy := y + (16 if lower else 0)
			if sy < edge:
				continue
			var color := source.get_pixel((0 if right else 16) + (0 if filled else 64) + sx, 192 + sy)
			if shallow and filled and sy - edge >= 12:
				color = source.get_pixel(32 + x % 16, 16 + y)
			canvas.set_pixel(x, y, color)
	var result := ImageTexture.create_from_image(canvas)
	_surfaces[key] = result
	return result


## Only square terrain intersected by the ribbon is cut to its upper surface.
## Its source Part/save/history survives; moving/erasing the slope restores it.
static func terrain_texture(cell: Vector2i, texture: Texture2D, slopes: Array[SlopePart]) -> Texture2D:
	var affected: Array[SlopePart] = []
	for ramp in slopes:
		if ramp.covers_cell(cell):
			affected.append(ramp)
	if affected.is_empty():
		return texture
	var image := texture.get_image()
	for x in 16:
		for y in 16:
			var world := Vector2(cell * 16 + Vector2i(x, y))
			for ramp in affected:
				var local := world - ramp.position
				if local.x < 16 or local.x >= (ramp.width_cells() - 1) * 16:
					continue
				var depth := local.y - ramp.surface_y(local.x + 0.5)
				if depth < 0:
					image.set_pixel(x, y, Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)


static func terrain_polygon(cell: Vector2i, slopes: Array[SlopePart]) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO, Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)])
	for ramp in slopes:
		if not ramp.covers_cell(cell):
			continue
		var local := Vector2(cell * 16) - ramp.position
		if local.x < 16 or local.x >= (ramp.width_cells() - 1) * 16:
			continue
		# Clip just the intersected stair tile; retain everything below it.
		var a := Vector2(0, ramp.surface_y(local.x) - local.y)
		var b := Vector2(16, ramp.surface_y(local.x + 16) - local.y)
		var clip := PackedVector2Array([a, b, Vector2(16, 128), Vector2(0, 128)])
		var clipped := Geometry2D.intersect_polygons(points, clip)
		points = clipped[0] if not clipped.is_empty() else PackedVector2Array()
		if points.is_empty():
			return points
	return points


static func _add_sprite(parent: Node, texture: Texture2D, at: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.position = at
	parent.add_child(sprite)


func build() -> void:
	var body := SlopeBody.new()
	body.position = position
	body.points = polygon()
	for child in _art.get_children():
		_add_sprite(body, child.texture, child.position)
		body.get_child(-1).z_index = 1
	sub_area.add(body)


func get_variant_state() -> Dictionary:
	return {"id": &"gentle" if gentle else &"steep", "rise": rise, "right": rises_right, "position": position}


func restore_variant_state(state: Dictionary) -> void:
	gentle = state.id == &"gentle"
	rise = clampi(state.rise, 1, MAX_RISE)
	rises_right = state.right
	position = state.position
	_grid_pos = Level.to_grid(position)
	if is_inside_tree():
		GroundPart.refresh_all(get_parent())


func _check_validity() -> void:
	_grid_pos = Level.to_grid(global_position + Vector2(8, 8))
	var at := Level.from_grid(_grid_pos)
	var floors := fusion_at(at, GroundPart.terrain_cells(get_parent()))
	_valid_space = fits_bounds(at) and space_free(at, _polygon_with_fusion(floors), get_world_2d(), [get_rid()])


func fits_bounds(at: Vector2) -> bool:
	return at.x >= 0 and at.x + width_cells() * 16 <= level.width and at.y >= -432 and at.y + (rise + 1) * 16 <= 0


func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
			and is_instance_valid(level) and is_instance_valid(level.editor) and level.editor.part_interact \
			and level.editor.erasing == Editor.EraseMode.NONE:
		var mouse := get_local_mouse_position()
		var ends := endpoints()
		for index in 2:
			if mouse.distance_to(ends[index]) <= 8:
				begin_resize(index)
				return
	super(viewport, event, shape_idx)


func begin_resize(index: int) -> void:
	if held or resizing or level.editor.held_part != null:
		return
	resizing = true
	_resize_before = get_variant_state()
	_fixed_end = position + endpoints()[1 - index]
	level.editor.held_part = self
	level.editor.part_interact = false
	Cursor.down = true
	queue_redraw()


func resize_endpoint(mouse: Vector2) -> void:
	# The untouched cap stays anchored. Projection onto the nearest fixed-angle
	# diagonal permits both horizontal and vertical drags, including crossing it.
	var ratio := 2 if gentle else 1
	var delta := (mouse - _fixed_end) / 16
	var horizontal := 1 if delta.x >= 0 else -1
	var vertical := 1 if delta.y >= 0 else -1
	var height := clampi(roundi((absf(delta.x) * ratio + absf(delta.y) - ratio) / (ratio * ratio + 1.0)), 1, MAX_RISE)
	var other := _fixed_end + Vector2(horizontal * (height * ratio + 1), vertical * height) * 16
	var left := other if horizontal < 0 else _fixed_end
	var right := _fixed_end if horizontal < 0 else other
	var before := get_variant_state()
	rise = height
	rises_right = right.y < left.y
	position = (Vector2(minf(left.x, right.x), minf(left.y, right.y)) - Vector2(8, 8)).snapped(Vector2(16, 16))
	if get_variant_state() == before:
		return
	refresh_fusion(GroundPart.terrain_cells(get_parent()))
	if fits_bounds(position) and space_free(position, polygon(), get_world_2d(), [get_rid()]):
		GroundPart.refresh_all(get_parent())
	else:
		restore_variant_state(before)


func end_resize() -> void:
	if not resizing:
		return
	resizing = false
	level.editor.held_part = null
	level.editor.part_interact = true
	level.editor.history.record_geometry(self, _resize_before, get_variant_state())
	Cursor.down = false
	queue_redraw()


func _process(delta: float) -> void:
	super(delta)
	if resizing:
		resize_endpoint(get_global_mouse_position())


func _input(event: InputEvent) -> void:
	if resizing and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		end_resize()
		return
	super(event)


func _draw() -> void:
	super()
	if is_instance_valid(_handles):
		_handles.queue_redraw()


func _draw_handles() -> void:
	if is_instance_valid(level) and is_instance_valid(level.editor) and level.status == Level.Status.EDITING \
			and not held and (_mouse_in or resizing) and level.editor.erasing == Editor.EraseMode.NONE:
		for point: Vector2 in endpoints():
			_handles.draw_circle(point, 6, Color("70331f"))
			_handles.draw_circle(point, 5, Color("ffdf52"))
			_handles.draw_circle(point, 3, Color("b47b00"), false, 1)


func _draw_highlight(at: Vector2, color: Color) -> void:
	var points := polygon()
	for i in points.size():
		points[i] += at
	draw_colored_polygon(points, color)


func _hold() -> void:
	super()
	_fusion_floors.clear()
	refresh_art({})
	GroundPart.refresh_all(get_parent())


func _unhold() -> void:
	super()
	GroundPart.refresh_all.call_deferred(get_parent())
