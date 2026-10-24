# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/bro_projectile_test.gd"
## Actual Sledge impacts interrupt both source hold families, including their
## distinct immunity alarms, turn tween disposal and runtime revision ownership.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--capture-held-stun" in OS.get_cmdline_user_args():
		await capture_stun()
		return
	for small in [false, true]:
		for direction in [-1, 1]:
			for kind in [&"shell", &"buzzy", &"spiny", &"galoomba", &"goombud"]:
				await check_impact(small, direction, kind)
	await check_initial_immunity()
	await check_interrupted_retry()
	await check_freeze_priority()
	await check_stun_effect()
	await finish("HELD_STUN_RESULT")


func hold(level: Level, kind: StringName) -> Entity:
	var item: Entity = load("res://scenes/entities/stomped_galoomba.tscn" \
			if kind in [&"galoomba", &"goombud"] else "res://scenes/entities/koopa_shell.tscn").instantiate()
	if kind == &"buzzy":
		item.variant = preload("res://resources/content/smw_buzzy_empty.tres")
	elif kind == &"spiny":
		item.variant = preload("res://resources/content/smw_spiny_empty.tres")
	elif kind == &"goombud":
		item.variant = preload("res://resources/content/smw_goomba_goombud.tres")
	item.position = Vector2(600, -96)
	level.current_sub_area.add(item)
	Input.action_press("player_run")
	await ticks(17)
	level.hud.player.give_item(item)
	await ticks(2)
	check(level.hud.player.held_item == item, "Held stun test failed to establish native ownership")
	return item


func pause_motion(item: Entity) -> void:
	item.set_physics_process(false)
	item.get_node("GravityComponent").set_physics_process(false)


func check_impact(small: bool, direction: int, kind: StringName) -> void:
	var level := await make_level()
	var player := level.hud.player
	if small:
		player.set_powerup(SmallPowerup.new(), false)
	var item := await hold(level, kind)
	player.set_physics_process(false)
	pause_motion(item)
	player.direction = -direction
	player.state_machine.switch(PlayerIdleState, true)
	player.state_machine.current_state.position_held_item(direction)
	player.direction = direction
	await ticks(2)
	var before := item.global_position
	var player_before := player.global_position
	player.velocity.x = 180 * direction
	var bro: HammerBro = load("res://scenes/entities/hammer_bro.tscn").instantiate()
	bro.variant = preload("res://resources/content/smw_hammerbro_sledge.tres")
	bro.position = Vector2(520, -100)
	level.current_sub_area.add(bro)
	bro._airborne = true
	bro.velocity.y = 120
	bro._jump_timer = 99
	bro._throw_timer = 99
	for frame in 30:
		await ticks(1)
		if player.state_machine.current_state is PlayerStunnedState:
			break
	check(player.state_machine.current_state is PlayerStunnedState and bro.is_on_floor(),
			"A real Sledge floor impact failed to enter stun with a carried %s" % kind)
	var pickup: PickupComponent = Utility.find_child_by_class(item, PickupComponent)
	check(player.held_item == null and pickup.get_holder() == null and item.get_parent() == player.get_parent(),
			"Sledge impact retained carried ownership or the player's child hierarchy")
	check(item.global_position == before - Vector2(0, 1) and item.velocity == Vector2(60 * direction, 0),
			"Forced drop lost source motion: kind=%s small=%s dir=%s before=%s after=%s velocity=%s" \
			% [kind, small, direction, before, item.global_position, item.velocity])
	check(player.velocity.x == 0 and player.sprite.animation == &"idle",
			"Sledge held interruption retained motion or played a normal throw/held animation")
	if item is KoopaShell:
		check(item.motion == KoopaShell.Motion.STATIONARY and item.collision_layer == 2,
				"Sledge drop launched a spinning shell or failed to restore its native body")
	player.give_item(item)
	check(player.held_item == null, "A direct pickup bypassed the source stun control lock")
	player.set_physics_process(true)
	item.set_physics_process(true)
	if item is StompedGaloomba:
		item.get_node("GravityComponent").set_physics_process(true)
	await ticks(14)
	check(pickup.pickup_immunity_left > 0 and player.held_item == null,
			"Sledge drop immunity ended before the source 15-tick alarm boundary")
	check(absf(item.global_position.x - player_before.x) < 64,
			"A stale held-item turning tween teleported the dropped body into area coordinates")
	await ticks(1)
	check(is_inf(pickup.pickup_immunity_left) if item is StompedGaloomba else pickup.pickup_immunity_left == 0,
			"Hold families lost their distinct source alarm6 handling")
	await ticks(64)
	check(player.state_machine.current_state is PlayerStunnedState and player.position == player_before,
			"Forced held release ended the source stun early or moved Mario")
	await ticks(1)
	check(not player.state_machine.current_state is PlayerStunnedState, "Held release extended the source 80-tick stun")
	player.give_item(item)
	check(player.held_item == null if item is StompedGaloomba else player.held_item == item,
			"Post-stun pickup ignored either the shell's cleared alarm or Galoomba's unused alarm6")
	if item is StompedGaloomba and not small and direction == 1:
		await check_recovery(level, item)
	release_input()
	level.queue_free()
	await ticks(2)


func check_recovery(level: Level, item: StompedGaloomba) -> void:
	var player := level.hud.player
	player.position = Vector2(200, -96)
	player.previous_position = player.position
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)
	var variant := item.variant
	item._age = variant.recovery_time - 2.0 / 60
	await ticks(3)
	var recovered: Galoomba
	for body in level.current_sub_area.get_foreground().get_children():
		if body is Galoomba and body.variant == variant:
			recovered = body
	check(not is_instance_valid(item) and recovered != null,
			"Stun's unused immunity alarm prevented the ordinary enemy recovery alarm")
	if recovered == null:
		return
	recovered.stomped.emit(player)
	await ticks(2)
	var fresh: StompedGaloomba
	for body in level.current_sub_area.get_foreground().get_children():
		if body is StompedGaloomba and body.variant == variant:
			fresh = body
	check(fresh != null, "Recovered enemy failed to create a fresh, typed held actor on stomp")
	if fresh != null:
		var pickup: PickupComponent = Utility.find_child_by_class(fresh, PickupComponent)
		check(pickup.pickup_immunity_left > 0 and not is_inf(pickup.pickup_immunity_left),
				"A new held actor inherited the old instance's unused alarm6 immunity")
		await ticks(15)
		check(pickup.pickup_immunity_left == 0, "Recovered held actor failed to clear its fresh alarm3")


func check_initial_immunity() -> void:
	var level := await make_level()
	var player := level.hud.player
	var item: StompedGaloomba = load("res://scenes/entities/stomped_galoomba.tscn").instantiate()
	item.position = player.position
	level.current_sub_area.add(item)
	await ticks(3)
	Input.action_press("player_run")
	await ticks(10)
	check(player.held_item == null, "A new flipped Galoomba skipped its inherited 15-tick alarm3 immunity")
	await ticks(3)
	check(player.held_item == item, "An already overlapping Run pickup did not resume when initial immunity expired")
	release_input()
	level.queue_free()
	await ticks(2)


func check_interrupted_retry() -> void:
	var level := await make_level()
	var player := level.hud.player
	var item := await hold(level, &"shell")
	check(player.stun_from_landing(), "Pending stun/retry test failed to stun Mario")
	level.reload()
	await ticks(3)
	check(not is_instance_valid(item) and not level.hud.player.state_machine.current_state is PlayerStunnedState,
			"Immediate retry let an old forced drop enter the new area revision")
	release_input()
	level.queue_free()
	await ticks(2)


func check_freeze_priority() -> void:
	var level := await make_level()
	var player := level.hud.player
	var item := await hold(level, &"galoomba")
	player.state_machine.switch(PlayerIdleState, true)
	player.set_physics_process(false)
	pause_motion(item)
	var before := item.global_position
	check(player.stun_from_landing() and player.freeze_in_ice(), "Same-step stun/freeze test failed its source transitions")
	await ticks(2)
	var pickup: PickupComponent = Utility.find_child_by_class(item, PickupComponent)
	check(item.global_position == before and item.velocity == Vector2.ZERO and pickup.pickup_immunity_left == 0,
			"Same-step freezing incorrectly took the old Mario's stunned hold branch")
	level.queue_free()
	await ticks(2)


func check_stun_effect() -> void:
	var level := await make_level()
	var player := level.hud.player
	check(player.stun_from_landing(), "Shake effect test failed to enter stun")
	await ticks(9) # Sample beyond the render-update boundary of frame8.
	var state: PlayerStunnedState = player.state_machine.current_state
	var effect := state._effect
	check(effect != null and effect.global_position == player.global_position + Vector2(0, -27) \
			and effect.frame == 2 and effect.sprite_frames.get_animation_speed(effect.animation) == 15,
			"Stun shake lost its source offset/rate: at=%s player=%s frame=%s fps=%s" \
			% [effect.global_position, player.global_position, effect.frame, effect.sprite_frames.get_animation_speed(effect.animation)])
	var progress := effect.frame_progress
	check(player.stun_from_landing() and state._effect == effect and effect.frame_progress == progress,
			"Repeated Sledge stun replaced/restarted the existing shake animation")
	check(is_equal_approx(state.remaining, 80.0 / 60), "Repeated impact failed to reset the source stun clock")
	check(player.freeze_in_ice(), "Shake teardown test failed to freeze stunned Mario")
	await ticks(2)
	check(not is_instance_valid(effect), "Source Mario replacement retained the stun shake sprite")
	level.reload()
	await ticks(3)
	check(not is_instance_valid(state), "Retry retained a previous stun state/effect")
	level.queue_free()
	await ticks(2)


func capture_stun() -> void:
	var level := await make_level()
	var player := level.hud.player
	player.equip_buzzy_helmet()
	var item := await hold(level, &"spiny")
	player.state_machine.switch(PlayerIdleState, true)
	var bro: HammerBro = load("res://scenes/entities/hammer_bro.tscn").instantiate()
	bro.variant = preload("res://resources/content/smw_hammerbro_sledge.tres")
	bro.position = Vector2(304, -100)
	level.current_sub_area.add(bro)
	bro._airborne = true
	bro.velocity.y = 120
	bro._jump_timer = 99
	bro._throw_timer = 99
	for frame in 20:
		await ticks(1)
		if player.state_machine.current_state is PlayerStunnedState:
			break
	await ticks(5)
	check(player.state_machine.current_state is PlayerStunnedState and player.held_item == null \
			and item.get_parent() == player.get_parent() and player.has_helmet(),
			"Capture missed a real Sledge landing, held drop or retained helmet")
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_held_stun.png")
	check(error == OK, "Could not save held stun capture")
	print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	level.queue_free()
	await ticks(2)
	get_tree().quit(0 if failures.is_empty() else 1)
