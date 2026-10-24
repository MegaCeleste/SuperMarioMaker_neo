# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Buzzy resource swaps, occupied shell recovery, ceiling drops and wing riding.

const FIXTURE := "res://tests/fixtures/port_slice.swe"
const BEETLE: BuzzyVariant = preload("res://resources/content/smw_buzzy_beetle.tres")
const EMPTY: BuzzyVariant = preload("res://resources/content/smw_buzzy_empty.tres")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await check_editor(false)
	await check_editor(true)
	await check_stomp_and_recovery()
	await check_shell_motion_and_carry()
	await check_ceiling()
	await check_wings()
	await check_projectiles_and_lifecycle()
	await finish("BUZZY_RESULT")


func make_level() -> Level:
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	var sub := level.current_sub_area
	for part in sub.get_parts().get_children():
		if not part is EditorPlayer and not part is StartingGround:
			sub.get_parts().remove_child(part)
			part.free()
	for x in range(12, 96):
		var ground := GroundPart.create()
		ground.position = Vector2(x * 16, -96)
		sub.add_part(ground)
	add_child(level)
	# Isolate flight/contact rules from the separately tested room activation.
	sub.actor_activity.enabled = false
	await ticks(8)
	return level


func ground_at(level: Level, pos: Vector2) -> void:
	var part := GroundPart.create()
	part.position = pos
	level.current_sub_area.add_part(part)
	part.load()
	part.build()


func beetle_at(level: Level, pos := Vector2(480, -96), wings := false, parachute := false) -> BuzzyBeetle:
	var body: BuzzyBeetle = load("res://scenes/entities/buzzy_beetle.tscn").instantiate()
	body.position = pos
	body.get_node("FlightComponent").wings = wings
	body.get_node("FlightComponent").parachute = parachute
	level.current_sub_area.add(body)
	return body


func shell_at(level: Level, pos := Vector2(480, -96), variant := BEETLE) -> KoopaShell:
	var shell: KoopaShell = load("res://scenes/entities/koopa_shell.tscn").instantiate()
	shell.position = pos
	shell.variant = variant
	level.current_sub_area.add(shell)
	return shell


func actors(level: Level, script: Script) -> Array:
	return level.current_sub_area.get_foreground().get_children().filter(
		func(node): return node.get_script() == script and not node.is_queued_for_deletion())


func park(player: Player, pos := Vector2(64, -16)) -> void:
	player.position = pos
	player.previous_position = player.global_position
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)


func check_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	for row in [[BEETLE.object_id, 400, 320, 1, 1], [EMPTY.object_id, 448, 320, 0, 1], [BEETLE.object_id, 496, 208, 0, 0]]:
		data.MAIN.NIVEL.append({"object": row[0], "x_pos": row[1], "y_pos": row[2],
			"wings": row[3], "paracaidas": row[4], "future_buzzy": "retain"})
	data.MAIN.SUELO.append({"x_pos": 496, "y_pos": 192, "index": 21})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for entry in data.S0.S4:
			entry.ID = entry.object
			entry.xx = entry.x_pos
			entry.yy = entry.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				entry.erase(key)
	var path := "res://.godot/porting-tests/buzzy_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var original: BuzzyPart
	var ceiling: BuzzyPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is BuzzyPart and part.wings:
			original = part
		elif part is BuzzyPart and part.position.x == 496:
			ceiling = part
	check(original != null and ceiling != null, "Both Buzzy resource IDs were not loaded")
	if original == null or ceiling == null:
		level.queue_free()
		await ticks(2)
		return
	check(ceiling.is_ceiling_attached() and ceiling.get_node("Graphics").get_child(0).flip_v,
			"Buzzy did not derive ceiling attachment from complete terrain")
	var editor := level.editor
	if not modern:
		var ring: PaletteRing = editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
		ring.category = load("res://resources/palette/category_terrain.tres")
		ring.choose(0)
		editor.place(Level.to_grid(ceiling.position + Vector2(0, 16)))
		check(not ceiling.is_ceiling_attached(), "Floor beneath Buzzy did not cancel ceiling attachment")
		editor.history.undo()
		check(ceiling.is_ceiling_attached(), "Terrain undo failed to restore ceiling attachment")
		ring.category = load("res://resources/palette/category_enemies.tres")
		check(ring.choose(2) and editor.get_selected_part() == BuzzyPart, "Buzzy palette still selects a disabled placeholder")
		original.held = true
		original.set_process(false)
		await ticks(40)
		check(original._window != null, "Buzzy long press did not open its native type window")
		if original._window != null:
			original._window.get_node("Content/Options/buzzy_empty").pressed.emit()
		original.held = false
		original.set_process(true)
		check(original.variant == EMPTY and not original.wings and original.parachute,
				"Empty-shell resource swap did not retain only the parachute")
		editor.history.undo()
		check(original.variant == BEETLE and original.wings and original.parachute,
				"Type-swap undo failed to restore dependent wing flags")
		editor.history.redo()
		check(original.variant == EMPTY and not original.wings and original.parachute,
				"Type-swap redo did not restore the complete changed state")
		check(original.get_modifiers().size() == 1 and original.get_modifiers()[0].id == &"parachute",
				"Empty-shell type incorrectly advertises wing attachment support")
		var next := editor.place(Vector2i(34, -8)) as BuzzyPart
		check(next.variant == BEETLE and not next.wings and not next.parachute,
				"Buzzy's object swap incorrectly changed subsequent card defaults")
	var expected := {}
	for part in level.current_sub_area.get_parts().get_children():
		if part is BuzzyPart:
			expected[part.position.x] = [part.variant.id, part.wings, part.parachute, part.is_ceiling_attached()]
	var result: Dictionary = await editor.save_to_path(path)
	check(result.error == OK, "Saving Buzzy parts failed")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var retained := 0
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is BuzzyPart:
			check(expected[part.position.x] == [part.variant.id, part.wings, part.parachute, part.is_ceiling_attached()],
					"Buzzy variant/attachment/ceiling state changed on signed SWE round-trip")
			retained += int(part.swe_data.has("future_buzzy"))
			check(int(part.swe_data.inup) == int(part.is_ceiling_attached()), "SWE saved a stale inup value")
	check(retained == 3, "Saving Buzzy parts discarded unknown source fields")
	add_child(reopened)
	check(actors(reopened, BuzzyBeetle).size() + actors(reopened, KoopaShell).size() == expected.size(),
			"Reopened Buzzy/empty-shell Parts did not build their runtimes")
	reopened.queue_free()
	level.queue_free()
	await ticks(2)


func check_stomp_and_recovery() -> void:
	var level := await make_level()
	var player := level.hud.player
	var beetle := beetle_at(level)
	await ticks(8)
	park(player, beetle.position + Vector2(-6, -48))
	player.state_machine.switch(PlayerFallingState)
	player.velocity.y = 120
	await ticks(22)
	var shells := actors(level, KoopaShell)
	check(not is_instance_valid(beetle) and shells.size() == 1 and actors(level, BeachKoopa).is_empty(),
			"Buzzy normal stomp must create an occupied shell without a beach Koopa")
	check(player.score == 200 and not player.is_dead(), "Buzzy stomp damaged Mario or scored more than once")
	if shells.size() == 1:
		var shell: KoopaShell = shells[0]
		check(shell.get_node("CollShape").shape.size == Vector2(12, 16), "Buzzy shell lost its 12px source mask")
		park(player)
		await ticks(510)
		check(is_instance_valid(shell) and shell.get_node("Graphics/Sprite").rotation == 0,
				"Buzzy shell warned before the original nine-second alarm")
		var shook := false
		for frame in 40:
			await ticks(1)
			shook = shook or (is_instance_valid(shell) and shell.get_node("Graphics/Sprite").rotation != 0)
		check(shook, "Occupied Buzzy shell did not warn before recovery")
		await ticks(100)
		check(not is_instance_valid(shell) and actors(level, BuzzyBeetle).size() == 1,
				"Buzzy shell did not restore its occupant at 640 source ticks")
	beetle = beetle_at(level, Vector2(900, -96))
	await ticks(5)
	park(player, beetle.position + Vector2(-6, -48))
	await ticks(1)
	player.state_machine.switch(PlayerSpinJumpingState)
	player.velocity.y = 120
	await ticks(22)
	check(not is_instance_valid(beetle) and actors(level, KoopaShell).is_empty() and player.score == 400,
			"Buzzy spin stomp failed to destroy it without shrinking to a shell")
	level.queue_free()
	await ticks(2)


func check_shell_motion_and_carry() -> void:
	var level := await make_level()
	var player := level.hud.player
	for x in [320, 640]:
		for y in range(-10, -6):
			ground_at(level, Vector2(x, y * 16))
	var shell := shell_at(level)
	await ticks(20)
	player.position.x = 450
	shell.launch(player)
	park(player)
	await ticks(660)
	check(is_instance_valid(shell) and shell.motion == KoopaShell.Motion.MOVING and actors(level, BuzzyBeetle).is_empty(),
			"Moving occupied shell woke despite its source moving-object lifecycle")
	level.queue_free()
	await ticks(2)
	level = await make_level()
	player = level.hud.player
	shell = shell_at(level)
	await ticks(20)
	Input.action_press("player_run")
	park(player, Vector2(470, -96))
	await ticks(4)
	check(player.held_item == shell, "Buzzy occupied shell could not be carried")
	await ticks(650)
	check(not is_instance_valid(shell) and player.held_item == null and actors(level, BuzzyBeetle).size() == 1,
			"Carried Buzzy failed to wake or left a dangling held-item reference")
	release_input()
	level.queue_free()
	await ticks(2)


func check_ceiling() -> void:
	var level := await make_level()
	for x in range(20, 40):
		ground_at(level, Vector2(x * 16, -240))
	var part := BuzzyPart.create()
	part.position = Vector2(480, -224)
	level.current_sub_area.add_part(part)
	part.load()
	part.build()
	await ticks(60)
	var bodies := actors(level, BuzzyBeetle)
	check(bodies.size() == 1 and bodies[0].ceiling and absf(bodies[0].position.y + 208) <= bodies[0].safe_margin + 0.001
			and bodies[0].get_node("Graphics/Sprite").flip_v,
			"Ceiling Buzzy failed to crawl under its support")
	if bodies.size() == 1:
		var beetle: BuzzyBeetle = bodies[0]
		park(level.hud.player, Vector2(beetle.position.x, -96))
		await ticks(2)
		check(not is_instance_valid(beetle) and actors(level, KoopaShell).size() == 1,
				"Buzzy did not drop an inverted shell on a player passing underneath")
		park(level.hud.player, Vector2(900, -96))
		await ticks(50)
		var shells := actors(level, KoopaShell)
		check(shells.size() == 1 and shells[0].inverted and shells[0].motion == KoopaShell.Motion.MOVING
				and shells[0].velocity.x == 150, "Ceiling drop failed to launch toward Mario on landing")
	level.reload()
	await ticks(8)
	check(actors(level, BuzzyBeetle).size() == 1, "Retry did not restore the saved ceiling Buzzy Part")
	level.queue_free()
	await ticks(2)


func check_wings() -> void:
	var level := await make_level()
	var player := level.hud.player
	var beetle := beetle_at(level, Vector2(640, -224), true)
	await ticks(5)
	park(player, beetle.position + Vector2(0, -64))
	player.state_machine.switch(PlayerFallingState)
	player.velocity.y = 120
	var rode := false
	var sank := false
	var rose := false
	for frame in 240:
		await ticks(1)
		rode = rode or (player.is_on_floor() and absf(player.get_platform_velocity().x + 30) < 1)
		sank = sank or beetle.velocity.y > 0
		rose = rose or beetle.velocity.y < 0
	check(rode and sank and rose and not player.is_dead() and player.score == 0,
			"Winged Buzzy is not a rideable native platform with loaded sink/rise behavior")
	check(absf(player.position.x - beetle.position.x) < 14 and player.position.x < 560,
			"Native Buzzy platform did not carry Mario horizontally")
	Input.action_press("player_jump")
	await ticks(6)
	Input.action_release("player_jump")
	await ticks(8)
	check(beetle.velocity.y == 0, "Unloaded winged Buzzy kept rising after Mario jumped off")
	park(player)
	beetle.queue_free()
	await ticks(2)
	check(level.current_sub_area.get_foreground().get_children().filter(
		func(n): return n.name == "BuzzyRidePlatform").is_empty(), "Winged Buzzy leaked its native one-way platform")
	beetle = beetle_at(level, Vector2(900, -224), true, true)
	await ticks(3)
	check(not beetle.get_node("FlightComponent").parachute and beetle.get_node("FlightComponent").wings,
			"Buzzy's no-gravity wing branch did not detach the combined parachute as in the source")
	beetle = beetle_at(level, Vector2(1200, -240), false, true)
	await ticks(90)
	check(beetle.velocity.y == 24 and beetle.get_node("Graphics").rotation == 0
			and beetle.get_node("Graphics/Sprite").sprite_frames.get_animation_speed(&"walk") == 9,
			"Unwinged parachute Buzzy lost its fall cap, fixed draw angle or source FPS")
	level.queue_free()
	await ticks(2)


func check_projectiles_and_lifecycle() -> void:
	var level := await make_level()
	var beetle := beetle_at(level, Vector2(540, -96))
	check(not beetle.hit_by_projectile(&"fire", 1) and not beetle.is_queued_for_deletion(), "Buzzy fireproof hit policy failed")
	var shell := shell_at(level, Vector2(460, -96))
	check(not shell.hit_by_projectile(&"fire", 1), "Buzzy shell lost fire resistance")
	await ticks(20)
	level.hud.player.position.x = 440
	shell.launch(level.hud.player)
	park(level.hud.player)
	await ticks(35)
	check(not is_instance_valid(beetle) and level.hud.player.score == 200, "Real moving shell failed to defeat fireproof Buzzy")
	beetle = beetle_at(level, Vector2(900, -96))
	beetle._stomped(level.hud.player)
	level.reload()
	await ticks(5)
	check(actors(level, KoopaShell).is_empty(), "Queued Buzzy shell leaked across a retry")
	beetle = beetle_at(level, Vector2(900, -224), true)
	var pending := level.current_sub_area._pending_spawns.values().duplicate()
	level.free()
	await ticks(2)
	for entry in pending:
		check(not is_instance_valid(entry.node), "Exiting leaked a pending Buzzy ride platform")
