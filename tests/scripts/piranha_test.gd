# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Native plant topology/history, SMW cycles, aimed fire and actual contacts.

const FIXTURE := "res://tests/fixtures/port_slice.swe"
const JUMP: PiranhaVariant = preload("res://resources/content/smw_piranha_jump.tres")
const FIRE: PiranhaVariant = preload("res://resources/content/smw_piranha_fire.tres")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await check_editor(false)
	await check_editor(true)
	await check_topology_history()
	for water in [false, true]:
		await check_jumps(water)
		await check_fire_cycle(water)
		for variant in [JUMP, FIRE]:
			for spin in [false, true]:
				await check_contact(variant, water, spin)
	await check_attachments_and_support()
	await check_fireball_collisions()
	await check_shells_and_helmets()
	await check_blocks()
	await check_sink_and_cleanup()
	await finish("PIRANHA_RESULT")


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
	sub.water_start_y = -48
	sub.water_limit_y = -48
	add_child(level)
	await ticks(8)
	return level


func park(player: Player, pos := Vector2(64, -16)) -> void:
	release_input()
	player.position = pos
	player.previous_position = player.global_position
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)


func actor_at(level: Level, variant := JUMP, pos := Vector2(200, -96), wings := false, parachute := false) -> PiranhaPlant:
	var body: PiranhaPlant = load("res://scenes/level/entities/piranha_plant.tscn").instantiate()
	body.variant = variant
	body.position = pos
	body.wings = wings
	body.parachute = parachute
	level.current_sub_area.add(body)
	return body


func actors(level: Level, script: Script) -> Array:
	return level.current_sub_area.get_foreground().get_children().filter(
		func(n): return n.get_script() == script and not n.is_queued_for_deletion())


func add_ground(level: Level, at: Vector2) -> GroundPart:
	var ground := GroundPart.create()
	ground.position = at
	level.current_sub_area.add_part(ground)
	ground.load()
	return ground


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
	data.MAIN.NIVEL.append({"object": JUMP.object_id, "x_pos": 400, "y_pos": 272,
		"wings": 1, "paracaidas": 1, "direct_t": 2, "inup": 99, "future_plant": {"keep": 17}})
	data.MAIN.NIVEL.append({"object": FIRE.object_id, "x_pos": 528, "y_pos": 272,
		"wings": 1, "paracaidas": 1, "inup": 3})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/piranha_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var normal: PiranhaPart
	var fire: PiranhaPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is PiranhaPart:
			if part.variant == JUMP:
				normal = part
			else:
				fire = part
	check(normal != null and fire != null, "SWE did not map both standalone plant resource IDs")
	check(normal.wings and normal.parachute and normal.attachment_orientation() == 0 and fire.wings and fire.parachute,
			"Native plant import lost independent flags or trusted stale source inup")
	check(normal.get_node("Graphics/Sprite").texture.resource_path.ends_with("frame_002.png")
			and normal.get_node("Graphics/Sprite").offset == Vector2(-1, -8)
			and fire.get_node("Graphics/Sprite").offset == Vector2(-8, -16), "Plant previews lost source SMW frame/origins")
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	ring.page_index = 1
	check(ring.choose(0) and level.editor.get_selected_part() == PiranhaPart, "Piranha page2 slot0 is disabled")
	var placed := level.editor.place(Vector2i(38, -10)) as PiranhaPart
	check(placed.variant == JUMP and not placed.wings and not placed.parachute, "New plant inherited imported flags/default type")
	level.editor.set_part_modifier(placed, &"wings", true)
	level.editor.set_part_modifier(placed, &"parachute", true)
	placed.held = true
	placed.set_process(false)
	await ticks(45)
	check(is_instance_valid(placed._window), "Plant long press did not open its native window")
	if is_instance_valid(placed._window):
		await click(placed._window.get_node("Content/Attachments/wings"))
		check(not placed.wings and placed.parachute, "Actual plant GUI failed independent wing toggle")
		await click(placed._window.get_node("Content/Attachments/wings"))
		await click(placed._window.get_node("Content/Options/fire"))
	placed.held = false
	placed.set_process(true)
	check(placed.variant == FIRE and placed.wings and placed.parachute, "Plant source type swap must retain both flags")
	level.editor.history.undo()
	check(placed.variant == JUMP and placed.wings and placed.parachute, "Undo failed the plant type/flag swap")
	level.editor.history.redo()
	check(level.editor.get_palette_icon(PiranhaPart) == FIRE.icon, "Plant card ignored the source persistent type")
	var next := level.editor.place(Vector2i(40, -10)) as PiranhaPart
	check(next.variant == FIRE and not next.wings and not next.parachute, "Plant next placement ignored its type card")
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Native plants failed signed SWE saving")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var counts := {&"jump": 0, &"fire": 0}
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is PiranhaPart:
			counts[part.variant.id] += 1
			if part.position.x == 400:
				check(part.wings and part.parachute and part.swe_data.inup == 0
						and part.swe_data.direct_t == 2 and part.swe_data.future_plant.keep == 17,
						"Plant save/reopen rewrote unknown fields or failed derived attachment")
	check(counts == {&"jump": 1, &"fire": 3}, "Plant save/reopen changed types/counts")
	add_child(reopened)
	await ticks(4)
	check(actors(reopened, PiranhaPlant).size() == 4, "Reopened standalone plants did not build native actors")
	reopened.queue_free()
	level.queue_free()
	await ticks(2)


func check_topology_history() -> void:
	var level: Level = await LevelActionBtn.prepare_level(FIXTURE, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var editor := level.editor
	var plant := PiranhaPart.create()
	plant.position = Vector2(400, -160)
	plant.wings = true
	plant.parachute = true
	level.current_sub_area.add_part(plant)
	plant.load()
	var ceiling := add_ground(level, Vector2(400, -176))
	editor.history.record_place(ceiling)
	await ticks(2)
	check(plant.attachment_orientation() == 1 and not plant.wings and not plant.parachute,
			"Ceiling terrain did not attach plant and remove dependent flags")
	check(plant.get_node("Graphics/Sprite").scale.y == -1, "Ceiling preview did not flip around source origin")
	editor.history.undo()
	await ticks(2)
	check(not ceiling.is_inside_tree() and plant.wings and plant.parachute, "Undoing terrain failed to restore plant flags in the same action")
	editor.history.redo()
	check(ceiling.is_inside_tree() and not plant.wings and not plant.parachute, "Redoing terrain failed dependent plant flags")
	var wall := add_ground(level, Vector2(384, -160))
	editor.history.record_place(wall)
	check(plant.attachment_orientation() == 1, "Plant attachment did not prioritize ceiling over side wall")
	editor.erase_part(ceiling)
	await ticks(2)
	check(plant.attachment_orientation() == 2 and is_equal_approx(plant.get_node("Graphics/Sprite").rotation, PI / 2),
			"Removing ceiling did not orient the plant toward its left wall")
	var floor_part := add_ground(level, Vector2(400, -144))
	editor.history.record_place(floor_part)
	check(plant.attachment_orientation() == 0, "Floor support must override ceiling/side attachment")
	editor.set_part_modifier(plant, &"wings", true)
	editor.set_part_modifier(plant, &"parachute", true)
	editor.erase_part(floor_part)
	check(not plant.wings and not plant.parachute, "Erasing floor failed side-attachment canonicalization")
	editor.history.undo()
	check(floor_part.is_inside_tree() and plant.wings and plant.parachute, "Undo floor erasure lost the previous plant flags")
	editor.history.redo()
	check(not floor_part.is_inside_tree() and not plant.wings and not plant.parachute, "Redo floor erasure lost dependent canonicalization")
	editor.set_part_variant(plant, &"fire")
	editor.set_part_modifier(plant, &"wings", true)
	editor.set_part_modifier(plant, &"parachute", true)
	plant.held = true
	plant.set_process(false)
	await ticks(45)
	if is_instance_valid(plant._window):
		await click(plant._window.get_node("Content/Options/jump"))
	check(plant.variant == JUMP and not plant.wings and not plant.parachute, "Held type selection bypassed plant topology dependencies")
	plant.held = false
	plant.set_process(true)
	editor.history.undo()
	check(plant.variant == FIRE and plant.wings and plant.parachute, "Type undo failed to restore fire flags against a wall")
	editor.history.redo()
	check(plant.variant == JUMP and not plant.wings and not plant.parachute, "Type redo failed side-attached jump plant")
	var before := plant.position
	plant.position = Vector2(480, -160)
	plant._grid_pos = Level.to_grid(plant.position)
	editor.history.record_move(plant, before, plant.position)
	editor.set_part_modifier(plant, &"wings", true)
	editor.set_part_modifier(plant, &"parachute", true)
	var right_wall := add_ground(level, Vector2(512, -160))
	editor.history.record_place(right_wall)
	plant.held = true
	plant.set_process(false)
	plant._moved_out = true
	plant.position = Vector2(496, -160)
	await ticks(2)
	check(plant.wings and plant.parachute, "Transient drag prematurely discarded history-owned plant flags")
	plant.held = false
	plant.set_process(true)
	check(plant.position == Vector2(496, -160) and plant.attachment_orientation() == 3 and not plant.wings and not plant.parachute,
			"Actual hold/release did not record move and attachment removal together")
	editor.history.undo()
	check(plant.position == Vector2(480, -160) and plant.wings and plant.parachute, "Drag undo failed to restore free plant and flags")
	editor.history.redo()
	check(plant.position == Vector2(496, -160) and not plant.wings and not plant.parachute, "Drag redo failed dependent attachment state")
	before = plant.position
	plant.position = Vector2(400, -160)
	plant._grid_pos = Level.to_grid(plant.position)
	editor.history.record_move(plant, before, plant.position)
	var saved: Dictionary = await editor.save_to_path("res://.godot/porting-tests/piranha_topology.swe")
	check(saved.error == OK, "Attached plant history could not be saved")
	var reopened: Level = await LevelProcessor.from_swe("res://.godot/porting-tests/piranha_topology.swe")
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is PiranhaPart:
			check(part.swe_data.inup == 2 and not part.wings and not part.parachute, "SWE did not serialize source side attachment")
	reopened.free()
	level.queue_free()
	await ticks(2)


func check_jumps(water: bool) -> void:
	var level := await make_level(Level.LevelTheme.UNDERWATER if water else Level.LevelTheme.OVERWORLD)
	level.hud.player.set_physics_process(false)
	var body := actor_at(level)
	await ticks(8)
	var ground_y := body.position.y
	check(body.is_on_floor() and absf(ground_y + 96) < 0.3, "SMW jump plant failed real floor support")
	var launches := 0
	var last_velocity := 0.0
	var first_launch := -1
	var first_land := -1
	for frame in 900:
		await ticks(1)
		if body.velocity.y < -1 and last_velocity >= 0:
			launches += 1
			if first_launch < 0:
				first_launch = frame
				check(absf(body.velocity.y + (120 if water else 150)) < 0.03,
						"SMW jump impulse must use source2.5/2.0 at floor departure")
				check(body.get_node("Graphics/Sprite").sprite_frames.get_animation_speed(&"body") == 9, "Jump plant lost airborne source animation cadence")
		elif first_launch >= 0 and first_land < 0 and body.is_on_floor():
			first_land = frame
			check(body.get_node("Graphics/Sprite").sprite_frames.get_animation_speed(&"body") == 33, "Landing failed to restore source fall animation")
		if launches == 2:
			check(frame - first_land == 180, "Plant wait after real landing was%d ticks, expected180" % (frame - first_land))
			break
		last_velocity = body.velocity.y
	check(launches == 2 and first_launch > 160 and first_land > first_launch, "SMW plant did not complete its native jump/land/wait cycle")
	level.queue_free()
	await ticks(2)


func check_fire_cycle(water: bool) -> void:
	var level := await make_level(Level.LevelTheme.UNDERWATER if water else Level.LevelTheme.OVERWORLD)
	var player := level.hud.player
	park(player, Vector2(64, -160))
	player.set_physics_process(false)
	var body := actor_at(level, FIRE)
	await ticks(119)
	check(body.attack == PiranhaPlant.Attack.IDLE and actors(level, PlantFireball).is_empty() and body.aiming_up,
			"Fire plant windup began early or aimed with the wrong source origins")
	await ticks(1)
	check(body.attack == PiranhaPlant.Attack.WINDUP and body.get_node("Graphics/Sprite").frame == 1
			and not body.get_node("Graphics/Sprite").is_playing(), "Fire plant did not open its mouth/pause at120 ticks")
	player.position = Vector2(300, -16)
	await ticks(29)
	check(actors(level, PlantFireball).is_empty() and body.aiming_up and body.direction == 1, "Fire plant lost its windup vertical lock or horizontal tracking")
	await ticks(1)
	var shots := actors(level, PlantFireball)
	check(shots.size() == 1 and body.attack == PiranhaPlant.Attack.RECOVERY, "Fire plant failed its150-tick shot")
	if shots.size() == 1:
		var shot: PlantFireball = shots[0]
		check(shot.velocity == Vector2(30 if water else 60, -15 if water else -30), "Plant shot lost source water slowdown or aimed diagonal")
		check(shot.position.distance_to(body.position + Vector2(10, -27)) < 1.3, "Plant fireball spawned at the wrong source mouth origin")
		var at := shot.position
		await ticks(30)
		check(shot.position.distance_to(at + Vector2(15 if water else 30, -7.5 if water else -15)) < 0.05, "Actual plant projectile trajectory drifted")
	await ticks(10)
	check(body.attack == PiranhaPlant.Attack.IDLE and not body.aiming_up and body.get_node("Graphics/Sprite").is_playing(),
			"Fire plant did not restore idle/down aim after40-tick recovery")
	var old_ids: Array = actors(level, PlantFireball).map(func(n): return n.get_instance_id())
	await ticks(129)
	check(body.attack == PiranhaPlant.Attack.WINDUP, "Fire plant repeat wait/windup changed")
	await ticks(1)
	check(body.attack == PiranhaPlant.Attack.RECOVERY and actors(level, PlantFireball).any(
			func(n): return n.get_instance_id() not in old_ids), "Fire plant did not repeat after170 ticks")
	level.queue_free()
	await ticks(2)


func check_contact(variant: PiranhaVariant, water: bool, spin: bool) -> void:
	var level := await make_level(Level.LevelTheme.UNDERWATER if water else Level.LevelTheme.OVERWORLD)
	var player := level.hud.player
	var body := actor_at(level, variant, Vector2(480, -96), true)
	body.set_physics_process(false)
	park(player, Vector2(480, -132 if water else -152))
	player.state_machine.switch(PlayerFallingState)
	await ticks(1)
	if spin:
		player.state_machine.switch(PlayerSpinJumpingState)
	player.velocity.y = 120
	var bounced := false
	for frame in 26:
		await ticks(1)
		bounced = bounced or player.velocity.y < 0
	check(is_instance_valid(body) and body.wings and player.score == 0,
			"Plant stomp must not defeat it, strip wings or award points")
	# Swim input cannot retain a spin-jump pose; only the air case can recoil.
	check((bounced and not player.is_dead()) if spin and not water else (player.is_dead() and not bounced),
			"Plant normal/spin contact lost source recoil policy")
	level.queue_free()
	await ticks(2)


func check_attachments_and_support() -> void:
	for orientation in [1, 2, 3]:
		var level := await make_level()
		var base := Vector2(480, -160)
		var offset := Vector2(0, -16) if orientation == 1 else Vector2(-16 if orientation == 2 else 16, 0)
		var ground := add_ground(level, base + offset)
		ground.build()
		var part := PiranhaPart.create()
		part.position = base
		part.wings = true
		part.parachute = true
		level.current_sub_area.add_part(part)
		part.load()
		part.build()
		await ticks(8)
		var body: PiranhaPlant = actors(level, PiranhaPlant)[0]
		check(body.attachment == orientation and not body.wings and not body.parachute and body.velocity == Vector2.ZERO,
				"Native plant did not derive its ceiling/side stationary attachment")
		var at := body.position
		await ticks(200)
		check(body.position == at and body.collision_mask == 0, "Attached SMW plant moved or jumped")
		for tile in level.current_sub_area.get_foreground().get_children():
			if tile is GroundTile and absf(tile.position.x - (base + offset).x) < 1 and absf(tile.position.y - (base + offset).y) < 1:
				tile.queue_free()
		await ticks(5)
		check(not is_instance_valid(body), "Removing real runtime support failed the plant's source cankill check")
		level.queue_free()
		await ticks(2)
	var level := await make_level()
	var body := actor_at(level, JUMP, Vector2(480, -180), true, true)
	await ticks(30)
	check(body.wings and body.parachute and body.velocity.x > 0 and body.velocity.y == 30,
			"SMW jump plant parachute lost its source gravity/sway/start alarm")
	await ticks(180)
	check(not body.parachute and body.wings and body.velocity.x == 0, "Actual landing did not shrink/detach plant parachute")
	body.queue_free()
	body = actor_at(level, FIRE, Vector2(480, -180), true, true)
	await ticks(30)
	check(body.velocity.x == 0 and body.velocity.y == 30 and not body.has_node("Graphics/Wings")
			and not body.has_node("Graphics/Parachute"), "SMW fire plant must retain source non-drawn flags/vertical float")
	level.queue_free()
	await ticks(2)


func shot_at(level: Level, pos: Vector2, speed: Vector2) -> PlantFireball:
	var shot := PlantFireball.new()
	shot.variant = FIRE
	shot.position = pos
	shot.velocity = speed
	level.current_sub_area.add(shot)
	return shot


func check_fireball_collisions() -> void:
	for helmet in [null, load("res://resources/content/smw_helmet_rules.tres"), load("res://resources/content/smw_helmet_spiny_rules.tres")]:
		var level := await make_level()
		var player := level.hud.player
		park(player, Vector2(240, -96))
		if helmet != null:
			player.equip_shell_helmet(helmet)
		var shot := shot_at(level, Vector2(200, -132), Vector2(60, 30))
		await ticks(45)
		check(not is_instance_valid(shot) and (player.is_dead() if helmet == null else not player.is_dead() and not player.has_helmet()),
				"Actual plant fireball hit must damage/consume armor, not acquire enemy head deflection")
		level.queue_free()
		await ticks(2)
	var level := await make_level()
	var wall := add_ground(level, Vector2(240, -128))
	wall.build()
	var shot := shot_at(level, Vector2(200, -136), Vector2(60, 30))
	await ticks(50)
	check(not is_instance_valid(shot) and level.hud.player.score == 0, "Plant fireball failed to burst on actual solid terrain")
	var platform := StaticBody2D.new()
	platform.collision_layer = 1
	platform.collision_mask = 0
	platform.position = Vector2(320, -160)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(64, 4)
	shape.shape = rectangle
	shape.one_way_collision = true
	platform.add_child(shape)
	level.current_sub_area.add(platform)
	shot = shot_at(level, Vector2(320, -120), Vector2(0, -60))
	await ticks(45)
	check(not is_instance_valid(shot), "Plant fireball incorrectly passed a semisolid from below")
	shot = shot_at(level, Vector2(-40, -96), Vector2.ZERO)
	await ticks(2)
	check(not is_instance_valid(shot), "Plant fireball ignored source32px camera culling")
	level.queue_free()
	await ticks(2)


func check_shells_and_helmets() -> void:
	var level := await make_level()
	var player := level.hud.player
	var body := actor_at(level, JUMP, Vector2(500, -96))
	body.set_physics_process(false)
	var shell: KoopaShell = load("res://scenes/level/entities/koopa_shell.tscn").instantiate()
	shell.position = Vector2(440, -96)
	level.current_sub_area.add(shell)
	await ticks(20)
	player.position.x = 420
	shell.launch(player)
	park(player)
	await ticks(28)
	check(not is_instance_valid(body) and player.score == 200, "Moving shell failed to defeat/score standalone plant")
	shell.queue_free()
	for spiny in [false, true]:
		park(player, Vector2(400, -96))
		player.invulnerability_left = 0
		player.equip_shell_helmet(load("res://resources/content/smw_helmet_spiny_rules.tres" if spiny else "res://resources/content/smw_helmet_rules.tres"))
		body = actor_at(level, FIRE, Vector2(400, -170))
		var deflected := false
		for frame in 65:
			await ticks(1)
			deflected = deflected or (is_instance_valid(body) and body.velocity.y < 0)
			if (spiny and not is_instance_valid(body)) or (not spiny and deflected):
				break
		check(player.has_helmet() and not player.is_dead() and ((not is_instance_valid(body)) if spiny else deflected), "Plant ignored typed helmet deflection/defeat")
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
	var body := actor_at(level, JUMP, Vector2(480, -144))
	park(level.hud.player, Vector2(480, -96))
	await ticks(3)
	Input.action_press("player_jump")
	await ticks(22)
	release_input()
	check(level.hud.player.coins == 1 and level.hud.player.score == 400 and not is_instance_valid(body),
			"Actual head-block bump failed plant defeat/score")
	level.queue_free()
	await ticks(2)


func check_sink_and_cleanup() -> void:
	for theme in [Level.LevelTheme.CASTLE, Level.LevelTheme.FOREST]:
		var level := await make_level(theme, theme == Level.LevelTheme.FOREST)
		var sub := level.current_sub_area
		var body := actor_at(level, JUMP, Vector2(200, -20), true)
		await ticks(3)
		check(not is_instance_valid(body) and actors(level, SinkingEnemy).size() == 1, "Lava/poison did not replace the plant with source sinking actor")
		var sink: SinkingEnemy = actors(level, SinkingEnemy)[0]
		await ticks(25)
		check(sink.velocity <= 3.61 and sink.position.y < 0, "Sinking plant lost source slow gravity/cap")
		level.reload()
		await ticks(4)
		check(actors(level, SinkingEnemy).is_empty() and actors(level, DetachedEnemyAttachment).is_empty(), "Sinking plant effects leaked into retry")
		body = actor_at(level, FIRE, Vector2(200, -96), true)
		body.attack = PiranhaPlant.Attack.WINDUP
		body._attack_left = 0
		body._advance_attack(1.0 / 60)
		body.kill(-1)
		var pending := sub._pending_spawns.values().duplicate()
		level.free()
		await ticks(2)
		for entry in pending:
			check(not is_instance_valid(entry.node), "Area teardown leaked a pending shot/defeat/wing/audio effect")
	for variant in [JUMP, FIRE]:
		var level := await make_level()
		var body := actor_at(level, variant, Vector2(300, -220), true)
		check(body.hit_by_projectile(&"fire", -1), "Plant incorrectly rejected a source fire hit")
		await ticks(2)
		var effects := actors(level, SwimmingEnemyDefeat)
		check(effects.size() == 1 and actors(level, DetachedEnemyAttachment).size() == 2, "Plant defeat lost typed spinning art or two detached wings")
		if effects.size() == 1:
			var effect: SwimmingEnemyDefeat = effects[0]
			check(effect.get_child(0).frame == variant.dead_frame and effect.velocity.x == -60 and effect.rotation < 0,
					"Native plant death did not retain source type/frame/launch")
		level.reload()
		await ticks(4)
		check(actors(level, SwimmingEnemyDefeat).is_empty(), "Plant death leaked into retry")
		level.queue_free()
		await ticks(2)
