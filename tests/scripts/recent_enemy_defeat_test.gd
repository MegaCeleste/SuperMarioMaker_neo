# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/bro_environment_test.gd"
## Source Other_10, inherited Mario/block/shell contacts and corpse Step order.

const MONTY := preload("res://resources/content/smw_monty.tres")
const PROFILES := [MONTY,
	preload("res://resources/content/smw_hammerbro_hammer.tres"),
	preload("res://resources/content/smw_hammerbro_fire.tres"),
	preload("res://resources/content/smw_hammerbro_ice.tres"),
	preload("res://resources/content/smw_hammerbro_boomerang.tres"),
	preload("res://resources/content/smw_hammerbro_sledge.tres")]
const FRAMES := [2, 0, 1, 2, 3, 0]
const OFFSETS := [-8, -13, -13, -13, -13, -16]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--capture-enemy-defeat" in OS.get_cmdline_user_args():
		await capture_defeats()
		return
	for index in PROFILES.size():
		for facing in [-1, 1]:
			await check_typed_defeat(index, facing)
		await check_hit_context(index)
		await check_pow_and_spin(index)
		await check_block_collision(index)
	for index in [0, 1, 5]:
		await check_water_launch(index)
		await check_shell_collision(index)
		await check_helmet_collision(index)
	await check_corpse_motion_boundaries()
	await check_defeat_retry()
	await finish("RECENT_ENEMY_DEFEAT_RESULT")


func enemy(level: Level, index: int, at := Vector2(480, -160), facing := -1, wings := false) -> Enemy:
	var body: Enemy = load("res://scenes/entities/monty.tscn" if index == 0
			else "res://scenes/entities/hammer_bro.tscn").instantiate()
	body.variant = PROFILES[index]
	body.position = at
	body.direction = facing
	body.wings = wings
	level.current_sub_area.add(body)
	body.set_physics_process(false)
	return body


func pending_corpse(area: SubArea) -> SwimmingEnemyDefeat:
	for entry in area._pending_spawns.values():
		if entry.node is SwimmingEnemyDefeat:
			return entry.node
	return null


func hold_corpse(area: SubArea) -> SwimmingEnemyDefeat:
	var corpse := pending_corpse(area)
	if corpse != null:
		corpse.ready.connect(func(): corpse.set_physics_process(false), CONNECT_ONE_SHOT)
	return corpse


func check_typed_defeat(index: int, facing: int) -> void:
	var level := await make_level()
	var area := level.current_sub_area
	var body := enemy(level, index, Vector2(480, -160), facing)
	# Facing is deliberately opposite the impulse; drawing and motion are independent.
	body.kill(-facing)
	var corpse := hold_corpse(area)
	check(corpse != null and corpse.position == Vector2(480, -160 + OFFSETS[index])
			and corpse.velocity.x == -60 * facing, "Wrong source corpse origin/impulse for family %s" % index)
	await ticks(2)
	if is_instance_valid(corpse):
		var sprite: AnimatedSprite2D = corpse.get_child(0)
		check(sprite.frame == FRAMES[index] and sprite.flip_h == (facing < 0)
				and not sprite.is_playing() and corpse.velocity.y == -240,
				"Corpse lost its type frame, facing, fixed pose or air launch for family %s" % index)
		corpse._physics_process(1.0 / 60)
		check(corpse.position.is_equal_approx(Vector2(480 - facing, -163.8 + OFFSETS[index]))
				and is_equal_approx(corpse.rotation_degrees, -16 * facing),
				"Corpse did not execute the source first air Step for family %s" % index)
	level.queue_free()
	await ticks(2)


func check_hit_context(index: int) -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_physics_process(false)
	# Moving Mario's actual speed wins over his facing and position.
	for speed in [-120.0, 120.0, 0.000001]:
		var body := enemy(level, index)
		player.position = Vector2(520, -160)
		player.direction = -int(signf(speed))
		player.velocity = Vector2(speed, 120)
		player.state_machine.switch(PlayerFallingState)
		var old_score := player.score
		body._stomped(player)
		var corpse := hold_corpse(level.current_sub_area)
		check(corpse != null and corpse.velocity.x == 60 * signf(speed) and player.score == old_score + 200,
				"Normal stomp used Mario's facing instead of actual speed for family %s" % index)
		await ticks(2)
		if is_instance_valid(corpse):
			corpse.queue_free()
	# A wide, stationary partner distinguishes Monty's weighted bounds from
	# the Bros' left-edge comparison. Equal masks must produce zero speed.
	var impact := CharacterBody2D.new()
	impact.collision_layer = 0
	impact.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80, 16)
	collider.shape = shape
	impact.add_child(collider)
	level.current_sub_area.add(impact)
	for equal in [false, true]:
		var body := enemy(level, index)
		var bounds := Utility.get_bounding_box(body)
		shape.size = bounds.size if equal else Vector2(80, 16)
		impact.position = bounds.get_center() if equal else Vector2(bounds.position.x + 39, -168)
		body.hit_by_actor(&"shell", impact, -1)
		var corpse := hold_corpse(level.current_sub_area)
		var expected := 0 if equal else -60 if index == 0 else 60
		check(corpse != null and corpse.velocity.x == expected,
				"Stationary impact collapsed source bbox rules or zero impulse for family %s" % index)
		await ticks(2)
		if is_instance_valid(corpse):
			corpse.queue_free()
	level.queue_free()
	await ticks(2)


func check_pow_and_spin(index: int) -> void:
	var level := await make_level()
	var area := level.current_sub_area
	var body := enemy(level, index)
	body.velocity.y = -1
	check(not body.hit_by_projectile(&"pow", 1) and not body.is_queued_for_deletion(),
			"POW defeated an airborne recent enemy")
	body.velocity.y = 0.000001
	check(not body.hit_by_projectile(&"pow", 1), "POW used an approximate stationary check")
	body.velocity.y = 0
	check(body.hit_by_projectile(&"pow", 1), "POW failed a stationary recent enemy")
	var corpse := hold_corpse(area)
	await ticks(2)
	var smoke := effects(area, &"spr_spinthump")
	check(corpse != null and corpse.velocity.x == 0 and smoke.size() == 1
			and smoke[0].position == Vector2(480, -165 + OFFSETS[index]),
			"dead_h=1 missed its vertical impulse/source smoke for family %s" % index)
	if corpse != null:
		corpse._physics_process(1.0 / 60)
		check(is_zero_approx(corpse.rotation), "Zero-speed POW corpse rotated")
		corpse.queue_free()
	await ticks(2)
	for wings in [false, true]:
		body = enemy(level, index, Vector2(480, -160), -1, wings)
		var player := level.hud.player
		player.state_machine.switch(PlayerSpinJumpingState)
		player.velocity.y = 120
		body._stomped(player)
		check(body.is_queued_for_deletion() and pending_corpse(area) == null,
				"Spin stomp stripped wings or created a normal corpse for family %s" % index)
		await ticks(2)
		check(live_nodes(area, SwimmingEnemyDefeat).is_empty(), "Spin stomp leaked a normal corpse")
	level.queue_free()
	await ticks(2)


func check_block_collision(index: int) -> void:
	var level := await make_level()
	var player := level.hud.player
	var part := QuestionBlockPart.create()
	part.position = Vector2(472, -144)
	level.current_sub_area.add_part(part)
	part.load()
	part.build()
	var body := enemy(level, index, Vector2(480, -144))
	await ticks(2) # Register the real native ellipse above the block.
	var block: QuestionBlock
	for node in level.current_sub_area.get_foreground().get_children():
		if node is QuestionBlock:
			block = node
	check(block != null, "Missing physical question block fixture")
	if block != null:
		player.velocity.x = -120 # Must not become the stationary block's speed.
		var score := player.score
		var component: BlockComponent = block.get_node("BlockComponent")
		component.sprout.empty = true # Isolate enemy points from the block's separate coin award.
		component.activate(player)
		var corpse := hold_corpse(level.current_sub_area)
		check(corpse != null and corpse.velocity.x == (-60 if index == 5 else 60)
				and player.score == score + 200, "Real block bump missed source partner/points for family %s: vx=%s, score=%s" % [
				index, corpse.velocity.x if corpse != null else INF, player.score - score])
	level.queue_free()
	await ticks(2)


func check_water_launch(index: int) -> void:
	var level := await make_level()
	var area := level.current_sub_area
	var liquid := add_liquid(level, Level.LevelTheme.FOREST, -150)
	for offset in [0.0, 0.01]:
		var body := enemy(level, index, Vector2(480, liquid.position.y - 19 - OFFSETS[index] + offset))
		body.kill(1)
		var corpse := hold_corpse(area)
		await ticks(2)
		check(corpse != null and corpse.velocity.y == (-240 if offset == 0 else -96),
				"Corpse launch ignored Create's default mask or its strict water boundary for family %s" % index)
		if corpse != null:
			var edge := 1 if index == 0 else 7 if index == 5 else 3
			check(is_equal_approx(corpse._water_offset(), edge), "Corpse water sample ignored selected art bounds")
			corpse.position.y = liquid.position.y - 12 - edge
			check(not corpse._swimming(), "Corpse water sample included the exact mask boundary")
			corpse.position.y += 0.01
			check(corpse._swimming(), "Corpse water sample missed the selected art below the boundary")
			corpse.velocity = Vector2(60, -96)
			var at := corpse.position
			corpse._physics_process(1.0 / 60)
			check(corpse.position.is_equal_approx(at + Vector2(1, -1.58))
					and is_equal_approx(corpse.rotation_degrees, 12), "Corpse missed its source water motion/spin")
			corpse.queue_free()
		await ticks(2)
	level.queue_free()
	await ticks(2)


func check_shell_collision(index: int) -> void:
	var level := await make_level()
	var area := level.current_sub_area
	var body := enemy(level, index, Vector2(480, -96), -1)
	var shell: KoopaShell = load("res://scenes/entities/koopa_shell.tscn").instantiate()
	shell.position = Vector2(450, -96)
	area.add(shell)
	level.hud.player.direction = 1
	shell.launch(level.hud.player, false)
	shell.velocity.x = 240
	await ticks(12)
	var corpses := live_nodes(area, SwimmingEnemyDefeat)
	check(not is_instance_valid(body) and corpses.size() == 1 and corpses[0].velocity.x == 60
			and corpses[0].get_child(0).flip_h, "Actual shell overlap lost typed corpse impulse/facing")
	level.queue_free()
	await ticks(2)


func check_helmet_collision(index: int) -> void:
	var level := await make_level()
	var player := level.hud.player
	player.direction = -1 # Source helmet hspeed stays zero despite Mario's facing.
	player.equip_shell_helmet(preload("res://resources/content/smw_helmet_spiny_rules.tres"))
	await ticks(2)
	var helmet: PlayerHelmet = player.get_node("BuzzyHelmet")
	var body := enemy(level, index, Vector2(player.position.x + 3, -180), -1)
	body.position.y += helmet._head_bounds().position.y + 2 - Utility.get_bounding_box(body).end.y
	body.velocity.y = 60
	await ticks(3)
	var corpses := live_nodes(level.current_sub_area, SwimmingEnemyDefeat)
	check(not is_instance_valid(body) and corpses.size() == 1 and player.score == 200
			and player.has_helmet() and corpses[0].velocity.x == 60,
			"Actual Spiny helmet overlap missed its stationary partner's source direction")
	level.queue_free()
	await ticks(2)


func check_corpse_motion_boundaries() -> void:
	var level := await make_level()
	var body := enemy(level, 0)
	body.kill(0)
	var corpse := hold_corpse(level.current_sub_area)
	await ticks(2)
	Utility.camera_position = Vector2(208, -248)
	corpse.position.y = 2
	corpse.velocity = Vector2(0, -240)
	corpse._physics_process(1.0 / 60)
	check(not corpse.is_queued_for_deletion(), "Rising corpse was removed below the source camera boundary")
	corpse.position.y = 0
	corpse.velocity.y = 60
	corpse._physics_process(1.0 / 60)
	check(not corpse.is_queued_for_deletion() and is_equal_approx(corpse.position.y, 1.2),
			"Corpse was culled at the inclusive camera+248 boundary or after motion")
	corpse._physics_process(1.0 / 60)
	check(corpse.is_queued_for_deletion(), "Descending corpse survived the next pre-motion cull")
	level.queue_free()
	await ticks(2)


func check_defeat_retry() -> void:
	var level := await make_level()
	var body := enemy(level, 0)
	body.hit_by_projectile(&"pow")
	level.reload()
	await ticks(3)
	check(live_nodes(level.current_sub_area, SwimmingEnemyDefeat).is_empty()
			and effects(level.current_sub_area, &"spr_spinthump").is_empty()
			and level.current_sub_area._pending_spawns.is_empty(), "Deferred corpse/smoke survived retry")
	level.queue_free()
	await ticks(2)


func capture_defeats() -> void:
	var level := await make_level()
	await ticks(40) # Finish the entry fade and camera follow before spawning short-lived corpses.
	for index in PROFILES.size():
		var body := enemy(level, index, Vector2(280 + index * 48, -140), -1 if index % 2 == 0 else 1)
		body.kill(1 if index % 2 == 0 else -1)
	await ticks(5)
	check(live_nodes(level.current_sub_area, SwimmingEnemyDefeat).size() == 6,
			"Defeat capture missed one of the six typed corpses")
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_enemy_defeat.png")
	check(error == OK, "Could not save recent-enemy defeat capture")
	print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	level.queue_free()
	await ticks(2)
	get_tree().quit(0 if failures.is_empty() else 1)
