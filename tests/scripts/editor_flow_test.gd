extends "res://tests/scripts/port_test.gd"
## Exercise the actual editor node, save API and Coursebot preparation path.

var capture := false
var terrain_poses: Array[Image] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-starting-ground" in OS.get_cmdline_user_args()
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	check(level != null and level.status == Level.Status.EDITING, "Coursebot Edit did not prepare an editable level")
	if level == null:
		await finish("EDITOR_FLOW_RESULT")
		return
	add_child(level)
	await ticks(8)
	check(level.editor != null, "Editable level did not create the editor")
	level.description = "Saved through the real Editor API"
	var path := "res://.godot/porting-tests/editor_saved.swe"
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK and level.editor.part_interact, "Editor save did not finish or restore interaction")
	var playable := await LevelActionBtn.prepare_level(path, Level.Status.PLAYING)
	check(playable != null and playable.status == Level.Status.PLAYING, "Coursebot Play did not prepare a playable level")
	check(playable.description == level.description, "Coursebot reopened stale level data")
	level.queue_free()
	await ticks(2)
	add_child(playable)
	await ticks(8)
	check(playable.hud.player != null and playable.hud.player.is_on_floor(), "Saved course did not spawn a playable player")
	check(playable.editor == null, "Coursebot Play opened the editor")
	playable.queue_free()
	await ticks(2)
	var fresh: Level = load("res://scenes/rooms/editor.tscn").instantiate()
	add_child(fresh)
	await ticks(8)
	var ground := GroundPart.create()
	ground.position = Vector2(144, -32)
	fresh.current_sub_area.add_part(ground)
	ground.load(true)
	await ticks(2)
	saved = await fresh.editor.save_to_path("res://.godot/porting-tests/new_editor.swe")
	check(saved.error == OK, "A newly created editor course could not be saved")
	var reopened: Level = await LevelProcessor.from_swe(fresh.file_path)
	var goals := 0
	var terrain := 0
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is GoalPolePart:
			goals += 1
		if part is GroundPart:
			terrain += 1
	check(goals == 1 and terrain == 1, "New-course goal or painted terrain was lost")
	reopened.free()
	# Physics picking can deliver the placing press on a later frame at high refresh rates.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	ground._input_event(get_viewport(), press, 0)
	check(not ground.held and fresh.editor.held_part == null, "The press that placed terrain grabbed it on a later frame")
	Editor.presses += 1
	ground._input_event(get_viewport(), press, 0)
	check(ground.held, "A new press could not grab placed terrain")
	ground.held = false
	await ticks(2)
	var left := GroundPart.create()
	left.position = Vector2(128, -32)
	fresh.current_sub_area.add_part(left)
	left.load(true)
	await ticks(2)
	var right := GroundPart.create()
	right.position = Vector2(160, -32)
	fresh.current_sub_area.add_part(right)
	right.load(true)
	await ticks(2)
	check(left.swe_atlas == Vector2(0, 96) and right.swe_atlas == Vector2(80, 96)
			and ground.swe_atlas.y == 96, "Painting did not connect new and existing terrain")
	ground.erase(true)
	await ticks(2)
	check(left.swe_atlas == Vector2(80, 160) and right.swe_atlas == Vector2(80, 160),
			"Erasing terrain did not reconnect both neighbours")
	ground = GroundPart.create()
	ground.position = Vector2(144, -32)
	fresh.current_sub_area.add_part(ground)
	ground.load(true)
	await ticks(2)
	check(left.swe_atlas == Vector2(0, 96) and right.swe_atlas == Vector2(80, 96),
			"Filling a terrain gap left disconnected neighbours")
	await check_start_connection(fresh)
	if capture:
		var sheet := Image.create(terrain_poses.size() * 320, 240, false, Image.FORMAT_RGBA8)
		for i in terrain_poses.size():
			sheet.blit_rect(terrain_poses[i], Rect2i(0, 0, 320, 240), Vector2i(i * 320, 0))
		check(sheet.save_png("res://.godot/porting-tests/slice_starting_ground.png") == OK, "Could not save starting-ground comparison")
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("EDITOR_FLOW_RESULT", fresh)


func check_start_connection(level: Level) -> void:
	var area := level.current_sub_area
	var start: StartingGround
	for part in area.get_parts().get_children():
		if part is StartingGround:
			start = part
	check(start != null, "Fresh course has no starting platform")
	if start == null:
		return
	var y := Level.to_grid(start.position).y
	# Fill the already authored strip to the course bottom so the comparison
	# shows a solid bank on both sides, rather than a separate bridge underside.
	for x in [128, 144, 160]:
		var fill := GroundPart.create()
		fill.position = Vector2(x, -16)
		area.add_part(fill)
		fill.load(true)
	check(start.regions[Vector2i(96, 0)].position.x == 80, "An isolated start lost its right cap")
	await capture_start(level)
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_terrain.tres")
	ring.choose(0)
	var before_count := area.get_parts().get_child_count()
	level.editor.history.clear()
	level.editor.history.begin_stroke("Join starting ground")
	var top := level.editor.place(Vector2i(7, y)) as GroundPart
	var bottom := level.editor.place(Vector2i(7, y + 1)) as GroundPart
	level.editor.history.end_stroke()
	await ticks(3)
	check(top != null and bottom != null, "Native paint could not touch the starting platform")
	check(start.regions[Vector2i(96, 0)].position.x < 80 and top.swe_atlas.x > 0,
			"Start and authored ground kept opposing vertical edge caps")
	await capture_start(level)
	level.editor.history.undo()
	check(start.regions[Vector2i(96, 0)].position.x == 80, "Undo did not restore the starting platform cap")
	level.editor.history.redo()
	check(start.regions[Vector2i(96, 0)].position.x < 80, "Redo left the starting seam disconnected")
	level.editor.erase_part(top)
	await ticks(2)
	check(start.regions[Vector2i(96, 0)].position.x == 80, "Erasing the top neighbour left a connected top cap")
	level.editor.history.undo()
	check(start.regions[Vector2i(96, 0)].position.x < 80, "Undo erase did not reconnect the start")
	level.editor.history.begin_stroke("Resize start")
	start.resize_to(start.position.y - 32)
	level.editor.history.end_stroke()
	await ticks(2)
	check(start.regions[Vector2i(96, 0)].position.x == 80
			and start.regions[Vector2i(96, 32)].position.x < 80, "Start resizing did not recompute the exposed and connected side rows")
	level.editor.history.undo()
	check(start.regions[Vector2i(96, 0)].position.x < 80, "Undo resize retained stale start regions")
	bottom.atlas(1, 1) # Deterministically exercise the native-only interior variant.
	check(bottom.swe_atlas == Vector2(16, 16) and bottom.swe_frame >= 0,
			"Native dirt fallback changed the displayed tile or has no serializable equivalent")
	var saved: Dictionary = await level.editor.save_to_path("res://.godot/porting-tests/start_connection.swe")
	check(saved.error == OK, "Connected starting ground did not save: " + str(saved))
	var reopened: Level = await LevelProcessor.from_swe(level.file_path)
	add_child(reopened)
	await ticks(4)
	check(reopened.current_sub_area.get_parts().get_child_count() == before_count + 2,
			"Starting-platform virtual cells became saved authored Parts")
	var restored: StartingGround
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is StartingGround:
			restored = part
	check(restored != null and restored.regions[Vector2i(96, 0)].position.x < 80,
			"Reopening the course lost the starting-ground connection")
	reopened.queue_free()
	await ticks(2)
	level.play()
	await ticks(8)
	var runtime_joined := false
	for tile in area.get_foreground().get_children():
		if tile is StaticBody2D and tile.position == start.position + Vector2(96, 0):
			runtime_joined = tile.get_node("%Sprite").texture.region.position.x < 80
	check(runtime_joined, "Runtime start tiles rebuilt the old disconnected edge")
	await capture_start(level)


func capture_start(level: Level) -> void:
	if not capture:
		return
	Utility.camera_scale = Vector2(4, 4)
	Utility.camera_position = Vector2(0, -120)
	var history_controls: Control
	if level.editor != null:
		history_controls = level.editor.get_node("HistoryControls")
		history_controls.hide()
	await ticks(2)
	await RenderingServer.frame_post_draw
	var at := level.current_sub_area.get_foreground().get_global_transform_with_canvas() * Vector2(112, -24)
	var crop := Rect2i(Vector2i(at) - Vector2i(160, 120), Vector2i(320, 240))
	terrain_poses.append(get_viewport().get_texture().get_image().get_region(crop))
	if is_instance_valid(history_controls):
		history_controls.show()
