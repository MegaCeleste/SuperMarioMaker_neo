# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/bro_environment_test.gd"
## Resource collision kinds matter in addition to their bounding-box sizes.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level := await make_level()
	var area := level.current_sub_area
	var bodies: Array[Entity] = []
	for sledge in [false, true]:
		var bro: HammerBro = load("res://scenes/entities/hammer_bro.tscn").instantiate()
		if sledge:
			bro.variant = preload("res://resources/content/smw_hammerbro_sledge.tres")
		bro.position = Vector2(280 + 60 * int(sledge), -176)
		area.add(bro)
		bodies.append(bro)
	var monty: Monty = load("res://scenes/entities/monty.tscn").instantiate()
	monty.position = Vector2(400, -176)
	area.add(monty)
	bodies.append(monty)
	var rocky: Rocky = load("res://scenes/entities/rocky.tscn").instantiate()
	rocky.position = Vector2(460, -176)
	area.add(rocky)
	bodies.append(rocky)
	for body in bodies:
		body.set_physics_process(false)
		body.get_node("PlayerArea").collision_layer = 1 << 7
	var hammer := shot(level, BroProjectile.Kind.HAMMER, Vector2(320, -224))
	var ice := shot(level, BroProjectile.Kind.ICE, Vector2(384, -224))
	for body in [hammer, ice]:
		body.set_physics_process(false)
		body.get_node("PlayerArea").collision_layer = 1 << 7
	await ticks(2)
	var widths := [10.0, 18.0, 10.0, 14.0]
	var heights := [16.0, 24.0, 16.0, 16.0]
	for index in bodies.size():
		var body := bodies[index]
		var corner := Vector2(widths[index] / 2 - 0.5, -heights[index] + 0.5)
		var center := Vector2(0, -heights[index] / 2)
		for area_query in [false, true]:
			check(not contact_at(body, corner, area_query) and contact_at(body, center, area_query),
					"Source ellipse %s retained a rectangular corner or lost its center (Area=%s)" % [body.get_class(), area_query])
	for area_query in [false, true]:
		check(not contact_at(hammer, Vector2(5.5, 4.5), area_query) and contact_at(hammer, Vector2.ZERO, area_query),
				"Hammer's 12x10 mask should be an ellipse, including its player sensor")
		check(contact_at(ice, Vector2(3.5, 4.5), area_query),
				"Source snowball's 8x8 rectangular corner was incorrectly cut into an ellipse")
	var bounds := Utility.get_bounding_box(ice)
	check(bounds.position.is_equal_approx(ice.global_position + Vector2(-4, 4)) \
			and bounds.size.is_equal_approx(Vector2(8, 8)),
			"Collision bounds must not merge the origin into an offset snowball mask")
	# The source lava replacement inherits the Bro sprite's elliptical mask.
	add_liquid(level, Level.LevelTheme.CASTLE, -160)
	var sinking_bro: HammerBro = bodies[0]
	sinking_bro._sink()
	await ticks(2)
	var sinks := live_nodes(area, SinkingEnemy)
	check(sinks.size() == 1, "Source mask test missed the real Bro sinking replacement")
	if sinks.size() == 1:
		var sink: SinkingEnemy = sinks[0]
		sink._area.collision_layer = 1 << 7
		await ticks(2)
		check(not contact_at(sink, Vector2(4.5, 0.5), true) and contact_at(sink, Vector2(0, 8), true),
				"Sinking Bro replaced its source ellipse with rectangular corner contacts")
	level.queue_free()
	await ticks(2)
	await finish("SOURCE_MASK_RESULT")


func contact_at(body: Node2D, at: Vector2, area_query: bool) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = body.to_global(at)
	query.collision_mask = 1 << 7 if area_query else 2
	query.collide_with_areas = area_query
	query.collide_with_bodies = not area_query
	return not body.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
