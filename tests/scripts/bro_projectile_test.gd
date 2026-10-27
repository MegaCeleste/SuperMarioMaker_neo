# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Regressions derived from the source events, including behaviours missing
## from the original green Bro tests: distinct ice contacts, alarm boundaries,
## animation, terrain collisions, control locks and restart disposal.

const FIXTURE := "res://tests/fixtures/port_slice.swe"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--capture-bro-status" in OS.get_cmdline_user_args():
		await capture_status()
		return
	for direction in [-1, 1]:
		await check_boomerang_alarms(direction)
	await check_hammer_water()
	for kind in [BroProjectile.Kind.FIRE, BroProjectile.Kind.ICE]:
		await check_wall(kind)
	await check_ice_bounces()
	await check_freeze_and_retry()
	await check_stun()
	await check_view_boundaries()
	await check_boomerang_lifetime()
	finish("BRO_PROJECTILE_RESULT")


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
	var player := level.hud.player
	player.position = Vector2(400, -96)
	player.previous_position = player.position
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)
	player.set_powerup(SuperPowerup.new(), false)
	await ticks(4)
	return level


func shot(level: Level, kind: BroProjectile.Kind, at: Vector2, direction := 1) -> BroProjectile:
	var body := BroProjectile.new()
	body.kind = kind
	body.direction = direction
	body.position = at
	level.current_sub_area.add(body)
	return body


func check_view_boundaries() -> void:
	var level := await make_level()
	for kind in [BroProjectile.Kind.HAMMER, BroProjectile.Kind.FIRE, BroProjectile.Kind.ICE, BroProjectile.Kind.BOOMERANG]:
		for edge in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			if kind == BroProjectile.Kind.HAMMER and edge == Vector2.UP:
				continue
			var view := Utility.get_visible_rect()
			var at := view.get_center()
			if edge.x != 0:
				at.x = view.position.x - 32 if edge.x < 0 else view.end.x + 32
				at.y = view.position.y + 48 # Keep Create's solid-overlap burst out of this culling fixture.
			else:
				at.y = view.position.y - 32 if edge.y < 0 else view.end.y + 32
			var body := shot(level, kind, at)
			body.set_physics_process(false)
			body.velocity = edge * 120
			body._physics_process(1.0 / 60)
			check(not body.is_queued_for_deletion(), "Shot %s was culled at the inclusive origin boundary %s" % [kind, edge])
			var after := body.position
			body._physics_process(1.0 / 60)
			check(body.is_queued_for_deletion() and body.position == after,
					"Shot %s did not cull before movement on the next Step at %s" % [kind, edge])
			await ticks(1)
	# An already-outside inward shot must not get one motion step to rescue itself.
	for kind in [BroProjectile.Kind.HAMMER, BroProjectile.Kind.FIRE, BroProjectile.Kind.ICE, BroProjectile.Kind.BOOMERANG]:
		var view := Utility.get_visible_rect()
		var body := shot(level, kind, Vector2(view.position.x - 32.01, view.position.y + 48))
		body.set_physics_process(false)
		body.velocity.x = 120
		var before := body.position
		body._physics_process(1.0 / 60)
		check(body.is_queued_for_deletion() and body.position == before, "Outside inward shot escaped its source Step cull")
		await ticks(1)
	var high := shot(level, BroProjectile.Kind.HAMMER, Vector2(400, Utility.get_visible_rect().position.y - 64))
	high.set_physics_process(false)
	high._physics_process(1.0 / 60)
	check(not high.is_queued_for_deletion(), "Hammer acquired the other shots' top culling boundary")
	level.queue_free()
	await ticks(2)


func check_boomerang_lifetime() -> void:
	var level := await make_level()
	var body := shot(level, BroProjectile.Kind.BOOMERANG, Vector2(460, -180))
	body.set_physics_process(false)
	# Keep a genuine boomerang stationary while advancing its own alarm clock.
	body._caught = true
	body._sprite.scale = Vector2(1000, 1000)
	body.velocity = Vector2.ZERO
	for frame in 359:
		body._physics_process(1.0 / 60)
	check(body._sprite.visible and not body.is_queued_for_deletion(), "Boomerang blinked before tick360")
	body._physics_process(1.0 / 60)
	check(not body._sprite.visible, "Boomerang missed the first hide at tick360")
	for frame in 6:
		body._physics_process(1.0 / 60)
	check(not body._sprite.visible, "Boomerang blink interval was shorter than seven ticks")
	body._physics_process(1.0 / 60)
	check(body._sprite.visible, "Boomerang did not reappear at tick367")
	for frame in 112:
		body._physics_process(1.0 / 60)
	check(not body.is_queued_for_deletion(), "Boomerang expired before tick480")
	body.velocity.x = 120
	var before := body.position
	body._physics_process(1.0 / 60)
	check(body.is_queued_for_deletion() and body.position == before, "Boomerang expiry ran after tick480 movement")
	body = shot(level, BroProjectile.Kind.BOOMERANG, Vector2(460, -180))
	body.set_physics_process(false)
	body._caught = true
	body._sprite.scale = Vector2(0.3, 0.3)
	body._physics_process(1.0 / 60)
	check(not body.is_queued_for_deletion() and body._sprite.scale.x < 0.2,
			"Caught boomerang was destroyed on the shrink step instead of the next Step")
	before = body.position
	body._physics_process(1.0 / 60)
	check(body.is_queued_for_deletion() and body.position == before, "Caught boomerang moved after its removal")
	level.queue_free()
	await ticks(2)


func check_boomerang_alarms(direction: int) -> void:
	var level := await make_level()
	var body := shot(level, BroProjectile.Kind.BOOMERANG, Vector2(400, -200), direction)
	await ticks(31)
	check(is_instance_valid(body), "Boomerang was culled inside the test's visible flight area")
	if not is_instance_valid(body):
		level.queue_free()
		await ticks(2)
		return
	check(body.velocity == Vector2(120 * direction, -45), "Boomerang changed its launch motion before alarm[0]=32")
	await ticks(1)
	check(is_equal_approx(body.velocity.y, -42), "Boomerang did not begin flattening on tick32")
	await ticks(14)
	check(is_zero_approx(body.velocity.y), "Boomerang did not finish the source 15-tick flattening phase")
	await ticks(1)
	check(is_equal_approx(body.velocity.y, 3), "Boomerang did not start descending at alarm[1]=47")
	await ticks(7)
	check(is_equal_approx(body.velocity.x, 120 * direction), "Boomerang reversed before alarm[2]=55")
	await ticks(1)
	check(is_equal_approx(body.velocity.x, 115.5 * direction), "Boomerang must accelerate into its turn, not reverse instantly")
	check(absf(body._sprite.rotation_degrees) > 500, "Boomerang art never rotated")
	var owner: HammerBro = load("res://scenes/level/entities/hammer_bro.tscn").instantiate()
	owner.position = Vector2(700 if direction > 0 else 100, -96)
	level.current_sub_area.add(owner)
	owner.set_physics_process(false)
	body.home = owner
	await ticks(56)
	check(is_instance_valid(body) and is_equal_approx(body.velocity.x, -120 * direction),
			"Boomerang homed toward its relocated owner instead of completing the source horizontal turn")
	level.queue_free()
	await ticks(2)


func check_hammer_water() -> void:
	var level := await make_level()
	level.current_sub_area.level_theme = Level.LevelTheme.UNDERWATER
	var hammer := shot(level, BroProjectile.Kind.HAMMER, Vector2(400, -160))
	check(hammer.velocity == Vector2(90, -120), "Underwater hammer lost its source -2px/frame launch")
	await ticks(10)
	check(is_equal_approx(hammer.velocity.y, -90), "Underwater hammer used air gravity instead of 0.05px/frame²")
	check(is_equal_approx(hammer._sprite.rotation_degrees, 60), "Underwater hammer rotation differs from SMW's 6 degrees/tick")
	check(hammer._sprite.frame == 0, "Single-frame hammer attempted to select a style index")
	level.queue_free()
	await ticks(2)


func check_wall(kind: BroProjectile.Kind) -> void:
	var level := await make_level()
	var wall := StaticBody2D.new()
	wall.position = Vector2(456, -176)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 128)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	wall.add_child(collider)
	level.current_sub_area.add(wall)
	var body := shot(level, kind, Vector2(400, -200))
	await ticks(8)
	check(body._sprite.frame > 0 and body._sprite.is_playing(), "Bro fire/ice animation was frozen on SMW style frame2")
	await ticks(24)
	check(not is_instance_valid(body), "Bro fire/ice passed through a native wall")
	level.queue_free()
	await ticks(2)


func check_ice_bounces() -> void:
	var level := await make_level()
	var body := shot(level, BroProjectile.Kind.ICE, Vector2(300, -144))
	var rebound := false
	for frame in 100:
		await ticks(1)
		if not is_instance_valid(body):
			break
		if body.velocity.y < 0:
			rebound = true
			check(is_equal_approx(body.velocity.y, -253.5), "Ice did not use its distinct -4.225px/frame first bounce")
			break
	check(rebound, "Ice never bounced from native terrain")
	for frame in 100:
		await ticks(1)
		if not is_instance_valid(body):
			break
	check(not is_instance_valid(body), "Ice must break on its second landing, not bounce forever")
	level.queue_free()
	await ticks(2)


func check_freeze_and_retry() -> void:
	var level := await make_level()
	var player := level.hud.player
	player.equip_buzzy_helmet()
	var at := player.global_position
	var body := shot(level, BroProjectile.Kind.ICE, at + Vector2(-4, -24))
	await ticks(4)
	check(player.is_frozen() and not is_instance_valid(body), "Ice overlap should freeze Mario and consume the snowball")
	check(player.get_powerup() is SuperPowerup and player.has_helmet(), "Freezing consumed Mario's power or helmet like generic damage")
	# Native Areas can still deliver a contact queued before layer0 was applied.
	var stale: HammerBro = load("res://scenes/level/entities/hammer_bro.tscn").instantiate()
	stale.position = player.position + Vector2(0, 16)
	level.current_sub_area.add(stale)
	stale.set_physics_process(false)
	stale._body_handling(true, player)
	check(player.is_frozen() and not stale.is_queued_for_deletion() and player.score == 0,
			"A stale enemy overlap broke frozen Mario out of the ice as a stomp")
	stale.queue_free()
	Input.action_press("player_right")
	Input.action_press("player_jump")
	await ticks(110)
	check(player.is_frozen() and player.global_position.distance_to(at) < 0.01,
			"Frozen Mario moved or resumed controls before the source three-second alarm")
	if player.is_frozen():
		var frozen: PlayerFrozenState = player.state_machine.current_state
		check(is_equal_approx(frozen._front.modulate.a, 0.3), "Frozen Mario lost the source translucent front layer")
	for frame in 80:
		await ticks(1)
		if not player.is_frozen():
			break
	check(not player.is_frozen() and player.collision_layer == 4,
			"Mario did not thaw and restore native enemy contacts")
	await ticks(12)
	check(player.global_position.x > at.x + 1, "Mario's movement stayed locked after thawing")
	release_input()
	check(player.freeze_in_ice(), "Mario could not freeze a second time")
	level.reload()
	await ticks(5)
	check(is_instance_valid(level.hud.player) and not level.hud.player.is_frozen(),
			"Frozen state or its ice graphics survived a level retry")
	level.queue_free()
	await ticks(2)


func check_stun() -> void:
	var level := await make_level()
	var player := level.hud.player
	var at := player.global_position
	check(player.stun_from_landing(), "Grounded Mario rejected the Sledge landing stun")
	Input.action_press("player_right")
	Input.action_press("player_jump")
	var event := InputEventAction.new()
	event.action = &"player_spin_jump"
	event.pressed = true
	get_viewport().push_input(event, true)
	await ticks(79)
	check(player.state_machine.current_state is PlayerStunnedState \
			and absf(player.global_position.x - at.x) < 0.01 and player.is_on_floor(),
			"Movement/jump input bypassed the 80-tick Sledge stun")
	await ticks(14)
	check(not player.state_machine.current_state is PlayerStunnedState \
			and player.global_position.x > at.x + 1,
			"Sledge stun failed to restore controls after 80 ticks")
	release_input()
	player.global_position.y -= 64
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerFallingState)
	await ticks(2)
	check(not player.stun_from_landing(), "Sledge landing incorrectly stunned airborne Mario")
	level.queue_free()
	await ticks(2)


func capture_status() -> void:
	var level := await make_level()
	var player := level.hud.player
	player.equip_buzzy_helmet()
	var bro: HammerBro = load("res://scenes/level/entities/hammer_bro.tscn").instantiate()
	bro.variant = preload("res://resources/content/smw_hammerbro_sledge.tres")
	bro.wings = true
	bro.position = Vector2(304, -96)
	level.current_sub_area.add(bro)
	await ticks(3)
	bro._jump_timer = 0
	shot(level, BroProjectile.Kind.ICE, player.position + Vector2(-4, -24))
	await ticks(78)
	check(player.is_frozen() and bro._hover_left > 0,
			"Graphical status capture missed actual freezing or Sledge hover")
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_bro_status.png")
	check(error == OK, "Could not save graphical Bro status capture")
	print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	level.queue_free()
	await ticks(2)
	get_tree().quit(0 if failures.is_empty() else 1)
