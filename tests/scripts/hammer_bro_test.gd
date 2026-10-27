# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Native Hammer/Fire/Ice/Boomerang Bro editor and runtime integration.

const FIXTURE := "res://tests/fixtures/port_slice.swe"
const HAMMER := preload("res://resources/content/smw_hammerbro_hammer.tres")
const FIRE := preload("res://resources/content/smw_hammerbro_fire.tres")
const ICE := preload("res://resources/content/smw_hammerbro_ice.tres")
const BOOMERANG := preload("res://resources/content/smw_hammerbro_boomerang.tres")
const SLEDGE := preload("res://resources/content/smw_hammerbro_sledge.tres")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for modern in [false, true]:
		await check_editor(modern)
	await check_patrol_and_throw(HAMMER, BroProjectile.Kind.HAMMER, 90.0)
	await check_patrol_and_throw(FIRE, BroProjectile.Kind.FIRE, 150.0)
	await check_patrol_and_throw(ICE, BroProjectile.Kind.ICE, 144.0)
	await check_boomerang()
	await check_sledge()
	await check_jump()
	await check_platform_jumps()
	await check_winged_sledge()
	await check_sledge_parachute()
	await check_art_anchor()
	await check_stomp_and_wings()
	finish("HAMMERBRO_RESULT")


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


func actor(level: Level, at: Vector2, variant: HammerBroVariant = HAMMER, wings := false) -> HammerBro:
	var body: HammerBro = load("res://scenes/level/entities/hammer_bro.tscn").instantiate()
	body.variant = variant
	body.wings = wings
	body.position = at
	level.current_sub_area.add(body)
	return body


func projectiles(level: Level) -> Array[BroProjectile]:
	var result: Array[BroProjectile] = []
	for node in level.current_sub_area.get_foreground().get_children():
		if node is BroProjectile:
			result.append(node)
	return result


func check_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	data.MAIN.NIVEL.append({"object": "obj_hammerbro_res", "x_pos": 426, "y_pos": 273,
		"wings": 1, "future_bro": {"keep": 23}})
	data.MAIN.NIVEL.append({"object": "obj_firebro_res", "x_pos": 512, "y_pos": 240})
	data.MAIN.NIVEL.append({"object": "obj_sledgebro_res", "x_pos": 600, "y_pos": 240, "paracaidas": 1})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/hammerbro_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var hammer: HammerBroPart
	var fire: HammerBroPart
	var sledge: HammerBroPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is HammerBroPart:
			if part.variant == HAMMER:
				hammer = part
			elif part.variant == FIRE:
				fire = part
			elif part.variant == SLEDGE:
				sledge = part
	check(hammer != null and fire != null and sledge != null,
			"Hammer/Fire/Sledge Bro resources did not create typed Parts")
	check(hammer.position == Vector2(426, -159) and fire.position == Vector2(512, -192)
			and sledge.position == Vector2(600, -192),
			"Hammer Bro loading snapped or reanchored source coordinates")
	check(hammer.wings, "Hammer Bro import lost its source wings flag")
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	ring.page_index = 1
	check(ring.choose(5) and level.editor.get_selected_part() == HammerBroPart,
			"Hammer Bro page2 slot5 still selects the disabled placeholder")
	var probe := HammerBroPart.create()
	probe.position = Vector2(704, -192)
	probe.wings = true
	probe.parachute = true
	level.current_sub_area.add_part(probe)
	await ticks(2)
	probe.held = true
	probe.set_process(false)
	await ticks(45)
	check(probe._window != null, "Hammer Bro did not open its native four-type window")
	if probe._window != null:
		check(probe._window.get_node("Content/Options").get_child_count() == 4,
				"Regular Bro window should have four type icons and a separate size toggle")
		check(probe._window.get_node("Content/Attachments").get_child_count() == 2,
				"Regular Bro window must expose size and wings")
		var size_button: Button = probe._window.get_node("Content/Attachments/large")
		await click_at(size_button.get_global_transform_with_canvas() * (size_button.size / 2))
		check(probe.variant == SLEDGE and probe.position == Vector2(720, -192),
				"Bro size checkbox did not apply the source +16px conversion")
		check(probe.wings and probe.parachute and probe.footprint().size == Vector2(32, 32),
				"Sledge conversion lost flags or its 2x2 editor footprint")
		check(probe.get_variants().is_empty() and probe.get_modifiers().size() == 3,
				"Sledge must use the source size/wings/parachute window")
	probe.held = false
	probe.set_process(true)
	await ticks(6)
	level.editor.history.undo()
	check(probe.variant == HAMMER and probe.position == Vector2(704, -192) and probe.wings and probe.parachute,
			"Size undo did not restore source position and all dependent flags")
	level.editor.set_part_variant(probe, &"ice")
	check(probe.variant == ICE and probe.wings and not probe.parachute,
			"Regular Bro type swap must keep wings and remove parachute")
	level.editor.history.undo()
	check(probe.variant == HAMMER and probe.parachute,
			"Type undo failed to restore the source-removed parachute")
	var placed: HammerBroPart = level.editor.place(Vector2i(36, -16))
	check(placed.variant == ICE, "Bro type selection did not persist on the next-placement card")
	level.editor.erase_part(placed)
	probe.free()
	await ticks(2)
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Native Hammer Bro failed signed SWE saving")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var restored := {"hammer": 0, "fire": 0, "sledge": 0}
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is HammerBroPart:
			restored["sledge" if part.variant == SLEDGE else "fire" if part.variant == FIRE else "hammer"] += 1
			if part.variant == HAMMER:
				check(part.wings and part.swe_data.future_bro.keep == 23 and part.position == Vector2(426, -159),
						"Bro save/reopen lost flags, off-grid position or unknown data")
			elif part.variant == SLEDGE:
				check(part.parachute, "Sledge save/reopen lost its runtime parachute flag")
	check(restored["hammer"] == 1 and restored["fire"] == 1 and restored["sledge"] == 1,
			"Signed SWE round-trip changed the Hammer/Fire/Sledge Bro types")
	reopened.free()
	level.queue_free()
	await ticks(2)


func check_patrol_and_throw(variant: HammerBroVariant, kind: BroProjectile.Kind, speed: float) -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_powerup(SuperPowerup.new(), false)
	park(player, Vector2(600, -96))
	var body := actor(level, Vector2(400, -96), variant)
	var thrown: BroProjectile
	for frame in 70:
		await ticks(1)
		if not thrown and projectiles(level).size() > 0:
			thrown = projectiles(level)[0]
	check(thrown != null, "%s never threw its source projectile" % variant.id)
	if thrown != null:
		check(thrown.kind == kind, "%s threw the wrong projectile kind" % variant.id)
		check(absf(thrown.velocity.x) == speed, "%s projectile speed differs from source" % variant.id)
		check(signf(thrown.velocity.x) == 1.0, "%s projectile did not face Mario" % variant.id)
	check(body.position.x >= 380.0 and body.position.x <= 416.0,
			"%s patrol left its source +/-16px window" % variant.id)
	level.queue_free()
	await ticks(2)


func check_boomerang() -> void:
	var level := await make_level()
	park(level.hud.player, Vector2(600, -96))
	var body := actor(level, Vector2(400, -96), BOOMERANG)
	var thrown: BroProjectile
	for frame in 110:
		await ticks(1)
		if not thrown and projectiles(level).size() > 0:
			thrown = projectiles(level)[0]
	check(thrown != null, "Boomerang Bro never threw obj_boomerang")
	if thrown != null:
		check(thrown.kind == BroProjectile.Kind.BOOMERANG, "Boomerang Bro threw a non-boomerang")
		check(thrown._returning or thrown.velocity.x < 0.0, "Boomerang never reversed toward its owner")
	level.queue_free()
	await ticks(2)


func check_sledge() -> void:
	var level := await make_level()
	park(level.hud.player, Vector2(600, -96))
	var body := actor(level, Vector2(400, -96), SLEDGE)
	check(body.get_node("CollShape").shape.get_rect().size.is_equal_approx(Vector2(18, 24)),
			"Sledge Bro did not use the source 18x24 mask")
	body._jump_timer = 0.01
	var jumped := false
	for frame in 40:
		await ticks(1)
		if not is_instance_valid(body):
			break
		jumped = jumped or body.velocity.y <= -340.0
	check(jumped, "Sledge Bro did not wind up and launch at -360px/s before gravity")
	level.queue_free()
	await ticks(2)


## Source Draw_0 draws at y with origin y=16: the art bottom must land on the
## feet. A 16px Graphics offset error buried the actor in the first attempt.
func check_art_anchor() -> void:
	for variant in [HAMMER, SLEDGE]:
		var level := await make_level()
		park(level.hud.player, Vector2(600, -96))
		var body := actor(level, Vector2(400, -96), variant)
		await ticks(2)
		var sprite: AnimatedSprite2D = body.get_node("Graphics/Sprite")
		var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		var drawn_bottom: float = sprite.global_position.y + sprite.offset.y + texture.get_height()
		check(absf(drawn_bottom - body.global_position.y - 1) < 0.1,
				"%s art does not overlap its physical feet by 1px" % variant.id)
		level.queue_free()
		await ticks(2)


func check_jump() -> void:
	var level := await make_level()
	park(level.hud.player, Vector2(600, -96))
	var body := actor(level, Vector2(400, -96), HAMMER)
	await ticks(2) # Refresh native floor contacts before forcing the source alarm.
	body._jump_timer = 0.01
	var jumped := false
	for frame in 40:
		await ticks(1)
		if not is_instance_valid(body):
			break
		jumped = jumped or body.velocity.y <= -140.0
	check(jumped, "Hammer Bro did not use the source jump heights")
	level.queue_free()
	await ticks(2)


func check_stomp_and_wings() -> void:
	var level := await make_level()
	var player := level.hud.player
	var body := actor(level, Vector2(400, -96), HAMMER, true)
	body.set_physics_process(false)
	player.set_powerup(SuperPowerup.new(), false)
	park(player, Vector2(400, -160))
	player.state_machine.switch(PlayerFallingState)
	player.velocity.y = 120
	await ticks(26)
	check(is_instance_valid(body), "A stomp defeated winged Hammer Bro instead of stripping wings")
	check(is_instance_valid(body) and not body.wings, "Hammer Bro kept its wings after a stomp")
	check(player.score == 0, "Wing stripping awarded points")
	park(player, Vector2(400, -160))
	player.state_machine.switch(PlayerFallingState)
	player.velocity.y = 120
	await ticks(45)
	check(not is_instance_valid(body), "The second stomp did not defeat Hammer Bro")
	check(player.score == 200, "Hammer Bro defeat did not award the source 200 points")
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


func check_platform_jumps() -> void:
	for small in [false, true]:
		var level := await make_level()
		park(level.hud.player, Vector2(600, -96))
		for x in [384, 400, 416]:
			var part := QuestionBlockPart.create()
			part.position = Vector2(x, -160)
			level.current_sub_area.add_part(part)
			part.load()
			part.build()
		var body := actor(level, Vector2(408, -160 if small else -96), HAMMER)
		await ticks(3)
		body._jump_timer = 0
		var passed := false
		var landed := false
		for frame in 130:
			await ticks(1)
			if not is_instance_valid(body):
				break
			passed = passed or body.position.y > -140 if small else passed or body.position.y < -163
			if passed and body.through_solid == 0 and body.is_on_floor():
				landed = absf(body.position.y - (-96 if small else -160)) < 0.1
				break
		check(passed and landed, "Bro failed its %s native platform pass/landing" % ("small drop" if small else "big upward jump"))
		check(level.hud.player.coins == 0, "Bro platform passing incorrectly activated question-block contents")
		level.queue_free()
		await ticks(2)


func check_winged_sledge() -> void:
	var level := await make_level()
	park(level.hud.player, Vector2(600, -96))
	var body := actor(level, Vector2(400, -96), SLEDGE, true)
	await ticks(3)
	body._jump_timer = 0
	var hover_ticks := 0
	var hovered := false
	var landed := false
	for frame in 180:
		await ticks(1)
		if body._hover_left > 0:
			hovered = true
			hover_ticks += 1
		if hovered and body.is_on_floor():
			landed = true
			break
	check(hovered and hover_ticks in [59, 60, 61] and landed,
			"Winged Sledge did not hover once for 60 ticks and then land")
	check(level.hud.player.state_machine.current_state is PlayerStunnedState,
			"Actual Sledge landing did not stun grounded Mario")
	check(body.get_node("Graphics/Wings").visible, "Winged Sledge lost its runtime wing art")
	level.queue_free()
	await ticks(2)


func check_sledge_parachute() -> void:
	var level := await make_level()
	var body: HammerBro = load("res://scenes/level/entities/hammer_bro.tscn").instantiate()
	body.variant = SLEDGE
	body.parachute = true
	body.position = Vector2(400, -176)
	level.current_sub_area.add(body)
	await ticks(30)
	check(body.parachute and body.velocity.y == 30 and body.position.x < 395,
			"Sledge parachute lost its source fall cap or initial sway")
	for frame in 200:
		await ticks(1)
		if not body.parachute:
			break
	check(not body.parachute and not body.get_node("Graphics/Parachute").visible,
			"Sledge did not detach its parachute on actual landing")
	level.queue_free()
	await ticks(2)
