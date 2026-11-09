# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Lifts and bridges: palette entries, PLATAFORMAS save/reopen, a moving lift
## carrying Mario and turning back, a falling lift and a walkable bridge.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var area := level.current_sub_area
	for candidate in area.get_parts().get_children():
		if not (candidate is StartingGround or candidate is EditorPlayer):
			candidate.free()
	for x in range(48, 128, 16):
		_add(area, GroundPart.create(), Vector2(x, -64))
	GroundPart.refresh_all(area.get_parts())
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_gizmos.tres")
	check(ring.choose(6) and level.editor.get_selected_part() == LiftPart, "Lift palette entry is not usable")
	ring.category = load("res://resources/palette/category_terrain.tres")
	check(ring.choose(7) and level.editor.get_selected_part() == BridgePart, "Bridge palette entry is not usable")
	var moving := LiftPart.create()
	_add(area, moving, Vector2(160, -128))
	var falling := LiftPart.create()
	_add(area, falling, Vector2(320, -160))
	falling.set_variant(&"falling")
	var bridge := BridgePart.create()
	_add(area, bridge, Vector2(448, -128))
	bridge.set_variant(&"five")

	var path := "res://.godot/porting-tests/platforms.swe"
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Lift/bridge save failed: %s" % saved)
	var rows: Array = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(path)).data.MAIN.PLATAFORMAS
	var by_id := {}
	for row in rows:
		by_id[row.object] = row
	check(by_id.has("obj_platform_res") and int(by_id.obj_platform_res.direct_t) == 1
			and by_id.has("obj_platform_blue_res") and by_id.has("obj_puente_res")
			and int(by_id.obj_puente_res.width) == 5 and float(by_id.obj_puente_res.y_pos) == -112 + 432,
			"Lift or bridge rows are wrong: %s" % [rows])
	var reopened: Level = await LevelProcessor.from_swe(path)
	var kinds := []
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is LiftPart:
			kinds.append(part.kind)
		elif part is BridgePart:
			kinds.append("bridge%d" % part.width if part.position == Vector2(448, -128) else "bridge?")
	check(Lift.Kind.RIGHT in kinds and Lift.Kind.FALLING in kinds and "bridge5" in kinds, "Reopened lifts or bridge lost settings: %s" % [kinds])
	reopened.free()

	area.get_parts().get_node("EditorPlayer").position = Vector2(64, -80)
	level.play()
	await ticks(4)
	var player := level.hud.player
	var lifts := area.get_foreground().get_children().filter(func(node): return node is Lift)
	var ride: Lift = lifts.filter(func(lift): return lift.kind == Lift.Kind.RIGHT)[0] if not lifts.is_empty() else null
	var drop: Lift = lifts.filter(func(lift): return lift.kind == Lift.Kind.FALLING)[0] if lifts.size() > 1 else null
	check(ride != null and drop != null, "Lifts were not built")
	if ride == null or drop == null:
		await finish("PLATFORMS_RESULT", level)
		return

	# Mario rides the moving lift to the right.
	_stand(player, Vector2(ride.global_position.x + 32, ride.global_position.y - 4))
	await ticks(12)
	var start_x := player.global_position.x
	var lift_x := ride.global_position.x
	await ticks(30)
	check(player.is_on_floor() and ride.global_position.x > lift_x + 15 and player.global_position.x > start_x + 15,
			"The moving lift did not carry Mario")
	await ticks(90)
	check(ride._velocity.x < 0, "The moving lift did not turn back after 48px")

	# The falling lift drops 15 ticks after Mario stands on it.
	_stand(player, Vector2(drop.global_position.x + 32, drop.global_position.y - 4))
	await ticks(10)
	var top := drop.global_position.y
	await ticks(30)
	check(drop.global_position.y > top + 2, "The falling lift did not fall under Mario")

	# The bridge holds Mario on its surface line.
	_stand(player, Vector2(488, -120))
	await ticks(20)
	check(player.is_on_floor() and absf(player.global_position.y + 112) < 1, "Mario does not stand on the bridge")
	level.edit()
	await ticks(2)
	await finish("PLATFORMS_RESULT", level)


func _stand(player: Player, at: Vector2) -> void:
	release_input()
	player.state_machine.switch(PlayerFallingState)
	player.global_position = at
	player.previous_position = at
	player.velocity = Vector2.ZERO


func _add(area: SubArea, part: Part, at: Vector2) -> void:
	part.position = at
	area.add_part(part)
	part.load()
