# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Bill Blaster and Fire Bar: palette entries, PLATAFORMAS save/reopen, the
## cannon firing at Mario, a stompable Bullet Bill, and a turning Fire Bar
## that hurts Mario.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var area := level.current_sub_area
	for candidate in area.get_parts().get_children():
		if not (candidate is StartingGround or candidate is EditorPlayer):
			candidate.free()
	for x in range(96, 512, 16):
		_add(area, GroundPart.create(), Vector2(x, -64))
	GroundPart.refresh_all(area.get_parts())
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_gizmos.tres")
	check(ring.choose(4) and level.editor.get_selected_part() == BillBlasterPart, "Bill Blaster palette entry is not usable")
	check(ring.choose(5) and level.editor.get_selected_part() == FireBarPart, "Fire Bar palette entry is not usable")
	var cannon := BillBlasterPart.create()
	_add(area, cannon, Vector2(352, -112))
	cannon.set_variant(&"three")
	var bar := FireBarPart.create()
	_add(area, bar, Vector2(160, -160))
	bar.set_variant(&"six")
	var reverse := FireBarPart.create()
	_add(area, reverse, Vector2(464, -160))
	reverse.set_modifier(&"clockwise", true)

	# PLATAFORMAS rows round-trip with their sizes and directions.
	var path := "res://.godot/porting-tests/hazards.swe"
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Bill Blaster/Fire Bar save failed: %s" % saved)
	var rows: Array = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(path)).data.MAIN.PLATAFORMAS
	var ids := rows.map(func(row): return row.object)
	check(ids.count("obj_bullebill_base_res") == 1 and ids.count("obj_firebar_res") == 2, "PLATAFORMAS rows are missing: %s" % [ids])
	var reopened: Level = await LevelProcessor.from_swe(path)
	var found := {}
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is BillBlasterPart:
			found.cannon = part.height == 3 and part.position == Vector2(352, -112)
		elif part is FireBarPart and part.position == Vector2(160, -160):
			found.bar = part.length == 6 and not part.clockwise
		elif part is FireBarPart:
			found.reverse = part.clockwise
	check(found.get("cannon", false) and found.get("bar", false) and found.get("reverse", false),
			"Reopened cannon or fire bars lost their settings: %s" % found)
	reopened.free()

	# obj_firebar_res drag: the end ball aims the bar and grows it by 2 up to 20.
	var dragged := FireBarPart.create()
	_add(area, dragged, Vector2(288, -288))
	var before := dragged.get_variant_state()
	for i in 12:
		dragged.drag_to(Vector2(8, 8) + Vector2(0, -(dragged.length - 1) * 8 - 20))
	check(is_equal_approx(dragged.start_angle, 90) and dragged.length == FireBarPart.MAX_LENGTH,
			"Dragging the Fire Bar's end did not aim it up and grow it to 20: %s, %s" % [dragged.start_angle, dragged.length])
	dragged.drag_to(Vector2(8, 8) + Vector2(-(dragged.length - 1) * 8 + 20, 0))
	check(is_equal_approx(dragged.start_angle, 180) and dragged.length == FireBarPart.MAX_LENGTH - 2,
			"Pulling the Fire Bar's end back did not shrink it by 2")
	var after := dragged.get_variant_state()
	dragged.restore_variant_state(before)
	check(dragged.length == 4 and dragged.start_angle == 0, "Fire Bar drag state did not restore")
	dragged.restore_variant_state(after)
	check(dragged.length == 18, "Fire Bar drag state lost a length beyond the window's 10")
	dragged.free()

	area.get_parts().get_node("EditorPlayer").position = Vector2(224, -80)
	level.play()
	await ticks(4)
	var player := level.hud.player
	var blaster: BillBlaster = _first(area, BillBlaster)
	var fire: FireBar
	for node in area.get_foreground().get_children():
		if node is FireBar and not node.clockwise:
			fire = node
	check(blaster != null and blaster.height == 3 and fire != null, "Cannon or fire bar was not built")
	if blaster == null or fire == null:
		await finish("HAZARDS_RESULT", level)
		return

	# The cannon fires left at Mario, and the Bullet Bill flies straight.
	blaster._clock = 1
	await ticks(3)
	var bullet: BulletBill = _first(area, BulletBill)
	check(bullet != null and bullet.direction == -1, "The Bill Blaster did not fire toward Mario")
	if bullet != null:
		var start := bullet.global_position
		await ticks(10)
		check(bullet.global_position.x < start.x - 8 and is_equal_approx(bullet.global_position.y, start.y),
				"The Bullet Bill does not fly straight")
		# Stomping it bounces Mario and drops it.
		player.state_machine.switch(PlayerFallingState)
		player.global_position = bullet.global_position + Vector2(0, -16)
		player.previous_position = player.global_position + Vector2(0, -4)
		player.velocity = Vector2(0, 120)
		await ticks(3)
		check(not is_instance_valid(bullet) or bullet.is_queued_for_deletion(), "Stomping the Bullet Bill did not defeat it")
		check(player.velocity.y < 0, "Stomping the Bullet Bill did not bounce Mario")
	check(blaster._clock > 100, "The cannon did not reload after firing")

	# The fire bar turns counter-clockwise; the clockwise one the other way.
	var angle := fire.angle
	await ticks(10)
	check(is_equal_approx(fire.angle, angle + 10), "The fire bar does not turn one degree per tick")
	var other: FireBar
	for node in area.get_foreground().get_children():
		if node is FireBar and node.clockwise:
			other = node
	check(other != null and other.angle < 0, "The clockwise fire bar turns the wrong way")
	# A fireball touching Mario hurts him.
	await ticks(60)
	player.state_machine.switch(PlayerIdleState)
	player.invulnerability_left = 0
	fire.angle = 0
	fire._place()
	player.global_position = fire.global_position + Vector2(24, 8)
	player.previous_position = player.global_position
	await ticks(2)
	check(player.is_dead() or player.invulnerability_left > 0, "The fire bar did not hurt Mario")
	level.edit()
	await ticks(2)
	await finish("HAZARDS_RESULT", level)


func _add(area: SubArea, part: Part, at: Vector2) -> void:
	part.position = at
	area.add_part(part)
	part.load()


func _first(area: SubArea, type: Variant) -> Node:
	for node in area.get_foreground().get_children():
		if is_instance_of(node, type) and not node.is_queued_for_deletion():
			return node
	return null
