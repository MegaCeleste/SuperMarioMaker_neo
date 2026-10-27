# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Door pairs: palette entry, paired placement/erase with history, the
## signed OpenWE PUERTAS row and a real trip through a door. With
## --capture-doors it also checks the curtain on real frames.

var capture := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-doors" in OS.get_cmdline_user_args()
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var editor := level.editor
	var area := level.current_sub_area
	for candidate in area.get_parts().get_children():
		if not (candidate is StartingGround or candidate is EditorPlayer):
			candidate.free()
	for x in range(96, 512, 16):
		var ground := GroundPart.create()
		ground.position = Vector2(x, -64)
		area.add_part(ground)
		ground.load()
	GroundPart.refresh_all(area.get_parts())
	await ticks(2)

	# Doors come in pairs and are erased together.
	var ring: PaletteRing = editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_gizmos.tres")
	check(ring.choose(1) and editor.get_selected_part() == DoorPart, "Door palette entry is not usable")
	editor.history.begin_stroke("Place")
	var door := editor.place(Vector2i(15, -6)) as DoorPart
	editor.history.end_stroke()
	var partner := door.get_exit() if door != null else null
	check(partner != null and partner.position == door.position + Vector2(32, 0), "Door did not add its partner")
	check(door.get_node("Graphics/Sprite").texture != null, "Door has no source art")
	editor.history.undo()
	check(door.get_parent() == null and partner.get_parent() == null, "Door placement undo kept a door")
	editor.history.redo()
	check(door.get_exit() == partner, "Door placement redo lost the pair")
	editor.erase_part(partner)
	check(door.get_parent() == null and partner.get_parent() == null, "Erasing one door kept the other")
	editor.history.undo()
	check(door.get_exit() == partner, "Door erase undo did not restore the pair")
	partner.position = Vector2(400, -96)

	# One OpenWE obj_door_res row stores the pair.
	var path := "res://.godot/porting-tests/doors.swe"
	var saved: Dictionary = await editor.save_to_path(path)
	check(saved.error == OK, "Door save failed: %s" % saved)
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(path)).data
	var rows: Array = data.MAIN.get("PUERTAS", [])
	check(rows.size() == 1 and rows[0].object == "obj_door_res" and rows[0].x_pos == door.position.x
			and rows[0].y_pos == door.position.y + 448 and rows[0].door_x == 400 and rows[0].door_y == -96 + 448,
			"Door pair was not saved as one OpenWE record: %s" % [rows])
	var reopened: Level = await LevelProcessor.from_swe(path)
	var doors: Array = reopened.current_sub_area.get_parts().get_children().filter(func(part): return part is DoorPart)
	check(doors.size() == 2 and doors[0].get_exit() == doors[1]
			and doors.any(func(part): return part.position == Vector2(400, -96)), "Reopened level lost the door pair")
	reopened.free()
	if capture:
		await snap("editor", level)

	# Play: up into one door, out of the other.
	area.get_parts().get_node("EditorPlayer").position = Vector2(64, -80)
	level.play()
	await ticks(4)
	var player := level.hud.player
	park(player, door.position + Vector2(8, 32))
	await ticks(2)
	Input.action_press("player_up")
	await ticks(3)
	release_input()
	check(player.state_machine.current_state is PlayerDoorState, "Pressing up in a door did not enter it")
	check(level.get_node("%LevelTimer").paused, "Level timer kept running inside the door")
	check(level.get_living_player() == null, "Enemies can still target Mario inside a door")
	if capture:
		await ticks(20)
		await snap("door_open", level)
		await ticks(35)
		await snap("curtain", level)
		await ticks(20)
		await snap("curtain_open", level)
	else:
		await ticks(60)
	check(player.global_position.is_equal_approx(partner.position + Vector2(8, 32)), "Door did not move Mario to its partner")
	# Control returns 25 ticks after arrival; the exit door refuses Mario for 40 more after closing.
	await ticks(26 if capture else 30)
	check(not player.is_traveling() and not level.get_node("%LevelTimer").paused, "Door did not return control")
	# Both doors refuse Mario for a moment after the trip.
	Input.action_press("player_up")
	await ticks(3)
	release_input()
	check(not player.is_traveling(), "A door accepted Mario again during its cooldown")
	level.edit()
	await ticks(2)
	if capture:
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("DOORS_RESULT", level)


func snap(label: String, level: Level) -> void:
	if level.status == Level.Status.EDITING:
		Utility.camera_position = Vector2(96, -230)
		await ticks(26)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if label.begins_with("curtain"):
		# Black first, then a hole around the arrival door (source obj_curtainin).
		var arrival := Vector2i(level.get_global_transform_with_canvas() * level.hud.player.global_position)
		check(image.get_pixel(20, 600).is_equal_approx(Color.BLACK), "Curtain %s does not cover the screen" % label)
		# Sky just above the 96px-tall door; the open door itself is dark inside.
		check(image.get_pixelv(arrival - Vector2i(0, 110)).is_equal_approx(Color.BLACK) == (label == "curtain"),
				"Curtain %s has the wrong state at the arrival point" % label)
	image.save_png("res://.godot/porting-tests/doors_%s.png" % label)
	if label == "door_open":
		image.save_png("res://.godot/porting-tests/slice_doors.png")


func park(player: Player, at: Vector2) -> void:
	release_input()
	player.state_machine.switch(PlayerIdleState)
	player.position = at
	player.previous_position = at
	player.velocity = Vector2.ZERO
