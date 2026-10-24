# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"

const FIXTURE := "res://tests/fixtures/port_slice.swe"
var capture := false
var poses: Array[Image] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-star" in OS.get_cmdline_user_args()
	await check_editor(false)
	if not capture:
		await check_editor(true)
	var level := await make_level()
	await check_pickup(level)
	if capture:
		await capture_colors(level)
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
		await finish("STAR_RESULT", level)
		return
	await check_speed(level)
	await check_contacts(level)
	await check_motion(level)
	await check_block(level)
	await check_duration(level)
	await check_cleanup(level)
	await finish("STAR_RESULT", level)


func make_level() -> Level:
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await ticks(8)
	for body in level.current_sub_area.get_foreground().get_children():
		if body is Enemy or body is Coin or body is QuestionBlock or body is TurnBlockTile or body is GoalGate:
			body.queue_free()
	await ticks(2)
	park(level.hud.player)
	return level


func park(player: Player) -> void:
	release_input()
	player.position = Vector2(320, -16)
	player.previous_position = player.position
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)


func star_at(level: Level, at: Vector2) -> SuperStar:
	var star := SuperStar.new()
	star.position = at
	level.current_sub_area.add(star)
	return star


func check_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	data.MAIN.NIVEL.append({"object": "obj_star_res", "x_pos": 400, "y_pos": 400, "future_star": 31})
	data.MAIN.NIVEL.append({"object": "obj_qblock_res", "x_pos": 512, "y_pos": 352, "sprout": -21})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/star_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(12)
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_items.tres")
	check(ring.choose(7) and level.editor.get_selected_part() == StarPart, "Star palette still selected a disabled placeholder")
	var placed := level.editor.place(Vector2i(28, -5)) as StarPart
	check(placed != null, "Native editor did not create StarPart")
	level.editor.history.undo()
	check(not placed.is_inside_tree(), "Star placement undo failed")
	level.editor.history.redo()
	var block: QuestionBlockPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is QuestionBlockPart and part.content_id == &"star":
			block = part
	check(block != null, "SWE sprout-21 did not create star contents")
	if block != null:
		level.editor.set_part_variant(block, &"mushroom")
		level.editor.history.undo()
		check(block.content_id == &"star", "Content undo lost the star selection")
	if capture:
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/star_editor.png") == OK, "Cannot save star editor capture")
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Star signed save failed")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var count := 0
	var contents := 0
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is StarPart:
			count += 1
			if part.position == Vector2(400, -32):
				check(part.swe_data.future_star == 31, "Star save lost unknown fields")
		if part is QuestionBlockPart and part.content_id == &"star":
			contents += 1
	check(count == 2 and contents == 1, "Star/source block ID or counts changed during signed round trip")
	reopened.free()
	level.queue_free()
	await ticks(2)


func check_pickup(level: Level) -> void:
	var player := level.hud.player
	for power in [SmallPowerup.new(), SuperPowerup.new(), FirePowerup.new()]:
		park(player)
		player._star.cancel(true)
		player.set_powerup(power, false)
		await ticks(3)
		var feet := player.position
		var score := player.score
		var star := star_at(level, feet)
		await ticks(3)
		check(not is_instance_valid(star) and player.has_star() and player.score == score + 1000,
				"Actual star pickup did not grant invincibility/1000 exactly once")
		check(player.get_powerup() == power and player.position.distance_to(feet) < 0.2 and not get_tree().paused,
				"Star changed the underlying power, feet or entered a growth pause")
		check(player._star.music.playing and player._star.music.stream.loop and not MusicPlayer.playing,
				"Star music did not loop while suspending level music")
		player.invulnerability_left = 0
		player.damage()
		check(player.get_powerup() == power and not player.is_dead() and not player.freeze_in_ice(),
				"Star failed to protect the underlying power from damage/freeze")
	var music := player._star.music
	await ticks(90)
	var before := music.get_playback_position()
	star_at(level, player.position)
	await ticks(3)
	check(player._star.music == music and music.get_playback_position() >= before and player._star.remaining_ticks >= 597,
			"Repeated star did not refresh duration or restarted music")
	# Power growth keeps the same star status/material and freezes its timer.
	player.set_powerup(SmallPowerup.new(), false)
	player.set_powerup(FirePowerup.new(), true)
	var remaining := player._star.remaining_ticks
	while get_tree().paused:
		check(player._star.remaining_ticks == remaining, "Star expired on render frames during a power pause")
		await get_tree().process_frame
	check(player.has_star() and player.sprite.material == player._star._material, "Power growth discarded star visuals/status")


func check_speed(level: Level) -> void:
	var player := level.hud.player
	for running in [false, true]:
		park(player)
		player.collect_star()
		if running:
			Input.action_press("player_run")
		Input.action_press("player_right")
		await ticks(75)
		check(is_equal_approx(player.velocity.x, 240 if running else 138), "Star movement did not add the source60px/s walk/run bonus")
		player._star.cancel(true)
		await ticks(1)
		check(player.velocity.x < (240 if running else 138), "Star expiry retained its speed cap")
	park(player)
	await ticks(3)


func check_contacts(level: Level) -> void:
	var player := level.hud.player
	park(player)
	player._star.cancel(true)
	player.collect_star()
	var before := player.score
	var lives := player.extra_lives
	for index in 8:
		var enemy: Enemy = load("res://scenes/entities/galoomba.tscn").instantiate()
		enemy.position = player.position
		level.current_sub_area.add(enemy)
		await ticks(3)
		check(not is_instance_valid(enemy), "Actual star overlap did not defeat Galoomba")
	check(player.score == before + 16400 and player.extra_lives == lives + 1, "Star combo did not progress200..8000 then1UP")
	check(not player.is_dead() and not player.state_machine.current_state is PlayerJumpingState, "Star contacts became ordinary damage/stomps")
	for scene in ["buzzy_beetle", "thwomp", "chain_chomp", "koopa_shell"]:
		var enemy: Enemy = load("res://scenes/entities/%s.tscn" % scene).instantiate()
		enemy.position = player.position
		level.current_sub_area.add(enemy)
		await ticks(3)
		check(not is_instance_valid(enemy), "Star incorrectly inherited ordinary fire/shell resistance: " + scene)
	var flipped: StompedGaloomba = load("res://scenes/entities/stomped_galoomba.tscn").instantiate()
	flipped.position = player.position
	level.current_sub_area.add(flipped)
	await ticks(3)
	check(not is_instance_valid(flipped), "Star omitted the existing flipped/carryable enemy family")


func check_motion(level: Level) -> void:
	var player := level.hud.player
	player._star.cancel(true)
	var star := star_at(level, Vector2(420, -64))
	var bounced := false
	for frame in 50:
		await ticks(1)
		if star.velocity.y <= -230:
			bounced = true
			break
	check(bounced and star.velocity.x == 60, "Star did not move right and bounce from real terrain")
	star.queue_free()
	await ticks(2)
	var wall := StaticBody2D.new()
	wall.position = Vector2(440, -64)
	var collider := CollisionShape2D.new()
	collider.shape = RectangleShape2D.new()
	collider.shape.size = Vector2(16, 80)
	wall.add_child(collider)
	level.current_sub_area.add(wall)
	await ticks(2)
	star = star_at(level, Vector2(420, -50))
	await ticks(16)
	check(star.velocity.x == -60, "Actual wall contact did not reverse the star")
	star.queue_free()
	wall.queue_free()
	await ticks(2)


func check_block(level: Level) -> void:
	var part := QuestionBlockPart.create()
	part.position = Vector2(440, -80)
	part.set_variant(&"star")
	level.current_sub_area.add_part(part)
	part.load()
	part.build()
	await ticks(2)
	var block: QuestionBlock
	for body in level.current_sub_area.get_foreground().get_children():
		if body is QuestionBlock and body.position == part.position:
			block = body
	block.get_node("%BlockComponent").activate(level.hud.player)
	await ticks(55)
	var found := false
	for body in level.current_sub_area.get_foreground().get_children():
		if body is SuperStar:
			found = true
			check(body.level == level and body.sub_area == level.current_sub_area, "Sprouted star lost its area context")
			body.queue_free()
	check(found and not block.get_node("%BlockComponent").enabled, "Question block did not release its star once")
	block.queue_free()
	part.queue_free()
	await ticks(2)


func check_duration(level: Level) -> void:
	var player := level.hud.player
	player._star.cancel(true)
	player.invulnerability_left = 0
	player.collect_star()
	await ticks(598)
	check(player.has_star(), "Star expired before its600-tick window")
	await ticks(3)
	check(not player.has_star() and player.invulnerability_left > 1.9 and player.sprite.material == null,
			"Expiry did not remove the star tint or retain source two-second protection")
	check(not player._star.music.playing and MusicPlayer.playing, "Expiry failed to stop star music and resume the course")


func check_cleanup(level: Level) -> void:
	var player := level.hud.player
	player.collect_star()
	level.complete(player)
	await ticks(2)
	check(not player._star.music.playing, "Star music overrode completion music")
	level.reload()
	await ticks(5)
	player = level.hud.player
	check(not player.has_star(), "Retry retained the old player's star")
	player.collect_star()
	player.kill()
	await ticks(2)
	check(player.is_dead() and not player.has_star() and not player._star.music.playing,
			"Forced death did not clear invincibility/music")
	level.reload()
	await ticks(5)
	player = level.hud.player
	player.collect_star()
	level.edit()
	await ticks(3)
	check(not is_instance_valid(player), "Return to editor retained the star player")


func capture_colors(level: Level) -> void:
	var player := level.hud.player
	park(player)
	player.collect_star()
	for frame in [1, 3, 5, 7]:
		await ticks(frame)
		var at := level.current_sub_area.presentation.canvas_transform_for(player).origin
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		poses.append(image.get_region(Rect2i(Vector2i(at) - Vector2i(80, 116), Vector2i(160, 144))))
	var sheet := Image.create(160 * poses.size(), 144, false, Image.FORMAT_RGBA8)
	for index in poses.size():
		sheet.blit_rect(poses[index], Rect2i(0, 0, 160, 144), Vector2i(index * 160, 0))
	check(sheet.save_png("res://.godot/porting-tests/slice_star.png") == OK, "Cannot save star renderer capture")
	check(poses[0].get_data() != poses[2].get_data(), "Star flash/particles never changed actual rendered pixels")
