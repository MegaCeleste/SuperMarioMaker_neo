class_name GroundPart
extends Part

@onready var _tex: AtlasTexture = %Sprite.texture

## Current SWE atlas frame, kept in sync with GodotWE's terrain connections.
@export var swe_frame := -1
@export var swe_atlas := Vector2.ZERO
var _render_key: Array = []


static func get_category() -> PaletteCategory:
	return load("uid://wtetnd7c3nmk")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	if SMWTheme.supports(_environment) and _environment.level_theme != Level.LevelTheme.OVERWORLD:
		var icon := Image.create(60, 60, false, Image.FORMAT_RGBA8)
		var region := SMWTheme.atlas(_environment).get_image().get_region(Rect2i(80, 160, 16, 16))
		region.resize(48, 48, Image.INTERPOLATE_NEAREST)
		icon.blit_rect(region, Rect2i(0, 0, 48, 48), Vector2i(6, 6))
		return ImageTexture.create_from_image(icon)
	return preload("uid://du8vtxsylbi78")


static func is_multiplaceable() -> bool:
	return true


static func create() -> GroundPart:
	return load("uid://dpfaa6qawfnk1").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	refresh_sprite(placed_from_editor)


## Authored tiles and the starting platform occupy the same native grid.
static func occupied_cells(parts: Node) -> Dictionary[Vector2i, bool]:
	var cells := terrain_cells(parts)
	for part in parts.get_children():
		if part is SlopePart and not part.held and not part.is_queued_for_deletion():
			for cell: Vector2i in part.cells():
				cells[cell] = true
	return cells


static func terrain_cells(parts: Node) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	for part in parts.get_children():
		if part.is_queued_for_deletion():
			continue
		if part is GroundPart and not part.held:
			cells[Level.to_grid(part.global_position)] = true
		elif part is StartingGround:
			for cell: Vector2i in part.get_cells():
				cells[cell] = true
	return cells


static func slopes_in(parts: Node) -> Array[SlopePart]:
	var slopes: Array[SlopePart] = []
	for part in parts.get_children():
		if part is SlopePart and not part.held and not part.is_queued_for_deletion():
			slopes.append(part)
	return slopes


## Authored corner-touching stairs belong to the same connected terrain.
static func terrain_components(terrain: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, int]:
	var groups: Dictionary[Vector2i, int] = {}
	var group := 0
	for start: Vector2i in terrain:
		if groups.has(start):
			continue
		var pending: Array[Vector2i] = [start]
		groups[start] = group
		var index := 0
		while index < pending.size():
			var cell := pending[index]
			index += 1
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var neighbour := cell + Vector2i(dx, dy)
					if terrain.has(neighbour) and not groups.has(neighbour):
						groups[neighbour] = group
						pending.append(neighbour)
		group += 1
	return groups


static func neighbours_at(pos: Vector2i, cells: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, bool]:
	var neighbours: Dictionary[Vector2i, bool] = {}
	for x in range(-2, 3):
		for y in range(-1, 2):
			var offset := Vector2i(x, y)
			neighbours[offset] = cells.has(pos + offset)
	return neighbours


## Reuse GodotWE's atlas decision tree for both directions of a seam.
static func refresh_all(parts: Node) -> void:
	var terrain := terrain_cells(parts)
	var groups := terrain_components(terrain)
	for part in parts.get_children():
		if part is SlopePart and not part.held:
			part.update_connections(parts)
			part.refresh_fusion(terrain, groups)
	var cells := occupied_cells(parts)
	var slopes := slopes_in(parts)
	for part in parts.get_children():
		if part.is_queued_for_deletion():
			continue
		if part is GroundPart and not part.held:
			var pos := Level.to_grid(part.global_position)
			part._connect(pos, neighbours_at(pos, cells), slopes)
		elif part is StartingGround:
			part.refresh_regions(cells)
		elif part is SlopePart and not part.held:
			part.refresh_art(cells)


func atlas(x: int, y: int) -> void:
	_tex.region.position = Vector2(x, y) * 16
	swe_atlas = _tex.region.position
	# GodotWE's plain interior has no SWE frame. Serialize an equivalent dirt
	# interior, keeping the native atlas choice and all connection rules intact.
	var saved_atlas := Vector2(32, 16) if swe_atlas == Vector2(16, 16) else swe_atlas
	swe_frame = LevelProcessor.SWE_GROUND_FRAME_TABLE.find(saved_atlas)


func _hold() -> void:
	super()
	reset_sprite()
	refresh_all(get_parent())


func _unhold() -> void:
	super()
	refresh_all.call_deferred(get_parent())


func erase(silent := false) -> void:
	super(silent)
	var parts := get_parent()
	parts.remove_child(self)
	refresh_all(parts)


func build() -> void:
	build_cell(sub_area, Level.to_grid(global_position), %Sprite.texture, slopes_in(get_parent()))


static func build_cell(area: SubArea, cell: Vector2i, texture: Texture2D, slopes: Array[SlopePart]) -> void:
	var points := SlopePart.terrain_polygon(cell, slopes)
	if points.is_empty():
		return
	if points != PackedVector2Array([Vector2.ZERO, Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)]):
		var clipped := SlopeBody.new()
		clipped.position = Vector2(cell * 16)
		clipped.points = points
		SlopePart._add_sprite(clipped, texture, Vector2.ZERO)
		area.add(clipped)
		return
	var tile = preload("uid://bpy1sebdq7k7s").instantiate()
	tile.position = Vector2(cell * 16)
	tile.get_node(^"%Sprite").texture = texture
	area.add(tile)


func refresh_sprite(refresh_nearby := true) -> void:
	if held:
		reset_sprite()
	if refresh_nearby:
		refresh_all(get_parent())
	elif not held:
		var pos := Level.to_grid(global_position)
		_connect(pos, neighbours_at(pos, occupied_cells(get_parent())), slopes_in(get_parent()))


func reset_sprite() -> void:
	_render_key = []
	_tex.atlas = SMWTheme.atlas(sub_area)
	%Sprite.texture = _tex
	atlas(5, 10)


func _connect(pos: Vector2i, data: Dictionary[Vector2i, bool], slopes: Array[SlopePart]) -> void:
	_tex.atlas = SMWTheme.atlas(sub_area)
	var key: Array = [pos, data, _tex.atlas]
	for ramp in slopes:
		if ramp.covers_cell(pos):
			key.append(ramp.get_variant_state())
	if key == _render_key:
		return
	_render_key = key
	var chosen := atlas_for(pos, data)
	atlas(chosen.x, chosen.y)
	%Sprite.texture = SlopePart.terrain_texture(pos, _tex, slopes)


static func atlas_for(pos: Vector2i, data: Dictionary[Vector2i, bool]) -> Vector2i:
	# Stable decorative variants: topology refreshes must not reroll the map.
	# This changes only the random choice, preserving the original53-rule tree.
	var variant_rng := RandomNumberGenerator.new()
	variant_rng.seed = hash(pos)
	var top_left = data[Vector2i(-1, -1)]
	var top = data[Vector2i(0, -1)]
	var top_right = data[Vector2i(1, -1)]
	var right = data[Vector2i(1, 0)]
	var right_right = data[Vector2i(2, 0)]
	var bottom_right = data[Vector2i(1, 1)]
	var bottom = data[Vector2i(0, 1)]
	var bottom_left = data[Vector2i(-1, 1)]
	var left = data[Vector2i(-1, 0)]
	var left_left = data[Vector2i(-2, 0)]
	
	if pos.y >= -1:
		bottom_left = true
		bottom = true
		bottom_right = true
	if pos.x <= 0:
		top_left = true
		left = true
		bottom_left = true
	if pos.x <= 1:
		left_left = false
	
	if top:
		if right:
			if top_right:
				if bottom:
					if bottom_right:
						if left:
							if bottom_left:
								if top_left:
									return Vector2i(variant_rng.randi_range(1, 4), 1)
								else:
									return Vector2i(2, 9)
							elif top_left:
								return Vector2i(2, 10)
							else:
								return Vector2i(2, 8)
						elif right_right:
							return Vector2i(0, variant_rng.randi_range(1, 4))
						else:
							return Vector2i(1, 3)
					elif left:
						if bottom_left:
							if top_left:
								return Vector2i(3, 10)
							else:
								return Vector2i(4, 4)
						elif top_left:
							return Vector2i(1, 10)
						else:
							return Vector2i(4, 2)
					else:
						return Vector2i(0, 10)
				elif left:
					if top_left:
						return Vector2i(variant_rng.randi_range(1, 4), 5)
					else:
						return Vector2i(2, 11)
				elif right_right or bottom_right:
					return Vector2i(0, 5)
				else:
					return Vector2i(1, 4)
			elif bottom:
				if bottom_right:
					if left:
						if bottom_left:
							if top_left:
								return Vector2i(3, 9)
							else:
								return Vector2i(1, 9)
						elif top_left:
							return Vector2i(3, 4)
						else:
							return Vector2i(4, 3)
					else:
						return Vector2i(0, 9)
				elif left:
					if bottom_left:
						if top_left:
							return Vector2i(3, 8)
						else:
							return Vector2i(3, 3)
					elif top_left:
						return Vector2i(3, 2)
					else:
						return Vector2i(1, 8)
				else:
					return Vector2i(0, 8)
			elif left:
				if top_left:
					return Vector2i(3, 11)
				else:
					return Vector2i(1, 11)
			else:
				return Vector2i(0, 11)
		elif bottom:
			if left:
				if bottom_left:
					if top_left:
						if left_left:
							return Vector2i(5, variant_rng.randi_range(1, 4))
						else:
							return Vector2i(2, 3)
					else:
						return Vector2i(4, 9)
				elif top_left:
					return Vector2i(4, 10)
				else:
					return Vector2i(4, 8)
			else:
				return Vector2i(5, 8)
		elif left:
			if top_left:
				if left_left or bottom_left:
					return Vector2i(5, 5)
				else:
					return Vector2i(2, 4)
			else:
				return Vector2i(4, 11)
		else:
			return Vector2i(5, 9)
	elif right:
		if bottom:
			if bottom_right:
				if left:
					if bottom_left:
						return Vector2i(variant_rng.randi_range(1, 4), 0)
					else:
						return Vector2i(2, 7)
				elif right_right or top_right:
					return Vector2i(0, 0)
				else:
					return Vector2i(1, 2)
			elif left:
				if bottom_left:
					return Vector2i(3, 7)
				else:
					return Vector2i(1, 7)
			else:
				return Vector2i(0, 7)
		elif left:
			return Vector2i(variant_rng.randi_range(1, 4), 6)
		else:
			return Vector2i(0, 6)
	elif bottom:
		if left:
			if bottom_left:
				if left_left or top_left:
					return Vector2i(5, 0)
				else:
					return Vector2i(2, 2)
			else:
				return Vector2i(4, 7)
		else:
			return Vector2i(5, 7)
	elif left:
		return Vector2i(5, 6)
	else:
		return Vector2i(5, 10)
