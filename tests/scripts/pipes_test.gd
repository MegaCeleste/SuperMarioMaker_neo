# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Main world / sub-world switching, pipes that cross between the worlds and
## same-world door pairs: editor, history, signed SWE and real play. With
## --capture-pipes-doors it also checks source pipe pixels on real frames.

var capture := false
var _pixels := 0
var _matches := 0
## Sampled pixel count per view; pipe views must all sample something.
var _views := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-pipes-doors" in OS.get_cmdline_user_args()
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

	# Palette entries.
	var ring: PaletteRing = editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_terrain.tres")
	check(ring.choose(3) and editor.get_selected_part() == PipePart, "Pipe palette entry is not usable")
	var pipe := editor.place(Vector2i(10, -6)) as PipePart
	check(pipe != null and pipe.get_size() == Vector2(32, 32), "Placed pipe is not a 32x32 head")
	check(pipe.get_node("Graphics/Sprite").texture != null, "Pipe has no source art")

	# Opening drag: lengthen upward from the fixed base, then shrink back.
	pipe.begin_resize()
	pipe.resize_to(Vector2(176, -128))
	check(pipe.segments == 2 and pipe.position == Vector2(160, -128), "Opening drag did not lengthen the pipe upward")
	pipe.resize_to(Vector2(176, -96))
	check(pipe.segments == 0 and pipe.position == Vector2(160, -96), "Opening drag did not shorten the pipe")
	pipe.end_resize()
	check(not editor.history.can_redo(), "Pipe resize history is inconsistent")
	# A head-only pipe turns when its opening is dragged sideways.
	pipe.begin_resize()
	pipe.resize_to(Vector2(240, -72))
	check(pipe.facing == PipePart.Facing.RIGHT, "Head-only pipe did not turn right")
	pipe.end_resize()
	editor.history.undo()
	check(pipe.facing == PipePart.Facing.UP and pipe.position == Vector2(160, -96), "Pipe turn undo failed")
	check(pipe.get_variants().size() == 4 and pipe.get_variant() == &"green", "Pipe colors are not offered")

	# Pairing with a pipe in the other world; undo shows that world first.
	var exit := PipePart.create()
	exit.position = Vector2(320, -96)
	sub.add_part(exit)
	exit.load()
	editor.history.link_pipes(pipe, exit)
	check(pipe.get_exit() == exit and exit.get_exit() == pipe and pipe.has_modifier(&"link"), "Pipes did not pair")
	editor.switch_world()
	editor.history.undo()
	check(level.current_sub_area == main and pipe.get_exit() == null, "Pair undo did not show the main world and unpair")
	editor.history.redo()
	check(pipe.get_exit() == exit, "Pair redo failed")
	editor.erase_part(pipe)
	check(exit.get_exit() == null, "Erasing a pipe left its partner paired")
	editor.history.undo()
	check(exit.get_exit() == pipe, "Undoing the erase did not restore the pair")

	# Doors come in pairs and are erased together.
	ring.category = load("res://resources/palette/category_gizmos.tres")
	check(ring.choose(1) and editor.get_selected_part() == DoorPart, "Door palette entry is not usable")
	editor.history.begin_stroke("Place")
	var door := editor.place(Vector2i(25, -6)) as DoorPart
	editor.history.end_stroke()
	var partner := door.get_exit() if door != null else null
	check(partner != null and partner.position == door.position + Vector2(32, 0), "Door did not add its partner")
	editor.history.undo()
	check(door.get_parent() == null and partner.get_parent() == null, "Door placement undo kept a door")
	editor.history.redo()
	editor.erase_part(partner)
	check(door.get_parent() == null and partner.get_parent() == null, "Erasing one door kept the other")
	editor.history.undo()
	check(door.get_exit() == partner, "Door erase undo did not restore the pair")

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

	# Signed save keeps both worlds, the pipe pair and the door pair.
	var path := "res://.godot/porting-tests/pipes_doors.swe"
	var saved: Dictionary = await editor.save_to_path(path)
	check(saved.error == OK, "Pipe/door save failed: %s" % saved)
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(path)).data
	check(data.has("SUB1") and data.SUB1.TUBERIAS.size() == 1, "Sub-world pipe was not saved in SUB1")
	var row: Dictionary = data.MAIN.TUBERIAS[0] if not data.MAIN.TUBERIAS.is_empty() else {}
	row = {} if data.MAIN.TUBERIAS.is_empty() else data.MAIN.TUBERIAS.filter(func(r): return r.smmneo_link > 0)[0]
	check(row.get("warp") == 0 and row.get("smmneo_link", 0) > 0
			and row.smmneo_link == data.SUB1.TUBERIAS[0].smmneo_link, "Pipe pair fields are wrong: %s" % row)
	check(data.MAIN.PUERTAS.size() == 1 and data.MAIN.PUERTAS[0].door_x == partner.position.x,
			"Door pair was not saved as one OpenWE record")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var pipes := {}
	var doors := 0
	for area in reopened.get_children():
		if area is SubArea:
			for part in area.get_parts().get_children():
				if part is PipePart:
					pipes[part] = area
				doors += int(part is DoorPart)
	var reloaded_pair := false
	for part: PipePart in pipes:
		reloaded_pair = reloaded_pair or (part.get_exit() != null and pipes.get(part.get_exit()) != pipes[part])
	check(pipes.size() == (6 if capture else 2) and reloaded_pair and doors == 2, "Reopened level lost a world, pipe pair or door pair")
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
	if capture:
		await ticks(12)
		await snap("entering", level)
		await ticks(26)
		await snap("curtain", level)
		await ticks(20)
		await snap("curtain_open", level)
	else:
		await ticks(40)
	check(level.current_sub_area == sub and player.sub_area == sub and sub.get_foreground().is_ancestor_of(player),
			"Mario did not cross to the sub-world")
	check(level.get_node_or_null("CurtainTransition") != null, "No curtain opened on arrival")
	await ticks(70)
	check(not player.is_traveling() and absf(player.global_position.x - 336) < 1
			and absf(player.global_position.y + 96) < 1, "Mario did not come out on top of the sub-world pipe")
	check(player.collision_layer != 0 and player.visible, "Mario's collisions were not restored after the pipe")
	Input.action_press("player_down")
	await ticks(110)
	release_input()
	check(level.current_sub_area == main and absf(player.global_position.x - 176) < 1, "Return trip failed")

	# A door pair moves Mario within the main world.
	park(player, door.position + Vector2(8, 32))
	await ticks(2)
	Input.action_press("player_up")
	await ticks(3)
	release_input()
	check(player.state_machine.current_state is PlayerDoorState, "Pressing up in a door did not enter it")
	check(level.get_node("%LevelTimer").paused, "Level timer kept running inside the door")
	if capture:
		await ticks(20)
		await snap("door_open", level)
		await ticks(40)
	else:
		await ticks(60)
	check(player.global_position.is_equal_approx(partner.position + Vector2(8, 32)), "Door did not move Mario to its partner")
	await ticks(30)
	check(not player.is_traveling() and not level.get_node("%LevelTimer").paused, "Door did not return control")

	# Returning to the editor resumes in the world Mario ended in.
	level.edit()
	await ticks(2)
	check(level.current_sub_area == main and level.get_editor_player().sub_area == main, "Edit did not resume in Mario's world")
	if capture:
		for view in ["editor_main", "editor_sub", "entering"]:
			check(_views.get(view, 0) > 20, "Capture view %s sampled too few pipe pixels" % view)
		check(_matches == _pixels, "Pipe source pixels differ on screen: %d/%d" % [_matches, _pixels])
		print("PIPES_DOORS_PIXELS ", _matches, "/", _pixels)
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("PIPES_DOORS_RESULT", level)


## Saves a real frame and compares every opaque source pipe pixel with the
## screen. Editor Parts and play-time pipes draw the same composed texture.
func snap(label: String, level: Level) -> void:
	if level.status == Level.Status.EDITING:
		Utility.camera_position = Vector2(16, -300) if label == "editor_main" else Vector2(176, -230)
		await ticks(26)
	var sampled := []
	var sample := func():
		var sprites: Array = []
		for node in level.current_sub_area.find_children("Sprite", "Sprite2D", true, false):
			if node.get_parent() is WarpPipe or (node.get_parent().get_parent() is PipePart
					and level.status == Level.Status.EDITING):
				sprites.append(node)
		for sprite: Sprite2D in sprites:
			sampled.append({"image": sprite.texture.get_image(), "transform": sprite.get_global_transform_with_canvas(),
					"centered": sprite.centered})
	RenderingServer.frame_pre_draw.connect(sample, CONNECT_ONE_SHOT)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var before := Vector2i(_matches, _pixels)
	if label.begins_with("curtain"):
		# Black first, then a hole around the arrival opening (source obj_curtainin).
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
		print("PIPES_DOORS_VIEW ", label, " ", _matches - before.x, "/", _pixels - before.y)
	image.save_png("res://.godot/porting-tests/pipes_doors_%s.png" % label)
	if label == "entering":
		image.save_png("res://.godot/porting-tests/slice_pipes_doors.png")


func park(player: Player, at: Vector2) -> void:
	release_input()
	player.state_machine.switch(PlayerIdleState)
	player.position = at
	player.previous_position = at
	player.velocity = Vector2.ZERO
