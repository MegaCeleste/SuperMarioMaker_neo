class_name StartingGround
extends Part

var _grabber_held := false
var _grabber_cooldown := 0.0
var _editor_preview_tiles: Array[GroundPart] = []

const COOLDOWN = 0.05


func _ready() -> void:
	%Graphics.set_script(GroundDrawer)
	%Graphics.queue_redraw()
	%CollShape.shape.size.y = absf(position.y)
	%CollShape.position.y = position.y / -2


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	if level.status == Level.Status.EDITING:
		call_deferred(&"_rebuild_editor_preview")
	if not level.editing.is_connected(_rebuild_editor_preview):
		level.editing.connect(_rebuild_editor_preview)


func _rebuild_editor_preview() -> void:
	_clear_editor_preview()
	var fore = sub_area.get_foreground()
	var depth = absi(position.y)
	var tiles: Array[GroundPart] = []
	for x in range(0, 112, 16):
		for y in range(0, depth, 16):
			var gp = GroundPart.create()
			var grid_pos = Level.to_grid(global_position + Vector2(x + 8, y + 8))
			gp.global_position = Level.from_grid(grid_pos)
			# Remove collision so preview tiles can't be dragged in editor
			var coll = gp.find_child("CollShape", false, false)
			if coll:
				coll.queue_free()
			gp.collision_layer = 0
			gp.collision_mask = 0
			gp.monitoring = false
			gp.monitorable = false
			gp.z_index = 49
			gp.z_as_relative = false
			gp.add_to_group(&"editor_preview")
			gp._grid_pos = grid_pos
			tiles.append(gp)
			_editor_preview_tiles.append(gp)
	# Add all to tree first so they can detect each other
	for gp in tiles:
		fore.add_child(gp)
	# Set atlas to match StartingGround.build()
	var origin_grid = Level.to_grid(global_position + Vector2(8, 8))
	var theme_tex = GroundPart._theme_ground_atlas(sub_area.level_theme)
	for gp in tiles:
		var gx = Level.to_grid(gp.global_position).x
		var gy = Level.to_grid(gp.global_position).y
		var rel_x = gx - origin_grid.x
		var rel_y = gy - origin_grid.y
		gp._set_theme_atlas(sub_area.level_theme)
		if rel_x == 6 and rel_y == 0:
			gp._atlas(5, 0)
		elif rel_x == 6:
			gp._atlas(5, 1)
		elif rel_y == 0:
			gp._atlas(1, 0)
		else:
			gp._atlas(1, 1)
	# Refresh nearby user-placed GroundParts so they reconnect
	_refresh_nearby_ground_parts()


func _refresh_nearby_ground_parts() -> void:
	if not is_instance_valid(sub_area):
		return
	for child in sub_area.get_parts().get_children():
		if child is GroundPart:
			child.refresh_sprite()


func _clear_editor_preview() -> void:
	for gp in _editor_preview_tiles:
		if is_instance_valid(gp):
			gp.queue_free()
	_editor_preview_tiles.clear()


func _process(delta: float) -> void:
	if _grabber_cooldown < COOLDOWN:
		_grabber_cooldown += delta
	if _grabber_held and _grabber_cooldown >= COOLDOWN:
		var mouse_y = mini(-1, Level.to_grid(get_global_mouse_position()).y)
		if mouse_y != _grid_pos.y:
			_grid_pos.y = floori(move_toward(_grid_pos.y, mouse_y, 1))
			position = Level.from_grid(_grid_pos)
			%CollShape.shape.size.y = absf(position.y)
			%CollShape.position.y = position.y / -2
			var query = PhysicsShapeQueryParameters2D.new()
			query.shape = RectangleShape2D.new()
			query.shape.size = %CollShape.shape.size - Vector2(16, 16)
			query.transform = %CollShape.global_transform
			query.collide_with_areas = true
			query.collide_with_bodies = false
			query.exclude = [get_rid()]
			query.collision_mask = 1 << 8
			for i in get_world_2d().direct_space_state.intersect_shape(query):
				if i["collider"] is Part:
					i["collider"].erase(true)
			UISoundPlayer.stream = preload("uid://mtek8lrj63d5")
			UISoundPlayer.play()
			_grabber_cooldown = 0
			_rebuild_editor_preview()


func _draw() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _grabber_held:
				_grabber_held = false
				level.editor.part_interact = true


func erase(_silent := false) -> void:
	push_warning("Starting ground can't be erased.")


func build() -> void:
	var fore = sub_area.get_foreground()
	var start = Sprite2D.new()
	start.name = "StartArrow"
	start.texture = preload("res://textures/smw/start.png")
	start.position = position + Vector2(40, -24)
	start.z_as_relative = false
	fore.add_child(start)
	var ground_atlas = GroundPart._theme_ground_atlas(sub_area.level_theme)
	for x in range(0, 112, 16):
		for y in range(0, absi(floori(global_position.y)), 16):
			var atlas: Rect2
			if x == 96 and y == 0:
				atlas = Rect2(80, 0, 16, 16)
			elif x == 96:
				atlas = Rect2(80, 16, 16, 16)
			elif y == 0:
				atlas = Rect2(16, 0, 16, 16)
			else:
				atlas = Rect2(16, 16, 16, 16)
			var tile = preload("uid://bpy1sebdq7k7s").instantiate()
			var tile_tex = tile.get_node(^"%Sprite").texture as AtlasTexture
			tile_tex.atlas = ground_atlas
			tile_tex.region = atlas
			fore.add_child(tile)
			tile.position = position + Vector2(x, y)


func _hold() -> void:
	push_warning("Starting ground can't be held.")
	held = false


func _unhold() -> void:
	pass


func _on_grabber_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not level.editor.part_interact:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_grabber_held = true
			level.editor.part_interact = false


class GroundDrawer extends Node2D:
	func _draw() -> void:
		pass
