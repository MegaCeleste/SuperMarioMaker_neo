# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Native Rocky Wrench and obj_wrench integration.

const FIXTURE := "res://tests/fixtures/port_slice.swe"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for modern in [false, true]:
		await check_editor(modern)
	await check_cycle()
	await check_air_placement()
	await check_wrench_flight()
	await check_wrench_hit_and_expiry()
	await check_stomp()
	await check_support_removal()
	finish("ROCKY_RESULT")


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


func actor(level: Level, at: Vector2) -> Rocky:
	var body: Rocky = load("res://scenes/entities/rocky.tscn").instantiate()
	body.position = at
	level.current_sub_area.add(body)
	return body


func wrenches(level: Level) -> Array[Wrench]:
	var result: Array[Wrench] = []
	for node in level.current_sub_area.get_foreground().get_children():
		if node is Wrench:
			result.append(node)
	return result


func check_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	data.MAIN.NIVEL.append({"object": "obj_rocky_res", "x_pos": 426, "y_pos": 273,
		"future_rocky": {"keep": 23}})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/rocky_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var rocky: RockyPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is RockyPart:
			rocky = part
	check(rocky != null, "obj_rocky_res did not create a native RockyPart")
	check(rocky.position == Vector2(426, -159), "Rocky loading snapped or reanchored its source coordinates")
	check(rocky.get_variants().is_empty() and rocky.get_modifiers().is_empty(),
			"Rocky invented a popup absent from obj_rocky_res")
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	ring.page_index = 1
	check(ring.choose(4) and level.editor.get_selected_part() == RockyPart,
			"Rocky page2 slot4 still selects the disabled placeholder")
	var probe := RockyPart.create()
	probe.position = Vector2(512, -192)
	level.current_sub_area.add_part(probe)
	await ticks(2)
	probe.held = true
	probe.set_process(false)
	await ticks(45)
	check(probe._window == null, "Rocky opened a window although its source resource has none")
	probe.held = false
	probe.set_process(true)
	await ticks(6)
	probe.free()
	await ticks(2)
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Native Rocky failed signed SWE saving")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var restored := 0
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is RockyPart:
			restored += 1
			check(part.position == Vector2(426, -159) and part.swe_data.future_rocky.keep == 23,
					"Signed SWE round-trip lost Rocky coordinates or unknown fields")
	check(restored == 1, "Signed SWE round-trip changed the Rocky count")
	reopened.free()
	level.queue_free()
	await ticks(2)


func check_cycle() -> void:
	var level := await make_level()
	park(level.hud.player, Vector2(600, -96))
	level.hud.player.invulnerability_left = 999.0
	var body := actor(level, Vector2(400, -96))
	var settled := false
	for frame in 60:
		await ticks(1)
		if body.phase == Rocky.Phase.WAIT:
			settled = true
			break
	check(settled and absf(body.position.y + 80.0) < 0.1,
			"Rocky did not bury its body with its source origin on the ground")
	check(body.z_index < GameConstants.Layers.Z_SOLIDS, "Rocky must draw behind its supporting ground")
	var low_rise := false
	var high_rise := false
	var thrown := false
	var returned := false
	for frame in 400:
		await ticks(1)
		if not is_instance_valid(body):
			break
		if body.phase == Rocky.Phase.HIGH_WAIT and body.position.y < -81.5:
			low_rise = true
		if body.phase == Rocky.Phase.WINDUP:
			high_rise = body.position.y < -88.5
		if not thrown and wrenches(level).size() > 0:
			thrown = true
			var fired := wrenches(level)[0]
			check(signf(fired.velocity.x) == 1.0 and absf(fired.velocity.x) == 60.0,
					"Rocky wrench did not use the source 1px/frame direction")
		if thrown and body.phase == Rocky.Phase.WAIT and absf(body.position.y + 80.0) < 0.1:
			returned = true
			break
	check(low_rise, "Rocky did not perform its first 2px source rise")
	check(high_rise, "Rocky did not rise to the source 9px throw height")
	check(thrown, "Rocky never threw an obj_wrench")
	check(returned, "Rocky did not sink back to its source anchor and repeat")
	level.queue_free()
	await ticks(2)


func check_wrench_flight() -> void:
	var level := await make_level()
	park(level.hud.player, Vector2(700, -96))
	var wrench := Wrench.new()
	wrench.position = Vector2(600, -140)
	wrench.direction = 1
	level.current_sub_area.add(wrench)
	var start := wrench.position
	# Source heights 1..4 take up to ~63 ticks to reach their 29px apex.
	for frame in 100:
		await ticks(1)
		if frame >= 60 and wrench._height == 0:
			break
	check(is_instance_valid(wrench), "Wrench was culled during its source flight")
	check(wrench.position.x > start.x + 55.0, "Wrench did not fly at the source 60px/s")
	check(wrench.position.y <= start.y + 0.01 and start.y - wrench.position.y <= 29.5,
			"Wrench ignored the source 5..29px height arc")
	check(is_zero_approx(wrench.velocity.y), "Wrench kept rising after its source arc ended")
	level.queue_free()
	await ticks(2)


func check_air_placement() -> void:
	var level := await make_level()
	var body := actor(level, Vector2(400, -176))
	for frame in 140:
		await ticks(1)
		if body.phase == Rocky.Phase.WAIT:
			break
	check(body.phase == Rocky.Phase.WAIT and absf(body.global_position.y + 80) < 0.1,
			"Air-placed Rocky teleported to its authored height instead of settling on actual terrain")
	check(body.get_node("CollShape").shape.get_rect().size.is_equal_approx(Vector2(14, 12)),
			"Rocky's hidden pose kept the taller exposed collision mask: %s" % body.get_node("CollShape").shape.get_rect().size)
	level.queue_free()
	await ticks(2)


func check_wrench_hit_and_expiry() -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_powerup(SuperPowerup.new(), false)
	park(player, Vector2(400, -96))
	var wrench := Wrench.new()
	wrench.position = Vector2(360, -104)
	wrench.direction = 1
	level.current_sub_area.add(wrench)
	await ticks(40)
	check(player.get_powerup() is SmallPowerup or player.invulnerability_left > 0,
			"Wrench did not damage Mario like obj_wrench/Collision_obj_mario")
	check(is_instance_valid(wrench), "Wrench removed itself after hitting Mario")
	level.queue_free()
	await ticks(2)
	# The shrink animation pauses the level; wait for it before the next level.
	for frame in 180:
		await ticks(1)
		if not get_tree().paused:
			break
	var level2 := await make_level()
	park(level2.hud.player, Vector2(64, -96))
	var expiring := Wrench.new()
	expiring.position = Vector2(300, -120)
	expiring.direction = 1
	level2.current_sub_area.add(expiring)
	expiring._age = 7.9
	await ticks(15)
	check(not is_instance_valid(expiring), "Wrench did not expire at the source 8s alarm")
	var culled := Wrench.new()
	culled.position = Vector2(-600, -96)
	culled.direction = -1
	level2.current_sub_area.add(culled)
	await ticks(3)
	check(not is_instance_valid(culled), "Wrench ignored its source camera culling")
	level2.queue_free()
	await ticks(2)


func check_stomp() -> void:
	var level := await make_level()
	var player := level.hud.player
	var body := actor(level, Vector2(400, -96))
	body.set_physics_process(false)
	player.set_powerup(SuperPowerup.new(), false)
	park(player, Vector2(400, -160))
	player.state_machine.switch(PlayerFallingState)
	player.velocity.y = 120
	await ticks(26)
	check(not is_instance_valid(body), "A stomp did not defeat Rocky")
	check(player.score == 200, "Rocky defeat did not award the source 200 points")
	level.queue_free()
	await ticks(2)


func check_support_removal() -> void:
	var level := await make_level()
	# Keep the support under test inside the source activation strip.
	park(level.hud.player, Vector2(700, -96))
	var platform := StaticBody2D.new()
	platform.position = Vector2(800, -88)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 16)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	platform.add_child(collider)
	level.current_sub_area.add(platform)
	var body := actor(level, Vector2(800, -96))
	for frame in 60:
		await ticks(1)
		if body.phase == Rocky.Phase.WAIT:
			break
	check(is_instance_valid(body) and body.phase == Rocky.Phase.WAIT, "Rocky did not settle on its platform")
	platform.free()
	await ticks(6)
	check(not is_instance_valid(body) or body.is_queued_for_deletion(),
			"Rocky survived losing the solid under its settled state")
	level.queue_free()
	await ticks(2)
