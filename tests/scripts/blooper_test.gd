extends "res://tests/scripts/port_test.gd"
## Source jet/cooldown tracking, ellipse contacts, air/water policy and native SWE.

const FIXTURE := "res://tests/fixtures/port_slice.swe"
const RULES: BlooperRules = preload("res://resources/content/smw_blooper.tres")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await check_editor(false)
	await check_editor(true)
	await check_jet_cycle()
	await check_initial_height_cases()
	await check_ellipse_and_solids()
	for water in [false, true]:
		for spin in [false, true]:
			await check_contact(water, spin)
	await check_projectiles_and_helmets()
	await check_blocks()
	await check_defeat_and_cleanup()
	await finish("BLOOPER_RESULT")


func make_level(water := false) -> Level:
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	var sub := level.current_sub_area
	for part in sub.get_parts().get_children():
		if not part is EditorPlayer and not part is StartingGround:
			part.free()
	for x in range(12, 80):
		var ground := GroundPart.create()
		ground.position = Vector2(x * 16, -96)
		sub.add_part(ground)
	if water:
		sub.level_theme = Level.LevelTheme.UNDERWATER
	add_child(level)
	await ticks(8)
	return level


func park(player: Player, pos := Vector2(64, -16)) -> void:
	release_input()
	player.position = pos
	player.previous_position = player.global_position
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)


func actor_at(level: Level, pos := Vector2(480, -96)) -> Blooper:
	var actor: Blooper = load("res://scenes/entities/blooper.tscn").instantiate()
	actor.position = pos
	level.current_sub_area.add(actor)
	return actor


func actors(level: Level, script: Script) -> Array:
	return level.current_sub_area.get_foreground().get_children().filter(
		func(n): return n.get_script() == script and not n.is_queued_for_deletion())


func check_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	data.MAIN.NIVEL.append({"object": "obj_blooper_res", "x_pos": 400, "y_pos": 288,
		"wings": 1, "paracaidas": 1, "direct_t": 2, "future_blooper": {"nested": 17}})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/blooper_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var part: BlooperPart
	for item in level.current_sub_area.get_parts().get_children():
		if item is BlooperPart:
			part = item
	check(part != null, "Blooper SWE resource was not mapped to its native Part")
	if part == null:
		level.queue_free()
		await ticks(2)
		return
	check(part.get_variants().is_empty() and part.get_modifiers().is_empty(),
			"Blooper advertises a window/attachments absent from the source")
	var preview: Sprite2D = part.get_node("Graphics/Sprite")
	check(preview.texture.resource_path.ends_with("frame_002.png") and preview.position.y == -2,
			"Blooper editor art lost its SMW frame or one-pixel placement overlap")
	check(part._decoration.get_child_count() == 2, "Legacy Blooper attachment drawings were discarded")
	if not modern:
		var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
		ring.category = load("res://resources/palette/category_enemies.tres")
		check(ring.choose(5) and level.editor.get_selected_part() == BlooperPart, "Blooper palette is still disabled")
		var next := level.editor.place(Vector2i(34, -9)) as BlooperPart
		check(next != null and next._decoration.get_child_count() == 0, "New Blooper inherited stale imported attachment flags")
		level.editor.history.undo()
		check(not next.is_inside_tree(), "Undo did not remove the placed Blooper")
		level.editor.history.redo()
		check(next.is_inside_tree(), "Redo did not restore the placed Blooper")
		part.held = true
		part.set_process(false)
		await ticks(40)
		check(part._window == null, "Long press created an invented Blooper window")
		part.held = false
		part.set_process(true)
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Native Blooper failed signed SWE saving")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var count := 0
	for item in reopened.current_sub_area.get_parts().get_children():
		if item is BlooperPart:
			count += 1
			if item.position.x == 400:
				check(item.swe_data.wings == 1 and item.swe_data.paracaidas == 1 and item.swe_data.direct_t == 2
						and item.swe_data.future_blooper.nested == 17,
						"Blooper save rewrote unpassed legacy flags or unknown fields")
	check(count == (1 if modern else 2), "Blooper placement count changed after reopen")
	add_child(reopened)
	await ticks(4)
	check(actors(reopened, Blooper).size() == count, "Reopened Blooper Parts failed to build")
	for body: Blooper in actors(reopened, Blooper):
		check(not body.has_node("FlightComponent"), "Blooper incorrectly simulates saved wing/parachute flags")
	reopened.queue_free()
	level.queue_free()
	await ticks(2)


func check_jet_cycle() -> void:
	var level := await make_level()
	var player := level.hud.player
	park(player, Vector2(400, -96))
	player.set_physics_process(false)
	var body := actor_at(level, Vector2(240, -96))
	await ticks(1)
	var component := 90 / sqrt(2.0)
	check(body.phase == Blooper.Phase.JETTING and body.velocity.is_equal_approx(Vector2(component, -component)),
			"Blooper did not start its 45-degree90px/s jet toward Mario")
	player.position.x = 200
	await ticks(39)
	check(body.position.distance_to(Vector2(240 + 30 * sqrt(2.0), -96 - 30 * sqrt(2.0))) < 0.03
			and body.get_node("Graphics/Sprite").frame == 0 and not body.get_node("Graphics/Sprite").flip_h,
			"Blooper retargeted mid-jet or lost its40-tick trajectory/rising frame")
	await ticks(1)
	check(body.phase == Blooper.Phase.COOLDOWN and body.velocity == Vector2(0, 3)
			and body.get_node("Graphics/Sprite").frame == 1, "Blooper did not stop horizontally and begin sinking after40 ticks")
	var stopped_x := body.position.x
	await ticks(39)
	check(body.phase == Blooper.Phase.COOLDOWN and body.position.x == stopped_x and body.velocity.y == 30,
			"Blooper escaped its cooldown or lost the0.5/frame sinking cap")
	await ticks(20)
	check(body.phase == Blooper.Phase.JETTING and body.velocity.x < 0,
			"Blooper did not track Mario's new side when the next jet became eligible")
	level.queue_free()
	await ticks(2)


func check_initial_height_cases() -> void:
	var level := await make_level()
	var player := level.hud.player
	park(player, Vector2(400, -96))
	player.set_physics_process(false)
	var body := actor_at(level, Vector2(240, -200))
	await ticks(1)
	check(body.phase == Blooper.Phase.JETTING, "Source initial zero-gravity jet above Mario was omitted")
	await ticks(120)
	check(body.phase == Blooper.Phase.WAITING and body.velocity == Vector2(0, 30),
			"Sinking Blooper re-jetted while still above Mario's source origin")
	body.queue_free()
	body = actor_at(level, Vector2(240, -112))
	player.position = Vector2(400, -96)
	await ticks(1)
	check(body.phase == Blooper.Phase.WAITING and body.velocity == Vector2(0, 3),
			"Equal GM origins triggered an invented first jet")
	await ticks(1)
	check(body.phase == Blooper.Phase.JETTING, "Blooper did not become eligible after sinking below equal origins")
	body.queue_free()
	body = actor_at(level, Vector2(240, -96))
	player.position = Vector2(240, -220)
	await ticks(1)
	check(body.velocity.x < 0, "Horizontal equality did not retain the source's leftward choice")
	level.queue_free()
	await ticks(2)


func check_ellipse_and_solids() -> void:
	var level := await make_level()
	var body := actor_at(level, Vector2(300, -220))
	body.set_physics_process(false)
	await ticks(2)
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 2
	query.position = body.global_position + Vector2(0, -9)
	check(not body.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "Native Blooper ellipse has no center collision")
	query.position = body.global_position + Vector2(4, -17)
	check(body.get_world_2d().direct_space_state.intersect_point(query).is_empty(), "Blooper uses its enclosing rectangle instead of an ellipse")
	body.queue_free()
	var wall := GroundPart.create()
	wall.position = Vector2(240, -144)
	level.current_sub_area.add_part(wall)
	wall.load()
	wall.build()
	park(level.hud.player, Vector2(64, -16))
	body = actor_at(level, Vector2(270, -96))
	await ticks(40)
	check(body.position.x < 230 and body.position.y < -138 and body.collision_mask == 0,
			"Blooper's own movement was incorrectly blocked by solid terrain")
	level.queue_free()
	await ticks(2)


func check_contact(water: bool, spin: bool) -> void:
	var level := await make_level(water)
	var player := level.hud.player
	var body := actor_at(level)
	await ticks(8)
	# Water descent is now source1px/tick, not the old land-speed fixture.
	park(player, body.position + Vector2(-6, -30 if water else -48))
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
		check(player.is_dead() and is_instance_valid(body) and player.score == 0 and not bounced,
				"Water Blooper allowed a normal/spin stomp instead of damaging Mario")
	else:
		check(not is_instance_valid(body) and not player.is_dead() and player.score == 200 and bounced,
				"Air Blooper did not distinguish a valid stomping defeat")
		check(actors(level, FloatingEnemyDefeat).size() == (0 if spin else 1),
				"Air Blooper normal/spin stomp used the wrong defeat effect")
	level.queue_free()
	await ticks(2)


func check_projectiles_and_helmets() -> void:
	var level := await make_level()
	var player := level.hud.player
	var body := actor_at(level)
	check(body.hit_by_projectile(&"fire", 1), "Blooper incorrectly acquired fire resistance")
	body = actor_at(level, Vector2(500, -96))
	body.set_physics_process(false)
	var shell: KoopaShell = load("res://scenes/entities/koopa_shell.tscn").instantiate()
	shell.position = Vector2(440, -96)
	level.current_sub_area.add(shell)
	await ticks(20)
	player.position.x = 420
	shell.launch(player)
	park(player)
	await ticks(28)
	check(not is_instance_valid(body) and player.score == 200, "Real shell contact failed to defeat Blooper")
	shell.queue_free()
	for spiny in [false, true]:
		park(player, Vector2(400, -96))
		player.invulnerability_left = 0
		var helmet: HelmetRules = load("res://resources/content/smw_helmet_spiny_rules.tres" if spiny
				else "res://resources/content/smw_helmet_rules.tres")
		check(player.equip_shell_helmet(helmet), "Could not equip the test helmet")
		body = actor_at(level, Vector2(400, -170))
		body.phase = Blooper.Phase.COOLDOWN
		body._clock = 4
		body._gravity_active = true
		var deflected := false
		for frame in 125:
			await ticks(1)
			deflected = deflected or (is_instance_valid(body) and body.velocity.y < 0)
			if (spiny and not is_instance_valid(body)) or (not spiny and deflected):
				break
		check(player.has_helmet() and not player.is_dead()
				and ((not is_instance_valid(body)) if spiny else deflected),
				"Blooper ignored typed helmet defeat/deflection behavior")
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
	var body := actor_at(level, Vector2(480, -144))
	body.phase = Blooper.Phase.COOLDOWN
	body._clock = 4
	body._gravity_active = true
	var player := level.hud.player
	park(player, Vector2(480, -96))
	await ticks(3)
	Input.action_press("player_jump")
	await ticks(22)
	release_input()
	check(player.coins == 1 and player.score == 400 and not is_instance_valid(body),
			"Actual question-block bump failed to defeat/score the descending Blooper")
	level.queue_free()
	await ticks(2)


func check_defeat_and_cleanup() -> void:
	for water in [false, true]:
		var level := await make_level(water)
		var body := actor_at(level, Vector2(300, -220))
		body.kill(-1)
		await ticks(2)
		var effects := actors(level, FloatingEnemyDefeat)
		check(effects.size() == 1, "Blooper's defeat effect was not deferred/inserted")
		if effects.size() == 1:
			var effect: FloatingEnemyDefeat = effects[0]
			var sprite: AnimatedSprite2D = effect.get_child(0)
			check(sprite.flip_v and sprite.position == RULES.defeat_offset and effect.velocity.x == 0,
					"Blooper death used generic spinning/launched art")
			await ticks(35)
			check(effect.rotation == 0 and effect.velocity.y <= 60
					and sprite.sprite_frames.get_animation_speed(&"fall") == 3,
					"Blooper death lost its slow capped drift or three-fps animation")
		level.reload()
		await ticks(5)
		check(actors(level, FloatingEnemyDefeat).is_empty(), "Floating Blooper death leaked into retry")
		body = actor_at(level)
		body.kill()
		var pending := level.current_sub_area._pending_spawns.values().duplicate()
		level.free()
		await ticks(2)
		for entry in pending:
			check(not is_instance_valid(entry.node), "Area exit leaked a pending floating defeat")
