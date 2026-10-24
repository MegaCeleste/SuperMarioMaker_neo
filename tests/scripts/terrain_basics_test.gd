# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## One grouped editor, surface physics, damage and lifecycle acceptance scene.

const FIXTURE := "res://tests/fixtures/port_slice.swe"
var capture := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-terrain-basics" in OS.get_cmdline_user_args()
	await check_editor(false)
	if not capture:
		await check_editor(true)
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await ticks(8)
	await clear_fixture(level)
	await check_spike_clock(level)
	await check_ice(level)
	await check_cloud(level)
	await check_spikes(level)
	if capture:
		await capture_runtime(level)
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	else:
		level.edit()
		await ticks(3)
		check(level.current_sub_area.get_foreground().get_child_count() == 0, "Returning to edit retained terrain bodies/effects")
	await finish("TERRAIN_BASICS_RESULT", level)


func park(player: Player, at := Vector2(320, -16)) -> void:
	release_input()
	player.position = at
	player.previous_position = at
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)
	player.invulnerability_left = 0


func clear_fixture(level: Level) -> void:
	for body in level.current_sub_area.get_foreground().get_children():
		if body is Enemy or body is Coin or body is QuestionBlock or body is TurnBlockTile or body is GoalGate:
			body.queue_free()
	await ticks(2)
	park(level.hud.player)


func terrain(level: Level, type: Script, at: Vector2) -> StaticBodyExt:
	var tile: StaticBodyExt = type.new()
	tile.sub_area = level.current_sub_area
	tile.position = at
	level.current_sub_area.add(tile)
	return tile


func check_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	var ids := ["obj_pinchos_res", "obj_ice_res", "obj_nube_res"]
	var types: Array[Script] = [SpikePart, IceBlockPart, CloudPart]
	for i in 3:
		data.MAIN.NIVEL.append({"object": ids[i], "x_pos": 400 + i * 48, "y_pos": 352, "future_terrain": 50 + i})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/terrain_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(10)
	var editor := level.editor
	var ring: PaletteRing = editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_terrain.tres")
	for i in 3:
		ring.page_index = 0 if i == 0 else 1
		check(ring.choose([4, 7, 6][i]) and editor.get_selected_part() == types[i], "Terrain palette slot is disabled or has wrong Part")
		var part := editor.place(Vector2i(39 + i * 2, -7))
		check(part != null and part.get_script() == types[i], "Terrain palette placement failed")
		if part == null:
			continue
		editor.history.undo()
		check(not part.is_inside_tree(), "Terrain placement undo failed")
		editor.history.redo()
		part.position = Vector2(624 + i * 32, -96)
		editor.history.record_move(part, Vector2(624 + i * 32, -112), part.position)
		check(part.position.y == -96, "Terrain move action failed")
		editor.history.undo()
		check(part.position.y == -112, "Terrain move undo failed")
		editor.history.redo()
		editor.history.erase(part)
		check(not part.is_inside_tree(), "Terrain eraser failed")
		editor.history.undo()
		check(part.is_inside_tree(), "Terrain eraser undo failed")
	var saved: Dictionary = await editor.save_to_path(path)
	check(saved.error == OK, "Terrain signed save failed")
	var reopened: Level = await LevelProcessor.from_swe(path)
	for i in 3:
		var found := false
		for part in reopened.current_sub_area.get_parts().get_children():
			if part.get_script() == types[i] and part.position == Vector2(400 + i * 48, -80):
				found = part.swe_data.future_terrain == 50 + i
		check(found, "Terrain round trip lost type, coordinates or unknown source fields")
	reopened.free()
	if capture:
		Utility.camera_position = Vector2(340, -210)
		await ticks(3)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/terrain_basics_editor.png")
	level.queue_free()
	await ticks(2)


func check_spike_clock(level: Level) -> void:
	var first := terrain(level, SpikeTile, Vector2(576, -80)) as SpikeTile
	await ticks(7)
	var second := terrain(level, SpikeTile, Vector2(608, -80)) as SpikeTile
	var changes := 0
	var previous := first._sprite.frame
	for i in 30:
		await ticks(1)
		var expected := int(floor(level.animation_time * 6 + 0.00001)) % 2
		check(first._sprite.frame == expected and second._sprite.frame == expected,
				"Spikes lost their source6fps shared clock or late-created phase")
		if first._sprite.frame != previous:
			changes += 1
		previous = first._sprite.frame
	check(changes == 3, "Spikes did not change once every10 physics ticks")
	get_tree().paused = true
	var paused_frame := first._sprite.frame
	await ticks(12)
	check(first._sprite.frame == paused_frame, "Spike clock advanced during a transformation pause")
	get_tree().paused = false
	first.queue_free()
	second.queue_free()
	await ticks(2)


func check_ice(level: Level) -> void:
	var player := level.hud.player
	var tiles: Array[StaticBodyExt] = []
	for i in 18:
		tiles.append(terrain(level, IceBlock, Vector2(384 + i * 16, -32)))
	park(player, Vector2(440, -33))
	await ticks(4)
	check(player.is_on_floor() and player.is_on_ice(), "Native ice support was not recognized")
	# Source-derived acceleration and braking are checked before native motion,
	# so a future wrong pixel/frame-to-second conversion cannot pass visually.
	var state: PlayerState = player.state_machine.current_state
	for direction in [-1, 1]:
		player.velocity.x = 0
		state.apply_horizontal_motion(direction, 1.0 / 60)
		check(is_equal_approx(player.velocity.x, 3 * direction), "Ice acceleration should add0.05px/tick")
		player.velocity.x = 60 * direction
		state.apply_horizontal_motion(0, 1.0 / 60)
		check(is_equal_approx(player.velocity.x, 59.7 * direction), "Ice coasting should lose0.005px/tick")
		state.apply_horizontal_motion(-direction, 1.0 / 60)
		check(is_equal_approx(player.velocity.x, 57.9 * direction), "Ice reverse braking should lose0.03px/tick")
	player.velocity.x = 60
	player.crouching = true
	state.apply_horizontal_motion(0, 1.0 / 60)
	check(is_equal_approx(player.velocity.x, 59.4), "Ice crouching should lose0.01px/tick")
	player.crouching = false
	player.velocity.x = 60
	var before := player.position.x
	await ticks(20)
	check(player.position.x > before + 15 and player.velocity.x > 53 and player.is_on_ice(), "Actual idle-state motion lost ice momentum")
	Input.action_press("player_jump")
	await ticks(3)
	check(not player.is_on_floor() and not player.is_on_ice(), "Jumping retained grounded ice traction")
	release_input()
	park(player)
	await ticks(3)
	check(not player.is_on_ice(), "Ordinary terrain retained ice traction")
	state = player.state_machine.current_state
	player.velocity.x = 60
	state.apply_horizontal_motion(0, 1.0 / 60)
	check(is_equal_approx(player.velocity.x, 57), "Ordinary-ground deceleration changed")
	park(player)
	for tile in tiles:
		tile.queue_free()
	# Ice uses rock-parent delayed breaking and its own shard art.
	var ice := terrain(level, IceBlock, Vector2(440, -80)) as IceBlock
	await ticks(2)
	ice.break_from_impact()
	check(ice.has_node("SourceBreakAlarm"), "Ice breaking was not block-owned")
	await ticks(3)
	check(not is_instance_valid(ice), "Ice did not break after the source alarm")
	var shards := 0
	for body in level.current_sub_area.get_foreground().get_children():
		if body is BlockShard and body.sprite_name == &"spr_shard_ice":
			shards += 1
	check(shards == 4, "Ice break used wrong or missing original fragments")
	await ticks(2)


func check_cloud(level: Level) -> void:
	var player := level.hud.player
	var clouds: Array[StaticBodyExt] = []
	for i in 5:
		clouds.append(terrain(level, CloudPlatform, Vector2(416 + i * 16, -80)))
	park(player, Vector2(448, -16))
	await ticks(3)
	Input.action_press("player_jump")
	var passed := false
	for i in 35:
		await ticks(1)
		passed = passed or player.position.y < -82
	release_input()
	await ticks(30)
	check(passed and player.is_on_floor() and absf(player.position.y + 80) < 0.2, "Mario did not rise through and land on cloud tops")
	# A body moving horizontally under the top must not hit a side wall.
	park(player, Vector2(390, -60))
	Input.action_press("player_right")
	await ticks(42)
	check(player.position.x > 425, "Cloud underside/side obstructed Mario")
	release_input()
	park(player)
	var enemy: Enemy = load("res://scenes/entities/galoomba.tscn").instantiate()
	enemy.position = Vector2(456, -130)
	enemy.get_node("SlideComponent").direction = 1
	level.current_sub_area.add(enemy)
	var item := OneUp.new()
	item.position = Vector2(432, -130)
	level.current_sub_area.add(item)
	await ticks(25)
	print("TERRAIN_CLOUD_LANDING enemy=", enemy.position, "/", enemy.is_on_floor(), " item=", item.position, "/", item.is_on_floor())
	check(enemy.is_on_floor() and absf(enemy.position.y + 80) < 0.2, "Enemy did not land on a native cloud")
	check(item.is_on_floor() and absf(item.position.y + 80) < 0.2, "Powerup did not land on a native cloud")
	enemy.queue_free()
	item.queue_free()
	for cloud in clouds:
		cloud.queue_free()
	await ticks(2)
	# Source cloud collision consumes one cloud and stops a down-attacking Thwomp.
	var cloud := terrain(level, CloudPlatform, Vector2(440, -64)) as CloudPlatform
	var thwomp := Thwomp.new()
	thwomp.position = Vector2(448, -120)
	level.current_sub_area.add(thwomp)
	thwomp.phase = Thwomp.Phase.ATTACKING
	thwomp.velocity.y = 240
	await ticks(15)
	print("TERRAIN_CLOUD_THWOMP cloud=", is_instance_valid(cloud), " thwomp=", thwomp.position, "/", thwomp.phase, " floor=", thwomp.is_on_floor())
	check(not is_instance_valid(cloud) and thwomp.phase == Thwomp.Phase.IMPACT, "Down-attacking Thwomp did not consume the cloud and stop")
	thwomp.queue_free()
	await ticks(2)


func check_spikes(level: Level) -> void:
	var player := level.hud.player
	park(player)
	player.set_powerup(SmallPowerup.new(), false)
	var spike := terrain(level, SpikeTile, Vector2(440, -32))
	park(player, Vector2(448, -60))
	player.state_machine.switch(PlayerFallingState)
	player.invulnerability_left = 10
	await ticks(18)
	check(player.is_on_floor() and not player.is_dead(), "Spike immunity failed or spike did not provide solid support")
	player.invulnerability_left = 0
	await ticks(2)
	check(player.is_dead(), "Standing contact did not damage Mario after immunity ended")
	level.reload()
	await ticks(8)
	check(not is_instance_valid(spike), "Retry retained a spike runtime body")
	await clear_fixture(level)
	player = level.hud.player
	spike = terrain(level, SpikeTile, Vector2(440, -32))
	park(player, Vector2(418, -16))
	player.set_powerup(SuperPowerup.new(), false)
	Input.action_press("player_right")
	await ticks(28)
	check(player.get_powerup() is SmallPowerup, "Spike side contact did not downgrade Super Mario")
	park(player)
	await ticks(60)
	spike.queue_free()
	await ticks(2)
	# Both helmet types protect the head without making foot contacts safe.
	for kind in [&"buzzy", &"spiny"]:
		spike = terrain(level, SpikeTile, Vector2(440, -64))
		park(player, Vector2(448, -16))
		player.equip_shell_helmet(load("res://resources/content/smw_helmet_spiny_rules.tres" if kind == &"spiny" else "res://resources/content/smw_helmet_rules.tres"))
		await ticks(3)
		Input.action_press("player_jump")
		var touched_ceiling := false
		for i in 13:
			await ticks(1)
			touched_ceiling = touched_ceiling or player.is_on_ceiling()
		check(touched_ceiling and not player.is_dead() and player.has_helmet() and player.invulnerability_left == 0,
				"Actual spike underside contact consumed a protected helmet/head")
		release_input()
		park(player)
		spike.queue_free()
		await ticks(2)
		player._helmet.break_off()
	# An invincible player can stand on the source solid hazard.
	spike = terrain(level, SpikeTile, Vector2(440, -32))
	park(player, Vector2(448, -60))
	player._star.collect()
	player.state_machine.switch(PlayerFallingState)
	await ticks(18)
	check(player.has_star() and not player.is_dead() and player.is_on_floor() and is_instance_valid(spike), "Star contact destroyed the spike or hurt Mario")
	player._star.cancel(true)
	park(player)
	spike.queue_free()
	await ticks(2)


func capture_runtime(level: Level) -> void:
	# Start the visual fixture clean: prior helmet/star probes leave legitimate
	# short-lived debris/trails that do not belong to this terrain overview.
	level.reload()
	await ticks(8)
	await clear_fixture(level)
	park(level.hud.player, Vector2(528, -97))
	for i in 8:
		terrain(level, IceBlock, Vector2(448 + i * 16, -16))
	for i in 3:
		terrain(level, SpikeTile, Vector2(608 + i * 16, -32))
	for i in 7:
		terrain(level, CloudPlatform, Vector2(480 + i * 16, -96))
	var enemy: Enemy = load("res://scenes/entities/galoomba.tscn").instantiate()
	enemy.position = Vector2(560, -17)
	level.current_sub_area.add(enemy)
	var item := OneUp.new()
	item.position = Vector2(476, -17)
	level.current_sub_area.add(item)
	Utility.camera_position = Vector2(320, -210)
	await ticks(4)
	check(level.hud.player.is_on_floor() and not level.hud.player.is_dead(), "GL terrain capture lost Mario's cloud support")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_terrain_basics.png")
