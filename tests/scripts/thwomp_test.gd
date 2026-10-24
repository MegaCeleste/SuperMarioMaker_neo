# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Native source triggers, collision, phases and editor round-trip integration.

const SMALL = preload("res://resources/content/smw_thwomp_small.tres")
const GIANT = preload("res://resources/content/smw_thwomp_giant.tres")
const FIXTURE := "res://tests/fixtures/port_slice.swe"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for modern in [false, true]:
		await check_editor(modern)
	for variant in [SMALL, GIANT]:
		for direction in [1, 2, 3]:
			await check_cycle(variant, direction)
		await check_triggers(variant)
		for water in [false, true]:
			await check_gravity(variant, water)
		for spin in [false, true]:
			await check_player_contact(variant, spin)
		for spiny in [false, true]:
			await check_helmet(variant, spiny)
	await check_blocks()
	await check_defeat_and_cleanup()
	await finish("THWOMP_RESULT")


func make_level() -> Level:
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	var area := level.current_sub_area
	for part in area.get_parts().get_children():
		if not part is EditorPlayer and not part is StartingGround:
			part.free()
	for x in range(12, 49):
		var part := GroundPart.create()
		part.position = Vector2(x * 16, -96)
		area.add_part(part)
	add_child(level)
	await ticks(8)
	park(level.hud.player)
	return level


func park(player: Player, at := Vector2(64, -16)) -> void:
	release_input()
	player.position = at
	player.previous_position = at
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)


func actor(level: Level, variant: ThwompVariant, direction: int, at: Vector2) -> Thwomp:
	var body: Thwomp = load("res://scenes/entities/thwomp.tscn").instantiate()
	body.variant = variant
	body.attack_direction = direction
	body.position = at
	level.current_sub_area.add(body)
	return body


func wall(level: Level, x: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = Vector2(x, -192)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 192)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	level.current_sub_area.add(body)
	return body


func check_cycle(variant: ThwompVariant, direction: int) -> void:
	var level := await make_level()
	var home := Vector2(400, -224 if direction == 1 else -128)
	var body := actor(level, variant, direction, home)
	if direction != 1:
		wall(level, 272 if direction == 2 else 528)
	await ticks(4)
	check(body.phase == Thwomp.Phase.WAITING and body.position.is_equal_approx(home),
			"Thwomp did not wait at the source home position")
	check(body.get_node("Sprite").position.y == 1 - variant.source_to_feet.y,
			"Thwomp art lost the source anchor plus 1px surface overlap")
	var target_x := 400.0 if direction == 1 else 400 + (-1 if direction == 2 else 1) * (variant.mask_size.x / 2 + 20)
	park(level.hud.player, Vector2(target_x, -96 if direction == 1 else -128))
	await ticks(2)

	check(body.phase == Thwomp.Phase.ATTACKING, "Source proximity failed to trigger Thwomp")
	park(level.hud.player)
	for frame in 120:
		await ticks(1)
		if body.phase == Thwomp.Phase.IMPACT:
			break
	check(body.phase == Thwomp.Phase.IMPACT, "Thwomp never collided with real floor/wall")
	var hit_position := body.position
	var impact_frame: int = body.get_node("Sprite").frame
	await ticks(59)
	check(body.phase == Thwomp.Phase.IMPACT and body.position.distance_to(hit_position) < 0.15,
			"Thwomp did not retain its 60-tick impact pause")
	await ticks(1)
	check(body.phase == Thwomp.Phase.RETURNING, "Thwomp did not start its source return after 60 ticks")
	check(impact_frame == 2 and body.get_node("Sprite").frame == 0,
			"Thwomp angry/return poses do not follow the source phases")
	for frame in 200:
		await ticks(1)
		if body.phase == Thwomp.Phase.WAITING:
			break
	print("THWOMP_CYCLE size=", variant.id, " dir=", direction, " home=", home,
			" impact=", hit_position, " returned=", body.position, " phase=", body.phase)
	check(body.phase == Thwomp.Phase.WAITING and body.position.distance_to(home) < 0.15,
			"Thwomp failed to return to its original attack anchor")
	level.queue_free()
	await ticks(2)


func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	await ticks(2)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await ticks(2)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	get_viewport().push_input(event, true)
	await ticks(2)


func check_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	data.MAIN.NIVEL.append({"object": SMALL.object_id, "x_pos": 426, "y_pos": 273,
		"direct_t": 3, "wings": 1, "paracaidas": 1, "future_thwomp": {"keep": 23}})
	data.MAIN.NIVEL.append({"object": GIANT.object_id, "x_pos": 512, "y_pos": 240,
		"direct_t": 3, "wings": 1, "paracaidas": 1})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/thwomp_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var small: ThwompPart
	var giant: ThwompPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is ThwompPart:
			if part.variant.giant:
				giant = part
			else:
				small = part
	check(small != null and giant != null, "Both source Thwomp IDs must create native Parts")
	check(small.position == Vector2(426, -159) and giant.position == Vector2(512, -192),
			"Thwomp loading snapped or reanchored source instance coordinates")
	check(small.attack_direction == 3 and giant.attack_direction == 3 and small.wings and giant.parachute,
			"Thwomp import lost source direction or independent flags")
	check(giant.get_node("CollShape").shape.size == Vector2(64, 64)
			and giant.get_node("CollShape").position == Vector2(0, 32), "Giant editor footprint lost its centered source origin")
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	ring.page_index = 1
	check(ring.choose(2) and level.editor.get_selected_part() == ThwompPart,
			"Native Thwomp page2 slot2 still selects a disabled placeholder")
	Utility.camera_position = Vector2(320, -216)
	await ticks(3)
	await click_at(small.get_global_transform_with_canvas() * SMALL.arrow_center)
	check(small.attack_direction == 1 and not small.held, "Actual source arrow click did not cycle right to down")
	await click_at(small.get_global_transform_with_canvas() * SMALL.arrow_center)
	check(small.attack_direction == 2, "Actual source arrow click did not cycle down to left")
	level.editor.history.undo()
	level.editor.history.undo()
	check(small.attack_direction == 3 and small.wings and small.parachute,
			"Direction undo lost the source direction or attachments")
	check(small.get_variants().is_empty(), "Small Thwomp invented a popup absent from the pinned source")
	giant.held = true
	giant.set_process(false)
	await ticks(40)
	check(giant._window != null, "Giant Thwomp did not open its source size/type window")
	if giant._window != null:
		var rolling: Button = giant._window.get_node("Content/Options/grrrol")
		check(not rolling.disabled, "Ported legacy Grrrol must be available in the source giant window")
		# grrrol_test exercises the actual type click and dependent undo; retain
		# this scene's separate Thwomp downsizing/flag-preservation coverage.
		var size_button: Button = giant._window.get_node("Content/Attachments/large")
		await click_at(size_button.get_global_transform_with_canvas() * (size_button.size / 2))
	giant.held = false
	giant.set_process(true)
	await ticks(8)
	check(giant.variant == SMALL and giant.attack_direction == 1 and giant.wings and giant.parachute,
			"Giant downsizing did not reset direction and retain source flags")
	level.editor.history.undo()
	check(giant.variant == GIANT and giant.attack_direction == 3 and giant.wings and giant.parachute,
			"Size undo did not restore the entire dependent Thwomp state")
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Native Thwomp failed signed SWE saving")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var restored := 0
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is ThwompPart:
			restored += 1
			check(part.attack_direction == 3 and part.wings and part.parachute,
					"Signed SWE round-trip lost Thwomp direction/flags")
			if not part.variant.giant:
				check(part.position == Vector2(426, -159) and part.swe_data.future_thwomp.keep == 23,
						"Signed SWE round-trip lost off-grid coordinates or unknown fields")
	check(restored == 2, "Signed SWE round-trip changed the number of Thwomps")
	reopened.free()
	level.queue_free()
	await ticks(2)


func check_triggers(variant: ThwompVariant) -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_physics_process(false)
	var body := actor(level, variant, 1, Vector2(400, -224))
	body.set_physics_process(false)
	var margin := 16.0 if variant.giant else 32.0
	var bounds := Utility.get_bounding_box(body)
	for x in [bounds.position.x - margin, bounds.end.x - 1 + margin]:
		park(player, Vector2(x, -96))
		check(not body._player_in_trigger(), "Thwomp downward trigger included its strict edge")
		player.position.x += 0.1 if x < 400 else -0.1
		check(body._player_in_trigger(), "Thwomp downward trigger excluded an interior point")
	for direction in [2, 3]:
		body.attack_direction = direction
		var distance := 56.0 if variant.giant else 112.0
		var x := bounds.position.x - distance if direction == 2 else bounds.end.x - 1 + distance
		park(player, Vector2(x, bounds.get_center().y + 32))
		check(not body._player_in_trigger(), "Thwomp side trigger included its strict distance edge")
		player.position.x += 0.1 if direction == 2 else -0.1
		check(body._player_in_trigger(), "Thwomp side trigger excluded an interior point")
	level.queue_free()
	await ticks(2)


func check_gravity(variant: ThwompVariant, water: bool) -> void:
	var level := await make_level()
	if water:
		level.current_sub_area.level_theme = Level.LevelTheme.UNDERWATER
	for parachute in [false, true]:
		var body := actor(level, variant, 1, Vector2(400, -320))
		body.parachute = parachute
		body.wings = true # Preserved flag has no runtime wing branch in this source.
		body.phase = Thwomp.Phase.ATTACKING
		await ticks(30)
		var expected := 30.0 if parachute else 31.5 if water else 252.0
		check(absf(body.velocity.y - expected) < 0.01,
				"Thwomp gravity/cap order or source parachute behavior changed")
		for child in body.get_children():
			if child is AnimatedSprite2D:
				check(child == body._sprite, "Thwomp invented runtime wing/parachute art absent from its Draw event")
		body.queue_free()
		await ticks(2)
	level.queue_free()
	await ticks(2)


func check_player_contact(variant: ThwompVariant, spin: bool) -> void:
	var level := await make_level()
	var body := actor(level, variant, 1, Vector2(400, -96))
	body.set_physics_process(false)
	var player := level.hud.player
	player.set_powerup(SuperPowerup.new(), false)
	park(player, Vector2(400, -96 - variant.mask_size.y - 24))
	# Let the teleport's stale floor state settle: PlayerSpinJumpingState exits
	# on is_on_floor(), which is still true from the parked position otherwise.
	await ticks(1)
	player.state_machine.switch(PlayerSpinJumpingState if spin else PlayerFallingState)
	player.velocity.y = 120
	var rebounded := false
	for frame in 75:
		await ticks(1)
		rebounded = rebounded or player.velocity.y < 0
	check(is_instance_valid(body) and player.score == 0, "A jump defeated or scored on a hardness99 Thwomp")
	check((player.get_powerup() is SuperPowerup and rebounded) if spin else player.get_powerup() is SmallPowerup,
			"Thwomp did not distinguish normal-jump damage from spin recoil")
	level.queue_free()
	await ticks(2)


func check_helmet(variant: ThwompVariant, spiny: bool) -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_powerup(SuperPowerup.new(), false)
	park(player, Vector2(400, -96))
	await ticks(3)
	player.equip_shell_helmet(load("res://resources/content/smw_helmet_spiny_rules.tres" if spiny else "res://resources/content/smw_helmet_rules.tres"))
	Input.action_press("player_run")
	var body := actor(level, variant, 1, Vector2(400, -224))
	var deflected := false
	for frame in 90:
		await ticks(1)
		if not is_instance_valid(body):
			break
		deflected = deflected or body.velocity.y < 0
		if deflected:
			break
	check(player.has_helmet() and player.get_powerup() is SuperPowerup and not player.is_dead(),
			"Falling Thwomp bypassed Mario's worn helmet")
	check((not is_instance_valid(body) and player.score == 200) if spiny else (deflected and player.score == 0),
			"Thwomp helmet contact lost Buzzy deflection or Spiny defeat")
	if not spiny and is_instance_valid(body):
		await ticks(12)
		check(player.has_helmet(), "Native overlap latency damaged Mario after the head deflection")
		body.set_physics_process(false)
		body.position = player.position + Vector2(10, 0)
		body.velocity.y = -120
		body._before = Utility.get_bounding_box(body)
		body._body_handling(true, player)
		check(not player.has_helmet() and player.get_powerup() is SuperPowerup,
				"A remembered head bounce incorrectly granted immunity to a later side contact")
	release_input()
	level.queue_free()
	await ticks(2)


func block_part(level: Level, at: Vector2, question: bool) -> StaticBody2D:
	var part: Part = QuestionBlockPart.create() if question else TurnBlockPart.create()
	part.position = at
	level.current_sub_area.add_part(part)
	part.load()
	part.build()
	for node in level.current_sub_area.get_foreground().get_children():
		if node.position == at and ((node is QuestionBlock) if question else (node is TurnBlockTile)):
			return node
	return null


func check_blocks() -> void:
	for variant in [SMALL, GIANT]:
		var level := await make_level()
		var block := block_part(level, Vector2(392, -176), false)
		var body := actor(level, variant, 1, Vector2(400, -272))
		body.phase = Thwomp.Phase.ATTACKING
		for frame in 90:
			await ticks(1)
			if not is_instance_valid(block):
				break
		check(not is_instance_valid(block), "Thwomp impact must break an actual SMW flip block")
		check(is_instance_valid(body) and body.phase == (Thwomp.Phase.ATTACKING if variant.giant else Thwomp.Phase.IMPACT),
				"Giant did not continue through a broken flip block, or small failed its impact pause")
		level.queue_free()
		await ticks(2)
	for direction in [1, 2, 3]:
		var level := await make_level()
		var block := block_part(level, Vector2(392 if direction == 1 else 352 if direction == 2 else 432,
				-176 if direction == 1 else -160), true)
		var body := actor(level, GIANT, direction, Vector2(400, -272 if direction == 1 else -128))
		body.phase = Thwomp.Phase.ATTACKING
		await ticks(45)
		if direction == 2:
			check(not is_instance_valid(block) and level.hud.player.coins == 0,
					"Giant left attack must destroy the question block without ejecting its coin")
		else:
			check(is_instance_valid(block) and level.hud.player.coins == 1,
					"Giant down/right attack must activate the question block and pass it")
		check(is_instance_valid(body), "Thwomp's downward block activation incorrectly killed its activator")
		level.queue_free()
		await ticks(2)


func check_defeat_and_cleanup() -> void:
	var level := await make_level()
	var body := actor(level, SMALL, 1, Vector2(400, -224))
	check(not body.hit_by_projectile(&"fire", 1) and not body.hit_by_projectile(&"shell", 1),
			"Hardness99 Thwomp accepted normal fire/shell defeat")
	check(body.hit_by_projectile(&"pow", 0), "Resting Thwomp rejected source stationary POW defeat")
	level.reload()
	await ticks(3)
	for node in level.current_sub_area.get_foreground().get_children():
		check(not node is DeadEntity and not node is BlockShard, "Pending Thwomp effects crossed a retry revision")
	var giant := actor(level, GIANT, 1, Vector2(400, 70))
	giant.phase = Thwomp.Phase.IMPACT
	giant._wait_left = 1
	await ticks(1)
	check(is_instance_valid(giant), "Giant void culling used its feet rather than the source top edge")
	giant.position.y = 82
	await ticks(2)
	check(not is_instance_valid(giant), "Thwomp remained after its top edge passed the source void boundary")
	level.queue_free()
	await ticks(2)
