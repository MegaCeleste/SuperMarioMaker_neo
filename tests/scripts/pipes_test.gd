# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Main world / sub-world switching and SMM2-style pipes: opening drags (length
## and quarter turns at any length), the exit button that places a paired exit
## pipe, pair markers, contents, signed SWE and real play through a pair. With
## --capture-pipes it also checks pipe pixels and the transition on real frames.

var capture := false
var _pixels := 0
var _matches := 0
## Sampled pixel count per view; pipe views must all sample something.
var _views := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-pipes" in OS.get_cmdline_user_args()
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var editor := level.editor
	var main := level.get_main_world()
	var sub := level.get_sub_world()
	check(sub != null and sub != main and level.current_sub_area == main, "Level has no separate sub-world")
	check(sub.process_mode == Node.PROCESS_MODE_DISABLED and not sub.visible, "Inactive sub-world is not frozen")

	# World switch: each world keeps its camera; the cursor follows the world.
	Utility.camera_position = Vector2(200, -300)
	var main_camera := Utility.camera_position
	check(editor.switch_world() and level.current_sub_area == sub, "Editor world switch did not show the sub-world")
	check(main.process_mode == Node.PROCESS_MODE_DISABLED and sub.visible, "Main world was not frozen on switch")
	check(level.get_editor_player().sub_area == sub, "Editor cursor did not follow the shown world")
	check(editor.get_node("HistoryControls/World").text == tr("EDITOR_SUB_WORLD"), "World button does not name the sub-world")
	check(editor.switch_world() and level.current_sub_area == main, "Editor world switch did not return to the main world")
	check(Utility.camera_position.is_equal_approx(main_camera), "Main world camera was not restored")

	for area in [main, sub]:
		for candidate in area.get_parts().get_children():
			if not (candidate is StartingGround or candidate is EditorPlayer):
				candidate.free()
	for area in [main, sub]:
		for x in range(96, 512, 16):
			var ground := GroundPart.create()
			ground.position = Vector2(x, -64)
			area.add_part(ground)
			ground.load()
		GroundPart.refresh_all(area.get_parts())
	await ticks(2)

	# Palette entry.
	var ring: PaletteRing = editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_terrain.tres")
	var chosen := false
	for index in 8:
		if ring.choose(index) and editor.get_selected_part() == PipePart:
			chosen = true
			break
	check(chosen, "Pipe palette entry is not usable")
	var pipe := editor.place(Vector2i(10, -6)) as PipePart
	check(pipe != null and pipe.get_size() == Vector2(32, 32), "Placed pipe is not a 32x32 head")
	check(pipe.get_node("Graphics/Sprite").texture != null, "Pipe has no art")

	# Opening drag: lengthen upward from the fixed base, then shrink back.
	pipe.begin_resize()
	pipe.resize_to(Vector2(176, -128))
	check(pipe.segments == 2 and pipe.position == Vector2(160, -128), "Opening drag did not lengthen the pipe upward")
	pipe.resize_to(Vector2(176, -96))
	check(pipe.segments == 0 and pipe.position == Vector2(160, -96), "Opening drag did not shorten the pipe")
	pipe.end_resize()
	check(not editor.history.can_redo(), "Pipe resize history is inconsistent")
	# SMM2 turns a pipe of any length a quarter about its far end.
	pipe.begin_resize()
	pipe.resize_to(Vector2(176, -128))
	pipe.resize_to(Vector2(240, -72))
	check(pipe.facing == PipePart.Facing.RIGHT and pipe.segments == 2 and pipe.position == Vector2(160, -96),
			"A long pipe did not turn right about its far end: %s %s %s" % [pipe.facing, pipe.segments, pipe.position])
	pipe.end_resize()
	editor.history.undo()
	check(pipe.facing == PipePart.Facing.UP and pipe.segments == 0 and pipe.position == Vector2(160, -96),
			"Pipe turn undo failed")
	check(pipe.get_variants().size() == 4 and pipe.get_variant() == &"green", "Pipe colours are not offered")

	# The exit button shows the other world; the next click places the exit
	# pipe, paired and the same colour, in one undo step, and stays there.
	pipe.set_variant(&"red")
	editor.begin_pipe_link(pipe)
	# The editor Mario goes into the pipe first (about 36 + 26 frames).
	await ticks(20)
	check(level.current_sub_area == main and level.get_editor_player().position.y > pipe.position.y - 16,
			"The exit button did not send the editor Mario into the pipe first")
	await ticks(60)
	check(level.current_sub_area == sub and editor.get_node_or_null("PipeLinkHint") != null,
			"The exit button did not show the other world with the prompt")
	var exit := editor.finish_pipe_link(Vector2i(20, -6))
	check(exit != null and exit.sub_area == sub and pipe.get_exit() == exit and exit.get_exit() == pipe,
			"Placing the exit pipe did not pair it")
	if exit == null:
		await finish("PIPES_RESULT", level)
		return
	check(exit.color == pipe.color and pipe.entrance and not exit.entrance,
			"The exit pipe lost the colour or the entrance/exit markers")
	check(level.current_sub_area == sub, "The editor left the exit pipe's world")
	await ticks(60)
	check(level.get_editor_player().sub_area == sub and level.get_editor_player().position == Vector2(328, -112),
			"The editor Mario did not come out on top of the new exit pipe: %s" % level.get_editor_player().position)
	editor.history.undo()
	check(exit.get_parent() == null and pipe.get_exit() == null, "One undo did not remove the exit pipe and its pair")
	editor.history.redo()
	check(pipe.get_exit() == exit, "Exit pipe redo failed")
	editor.erase_part(exit)
	check(pipe.get_exit() == null and pipe.get_parent() != null, "Erasing the exit did not leave a plain pipe")
	editor.history.undo()
	check(pipe.get_exit() == exit, "Undoing the erase did not restore the pair")
	editor.switch_world()
	check(level.current_sub_area == main, "Could not return to the main world")

	# A plain pipe holds a mushroom and lets it out in play.
	var feeder := PipePart.create()
	# Off screen during the trip, so its mushrooms cannot power Mario up.
	feeder.position = Vector2(464, -96)
	main.add_part(feeder)
	feeder.load()
	editor.history.set_pipe_content(feeder, MushroomPart.create())
	check(feeder.content is MushroomPart, "A pipe did not take a mushroom")
	editor.history.undo()
	check(feeder.content == null, "Content undo failed")
	editor.history.redo()
	check(feeder.content is MushroomPart, "Content redo failed")

	if capture:
		# Every facing and colour, floating clear of the play path below.
		for spec in [[Vector2(96, -240), PipePart.Facing.RIGHT, 2, 1], [Vector2(208, -256), PipePart.Facing.DOWN, 1, 2],
				[Vector2(272, -240), PipePart.Facing.LEFT, 0, 3], [Vector2(336, -256), PipePart.Facing.UP, 1, 0]]:
			var extra := PipePart.create()
			extra.position = spec[0]
			extra.facing = spec[1]
			extra.segments = spec[2]
			extra.color = spec[3]
			main.add_part(extra)
			extra.load()
		await snap("editor_main", level)
		editor.switch_world()
		await snap("editor_sub", level)
		editor.switch_world()
		# Views for a person to compare with SMM2: window, prompt, contents, trip.
		Utility.camera_position = Vector2(96, -260)
		await ticks(20)
		# The window opens on a held Part (a long press in the editor).
		pipe.held = true
		pipe._create_window()
		pipe.held = false
		await ticks(20)
		await snap("view_window", level)
		if is_instance_valid(pipe._window):
			pipe._window.close()
		await ticks(10)
		feeder.position = Vector2(256, -96)
		feeder.queue_redraw()
		await ticks(4)
		await snap("view_content", level)
		feeder.position = Vector2(464, -96)
		var spare := PipePart.create()
		spare.position = Vector2(224, -160)
		main.add_part(spare)
		spare.load()
		editor.begin_pipe_link(spare)
		await ticks(20)
		await snap("view_link_dive", level)
		await ticks(80)
		await snap("view_prompt", level)
		editor.finish_pipe_link()
		await ticks(20)
		spare.free()
		Utility.camera_position = Vector2(96, -260)
		await ticks(4)
		editor.travel_through_pipe(level.get_editor_player(), Level.to_grid(pipe.position))
		await ticks(20)
		await snap("view_trip_in", level)
		await ticks(90)
		await snap("view_trip_out", level)
		await ticks(60)
		editor.switch_world()
		await ticks(10)

	# Signed save keeps both worlds, the pair, its markers and the contents.
	var path := "res://.godot/porting-tests/pipes.swe"
	var saved: Dictionary = await editor.save_to_path(path)
	check(saved.error == OK, "Pipe save failed: %s" % saved)
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(path)).data
	check(data.has("SUB1") and data.SUB1.TUBERIAS.size() == 1, "Sub-world pipe was not saved in SUB1")
	var linked: Array = data.MAIN.TUBERIAS.filter(func(r): return r.get("smmneo_link", 0) > 0)
	var row: Dictionary = linked[0] if not linked.is_empty() else {}
	check(row.get("warp") == 0 and row.get("smmneo_link", 0) > 0 and row.get("smmneo_entrance") == 1
			and row.smmneo_link == data.SUB1.TUBERIAS[0].smmneo_link and data.SUB1.TUBERIAS[0].smmneo_entrance == 0,
			"Pipe pair fields are wrong: %s" % row)
	check(data.MAIN.TUBERIAS.any(func(r): return r.get("smmneo_content") is Dictionary), "Pipe contents were not saved")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var pipes := {}
	for area in reopened.get_children():
		if area is SubArea:
			for part in area.get_parts().get_children():
				if part is PipePart:
					pipes[part] = area
	var reloaded_pair := false
	var reloaded_content := false
	for part: PipePart in pipes:
		reloaded_pair = reloaded_pair or (part.get_exit() != null and pipes.get(part.get_exit()) != pipes[part]
				and part.entrance != part.get_exit().entrance)
		reloaded_content = reloaded_content or part.content is MushroomPart
	check(pipes.size() == (7 if capture else 3) and reloaded_pair and reloaded_content,
			"Reopened level lost a world, pipe pair or contents")
	reopened.free()

	# Play: down into the main pipe, out of the sub-world pipe, and back.
	level.get_editor_player().position = Vector2(64, -80)
	level.play()
	await ticks(4)
	var player := level.hud.player
	park(player, Vector2(176, -96))
	await ticks(2)
	Input.action_press("player_down")
	await ticks(3)
	check(player.state_machine.current_state is PlayerPipeState, "Pressing down on a linked pipe did not enter it")
	check(level.get_living_player() == null, "Enemies can still target Mario inside a pipe")
	release_input()
	# He sinks at about 0.5px/frame, then the screen fades for 26 frames.
	if capture:
		await ticks(12)
		await snap("view_play_entering", level)
		await ticks(12)
	else:
		await ticks(25)
	check(level.current_sub_area == main and player.visible, "Mario left or vanished before he was inside")
	await ticks(25)
	check(level.get_node_or_null("FadeTransition") != null, "The screen did not fade out")
	if capture:
		await ticks(10)
		await snap("fade", level)
		await ticks(20)
	else:
		await ticks(30)
	check(level.current_sub_area == sub and player.sub_area == sub and sub.get_foreground().is_ancestor_of(player),
			"Mario did not cross to the sub-world")
	var curtain := level.get_node_or_null("CurtainTransition") as CurtainTransition
	check(curtain != null and curtain.black_ticks == PlayerPipeState.BLACK_TICKS,
			"No measured black-then-iris transition on arrival")
	if capture:
		await ticks(30)
		await snap("curtain", level)
		# A few ticks into the iris: open around the exit, black at the corners.
		await ticks(50)
		await snap("curtain_open", level)
		await ticks(160)
	else:
		await ticks(240)
	check(not player.is_traveling() and absf(player.global_position.x - 336) < 1
			and absf(player.global_position.y + 96) < 1, "Mario did not come out on top of the sub-world pipe")
	check(player.collision_layer != 0 and player.visible, "Mario's collisions were not restored after the pipe")
	# The pair works both ways.
	Input.action_press("player_down")
	await ticks(5)
	release_input()
	await ticks(315)
	check(level.current_sub_area == main and absf(player.global_position.x - 176) < 1, "Return trip failed")

	# The feeder pipe lets its mushroom out while it is on screen.
	park(player, Vector2(420, -64))
	var let_out := false
	for tick in 300:
		await ticks(1)
		for node in main.get_foreground().get_children():
			if node is Mushroom and node.global_position.y <= -95 and node.process_mode != Node.PROCESS_MODE_DISABLED:
				let_out = true
		if let_out:
			break
	check(let_out, "The pipe did not let its mushroom out")

	# Returning to the editor resumes in the world Mario ended in.
	level.edit()
	await ticks(2)
	check(level.current_sub_area == main and level.get_editor_player().sub_area == main, "Edit did not resume in Mario's world")
	if capture:
		# The sub-world's only pipe is the marked exit, which is not sampled.
		for view in ["editor_main"]:
			check(_views.get(view, 0) > 20, "Capture view %s sampled too few pipe pixels" % view)
		check(_matches == _pixels, "Pipe pixels differ on screen: %d/%d" % [_matches, _pixels])
		print("PIPES_PIXELS ", _matches, "/", _pixels)
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("PIPES_RESULT", level)


## Saves a real frame. Editor views compare every opaque pipe pixel with the
## screen; transition views check the black cover and the iris hole.
func snap(label: String, level: Level) -> void:
	if level.status == Level.Status.EDITING and not label.begins_with("view_"):
		Utility.camera_position = Vector2(16, -300) if label == "editor_main" else Vector2(176, -230)
		await ticks(26)
	var sampled := []
	var sample := func():
		for node in level.current_sub_area.find_children("Sprite", "Sprite2D", true, false):
			var owner_pipe = node.get_parent().get_parent()
			# Pair markers and contents are drawn over their pipes on purpose.
			if owner_pipe is PipePart and level.status == Level.Status.EDITING \
					and owner_pipe.get_exit() == null and owner_pipe.content == null:
				sampled.append({"image": node.texture.get_image(), "transform": node.get_global_transform_with_canvas(),
						"centered": node.centered})
	RenderingServer.frame_pre_draw.connect(sample, CONNECT_ONE_SHOT)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var before := Vector2i(_matches, _pixels)
	if label.begins_with("view_"):
		pass
	elif label == "fade":
		var corner := image.get_pixel(20, 600)
		check(corner.r < 0.7 and not corner.is_equal_approx(Color.BLACK), "Fade %s is not part-way to black" % label)
	elif label.begins_with("curtain"):
		var arrival := Vector2i(level.get_global_transform_with_canvas() * level.hud.player.global_position)
		var corner := image.get_pixel(20, 600)
		var middle := image.get_pixelv(arrival - Vector2i(0, 30))
		check(corner.is_equal_approx(Color.BLACK), "Curtain %s does not cover the screen" % label)
		check(middle.is_equal_approx(Color.BLACK) == (label == "curtain"),
				"Curtain %s has the wrong state at the arrival point" % label)
	else:
		for entry: Dictionary in sampled:
			var original: Image = entry.image
			var origin := -Vector2(original.get_size()) / 2 if entry.centered else Vector2.ZERO
			for y in range(3, original.get_height(), 6):
				for x in range(3, original.get_width(), 6):
					var color := original.get_pixel(x, y)
					var at := Vector2i(entry.transform * (origin + Vector2(x + 0.5, y + 0.5)))
					# Editor panels and the HUD cover the edges, as in the semisolid capture.
					if color.a < 1 or at.x < 180 or at.x > 1040 or at.y < 120 or at.y > 550:
						continue
					_pixels += 1
					if image.get_pixelv(at).is_equal_approx(color):
						_matches += 1
		_views[label] = _pixels - before.y
		print("PIPES_VIEW ", label, " ", _matches - before.x, "/", _pixels - before.y)
	image.save_png("res://.godot/porting-tests/pipes_%s.png" % label)
	if label == "editor_main":
		image.save_png("res://.godot/porting-tests/slice_pipes.png")


func park(player: Player, at: Vector2) -> void:
	release_input()
	player.state_machine.switch(PlayerIdleState)
	player.position = at
	player.previous_position = at
	player.velocity = Vector2.ZERO
