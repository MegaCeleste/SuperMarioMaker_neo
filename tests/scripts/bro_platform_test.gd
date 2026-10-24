# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/hammer_bro_test.gd"
## Source Alarm_1 choices and full-width native support/clearance contacts.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await check_choice_with_two_platforms()
	await check_bottom_margin()
	await check_narrow_edge()
	for one_way in [false, true]:
		await check_landing_clearance(one_way)
	await check_moving_support()
	await check_missed_airborne_alarm()
	finish("BRO_PLATFORM_RESULT")


func add_blocks(level: Level, y: float) -> void:
	for x in [384, 400, 416]:
		var part := QuestionBlockPart.create()
		part.position = Vector2(x, y)
		level.current_sub_area.add_part(part)
		part.load()
		part.build()


func platform(level: Level, at: Vector2, size: Vector2, one_way := false, moving := false) -> PhysicsBody2D:
	var body: PhysicsBody2D = AnimatableBody2D.new() if moving else StaticBody2D.new()
	if moving:
		body.sync_to_physics = false
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	collider.one_way_collision = one_way
	body.add_child(collider)
	level.current_sub_area.add(body)
	return body


func falling(level: Level, at: Vector2) -> HammerBro:
	var body := actor(level, at)
	body.through_solid = 2
	body.collision_mask = 0
	body.velocity.y = 120
	return body


func check_choice_with_two_platforms() -> void:
	var level := await make_level()
	level.hud.player.set_physics_process(false)
	add_blocks(level, -160)
	add_blocks(level, -224)
	var body := actor(level, Vector2(408, -160))
	body.set_physics_process(false)
	await ticks(2)
	body._random.seed = 45217
	var small := 0
	for i in 128:
		small += int(body._choose_small_jump())
	check(small > 0 and small < 128,
			"Bros between two platforms must use both source random choices when a lower support exists")
	for node in level.current_sub_area.get_foreground().get_children():
		if node is GroundTile:
			node.free()
	await ticks(2)
	for i in 12:
		check(not body._choose_small_jump(),
				"Bro selected a small drop above a void despite the source lower-support probes")
	level.queue_free()
	await ticks(2)


func check_bottom_margin() -> void:
	var level := await make_level()
	add_blocks(level, -32)
	var body := actor(level, Vector2(408, -32))
	body.set_physics_process(false)
	await ticks(2)
	check(not body._choose_small_jump(), "Bro selected a source small drop without 64px of room below its origin")
	level.queue_free()
	await ticks(2)


func check_narrow_edge() -> void:
	var level := await make_level()
	platform(level, Vector2(404, -152), Vector2(2, 16))
	var body := falling(level, Vector2(409.4, -164))
	var landed := false
	for frame in 5:
		await ticks(1)
		landed = body.through_solid == 0 and absf(body.position.y + 160) < 0.1
		if landed:
			break # Patrol can walk off this two-pixel ledge on the next tick.
	check(landed,
			"Full-width Bro sweep missed a platform between its old three point probes")
	level.queue_free()
	await ticks(2)


func check_landing_clearance(one_way: bool) -> void:
	var level := await make_level()
	platform(level, Vector2(408, -152), Vector2(64, 16))
	platform(level, Vector2(408, -174), Vector2(64, 4), one_way)
	var body := falling(level, Vector2(408, -164))
	await ticks(45)
	check(body.through_solid == 0 and absf(body.position.y - (-160 if one_way else -96)) < 0.1,
			"Bro clearance did not distinguish a solid obstruction from a semisolid underside")
	level.queue_free()
	await ticks(2)


func check_moving_support() -> void:
	var level := await make_level()
	var support := platform(level, Vector2(408, -152), Vector2(64, 16), true, true)
	var body := falling(level, Vector2(408, -164))
	await ticks(5)
	check(body.through_solid == 0 and body.is_on_floor(), "Bro failed to land on a moving semisolid")
	var carried := false
	for i in 24:
		support.position.x += 0.5
		support.position.y -= 0.25
		await ticks(1)
		carried = carried or body.get_platform_velocity().x > 20
	check(carried and absf(body.position.y - (support.position.y - 8)) < 0.2,
			"Bro did not retain native platform carrying after restoring solid collisions")
	level.queue_free()
	await ticks(2)


func check_missed_airborne_alarm() -> void:
	var level := await make_level()
	var body := actor(level, Vector2(408, -160))
	body._jump_timer = 0
	await ticks(70)
	check(body.is_on_floor(), "Airborne alarm regression failed to establish a later landing")
	var jumped_again := false
	for frame in 360:
		await ticks(1)
		jumped_again = jumped_again or body.velocity.y < 0
	check(not jumped_again, "Airborne Bro alarm[1] incorrectly rearmed a jump through the source's unused alarm[0]")
	level.queue_free()
	await ticks(2)
