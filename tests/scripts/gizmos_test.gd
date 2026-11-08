# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## P-switch and POW block: palette entries, the P-switch press, coin/turn
## block swap and its end, and a thrown POW defeating grounded enemies and
## knocking coins loose.


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
	check(ring.choose(2) and level.editor.get_selected_part() == PSwitchPart, "P-switch palette entry is not usable")
	check(ring.choose(3) and level.editor.get_selected_part() == PowPart, "POW palette entry is not usable")
	for x in [288, 304]:
		_add(area, CoinPart.create(), Vector2(x, -112))
	_add(area, TurnBlockPart.create(), Vector2(320, -112))
	var stocked := TurnBlockPart.create()
	stocked.set_variant(&"mushroom")
	_add(area, stocked, Vector2(336, -112))
	_add(area, PSwitchPart.create(), Vector2(192, -80))
	_add(area, PowPart.create(), Vector2(400, -80))
	_add(area, GaloombaPart.create(), Vector2(352, -80))
	area.get_parts().get_node("EditorPlayer").position = Vector2(96, -80)
	level.play()
	await ticks(6)
	var player := level.hud.player
	var p_switch: PSwitch = _first(area, PSwitch)
	var pow: PowBlock = _first(area, PowBlock)
	check(p_switch != null and pow != null, "P-switch or POW block was not built")
	if p_switch == null or pow == null:
		await finish("GIZMOS_RESULT", level)
		return

	# Landing on the P-switch presses it and swaps coins with plain turn blocks.
	player.state_machine.switch(PlayerFallingState)
	player.global_position = Vector2(p_switch.global_position.x, p_switch.top_y() - 6)
	player.previous_position = player.global_position
	player.velocity = Vector2(0, 60)
	await ticks(6)
	check(PSwitchTimer.is_active(level), "Landing on the P-switch did not press it")
	check(MusicPlayer.stream != null and MusicPlayer.stream.resource_path.ends_with("snd_switchsong.ogg"),
			"P-switch music did not start")
	await ticks(2)
	check(_count(area, Coin) == 1 and _count(area, TurnBlockTile) == 3, "Coins and plain turn blocks did not swap")
	var stocked_tile := _tile_at(area, Vector2(336, -112))
	check(stocked_tile != null and not stocked_tile.has_meta(&"pswitch"), "A turn block with contents became a coin")
	var timer: PSwitchTimer = level.get_node("PSwitchTimer")
	timer.ticks = 2
	await ticks(6)
	check(not PSwitchTimer.is_active(level) and _count(area, Coin) == 2 and _count(area, TurnBlockTile) == 2,
			"The P-switch did not swap everything back")

	# A thrown POW goes off on landing: grounded enemies fall, coins come loose.
	var galoomba := _first(area, Galoomba)
	check(galoomba != null and galoomba.is_on_floor(), "Galoomba is not standing for the POW check")
	pow.thrown = true
	pow.velocity = Vector2(0, -120)
	await ticks(40)
	check(not is_instance_valid(pow) or pow.is_queued_for_deletion(), "A thrown POW did not go off on landing")
	check(not is_instance_valid(galoomba) or galoomba.is_queued_for_deletion(), "The POW did not defeat a grounded enemy")
	check(_count(area, Coin) == 0 and _count(area, PowCoin) == 2, "The POW did not knock coins loose")
	await ticks(60)
	var landed := true
	for coin in area.get_foreground().get_children():
		if coin is PowCoin:
			landed = landed and absf(coin.global_position.y + 80) < 1
	check(landed, "Loose POW coins did not settle on the ground")

	# Bumping a POW from below sets it off too (geometry check).
	var second: PowBlock = load("res://scenes/level/entities/pow_block.tscn").instantiate()
	second.position = Vector2(448, -100)
	area.add(second)
	await ticks(1)
	player.state_machine.switch(PlayerFallingState)
	player.global_position = Vector2(448, second.global_position.y + 15)
	player.velocity = Vector2(0, -120)
	check(second.player_bump(player), "A bump from below is not detected")
	level.edit()
	await ticks(2)
	await finish("GIZMOS_RESULT", level)


func _add(area: SubArea, part: Part, at: Vector2) -> void:
	part.position = at
	area.add_part(part)
	part.load()


func _first(area: SubArea, type: Variant) -> Node:
	for node in area.get_foreground().get_children():
		if is_instance_of(node, type) and not node.is_queued_for_deletion():
			return node
	return null


func _count(area: SubArea, type: Variant) -> int:
	var count := 0
	for node in area.get_foreground().get_children():
		count += int(is_instance_of(node, type) and not node.is_queued_for_deletion())
	return count


func _tile_at(area: SubArea, at: Vector2) -> Node:
	for node in area.get_foreground().get_children():
		if node is TurnBlockTile and node.global_position.is_equal_approx(at):
			return node
	return null
