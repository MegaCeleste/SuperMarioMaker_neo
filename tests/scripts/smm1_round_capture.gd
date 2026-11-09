# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Real-render view of the 2026-11-09 round's nine objects in the editor and
## in play, for visual inspection (capture_slice.py --smm1-round).


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var area := level.current_sub_area
	for candidate in area.get_parts().get_children():
		if not (candidate is StartingGround or candidate is EditorPlayer):
			candidate.free()
	for x in range(0, 640, 16):
		_add(area, GroundPart.create(), Vector2(x, -64))
	GroundPart.refresh_all(area.get_parts())
	_add(area, PSwitchPart.create(), Vector2(48, -80))
	_add(area, PowPart.create(), Vector2(80, -80))
	var cannon := BillBlasterPart.create()
	_add(area, cannon, Vector2(112, -112))
	cannon.set_variant(&"three")
	_add(area, FireBarPart.create(), Vector2(176, -160))
	_add(area, LiftPart.create(), Vector2(224, -128))
	var falling := LiftPart.create()
	_add(area, falling, Vector2(224, -192))
	falling.set_variant(&"falling")
	var bridge := BridgePart.create()
	_add(area, bridge, Vector2(304, -112))
	bridge.set_variant(&"five")
	_add(area, BooPart.create(), Vector2(400, -144))
	_add(area, BobOmbPart.create(), Vector2(432, -80))
	_add(area, DryBonesPart.create(), Vector2(464, -80))
	for x in [304, 320]:
		_add(area, CoinPart.create(), Vector2(x, -160))
	Utility.camera_position = Vector2(0, -230)
	await ticks(30)
	await _snap("editor")
	Utility.camera_position = Vector2(300, -230)
	await ticks(10)
	await _snap("editor_enemies")
	area.get_parts().get_node("EditorPlayer").position = Vector2(16, -80)
	level.play()
	await ticks(20)
	Utility.camera_position = Vector2(0, -230)
	level.hud.player.global_position = Vector2(16, -64)
	await ticks(4)
	await _snap("play")
	Utility.camera_position = Vector2(300, -230)
	await ticks(6)
	await _snap("enemies")
	for node in area.get_foreground().get_children():
		if node is BobOmb:
			node._stomped(level.hud.player)
	await ticks(10)
	Utility.camera_position = Vector2(300, -230)
	await ticks(2)
	await _snap("held_bomb")
	for cells in [2, 3, 5]:
		BillBlasterPart.icon_for(cells).get_image().save_png("res://.godot/porting-tests/smm1_round_cannon_icon_%d.png" % cells)
	print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("SMM1_ROUND_RESULT", level)


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://.godot/porting-tests/smm1_round_%s.png" % label)
	if label == "play":
		image.save_png("res://.godot/porting-tests/slice_smm1_round.png")


func _add(area: SubArea, part: Part, at: Vector2) -> void:
	part.position = at
	area.add_part(part)
	part.load()
