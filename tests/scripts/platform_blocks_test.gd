# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"

const FIXTURE := "res://tests/fixtures/port_slice.swe"
var capture := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-platform-blocks" in OS.get_cmdline_user_args()
	await check_editor(false)
	if not capture:
		await check_editor(true)
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await ticks(8)
	await clear_fixture(level)
	await check_donut(level)
	await check_note(level)
	await check_contents(level)
	if capture:
		await capture_runtime(level)
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	else:
		level.edit()
		await ticks(4)
		check(level.current_sub_area.get_foreground().get_child_count() == 0, "Platform/editor return retained runtime nodes")
	await finish("PLATFORM_BLOCKS_RESULT", level)


func park(player: Player, at := Vector2(320, -16)) -> void:
	release_input()
	player.state_machine.switch(PlayerIdleState)
	player.position = at
	player.previous_position = at
	player.velocity = Vector2.ZERO


func clear_fixture(level: Level) -> void:
	for body in level.current_sub_area.get_foreground().get_children():
		if body is Enemy or body is Coin or body is QuestionBlock or body is TurnBlockTile or body is GoalGate:
			body.queue_free()
	await ticks(2)
	park(level.hud.player)


func add_part(level: Level, type: Script, at: Vector2) -> Part:
	var part: Part = type.create()
	part.position = at
	level.current_sub_area.add_part(part)
	part.load()
	return part


func check_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	data.MAIN.NIVEL.append({"object": "obj_donut_res", "x_pos": 416, "y_pos": 336, "future_platform": 31})
	data.MAIN.NIVEL.append({"object": "obj_noteblock_res", "x_pos": 464, "y_pos": 336, "sprout": -18, "future_note": 32})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/platform_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(10)
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_terrain.tres")
	ring.page_index = 1
	for slot in [4, 5]:
		check(ring.choose(slot), "Donut/note palette entry remains disabled")
		var placed := level.editor.place(Vector2i(38 + slot * 2, -5))
		check((placed is DonutPart if slot == 4 else placed is NoteBlockPart), "Platform palette still creates a placeholder")
		level.editor.history.undo()
		check(not placed.is_inside_tree(), "Platform placement undo failed")
		level.editor.history.redo()
	var block := add_part(level, NoteBlockPart, Vector2(592, -96)) as NoteBlockPart
	for id: StringName in [&"mushroom", &"one_up", &"flower", &"progressive_flower", &"star"]:
		var item := ContainerBlockPart.create_content(id)
		item.position = Vector2(640, -96)
		level.current_sub_area.add_part(item)
		item.load()
		var before := block.content_id
		item.held = true
		item.position = block.position
		item.held = false
		check(block.content_id == id and not item.is_inside_tree(), "Note drag did not store its powerup")
		level.editor.history.undo()
		check(block.content_id == before and item.is_inside_tree(), "Note insertion undo lost the loose item")
		level.editor.history.redo()
	var coin := add_part(level, CoinPart, Vector2(640, -96))
	coin.held = true
	coin.position = block.position
	coin.held = false
	check(coin.is_inside_tree() and coin.position == Vector2(640, -96) and block.content_id == &"star", "Note accepted an unsupported coin/multi-coin slot")
	var extracted := level.editor.take_content(block)
	extracted.position = Vector2(672, -96)
	extracted.held = false
	level.editor.history.end_stroke()
	check(extracted is StarPart and block.content_id == &"none", "Note extraction did not restore empty default")
	level.editor.history.undo()
	check(block.content_id == &"star" and not extracted.is_inside_tree(), "Note extraction undo was not atomic")
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Platform signed save failed")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var found := [false, false]
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is DonutPart and part.position == Vector2(416, -96):
			found[0] = part.swe_data.future_platform == 31
		if part is NoteBlockPart and part.position == Vector2(464, -96):
			found[1] = part.swe_data.future_note == 32 and part.content_id == &"one_up"
	check(not false in found, "Platform SWE round trip lost type, contents, origin or unknown fields")
	reopened.free()
	if capture:
		Utility.camera_position = Vector2(350, -210)
		await ticks(3)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/platform_blocks_editor.png")
	level.queue_free()
	await ticks(2)


func check_donut(level: Level) -> void:
	var player := level.hud.player
	var donut := DonutPlatform.new()
	donut.sub_area = level.current_sub_area
	donut.position = Vector2(440, -96)
	level.current_sub_area.add(donut)
	park(player, Vector2(448, -128))
	player.state_machine.switch(PlayerFallingState)
	for i in 40:
		await ticks(1)
		if donut.phase == DonutPlatform.Phase.WARNING: break
	check(donut.phase == DonutPlatform.Phase.WARNING, "Mario landing did not arm donut warning")
	var home_x := player.position.x
	await ticks(12)
	check(absf(player.position.x - home_x) < 0.2 and absf(player.position.y + 96) < 0.2,
			"Donut's visual/mask shake moved its rider")
	park(player)
	await ticks(2)
	check(donut.phase == DonutPlatform.Phase.IDLE and donut.phase_ticks == 0 and donut.position == Vector2(440, -96),
			"Stepping off did not cancel donut countdown")
	park(player, Vector2(448, -97))
	await ticks(4)
	for i in 40:
		await ticks(1)
		if donut.phase == DonutPlatform.Phase.FALLING: break
	check(donut.phase == DonutPlatform.Phase.FALLING and donut.phase_ticks == 30, "Donut did not fall after30 continuous loaded ticks")
	await ticks(5)
	check(donut.position.y > -95 and player.position.y > -96 \
			and absf(player.position.y - donut.position.y) < 1, "Falling donut did not carry Mario downward")
	park(player)
	for i in 120:
		await ticks(1)
		if donut.phase == DonutPlatform.Phase.WAITING: break
	check(donut.phase == DonutPlatform.Phase.WAITING and not donut.visible and donut.collision_layer == 0, "Donut did not disappear below the room")
	await ticks(179)
	check(donut.phase == DonutPlatform.Phase.WAITING, "Donut respawned before180 ticks")
	await ticks(2)
	check(not is_instance_valid(donut), "Donut return retained the old falling body/velocity")
	for body in level.current_sub_area.get_foreground().get_children():
		if body is DonutPlatform:
			donut = body
	check(donut.visible and donut.position == Vector2(440, -96) and donut._size < 0.4, "Donut did not return at its authored origin with growth")
	await ticks(20)
	check(is_equal_approx(donut._size, 1), "Returned donut did not grow to its original size")
	donut.queue_free()
	await ticks(2)


func make_note(level: Level, at := Vector2(440, -96)) -> NoteBlock:
	var block := NoteBlock.new()
	block.sub_area = level.current_sub_area
	block.position = at
	level.current_sub_area.add(block)
	return block


func note_jump(level: Level, action: String) -> float:
	var player := level.hud.player
	var block := make_note(level)
	park(player, Vector2(448, -125))
	player.state_machine.switch(PlayerFallingState)
	for i in 40:
		await ticks(1)
		if player.state_machine.current_state is PlayerNoteState: break
	check(player.state_machine.current_state is PlayerNoteState, "Mario did not enter physical note compression")
	if not action.is_empty(): Input.action_press(action)
	var lowest := -INF
	for i in 14:
		await ticks(1)
		lowest = maxf(lowest, player.position.y)
		if not player.state_machine.current_state is PlayerNoteState: break
	check(lowest >= -89 and lowest <= -87, "Note compression did not carry Mario through the8px stroke")
	check(player.velocity.y < -270 and not player.is_on_floor(), "Note did not launch Mario at the source5px/tick speed")
	check((player.state_machine.current_state is PlayerSpinJumpingState if action == "player_spin_jump" else player.state_machine.current_state is PlayerJumpingState),
			"Note launch lost normal/spin input selection")
	var apex := player.position.y
	for i in 45:
		await ticks(1)
		apex = minf(apex, player.position.y)
	release_input()
	park(player)
	block.queue_free()
	await ticks(2)
	return apex


func check_note(level: Level) -> void:
	var short_apex := await note_jump(level, "")
	var held_apex := await note_jump(level, "player_jump")
	check(held_apex < short_apex - 30, "Held jump did not extend the note bounce")
	await note_jump(level, "player_spin_jump")
	var player := level.hud.player
	park(player)
	var block := make_note(level, Vector2(440, -80))
	block.content_id = &"one_up"
	park(player, Vector2(448, -16))
	await ticks(3)
	Input.action_press("player_jump")
	await ticks(14)
	check(block.active and block.compression == -1, "Head bump did not trigger the opposite note stroke")
	release_input()
	park(player)
	await ticks(15)
	check(not block.active and block.position == Vector2(440, -80), "Head-bumped note did not reset")
	var released := 0
	for item in level.current_sub_area.get_foreground().get_children():
		if item is OneUp:
			released += 1
			check(item.position.y < -80 and item.velocity.y < 0, "Actual head bump did not eject the stored1UP upward")
			item.queue_free()
	check(released == 1 and block.content_id == &"none", "Actual note contact did not consume its stored item once")
	var enemy: Enemy = load("res://scenes/level/entities/galoomba.tscn").instantiate()
	enemy.position = Vector2(448, -81)
	level.current_sub_area.add(enemy)
	await ticks(4)
	check(enemy.velocity.y < -250 and block.active, "Note did not bounce an existing walking enemy")
	enemy.queue_free()
	block.queue_free()
	await ticks(2)


func check_contents(level: Level) -> void:
	var player := level.hud.player
	park(player)
	for direction in [Vector2.UP, Vector2.DOWN]:
		var block := make_note(level, Vector2(440, -112))
		block.content_id = &"one_up"
		block._release_content(direction)
		await ticks(4)
		var count := 0
		for item in level.current_sub_area.get_foreground().get_children():
			if item is OneUp:
				count += 1
				check(item.position.y < -112 and item.velocity.y < -250 if direction.y < 0 else item.position.y > -90,
						"Note contents used a rising-block animation or the wrong release side")
				item.queue_free()
		check(count == 1 and block.content_id == &"none", "Note did not release its contents exactly once")
		block._release_content(direction)
		await ticks(3)
		block.queue_free()
	var pending := make_note(level)
	pending.content_id = &"star"
	pending._release_content(Vector2.UP)
	level.reload()
	await ticks(8)
	check(not is_instance_valid(pending), "Retry kept a pending note release")
	await clear_fixture(level)
	for item in level.current_sub_area.get_foreground().get_children():
		check(not item is SuperStar, "Cancelled note release spawned a star after retry")


func capture_runtime(level: Level) -> void:
	var player := level.hud.player
	park(player, Vector2(456, -97))
	for i in 5:
		var donut := DonutPlatform.new()
		donut.sub_area = level.current_sub_area
		donut.position = Vector2(432 + i * 16, -96)
		level.current_sub_area.add(donut)
	for i in 4:
		make_note(level, Vector2(560 + i * 16, -64))
	var spikes: Array[SpikeTile] = []
	for i in 3:
		var spike := SpikeTile.new()
		spike.sub_area = level.current_sub_area
		spike.position = Vector2(672 + i * 16, -32)
		level.current_sub_area.add(spike)
		spikes.append(spike)
	Utility.camera_position = Vector2(336, -210)
	await ticks(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_platform_blocks.png")
	var changed := 0
	var previous := spikes[0]._sprite.frame
	var sample: Dictionary = {}
	# Sample after WorldPresentation's pre-draw callback, on the same render
	# frame as the GPU readback. At120Hz a later canvas/clamp value can differ.
	var before_draw := func():
		sample.frame = spikes[0]._sprite.frame
		sample.time = level.animation_time
		sample.transform = spikes[0]._sprite.get_global_transform_with_canvas()
	RenderingServer.frame_pre_draw.connect(before_draw)
	var pixels_match := true
	for i in 30:
		await ticks(1)
		Utility.camera_position = Vector2(336, -210)
		await RenderingServer.frame_post_draw
		check(spikes[0]._sprite.frame == int(floor(level.animation_time * 6 + 0.00001)) % 2, "GL spike animation lost its source clock")
		var source := spikes[0]._sprite.sprite_frames.get_frame_texture(&"default", sample.frame).get_image()
		var rendered := get_viewport().get_texture().get_image()
		var transform: Transform2D = sample.transform
		var matched := true
		var opaque := 0
		for y in source.get_height():
			for x in source.get_width():
				var pixel := source.get_pixel(x, y)
				if pixel.a < 0.999: continue
				var point := Vector2i((transform * (Vector2(x, y) + Vector2(0.5, 0.5))).floor())
				if not Rect2i(Vector2i.ZERO, rendered.get_size()).has_point(point):
					matched = false
				else:
					opaque += 1
					matched = matched and rendered.get_pixelv(point).is_equal_approx(pixel)
		if not matched or opaque <= 10:
			if pixels_match:
				print("SPIKE_PIXEL_SAMPLE i=", i, " frame=", sample.frame, " time=", sample.time, " transform=", transform, " opaque=", opaque)
				rendered.save_png("res://.godot/porting-tests/spike_pixel_failure.png")
			pixels_match = false
		if spikes[0]._sprite.frame != previous: changed += 1
		previous = spikes[0]._sprite.frame
	RenderingServer.frame_pre_draw.disconnect(before_draw)
	check(pixels_match, "Rendered spike pixels do not match the current source6fps frame")
	check(changed == 3, "GL spike animation did not keep6fps at this render rate")
