# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/bro_environment_test.gd"
## Real death lifecycle: selected motion stops, uncancelled events still run.

const BODIES := ["galoomba", "green_koopa", "beach_koopa", "koopa_shell",
	"stomped_galoomba", "buzzy_beetle", "spiny", "blooper", "cheep_cheep",
	"piranha_plant", "monty", "hammer_bro", "mushroom", "muncher", "thwomp", "grrrol"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--capture-world-death" in OS.get_cmdline_user_args():
		await capture_death()
		return
	for name in BODIES:
		await check_body_stop(name)
	await check_independent_objects()
	await check_stopped_shell_contact()
	await check_replacement_targets()
	for kind in [&"hammer", &"boomerang", &"sledge"]:
		await check_pending_throw(kind)
	await check_held_release(false)
	await check_held_release(true)
	await check_held_release(false, true)
	await check_held_release(true, true)
	await check_recovery_and_manual_rise()
	await check_death_clock(false)
	await check_death_clock(true)
	await check_power_pause(false)
	await check_power_pause(true)
	await check_retry_ownership()
	await finish("WORLD_DEATH_RESULT")


func actor(level: Level, scene: String, at := Vector2(480, -180)) -> CharacterBodyExt:
	var body: CharacterBodyExt = load("res://scenes/level/entities/" + scene + ".tscn").instantiate()
	body.position = at
	level.current_sub_area.add(body)
	return body


func check_body_stop(scene: String) -> void:
	var level := await make_level()
	var body := actor(level, scene)
	body.velocity = Vector2(60, 120)
	var at := body.position
	var time := level.get_current_time()
	var animation_clock := level.animation_time
	level.hud.player.kill()
	await ticks(12)
	check(body.can_process() and level.can_process() and not get_tree().paused,
			"Death disabled events instead of applying source motion policy: " + scene)
	check(body.position.is_equal_approx(at) and body.velocity == Vector2.ZERO,
			"Source physical actor moved during death: %s (%s -> %s, v=%s)" % [scene, at, body.position, body.velocity])
	check(level.get_current_time() == time and level.animation_time > animation_clock + 0.1,
			"Death stopped the manager clock or changed the visible course time")
	for sprite in body.find_children("*", "AnimatedSprite2D", true, false):
		check(not sprite.is_playing(), "Physical image_speed was not stopped for " + scene)
	level.queue_free()
	await ticks(2)


func check_independent_objects() -> void:
	var level := await make_level()
	var area := level.current_sub_area
	var hammer := shot(level, BroProjectile.Kind.HAMMER, Vector2(440, -180))
	var fire := shot(level, BroProjectile.Kind.FIRE, Vector2(460, -180))
	var ice := shot(level, BroProjectile.Kind.ICE, Vector2(480, -180))
	var boom := shot(level, BroProjectile.Kind.BOOMERANG, Vector2(420, -180))
	var plant := PlantFireball.new()
	plant.variant = preload("res://resources/content/smw_piranha_fire.tres")
	plant.position = Vector2(440, -200)
	plant.velocity = Vector2(60, 0)
	area.add(plant)
	var wrench := Wrench.new()
	wrench.position = Vector2(450, -150)
	area.add(wrench)
	wrench._height = 0
	var corpse := SwimmingEnemyDefeat.new()
	corpse.sub_area = area
	corpse.variant = preload("res://resources/content/smw_monty.tres")
	corpse.position = Vector2(430, -160)
	corpse.velocity.x = 60
	area.add(corpse)
	var smoke := EnemyEffect.play_once(area, &"spr_smoke", Vector2(500, -160), 18)
	var splash := EnemyEffect.play_once(area, &"spr_splash", Vector2(520, -170), 12, false)
	var sink := SinkingEnemy.new()
	sink.sub_area = area
	sink.sprite_name = &"spr_rocky_idle"
	sink.animate = false
	sink.position = Vector2(480, -180)
	area.add(sink)
	await ticks(2)
	var hammer_at := hammer.position
	var fire_at := fire.position
	var boom_at := boom.position
	var plant_at := plant.position
	var corpse_at := corpse.position
	var corpse_angle := corpse.rotation
	var hammer_angle := hammer._sprite.rotation
	var sink_y := sink.position.y
	level.hud.player.kill()
	await ticks(8)
	check(hammer.position == hammer_at and fire.position == fire_at and hammer._sprite.rotation == hammer_angle,
			"The central death handler did not stop hammer/fire motion and rotation")
	check(not is_instance_valid(ice), "Ice's unguarded second count did not burst during death")
	check(boom.position.x > boom_at.x + 12 and boom._sprite.rotation_degrees > 50,
			"Independent boomerang movement/rotation was globally paused")
	check(plant.position.x > plant_at.x + 6, "Independent plant-fire projectile was globally paused")
	check(wrench.velocity == Vector2.ZERO and wrench._sprite.is_playing() and wrench._age > 0.1,
			"Wrench must stop motion while keeping its animation/alarms")
	check(corpse.position == corpse_at and corpse.rotation == corpse_angle and corpse.velocity == Vector2.ZERO,
			"The source obj_enemy_dead death stop was missing")
	check(is_instance_valid(smoke) and not smoke.is_playing() and is_instance_valid(splash) and splash.is_playing(),
			"The source smoke stop was incorrectly applied to independent splashes")
	check(sink.position.y > sink_y + 0.2, "Independent obj_enemyparent_lava was incorrectly stopped with normal corpses")
	level.queue_free()
	await ticks(2)


func check_pending_throw(kind: StringName) -> void:
	var level := await make_level()
	var body: HammerBro = load("res://scenes/level/entities/hammer_bro.tscn").instantiate()
	body.variant = load("res://resources/content/smw_hammerbro_" + String(kind) + ".tres")
	body.position = Vector2(480.4, -96)
	level.current_sub_area.add(body)
	body._throw_timer = 1.0 / 60
	body._jump_timer = 1.0 / 60
	body._windup = 3.0 / 60
	body._throw_pose = 1
	level.hud.player.kill()
	await ticks(12)
	var shots := live_nodes(level.current_sub_area, BroProjectile)
	check(shots.size() == 1 and body._throw_timer == INF and body._jump_timer == INF,
			"Death cancelled a pending throw or allowed a cancelled throw/jump alarm: " + String(kind))
	if shots.size() == 1:
		check(shots[0].velocity.x < 0 if kind == &"boomerang" else shots[0].velocity == Vector2.ZERO,
				"A pending shot did not follow its own source death policy")
		if kind != &"boomerang":
			check(shots[0]._sprite.flip_h and is_equal_approx(shots[0]._sprite.global_position.x, roundf(shots[0].global_position.x)),
					"A hammer born during death lost its facing or drawing-only pixel alignment")
	await ticks(40)
	check(live_nodes(level.current_sub_area, BroProjectile).size() <= 1,
			"A cancelled throw-start alarm kept creating shots during death")
	level.queue_free()
	await ticks(2)


func check_stopped_shell_contact() -> void:
	var level := await make_level()
	var body := actor(level, "monty", Vector2(500, -96))
	var shell: KoopaShell = actor(level, "koopa_shell", Vector2(460, -96))
	shell.motion = KoopaShell.Motion.MOVING
	shell.velocity.x = 180
	shell._target_velocity = 180
	level.hud.player.kill()
	body.position.x = 468 # Native overlap arrives after the speed was cleared.
	await ticks(4)
	check(is_instance_valid(body) and not body.is_queued_for_deletion() and shell.velocity == Vector2.ZERO,
			"A stopped moving-shell state damaged an enemy despite source hspeed=0")
	level.queue_free()
	await ticks(2)


func check_replacement_targets() -> void:
	var level := await make_level()
	var player := level.hud.player
	var mole: Monty = actor(level, "monty", Vector2(320, -96))
	var rocky: Rocky = actor(level, "rocky", Vector2(320, -160))
	var bro: HammerBro = actor(level, "hammer_bro", Vector2(320, -96))
	var plant: PiranhaPlant = load("res://scenes/level/entities/piranha_plant.tscn").instantiate()
	plant.variant = preload("res://resources/content/smw_piranha_fire.tres")
	plant.position = Vector2(320, -96)
	level.current_sub_area.add(plant)
	await ticks(2)
	check(mole.direction == 1 and rocky.direction == 1 and bro.direction == 1 and plant.direction == 1,
			"Replacement-target fixture did not initially face living Mario")
	player.freeze_in_ice()
	var thwomp: Thwomp = actor(level, "thwomp", Vector2(player.position.x, -180))
	await ticks(3)
	check(level.get_living_player() == null and mole.direction == -1 and rocky.direction == -1
			and bro.direction == -1 and plant.direction == -1 and thwomp.phase == Thwomp.Phase.WAITING,
			"Recent enemy AI still targeted a frozen replacement as source obj_mario")
	player.state_machine.switch(PlayerIdleState)
	level.complete(player)
	check(level.get_living_player() == null, "Goal replacement remained a source AI target")
	level.queue_free()
	await ticks(2)


func check_held_release(galoomba: bool, simultaneous_stun := false) -> void:
	var level := await make_level()
	var player := level.hud.player
	var body := actor(level, "stomped_galoomba" if galoomba else "koopa_shell", Vector2(460, -160))
	await ticks(16)
	Input.action_press("player_run")
	player.give_item(body)
	await ticks(2)
	body.set_physics_process(false)
	var pickup: PickupComponent = Utility.find_child_by_class(body, PickupComponent)
	check(player.held_item == body and pickup.get_holder() == player, "Held-death fixture did not pick up its item")
	player.state_machine.current_state.position_held_item(-player.direction)
	var at := body.global_position
	var kicks: Array[int] = []
	player.item_dropped.connect(func(_item): kicks.append(1))
	if simultaneous_stun:
		player.stun_from_landing()
	player.kill()
	await ticks(3)
	check(player.held_item == null and pickup.get_holder() == null and body.get_parent() == level.current_sub_area.get_foreground(),
			"Death retained a stale held owner/parent")
	check(body.global_position.is_equal_approx(at) and body.velocity == Vector2.ZERO and kicks.is_empty()
			and player.held_item_tween == null, "Death gave a kick impulse or let the held turn tween move the released item")
	level.queue_free()
	await ticks(2)
	release_input()


func check_recovery_and_manual_rise() -> void:
	var level := await make_level()
	var area := level.current_sub_area
	var held: StompedGaloomba = actor(level, "stomped_galoomba", Vector2(500, -96))
	held._age = held.variant.recovery_time - 3.0 / 60
	var rocky: Rocky = actor(level, "rocky", Vector2(440, -80))
	rocky.phase = Rocky.Phase.RISE
	rocky._home = -80
	rocky._target = -82
	rocky._rise_next = Rocky.Phase.HIGH_WAIT
	var liquid := add_liquid(level, Level.LevelTheme.FOREST, -24)
	liquid.set_physics_process(true)
	liquid.phase = LiquidSurface.Phase.HOLD_TOP
	liquid._hold = 3.0 / 60
	level.hud.player.kill()
	var y := rocky.position.y
	await ticks(6)
	check(not is_instance_valid(held) and live_nodes(area, Galoomba).size() == 1,
			"Uncancelled held-enemy recovery was globally paused")
	check(rocky.position.y < y and rocky.phase == Rocky.Phase.HIGH_WAIT,
			"Rocky's explicit y changes/phase alarms were disabled with automatic motion")
	check(liquid.phase == LiquidSurface.Phase.DESCEND and liquid.velocity == 0 and liquid._age == 0,
			"Liquid death stop froze its uncancelled hold alarm or continued motion/animation")
	level.queue_free()
	await ticks(2)


func check_death_clock(editor: bool) -> void:
	var level := await make_level()
	if editor:
		level.create_editor()
	var player := level.hud.player
	var at := player.position
	var camera := Utility.camera_position
	var revision := level.current_sub_area._runtime_revision
	player.direction = -1
	player.sprite.flip_h = true
	player.kill()
	await ticks(29)
	check(player.position == at and player.velocity == Vector2.ZERO and player.sprite.frame == 0 and not player.sprite.flip_h,
			"SMW death did not hold its initial pose for 29 ticks")
	check(player.sprite.offset.y == -SpriteLibrary.get_origin(&"spr_mario_dead").y - 32,
			"The separate death Draw incorrectly kept normal Mario's y+1 offset")
	await ticks(1)
	check(is_equal_approx(player.velocity.y, -198) and is_equal_approx(player.position.y, at.y - 3.3),
			"SMW death failed to launch before motion on tick30")
	await ticks(119)
	check(is_instance_valid(player) and not player.is_queued_for_deletion() and player.is_dead()
			and Utility.camera_position.is_equal_approx(camera), "Death retried early or made the camera follow the corpse")
	await ticks(1)
	check(level.current_sub_area._runtime_revision > revision and not level.is_player_dying(),
			"SMW death did not leave its runtime at tick150")
	check(level.status == Level.Status.EDITING if editor else level.status == Level.Status.PLAYING
			and level.hud.player != player and not level.hud.player.is_dead(),
			"Death did not return to editing or rebuild a living player")
	level.queue_free()
	await ticks(2)


func check_power_pause(external_pause: bool) -> void:
	var level := await make_level()
	var player := level.hud.player
	get_tree().paused = external_pause
	player.set_powerup(SmallPowerup.new(), true)
	check(get_tree().paused, "Power interruption fixture did not acquire its pause")
	player.kill()
	var hold_left: float = player.state_machine.current_state._hold_left
	await ticks(3)
	check(get_tree().paused == external_pause and player.is_dead() and player.sprite.visible,
			"Death did not release the transformation pause or stole an external pause")
	if external_pause:
		check(player.state_machine.current_state._hold_left == hold_left,
				"Death alarms advanced through an externally owned pause")
	for node in player.sprite.get_children():
		check(not node is PowerupAnimation or node.is_queued_for_deletion(), "Old power animation survived death")
	get_tree().paused = false
	level.queue_free()
	await ticks(2)


func check_retry_ownership() -> void:
	var level := await make_level()
	var player := level.hud.player
	var body := actor(level, "koopa_shell")
	await ticks(16)
	player.give_item(body)
	await ticks(1)
	player.kill()
	level.reload()
	await ticks(3)
	check(not is_instance_valid(body) and not level.is_player_dying() and not level.hud.player.is_dead()
			and level.can_process() and level.current_sub_area._pending_spawns.is_empty(),
			"Same-step death/retry rescued an old held actor or retained death state")
	level.queue_free()
	await ticks(2)


func capture_death() -> void:
	var level := await make_level()
	await ticks(40)
	actor(level, "monty", Vector2(440, -96))
	actor(level, "hammer_bro", Vector2(320, -96))
	var hammer := shot(level, BroProjectile.Kind.HAMMER, Vector2(350, -155))
	var boom := shot(level, BroProjectile.Kind.BOOMERANG, Vector2(500, -165), -1)
	level.hud.player.kill()
	await ticks(42)
	check(hammer.position == Vector2(350, -155) and boom.position.x < 450 and level.hud.player.is_dead(),
			"Death capture missed stopped and independent objects")
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_world_death.png")
	check(error == OK, "Could not save world-death capture")
	print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	level.queue_free()
	await ticks(2)
	get_tree().quit(0 if failures.is_empty() else 1)
