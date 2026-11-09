# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Boo, Bob-omb and Dry Bones: palette entries, NIVEL save/reopen, the Boo's
## shyness, a stomped Bob-omb's fuse and blast, and Dry Bones collapsing and
## standing up again.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var area := level.current_sub_area
	for candidate in area.get_parts().get_children():
		if not (candidate is StartingGround or candidate is EditorPlayer):
			candidate.free()
	for x in range(48, 560, 16):
		_add(area, GroundPart.create(), Vector2(x, -64))
	GroundPart.refresh_all(area.get_parts())
	var listed := []
	for page in load("res://resources/palette/category_enemies.tres").pages:
		for entry in page.items:
			if entry != null and not entry.disabled:
				listed.append(entry.part)
	check(BooPart in listed and BobOmbPart in listed and DryBonesPart in listed, "An enemy palette entry is missing")
	_add(area, BooPart.create(), Vector2(320, -144))
	_add(area, BobOmbPart.create(), Vector2(432, -80))
	_add(area, GaloombaPart.create(), Vector2(464, -80))
	_add(area, TurnBlockPart.create(), Vector2(400, -80))
	_add(area, DryBonesPart.create(), Vector2(160, -80))

	var path := "res://.godot/porting-tests/enemies.swe"
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Enemy save failed: %s" % saved)
	var ids: Array = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(path)).data.MAIN.NIVEL.map(
			func(row): return row.get("object", row.get("ID", "")))
	check("obj_boo_res" in ids and "obj_bobomb_res" in ids and "obj_drybones_res" in ids, "Enemy NIVEL rows are missing: %s" % [ids])
	var reopened: Level = await LevelProcessor.from_swe(path)
	var kinds := reopened.current_sub_area.get_parts().get_children().map(func(part): return part.get_script())
	check(BooPart in kinds and BobOmbPart in kinds and DryBonesPart in kinds, "Reopened level lost an enemy")
	reopened.free()

	area.get_parts().get_node("EditorPlayer").position = Vector2(240, -80)
	level.play()
	await ticks(4)
	var player := level.hud.player
	var boo: Boo = _first(area, Boo)
	var bomb: BobOmb = _first(area, BobOmb)
	var bones: DryBones = _first(area, DryBones)
	check(boo != null and bomb != null and bones != null, "An enemy was not built")
	if boo == null or bomb == null or bones == null:
		await finish("ENEMIES_RESULT", level)
		return

	# The Boo only comes closer while Mario turns his back on it.
	_park(player, Vector2(250, -64))
	player.direction = 1
	await ticks(30)
	var shy_distance := boo.global_position.distance_to(player.global_position)
	check(boo.shy and boo.velocity.length() < 1, "The Boo moved while Mario faced it")
	player.direction = -1
	await ticks(60)
	check(not boo.shy and boo.global_position.distance_to(player.global_position) < shy_distance - 5,
			"The Boo did not chase Mario when he turned away")
	check(not boo.hit_by_projectile(&"fire"), "A fireball defeated the Boo")
	boo.queue_free()

	# Stomping the Bob-omb lights it; the blast clears its surroundings.
	var galoomba: Galoomba = _first(area, Galoomba)
	# Both walked meanwhile; set them beside the turn block before lighting.
	bomb.global_position = Vector2(428, -64)
	galoomba.global_position = Vector2(450, -64)
	bomb.light()
	check(bomb.fuse == BobOmb.FUSE_TICKS and bomb.velocity.x == 0, "The Bob-omb fuse did not start")
	_park(player, Vector2(200, -64))
	bomb.fuse = 2
	await ticks(4)
	check(not is_instance_valid(bomb) or bomb.is_queued_for_deletion(), "The Bob-omb did not explode")
	check(not is_instance_valid(galoomba) or galoomba.is_queued_for_deletion(), "The blast did not defeat a nearby enemy")
	await ticks(4)
	check(_tile_count(area) == 0, "The blast did not break the turn block")
	check(not player.is_dead() and player.invulnerability_left == 0, "The blast hurt Mario from far away")

	# Dry Bones collapses under a stomp and stands up again.
	player.state_machine.switch(PlayerFallingState)
	player.global_position = bones.global_position + Vector2(0, -30)
	player.previous_position = player.global_position + Vector2(0, -4)
	player.velocity = Vector2(0, 150)
	# Area contacts report a few ticks after the overlap begins.
	await ticks(12)
	check(bones.collapsed >= 0 and not bones.hit_by_projectile(&"shell"), "Dry Bones did not collapse or could be hurt")
	bones.collapsed = DryBones.COLLAPSE_TICKS + DryBones.HEAP_TICKS + DryBones.SHAKES * DryBones.SHAKE_TICKS * 2 + DryBones.STAND_TICKS - 2
	_park(player, Vector2(320, -64))
	await ticks(4)
	check(bones.collapsed < 0 and is_instance_valid(bones), "Dry Bones did not stand up again")
	var x := bones.global_position.x
	await ticks(20)
	check(absf(bones.global_position.x - x) > 4, "Dry Bones did not walk again")
	level.edit()
	await ticks(2)
	await finish("ENEMIES_RESULT", level)


func _park(player: Player, at: Vector2) -> void:
	release_input()
	player.state_machine.switch(PlayerIdleState)
	player.global_position = at
	player.previous_position = at
	player.velocity = Vector2.ZERO


func _add(area: SubArea, part: Part, at: Vector2) -> void:
	part.position = at
	area.add_part(part)
	part.load()


func _first(area: SubArea, type: Variant) -> Node:
	for node in area.get_foreground().get_children():
		if is_instance_of(node, type) and not node.is_queued_for_deletion():
			return node
	return null


func _tile_count(area: SubArea) -> int:
	return area.get_foreground().get_children().filter(
			func(node): return node is TurnBlockTile and not node.is_queued_for_deletion()).size()
