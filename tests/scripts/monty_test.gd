# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Native Monty Mole editor/runtime integration.

const FIXTURE := "res://tests/fixtures/port_slice.swe"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for modern in [false, true]:
		await check_editor(modern)
	await check_placement()
	await check_walk_and_chase()
	await check_wall_hop()
	await check_stomp_and_wings()
	await check_wing_hop()
	await check_parachute()
	await check_water_speed()
	finish("MONTY_RESULT")


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


func actor(level: Level, at: Vector2, wings := false, parachute := false) -> Monty:
	var body: Monty = load("res://scenes/entities/monty.tscn").instantiate()
	body.wings = wings
	body.parachute = parachute
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
	data.MAIN.NIVEL.append({"object": "obj_monty_res", "x_pos": 426, "y_pos": 273,
		"wings": 1, "paracaidas": 0, "future_monty": {"keep": 23}})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/monty_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var monty: MontyPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is MontyPart:
			monty = part
	check(monty != null, "obj_monty_res did not create a native MontyPart")
	check(monty.position == Vector2(426, -159), "Monty loading snapped or reanchored its source coordinates")
	check(monty.wings and not monty.parachute, "Monty import lost its independent wings/parachute flags")
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	ring.page_index = 1
	check(ring.choose(3) and level.editor.get_selected_part() == MontyPart,
			"Monty page2 slot3 still selects the disabled placeholder")
	check(monty.get_variants().is_empty(), "Monty invented a type popup absent from obj_monty_res")
	# The window belongs to a second, on-grid Part: holding snaps the cell and
	# would hide whether the loaded source coordinates survived saving.
	var held := MontyPart.create()
	held.position = Vector2(512, -192)
	held.wings = true
	level.current_sub_area.add_part(held)
	await ticks(2)
	held.held = true
	held.set_process(false)
	await ticks(45)
	check(held._window != null, "Monty did not open its source wings/parachute window")
	if held._window != null:
		check(held._window.get_node("Content/Attachments").get_child_count() == 2,
				"Monty window did not expose exactly the source wings/parachute toggles")
		var parachute: Button = held._window.get_node("Content/Attachments/parachute")
		await click_at(parachute.get_global_transform_with_canvas() * (parachute.size / 2))
		check(held.parachute, "Actual Monty window click did not toggle the parachute")
		held.held = false
		held.set_process(true)
		await ticks(8)
		level.editor.history.undo()
		check(not held.parachute and held.wings, "Monty undo lost the dependent attachment state")
	held.free()
	await ticks(2)
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Native Monty failed signed SWE saving")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var restored := 0
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is MontyPart:
			restored += 1
			check(part.wings and not part.parachute, "Signed SWE round-trip lost Monty flags")
			check(part.position == Vector2(426, -159) and part.swe_data.future_monty.keep == 23,
					"Signed SWE round-trip lost off-grid coordinates or unknown fields")
	check(restored == 1, "Signed SWE round-trip changed the Monty count")
	reopened.free()
	level.queue_free()
	await ticks(2)


func check_placement() -> void:
	var level := await LevelActionBtn.prepare_level(FIXTURE, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var area := level.current_sub_area
	var ground := GroundPart.create()
	ground.position = Vector2(448, -96)
	area.add_part(ground)
	await ticks(3)
	var world := level.get_world_2d()
	check(MontyPart.is_placeable(Vector2i(28, -10), world),
			"Monty invented a source-absent ground-only placement rule")
	check(not MontyPart.is_placeable(Vector2i(28, -6), world),
			"Monty ignored the normal resource overlap check")
	var part := MontyPart.create()
	part.position = Vector2(448, -160)
	area.add_part(part)
	part.build()
	var built: Monty
	for node in area.get_foreground().get_children():
		if node is Monty:
			built = node
	check(built != null, "Monty built no actor")
	if built != null:
		check(built.global_position == part.global_position + Vector2(8, 16),
				"Monty build shifted the source origin by a cell")
		var sprite: AnimatedSprite2D = built.get_node("Graphics/Sprite")
		check(sprite.global_position.y + sprite.offset.y == part.global_position.y + 1,
				"Monty drawing lost the authored source y plus 1px surface overlap")
	level.queue_free()
	await ticks(2)


func check_walk_and_chase() -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_powerup(SuperPowerup.new(), false)
	park(player, Vector2(480, -96))
	var body := actor(level, Vector2(400, -96))
	await ticks(1)
	check(absf(body.velocity.x) < 0.01, "Monty charged before the source two-tick alarm")
	await ticks(60)
	check(body.velocity.x > 80.0 and body.velocity.x <= 90.01,
			"Monty did not accelerate to the source 1.5px/frame chase")
	check(body.position.x > 430.0, "Monty did not move toward Mario")
	check(body.get_node("Graphics/Sprite").flip_h == false, "Monty faced away from Mario")
	park(player, Vector2(300, -96))
	await ticks(110)
	check(is_instance_valid(body), "Monty was torn down during its own chase")
	check(body.velocity.x < -80.0 and body.position.x < 500.0,
			"Monty did not reverse its chase after Mario moved behind")
	check(body.get_node("Graphics/Sprite").flip_h, "Monty did not flip toward Mario")
	level.queue_free()
	await ticks(2)


func check_wall_hop() -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_powerup(SuperPowerup.new(), false)
	park(player, Vector2(600, -96))
	var body := actor(level, Vector2(400, -96))
	wall(level, 464)
	var reversed := false
	var hopped := false
	for frame in 170:
		await ticks(1)
		if not is_instance_valid(body):
			break
		if body.velocity.x < 0:
			reversed = true
		hopped = hopped or body.velocity.y <= -80.0
	check(reversed and hopped, "Monty did not reverse and hop at a source wall")
	level.queue_free()
	await ticks(2)


func check_stomp_and_wings() -> void:
	var level := await make_level()
	var player := level.hud.player
	var body := actor(level, Vector2(400, -96), true, false)
	body.set_physics_process(false)
	player.set_powerup(SuperPowerup.new(), false)
	park(player, Vector2(400, -160))
	player.state_machine.switch(PlayerFallingState)
	player.velocity.y = 120
	await ticks(26)
	check(is_instance_valid(body), "A stomp defeated winged Monty instead of stripping its wings")
	check(not body.wings if is_instance_valid(body) else true, "Monty kept its wings after a stomp")
	check(player.score == 0, "Monty awarded points while only losing its wings")
	park(player, Vector2(400, -160))
	player.state_machine.switch(PlayerFallingState)
	player.velocity.y = 120
	await ticks(45)
	check(not is_instance_valid(body), "The second stomp did not defeat Monty")
	check(player.score == 200, "Monty defeat did not award the source 200 points")
	level.queue_free()
	await ticks(2)


func check_wing_hop() -> void:
	var level := await make_level()
	var body := actor(level, Vector2(400, -96), true, false)
	var hopped := false
	for frame in 30:
		await ticks(1)
		hopped = hopped or body.velocity.y <= -179.0
	check(hopped, "Winged Monty did not use the source 3px/frame grounded hop")
	check(body.get_node("Graphics").get_node_or_null("Wings") != null, "Winged Monty lost its native wing art")
	level.queue_free()
	await ticks(2)


func check_parachute() -> void:
	var level := await make_level()
	var body := actor(level, Vector2(400, -200), false, true)
	var peak := 0.0
	var left_sway := false
	var right_sway := false
	for frame in 80:
		await ticks(1)
		if not is_instance_valid(body):
			break
		peak = maxf(peak, body.velocity.y)
		left_sway = left_sway or body.position.x < 390
		right_sway = right_sway or body.velocity.x > 0
	check(peak <= 30.01, "Monty parachute exceeded the source cap plus gravity")
	check(absf(body.position.x - 400.0) > 2.0, "Monty parachute never started its source sway")
	check(left_sway and right_sway, "Monty parachute did not reverse at its source sway threshold")
	# Source +/-16px thresholds start braking, with another ~8.3px to stop.
	check(absf(body.position.x - 400.0) <= 26.0, "Monty parachute exceeded its source braking distance")
	for frame in 240:
		await ticks(1)
		if not is_instance_valid(body) or not body.parachute:
			break
	check(not body.parachute, "Monty parachute did not detach on landing")
	level.queue_free()
	await ticks(2)


func check_water_speed() -> void:
	var level := await make_level()
	level.current_sub_area.level_theme = Level.LevelTheme.UNDERWATER
	var player := level.hud.player
	park(player, Vector2(300, -96))
	var body := actor(level, Vector2(400, -96))
	await ticks(45)
	check(body.velocity.x < -58.0 and body.velocity.x >= -60.01,
			"Monty leftward water chase does not match Step_0's 1px/frame cap")
	park(player, Vector2(600, -96))
	await ticks(100)
	check(body.velocity.x > 88.0 and body.velocity.x <= 90.01,
			"Monty rightward water chase lost the source 1.5px/frame cap")
	level.queue_free()
	await ticks(2)
