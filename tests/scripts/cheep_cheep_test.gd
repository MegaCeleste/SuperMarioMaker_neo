# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Source swimmer/jump trajectories, real contacts and native editor/SWE flow.

const FIXTURE := "res://tests/fixtures/port_slice.swe"
const RED: CheepCheepVariant = preload("res://resources/content/smw_cheep_cheep_red.tres")
const YELLOW: CheepCheepVariant = preload("res://resources/content/smw_cheep_cheep_yellow.tres")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await check_editor(false)
	await check_editor(true)
	for variant in [RED, YELLOW]:
		await check_swimming(variant)
		await check_jumps(variant)
		for water in [false, true]:
			for spin in [false, true]:
				await check_contact(variant, water, spin, false)
				await check_contact(variant, water, spin, true)
		await check_contact(variant, false, false, false, true)
	await check_mask_and_terrain()
	await check_flight()
	await check_partial_water()
	await check_projectiles_and_helmets()
	await check_blocks()
	await check_defeat_and_cleanup()
	await finish("CHEEP_CHEEP_RESULT")


func make_level(theme := Level.LevelTheme.OVERWORLD, night := false) -> Level:
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	var sub := level.current_sub_area
	for part in sub.get_parts().get_children():
		if not part is EditorPlayer and not part is StartingGround:
			part.free()
	for x in range(12, 80):
		var ground := GroundPart.create()
		ground.position = Vector2(x * 16, -96)
		sub.add_part(ground)
	sub.level_theme = theme
	sub.night_mode = night
	sub.water_start_y = -112
	sub.water_limit_y = -112
	add_child(level)
	# Long swimming/glide oracles use source instance_deactivate=0.
	sub.actor_activity.enabled = false
	await ticks(8)
	return level


func actor_at(level: Level, variant := RED, pos := Vector2(480, -96), wings := false, parachute := false) -> CheepCheep:
	var body: CheepCheep = load("res://scenes/level/entities/cheep_cheep.tscn").instantiate()
	body.variant = variant
	body.position = pos
	body.wings = wings
	body.parachute = parachute
	level.current_sub_area.add(body)
	return body


func park(player: Player, at := Vector2(64, -16)) -> void:
	release_input()
	player.position = at
	player.previous_position = player.global_position
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)


func actors(level: Level, script: Script) -> Array:
	return level.current_sub_area.get_foreground().get_children().filter(
		func(n): return n.get_script() == script and not n.is_queued_for_deletion())


func click(button: Button) -> void:
	var at := button.get_global_transform_with_canvas() * (button.size / 2)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await ticks(1)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	get_viewport().push_input(event, true)
	await ticks(1)


func check_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	data.MAIN.AJUSTES[0].entorno = "forest"
	data.MAIN.AJUSTES[0].water_level = 280
	data.MAIN.AJUSTES[0].water_level_limit = 240
	data.MAIN.AJUSTES[0].water_level_speed = 0.5
	data.MAIN.AJUSTES[0].future_water = {"keep": true}
	data.MAIN.NIVEL.append({"object": RED.object_id, "x_pos": 400, "y_pos": 352,
		"wings": 1, "paracaidas": 1, "direct_t": 2, "modo_water": 99, "future_fish": {"nested": 17}})
	data.MAIN.NIVEL.append({"object": YELLOW.object_id, "x_pos": 528, "y_pos": 256})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/cheep_cheep_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var imported: CheepCheepPart
	var yellow: CheepCheepPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is CheepCheepPart:
			if part.variant == RED:
				imported = part
			else:
				yellow = part
	check(imported != null and yellow != null, "SWE did not restore both Cheep Cheep resource IDs")
	check(imported.wings and imported.parachute and imported.is_in_water() and not yellow.is_in_water(),
			"Imported flags or source editor water-depth threshold changed")
	check(imported.get_node("Graphics/Sprite").texture.resource_path.ends_with("frame_002.png")
			and imported.get_node("Graphics/Sprite").position == Vector2(-0.5, 0.5),
			"Fish preview lost SMW frame2, horizontal origin or one-pixel placement overlap")
	check(imported._decoration.get_child_count() == 2, "Native editor decorations are missing")
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	check(ring.choose(6) and level.editor.get_selected_part() == CheepCheepPart, "Cheep Cheep palette slot6 is disabled")
	var placed := level.editor.place(Vector2i(28, -6)) as CheepCheepPart
	check(placed.variant == RED and not placed.wings and not placed.parachute, "New fish inherited stale type/attachment flags")
	level.editor.history.undo()
	check(not placed.is_inside_tree(), "Undo failed to remove a placed fish")
	level.editor.history.redo()
	check(placed.is_inside_tree(), "Redo failed to restore a placed fish")
	level.editor.set_part_modifier(placed, &"wings", true)
	level.editor.set_part_modifier(placed, &"parachute", true)
	placed.held = true
	placed.set_process(false)
	await ticks(45)
	check(is_instance_valid(placed._window), "Fish long press failed to open its native type window")
	if is_instance_valid(placed._window):
		await click(placed._window.get_node("Content/Attachments/parachute"))
		check(not placed.parachute and placed.wings, "Actual GUI toggle failed to change parachute independently")
		await click(placed._window.get_node("Content/Attachments/parachute"))
		await click(placed._window.get_node("Content/Options/yellow"))
	placed.held = false
	placed.set_process(true)
	check(placed.variant == YELLOW and placed.wings and not placed.parachute,
			"Source type swap must retain wings and remove parachute")
	level.editor.history.undo()
	check(placed.variant == RED and placed.wings and placed.parachute, "Dependent type undo lost the parachute")
	level.editor.history.redo()
	check(placed.variant == YELLOW and placed.wings and not placed.parachute, "Dependent type redo changed attachment state")
	check(level.editor.get_palette_icon(CheepCheepPart) == YELLOW.icon, "Fish card did not retain the chosen type")
	var next := level.editor.place(Vector2i(38, -6)) as CheepCheepPart
	check(next.variant == YELLOW and not next.wings and not next.parachute, "Subsequent fish placement ignored its source card default")
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Fish editor failed signed SWE saving")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var counts := {&"red": 0, &"yellow": 0}
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is CheepCheepPart:
			counts[part.variant.id] += 1
			if part.position.x == 400:
				check(part.wings and part.parachute and part.swe_data.direct_t == 2
						and part.swe_data.future_fish.nested == 17 and part.swe_data.modo_water == 1,
						"Fish round-trip lost unknown fields/attachments or failed to derive modo_water")
	check(counts == {&"red": 1, &"yellow": 3}, "Fish types/counts changed across reopen")
	check(reopened.current_sub_area.water_start_y == -152 and reopened.current_sub_area.water_limit_y == -192
			and reopened.current_sub_area.water_speed == Level.WaterSpeed.MEDIUM,
			"SWE water positions/speed lost source-to-native conversion")
	var decoded: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(path)).data
	var wrapper: Dictionary = decoded.get("S0", decoded.get("MAIN", {}))
	check(wrapper.get("S1", wrapper.get("AJUSTES", []))[0].future_water.keep, "Water metadata round-trip lost retained fields")
	add_child(reopened)
	await ticks(4)
	check(actors(reopened, CheepCheep).size() == 4, "Reopened fish Parts did not build their native runtimes")
	reopened.queue_free()
	level.queue_free()
	await ticks(2)


func check_swimming(variant: CheepCheepVariant) -> void:
	var level := await make_level(Level.LevelTheme.UNDERWATER)
	var body := actor_at(level, variant, Vector2(700, -160))
	await ticks(3)
	check(body.velocity == Vector2.ZERO, "Fish moved before the source four-tick start alarm")
	await ticks(1)
	check(body.velocity == Vector2(-30, 0) and body.position == Vector2(699.5, -160), "Fish did not begin constant0.5/frame leftward swimming")
	await ticks(239)
	check(body.velocity.x == -30 and absf(body.position.x - 580) < 0.02 and body.position.y == -160,
			"Swimming trajectory drifted or yellow fish reversed before240 ticks")
	await ticks(1)
	check(body.velocity.x == (30 if variant == YELLOW else -30), "Fish source type-specific240-tick reversal changed")
	if variant == YELLOW:
		check(not body.get_node("Graphics/Sprite").flip_h, "Yellow fish did not face its reversed motion")
	level.queue_free()
	await ticks(2)


func check_jumps(variant: CheepCheepVariant) -> void:
	var level := await make_level()
	park(level.hud.player, Vector2(1000, -300))
	level.hud.player.set_physics_process(false)
	var body := actor_at(level, variant, Vector2(500, -80))
	await ticks(10)
	check(absf(body.position.y + 73.4) < 0.02 and body.velocity == Vector2(0, 72),
			"Air fish lost source0.12/frame² falling before its first jump")
	var previous := body.jump_index
	var launches: Array[Vector2] = []
	for frame in 300:
		await ticks(1)
		if body.jump_index != previous:
			launches.append(body.velocity)
			previous = body.jump_index
			if launches.size() == 3:
				break
	check(launches.size() == 3, "Air fish did not repeat two small jumps then one large jump at room bottom")
	if launches.size() == 3:
		check(absf(launches[0].y + 172.8) < 0.02 and absf(launches[1].y + 172.8) < 0.02
				and absf(launches[2].y + 292.8) < 0.02, "Fish launch impulse or source gravity order changed")
		check(launches[0].x == (-30 if variant == YELLOW else -48)
				and launches[2].x == (30 if variant == YELLOW else -48), "Yellow large-jump aiming or red direction/speed changed")
	level.queue_free()
	await ticks(2)


func check_contact(variant: CheepCheepVariant, water: bool, spin: bool, wings: bool, from_right := false) -> void:
	var level := await make_level(Level.LevelTheme.UNDERWATER if water else Level.LevelTheme.OVERWORLD)
	var player := level.hud.player
	var body := actor_at(level, variant, Vector2(480, -96), wings)
	body.set_physics_process(false)
	park(player, Vector2(486 if from_right else 474, -126 if water else -144))
	player.state_machine.switch(PlayerFallingState)
	await ticks(1)
	if spin:
		player.state_machine.switch(PlayerSpinJumpingState)
	player.velocity.y = 120
	var bounced := false
	for frame in 24:
		await ticks(1)
		bounced = bounced or player.velocity.y < 0
	if water:
		check(player.is_dead() and is_instance_valid(body) and not bounced and player.score == 0,
				"Underwater fish allowed normal/spin/wing stripping instead of damage")
	elif wings and not spin:
		check(is_instance_valid(body) and not body.wings and bounced and player.score == 200,
				"Normal winged-fish stomp did not strip wings and preserve the body")
		check(actors(level, DetachedEnemyAttachment).size() == 1, "Fish stripped the wrong number of wings")
	else:
		check(not is_instance_valid(body) and not player.is_dead() and bounced and player.score == 200,
				"Fish air contact did not perform a normal/spin defeat")
		check(actors(level, SwimmingEnemyDefeat).size() == (0 if spin else 1), "Fish used the wrong normal/spin defeat path")
		if not spin:
			var effect: SwimmingEnemyDefeat = actors(level, SwimmingEnemyDefeat)[0]
			check(effect.velocity.x == (-60 if from_right else 60) and signf(effect.rotation) == (-1 if from_right else 1),
					"Normal fish stomp must retain Other_10's bbox-directed horizontal spinning death")
	level.queue_free()
	await ticks(2)


func check_mask_and_terrain() -> void:
	var level := await make_level()
	var body := actor_at(level, RED, Vector2(400, -160))
	body.set_physics_process(false)
	await ticks(2)
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 2
	query.position = body.global_position + Vector2(0, -8)
	check(not body.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "Precise native fish mask lost its center")
	query.position = body.global_position + Vector2(-7.5, -15.5)
	check(body.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "Fish transparent source corner became a solid rectangular contact")
	body.set_physics_process(true)
	await ticks(40)
	check(absf(body.position.y + 63.88) < 0.03 and absf(body.velocity.y - 247.2) < 0.02
			and body.collision_mask == 0 and not body.is_on_floor(),
			"Fish failed its40-tick capped fall through terrain: %s / %s" % [body.position, body.velocity])
	level.queue_free()
	await ticks(2)


func check_flight() -> void:
	var level := await make_level(Level.LevelTheme.UNDERWATER)
	var body := actor_at(level, RED, Vector2(700, -160), true)
	var minimum := 0.0
	var maximum := 0.0
	for frame in 300:
		await ticks(1)
		minimum = minf(minimum, body.position.y + 160)
		maximum = maxf(maximum, body.position.y + 160)
	check(minimum < -16 and maximum > 16 and minimum > -27 and maximum < 27,
			"Winged fish did not oscillate around its source start±16px band")
	body.queue_free()
	body = actor_at(level, RED, Vector2(700, -160), true, true)
	await ticks(10)
	check(not body.parachute and body.velocity.x == 0, "Underwater parachute failed immediate detach/delayed start")
	await ticks(1)
	check(body.velocity.x == -30 and body.velocity.y == 30, "Detached fish ignored its10-tick restart alarm")
	level.queue_free()
	await ticks(2)
	level = await make_level()
	level.hud.player.set_physics_process(false)
	body = actor_at(level, RED, Vector2(500, -200), false, true)
	await ticks(100)
	check(body.parachute and body.position.y < -145 and body.velocity.y == 30 and absf(body.position.x - 500) < 27
			and body.direction == -1 and body.get_node("Graphics").rotation == 0,
			"Fish parachute used generic gravity/rotation or lost its source horizontal sway")
	body.queue_free()
	body = actor_at(level, RED, Vector2(500, -4), false, true)
	await ticks(20)
	check(not body.parachute and body.jump_index == 1 and body.velocity.y < 0, "Parachute failed to detach on an actual room-bottom jump")
	body.queue_free()
	body = actor_at(level, YELLOW, Vector2(700, -16), true)
	var saw_glide := false
	var ended := false
	var start_tick := 0
	for frame in 420:
		await ticks(1)
		if not saw_glide and body.gliding:
			saw_glide = true
			start_tick = frame
			check(absf(body.velocity.x) == 12 and body.velocity.y == -18,
					"Third-jump wing glide lost its source0.2/-0.3 speeds")
		elif saw_glide and not body.gliding:
			ended = true
			check(frame - start_tick == 120, "Fish wing glide did not expire after120 ticks")
			break
	check(saw_glide and ended, "Winged fish never entered/completed its third-jump glide")
	level.queue_free()
	await ticks(2)


func check_partial_water() -> void:
	for theme in [Level.LevelTheme.FOREST, Level.LevelTheme.BEACH, Level.LevelTheme.CASTLE]:
		var level := await make_level(theme)
		var sub := level.current_sub_area
		check(is_instance_valid(sub.liquid), "Fish theme is missing its native liquid surface")
		var part := CheepCheepPart.create()
		part.position = Vector2(480, -96 if theme == Level.LevelTheme.CASTLE else -80)
		sub.add_part(part)
		part.load()
		part.build()
		await ticks(6)
		var body: CheepCheep = actors(level, CheepCheep)[0]
		if theme == Level.LevelTheme.CASTLE:
			check(not body.water_mode and body.jump_index > 0 and body.lava
					and body.stomp_behavior == Enemy.Stompability.NONE and body.has_node("Graphics/LavaAura"),
					"Castle fish did not jump from real lava and acquire its damaging aura")
		else:
			check(body.water_mode and body.velocity.y == 0 and body.velocity.x == -30,
					"Forest/beach placement failed to derive swimmer mode from source depth")
			check(body.stomp_behavior == (Enemy.Stompability.NONE if theme == Level.LevelTheme.FOREST else Enemy.Stompability.STOMPABLE),
					"Fish partial-water contact lost the source forest/beach distinction")
		level.queue_free()
		await ticks(2)
	var level := await make_level(Level.LevelTheme.FOREST, true)
	var body := actor_at(level, YELLOW, Vector2(500, -70))
	await ticks(1)
	check(body.lava and body.has_node("Graphics/LavaAura"), "Night forest fish did not acquire its purple aura")
	level.queue_free()
	await ticks(2)


func check_projectiles_and_helmets() -> void:
	var level := await make_level()
	var player := level.hud.player
	var body := actor_at(level)
	check(body.hit_by_projectile(&"fire", 1), "Cheep Cheep incorrectly acquired fire resistance")
	body = actor_at(level, YELLOW, Vector2(500, -96))
	body.set_physics_process(false)
	var shell: KoopaShell = load("res://scenes/level/entities/koopa_shell.tscn").instantiate()
	shell.position = Vector2(440, -96)
	level.current_sub_area.add(shell)
	await ticks(20)
	player.position.x = 420
	shell.launch(player)
	park(player)
	await ticks(28)
	check(not is_instance_valid(body) and player.score == 200, "Actual moving shell failed to defeat/score the fish")
	shell.queue_free()
	for spiny in [false, true]:
		park(player, Vector2(400, -96))
		player.invulnerability_left = 0
		var helmet: HelmetRules = load("res://resources/content/smw_helmet_spiny_rules.tres" if spiny else "res://resources/content/smw_helmet_rules.tres")
		check(player.equip_shell_helmet(helmet), "Could not equip the fish test helmet")
		body = actor_at(level, RED, Vector2(400, -170))
		var deflected := false
		for frame in 65:
			await ticks(1)
			deflected = deflected or (is_instance_valid(body) and body.velocity.y < 0)
			if (spiny and not is_instance_valid(body)) or (not spiny and deflected):
				break
		check(player.has_helmet() and not player.is_dead() and ((not is_instance_valid(body)) if spiny else deflected),
				"Fish ignored Buzzy helmet deflection or Spiny helmet defeat")
		if is_instance_valid(body):
			body.queue_free()
		player.damage()
	level.queue_free()
	await ticks(2)


func check_blocks() -> void:
	var level := await make_level()
	var part := QuestionBlockPart.create()
	part.position = Vector2(472, -144)
	level.current_sub_area.add_part(part)
	part.load()
	part.build()
	var body := actor_at(level, RED, Vector2(480, -144))
	var player := level.hud.player
	park(player, Vector2(480, -96))
	await ticks(3)
	Input.action_press("player_jump")
	await ticks(22)
	release_input()
	check(player.coins == 1 and player.score == 400 and not is_instance_valid(body),
			"Physical question-block bump failed to defeat/score the fish")
	level.queue_free()
	await ticks(2)


func check_defeat_and_cleanup() -> void:
	for water in [false, true]:
		var level := await make_level(Level.LevelTheme.UNDERWATER if water else Level.LevelTheme.OVERWORLD)
		var body := actor_at(level, YELLOW, Vector2(300, -220), true, true)
		body.kill(-1)
		await ticks(2)
		var effects := actors(level, SwimmingEnemyDefeat)
		check(effects.size() == 1 and actors(level, DetachedEnemyAttachment).size() == 1, "Fish defeat/wing effect was not owned and inserted")
		if effects.size() == 1:
			var effect: SwimmingEnemyDefeat = effects[0]
			var sprite: AnimatedSprite2D = effect.get_child(0)
			check(sprite.frame == 2 and sprite.sprite_frames.get_frame_texture(&"default", 2).resource_path.contains("spr_cheepcheep2_deads")
					and effect.velocity.x == -60 and effect.velocity.y < (-80 if water else -200) and effect.rotation < 0,
					"Fish defeat lost typed source art, launch or signed spinning")
			await ticks(45)
			check(effect.velocity.y <= (61.21 if water else 252.01), "Fish defeat lost its air/water cap-before-gravity order")
		level.reload()
		await ticks(5)
		check(actors(level, SwimmingEnemyDefeat).is_empty() and actors(level, DetachedEnemyAttachment).is_empty(), "Fish effects leaked into retry")
		body = actor_at(level, RED, Vector2(300, -200), true, true)
		body.kill()
		var pending := level.current_sub_area._pending_spawns.values().duplicate()
		level.free()
		await ticks(2)
		for entry in pending:
			check(not is_instance_valid(entry.node), "Area exit leaked a pending fish effect")
