# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Screenshot regression: a SINGLE-CELL staircase touches the ribbon at corners.
## Expected wedges are solid soil, rather than background or interior grass.

var capture := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-slope-fusion" in OS.get_cmdline_user_args()
	for shallow in [false, true]:
		for right in [true, false]:
			await check_chain(shallow, right)
	for right in [true, false]:
		await check_irregular(right, false)
		await check_irregular(right, true)
	if capture:
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("SLOPE_FUSION_RESULT")


func put(level: Level, type: Script, at: Vector2) -> Part:
	var part: Part = type.create()
	part.position = at
	level.current_sub_area.add_part(part)
	part.load()
	return part


func check_chain(shallow: bool, right: bool) -> void:
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var parts := level.current_sub_area.get_parts()
	for part in parts.get_children():
		if not (part is StartingGround or part is EditorPlayer):
			part.queue_free()
	await ticks(2)
	var ramp: SlopePart = (GentleSlopePart if shallow else SlopePart).create()
	ramp.position = Vector2(208, -288)
	ramp.rise = 5
	ramp.rises_right = right
	level.current_sub_area.add_part(ramp)
	ramp.load()
	var ratio := 2 if shallow else 1
	var native_ground: Array[GroundPart] = []
	var gap_points: Array[Vector2] = []
	for x in range(1, ramp.width_cells() - 1):
		var step := (x - 1) / ratio
		var row := 6 - step if right else step + 2
		native_ground.append(put(level, GroundPart, ramp.position + Vector2(x, row) * 16))
		# A reference point in each triangular opening visible in the report.
		gap_points.append(Vector2(x * 16 + 8, row * 16 - 2))
	var high_x := ramp.width_cells() - 1 if right else 0
	native_ground.append(put(level, GroundPart, ramp.position + Vector2(high_x, 1) * 16))
	var low_x := 0 if right else ramp.width_cells() - 1
	for dx in range(-5, 2):
		put(level, GroundPart, ramp.position + Vector2(low_x + dx, 7) * 16)
	for part in parts.get_children():
		if part is EditorPlayer:
			part.position = ramp.position + Vector2(low_x * 16 + (-32 if right else 16), 96)
	GroundPart.refresh_all(parts)
	var authored_count := parts.get_child_count()
	for point in gap_points:
		check(Geometry2D.is_point_in_polygon(point, ramp.polygon()), "Corner-touch staircase left a triangular collision gap")
	check(not Geometry2D.is_point_in_polygon(Vector2(low_x * 16 + 8, 130), ramp.polygon()), "Fusion extended beyond its connected ground")
	var tag := "%s_%s" % ["gentle" if shallow else "steep", "up" if right else "down"]
	if capture:
		Utility.camera_position = Vector2(112, -352)
		await ticks(24)
		await RenderingServer.frame_post_draw
		var gpu := get_viewport().get_texture().get_image()
		gpu.save_png("res://.godot/porting-tests/slope_fusion_editor_%s.png" % tag)
		for point in gap_points:
			var pixel: Vector2i = parts.get_global_transform_with_canvas() * (ramp.position + point + Vector2(0.5, 0.5))
			var color := gpu.get_pixelv(pixel)
			check(color.r > color.g and color.g > color.b and color.r > 0.55, "Staircase seam contains background/grass instead of soil")
	level.play()
	await ticks(6)
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	for point in gap_points:
		query.position = ramp.position + point
		check(not level.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "Visible fusion wedge has no runtime collision")
	if capture:
		Utility.camera_position = Vector2(112, -352)
		await ticks(12)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slope_fusion_runtime_%s.png" % tag)
		get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_slope_fusion.png")
	level.edit()
	await ticks(2)
	check(parts.get_child_count() == authored_count, "Fusion created permanent authored ground")
	level.editor.erase_part(ramp)
	await ticks(2)
	for tile in native_ground:
		check(tile.get_node("%Sprite").texture is AtlasTexture, "Erasing slope did not restore native stair terrain")
	level.editor.history.undo()
	await ticks(2)
	for point in gap_points:
		check(Geometry2D.is_point_in_polygon(point, ramp.polygon()), "Undo did not rebuild staircase fusion")
	var original := ramp.get_variant_state()
	var moved := original.duplicate()
	moved.position += Vector2(400, 0)
	ramp.restore_variant_state(moved)
	for point in gap_points:
		check(not Geometry2D.is_point_in_polygon(point, ramp.polygon()), "Moving a slope carried old terrain fusion with it")
	ramp.restore_variant_state(original)
	print("SLOPE_CHAIN ", tag, " gaps=", gap_points.size(), " authored=", authored_count)
	level.queue_free()
	await ticks(2)


func check_irregular(right: bool, central_pillar: bool) -> void:
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var parts := level.current_sub_area.get_parts()
	for part in parts.get_children():
		if not (part is StartingGround or part is EditorPlayer):
			part.queue_free()
	await ticks(2)
	var ramp := SlopePart.create()
	ramp.position = Vector2(208, -288)
	ramp.rise = 5
	ramp.rises_right = right
	level.current_sub_area.add_part(ramp)
	ramp.load()
	var layout: Array = [Vector2i(1, 8), Vector2i(2, 7), Vector2i(2, 6), Vector2i(2, 5),
		Vector2i(2, 4), Vector2i(2, 3), Vector2i(3, 7), Vector2i(4, 7), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 5), Vector2i(6, 4)] \
		if central_pillar else [Vector2i(1, 8), Vector2i(2, 7), Vector2i(3, 7), Vector2i(3, 6), Vector2i(4, 6), Vector2i(4, 5),
		Vector2i(5, 5), Vector2i(5, 4), Vector2i(5, 3), Vector2i(5, 2), Vector2i(5, 1), Vector2i(6, 3), Vector2i(6, 2)]
	for cell: Vector2i in layout:
		put(level, GroundPart, ramp.position + Vector2(6 - cell.x if not right else cell.x, cell.y) * 16)
	GroundPart.refresh_all(parts)
	var expected: Array[Vector2] = []
	# The two screenshots have deep concave gaps, beyond the former one-cell
	# limit. Every point down to the same connected ground must now be solid.
	for x in range(1, 6):
		var mirrored_x := 6 - x if not right else x
		var first_row := 100
		for cell: Vector2i in layout:
			if cell.x == x:
				first_row = mini(first_row, cell.y)
		var upper := ramp.surface_y(mirrored_x * 16 + 8)
		for y in range(ceili(upper + 18), first_row * 16, 5):
			expected.append(Vector2(mirrored_x * 16 + 8, y))
	for point in expected:
		check(Geometry2D.is_point_in_polygon(point, ramp.polygon()), "Connected pillar/concave profile left an unfilled gap")
	if capture:
		for part in parts.get_children():
			if part is EditorPlayer:
				part.hide() # Keep all expected soil pixels unobstructed.
		Utility.camera_position = Vector2(112, -352)
		await ticks(24)
		await RenderingServer.frame_post_draw
		var gpu := get_viewport().get_texture().get_image()
		gpu.save_png("res://.godot/porting-tests/slope_fusion_%s_%s.png" % ["central" if central_pillar else "high_end", "up" if right else "down"])
		for point in expected:
			var pixel: Vector2i = parts.get_global_transform_with_canvas() * (ramp.position + point + Vector2(0.5, 0.5))
			var color := gpu.get_pixelv(pixel)
			# The native one-cell-wide exterior retains brown edge shading.
			check(color.r > color.g and color.g > color.b, "Connected profile still shows internal grass/background at %s: %s" % [point, color])
	level.play()
	await ticks(4)
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	for point in expected:
		query.position = ramp.position + point
		check(not level.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "Connected profile art has no matching runtime collision")
	level.edit()
	await ticks(2)
	var independent := SlopePart.create()
	independent.position = Vector2(608, -288)
	independent.rise = 5
	level.current_sub_area.add_part(independent)
	independent.load()
	put(level, GroundPart, independent.position + Vector2(3, 9) * 16)
	GroundPart.refresh_all(parts)
	check(independent._fusion_floors.is_empty(), "Disconnected terrain below a floating slope activated fusion")
	print("IRREGULAR_FUSION ", right, " central=", central_pillar, " samples=", expected.size())
	level.queue_free()
	await ticks(2)
