class_name StartingGround
extends Part

var _grabber_held := false
var _grabber_cooldown := 0.0
## Cached native atlas choices, shared by editor drawing and runtime tiles.
var regions: Dictionary[Vector2i, Rect2i] = {}
var terrain_textures: Dictionary[Vector2i, Texture2D] = {}

const COOLDOWN = 0.05

func _ready() -> void:
	%Graphics.set_script(GroundDrawer)
	%Graphics.starting_ground = self
	%CollShape.shape = %CollShape.shape.duplicate()
	update_size()


func update_size() -> void:
	%CollShape.shape.size.y = maxf(0.01, absf(position.y))
	%CollShape.position.y = position.y / -2
	%Graphics.queue_redraw()
	if sub_area != null:
		GroundPart.refresh_all(get_parent())


func get_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(0, 112, 16):
		for y in range(0, absi(floori(global_position.y)), 16):
			cells.append(Level.to_grid(global_position + Vector2(x, y)))
	return cells


func refresh_regions(cells: Dictionary[Vector2i, bool]) -> void:
	regions.clear()
	terrain_textures.clear()
	var slopes := GroundPart.slopes_in(get_parent())
	for x in range(0, 112, 16):
		for y in range(0, absi(floori(global_position.y)), 16):
			var pos := Level.to_grid(global_position + Vector2(x, y))
			var atlas := GroundPart.atlas_for(pos, GroundPart.neighbours_at(pos, cells))
			regions[Vector2i(x, y)] = Rect2i(atlas * 16, Vector2i(16, 16))
			var tile := AtlasTexture.new()
			tile.atlas = SMWTheme.atlas(sub_area)
			tile.region = Rect2(regions[Vector2i(x, y)])
			terrain_textures[Vector2i(x, y)] = SlopePart.terrain_texture(pos, tile, slopes)
	%Graphics.queue_redraw()


func _process(delta: float) -> void:
	if _grabber_cooldown < COOLDOWN:
		_grabber_cooldown += delta
	if _grabber_held and _grabber_cooldown >= COOLDOWN:
		var mouse_y = mini(-1, Level.to_grid(get_global_mouse_position()).y)
		if mouse_y != _grid_pos.y:
			var next_y := floori(move_toward(_grid_pos.y, mouse_y, 1))
			resize_to(Level.from_grid(Vector2i(0, next_y)).y)
			_grabber_cooldown = 0


## Existing start-ground resize behavior, recorded together with covered Parts.
func resize_to(target_y: float) -> void:
	var before := position
	position.y = clampf(target_y, -432, -16)
	_grid_pos = Level.to_grid(position)
	if position == before:
		return
	update_size()
	level.editor.history.record_move(self, before, position)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = %CollShape.shape.size - Vector2(16, 16)
	query.transform = %CollShape.global_transform
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [get_rid()]
	query.collision_mask = 1 << 8
	for result in get_world_2d().direct_space_state.intersect_shape(query):
		if result["collider"] is Part:
			level.editor.history.erase(result["collider"])
	UISoundPlayer.stream = preload("uid://b4d2q2idv2khi")
	UISoundPlayer.play()


func _draw() -> void:
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _grabber_held:
				UISoundPlayer.stream = preload("uid://r55em6pfkmqk")
				UISoundPlayer.play()
				_grabber_held = false
				level.editor.part_interact = true


func erase(_silent := false) -> void:
	push_warning("Starting ground can't be erased.")


func can_erase() -> bool:
	return false


func build() -> void:
	GroundPart.refresh_all(get_parent())
	var fore = sub_area.get_foreground()
	var start = Sprite2D.new()
	start.name = "StartArrow"
	start.texture = preload("uid://cgslc0o8upncx")
	start.position = position + Vector2(40, -24)
	start.z_as_relative = false
	fore.add_child(start)
	for offset: Vector2i in regions:
		GroundPart.build_cell(sub_area, Level.to_grid(position + Vector2(offset)), terrain_textures[offset], GroundPart.slopes_in(get_parent()))


func _hold() -> void:
	held = false


func _unhold() -> void:
	pass


func _on_grabber_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not level.editor.part_interact:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			level.editor.history.begin_stroke("Resize starting ground")
			_grabber_held = true
			level.editor.part_interact = false


class GroundDrawer extends Node2D:
	const GROUND = preload("uid://clwe7seivxsur")
	var starting_ground: StartingGround
	
	
	func _draw() -> void:
		draw_ground(self)

	func draw_ground(target: CanvasItem) -> void:
		if not is_instance_valid(starting_ground):
			return
		for offset: Vector2i in starting_ground.regions:
			starting_ground.terrain_textures[offset].draw(target.get_canvas_item(), Vector2(offset) - Vector2(8, 8))
