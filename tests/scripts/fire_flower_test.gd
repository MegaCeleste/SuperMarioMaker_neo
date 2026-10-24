# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Native palette/content/history/SWE, actual pickup, inputs and collisions.

const FIXTURE := "res://tests/fixtures/port_slice.swe"
var capture := false
var poses: Array[Image] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-fire-flower" in OS.get_cmdline_user_args()
	for modern in [false, true]:
		await check_editor(modern)
	var level := await make_level()
	await check_pickup(level)
	await check_input(level)
	await check_collisions(level)
	await check_blocks(level)
	await check_liquids()
	await check_lifecycle(level)
	if capture:
		var sheet := Image.create(320 * poses.size(), 208, false, Image.FORMAT_RGBA8)
		for i in poses.size():
			sheet.blit_rect(poses[i], Rect2i(0, 0, 320, 208), Vector2i(320 * i, 0))
		check(sheet.save_png("res://.godot/porting-tests/slice_fire_flower.png") == OK, "Fire Flower capture could not be saved")
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("FIRE_FLOWER_RESULT", level)


func make_level() -> Level:
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await ticks(8)
	for node in level.current_sub_area.get_foreground().get_children():
		if node is Enemy or node is Coin or node is GoalGate or node is QuestionBlock or node is TurnBlockTile:
			node.queue_free()
	await ticks(2)
	park(level.hud.player)
	return level


func park(player: Player, at := Vector2(320, -16)) -> void:
	release_input()
	player.position = at
	player.previous_position = at
	player.velocity = Vector2.ZERO
	player.crouching = false
	player.growth_crouched = false
	player.state_machine.switch(PlayerIdleState)


func flowers(level: Level) -> Array[FireFlower]:
	var result: Array[FireFlower] = []
	for body in level.current_sub_area.get_foreground().get_children():
		if body is FireFlower and not body.is_queued_for_deletion():
			result.append(body)
	return result


func shots(level: Level) -> Array[PlayerFireball]:
	var result: Array[PlayerFireball] = []
	for body in level.current_sub_area.get_foreground().get_children():
		if body is PlayerFireball and not body.is_queued_for_deletion():
			result.append(body)
	return result


func clear_shots(level: Level) -> void:
	for body in shots(level):
		body.queue_free()
	await ticks(2)


func flower_at(level: Level, at: Vector2, progressive := false) -> FireFlower:
	var flower := FireFlower.new()
	flower.position = at
	flower.progressive = progressive
	level.current_sub_area.add(flower)
	return flower


func shot_at(level: Level, at: Vector2, velocity := Vector2(180, 0)) -> PlayerFireball:
	var shot := PlayerFireball.new()
	shot.position = at
	shot.velocity = velocity
	level.current_sub_area.add(shot)
	return shot


func check_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	data.MAIN.NIVEL.append({"object": "obj_fireflower_res", "x_pos": 384, "y_pos": 400,
		"progresivo": 0, "future_flower": {"keep": 17}})
	data.MAIN.NIVEL.append({"object": "obj_fireflower_res", "x_pos": 448, "y_pos": 400, "progresivo": 1})
	data.MAIN.NIVEL.append({"object": "obj_qblock_res", "x_pos": 512, "y_pos": 352, "sprout": 2, "progresivo": 1})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/flower_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var ordinary: FireFlowerPart
	var progressive: FireFlowerPart
	var block: QuestionBlockPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is FireFlowerPart:
			if part.progressive:
				progressive = part
			else:
				ordinary = part
		elif part is QuestionBlockPart and part.content_id == &"progressive_flower":
			block = part
	check(ordinary != null and progressive != null and block != null, "SWE missed ordinary/progressive Fire Flower or sprout2")
	if ordinary == null or progressive == null or block == null:
		level.queue_free()
		await ticks(2)
		return
	check(ordinary.position == Vector2(384, -32) and progressive.position == Vector2(448, -32), "Flower SWE changed its cell anchor")
	check(ordinary.get_node("Graphics/Sprite").texture != progressive.get_node("Graphics/Sprite").texture, "Progressive preview did not show the original mushroom marker")
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_items.tres")
	check(ring.choose(4) and level.editor.get_selected_part() == FireFlowerPart, "Fire Flower palette still selected a disabled placeholder")
	var placed := level.editor.place(Vector2i(36, -5)) as FireFlowerPart
	check(placed != null, "Native palette could not place a Fire Flower")
	level.editor.history.undo()
	check(not placed.is_inside_tree(), "Flower placement undo failed")
	level.editor.history.redo()
	level.editor.set_part_variant(placed, &"progressive_flower")
	check(placed.progressive, "Flower type selector did not set progressive content")
	level.editor.history.undo()
	check(not placed.progressive, "Flower variant undo failed")
	level.editor.history.redo()
	check(placed.progressive, "Flower variant redo failed")
	level.editor.set_part_variant(block, &"flower")
	check(block.content_id == &"flower", "Block selector did not accept Fire Flower")
	level.editor.history.undo()
	check(block.content_id == &"progressive_flower", "Block undo lost progressive content")
	if not modern:
		ordinary.held = true
		ordinary.set_process(false)
		await ticks(45)
		check(ordinary._window != null and ordinary._window.get_node("Content/Options").get_child_count() == 2,
				"Flower hold did not open the native ordinary/progressive window")
		await capture_pose(level, Vector2(416, -16))
		ordinary.held = false
		ordinary.set_process(true)
		await ticks(4)
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Flower native signed save failed")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var counts := [0, 0]
	var blocks := 0
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is FireFlowerPart:
			counts[int(part.progressive)] += 1
			if not part.progressive:
				check(part.swe_data.future_flower.keep == 17, "Flower save lost unknown fields")
		if part is QuestionBlockPart and part.content_id == &"progressive_flower":
			blocks += 1
	check(counts == [1, 2] and blocks == 1, "Flower/content signed round trip changed types or counts")
	reopened.free()
	level.queue_free()
	await ticks(2)


func check_pickup(level: Level) -> void:
	var player := level.hud.player
	for small in [true, false]:
		park(player)
		player.set_powerup(SmallPowerup.new() if small else SuperPowerup.new(), false)
		await ticks(3)
		var feet := player.position
		var before := player.score
		var flower := flower_at(level, player.position)
		var became_fire := false
		for frame in 100:
			await get_tree().process_frame
			if player.get_powerup() is FirePowerup:
				became_fire = true
				break
		check(became_fire and player.score == before + 1000, "Actual Fire Flower pickup did not grant Fire Mario and1000 once")
		if small and get_tree().paused:
			var pose := player.get_node("Graphics").get_node_or_null("GrowthPose") as Sprite2D
			check(pose != null and pose.texture == SpriteLibrary.get_frames(&"spr_mario_fire_idle").get_frame_texture(&"default", 0),
					"Small-to-fire growth used the wrong source texture")
		while get_tree().paused:
			await get_tree().process_frame
		await ticks(2)
		check(not is_instance_valid(flower) and player.position.distance_to(feet) < 0.2, "Flower growth shifted the feet or left a collectible")
		check(player.sprite.sprite_frames.get_frame_texture(&"walk", 0) == SpriteLibrary.get_frames(&"spr_mario_fire_walk").get_frame_texture(&"default", 0), "Fire Mario walk used Super Mario's palette")
	await capture_pose(level, player.position)
	var score := player.score
	flower_at(level, player.position)
	await ticks(3)
	check(player.score == score + 1000 and player.get_powerup() is FirePowerup and not get_tree().paused,
			"A second flower replayed the transformation or downgraded Fire Mario")
	var mushroom: Mushroom = load("res://scenes/entities/mushroom.tscn").instantiate()
	mushroom.position = player.position
	level.current_sub_area.add(mushroom)
	await ticks(3)
	check(player.get_powerup() is FirePowerup and not get_tree().paused, "A mushroom downgraded Fire Mario")
	var feet := player.position
	player.invulnerability_left = 0
	player.damage()
	check(player.get_powerup() is SuperPowerup and get_tree().paused, "Fire damage must downgrade to Super, with the native pause")
	while get_tree().paused:
		await get_tree().process_frame
	check(player.position.distance_to(feet) < 0.2, "Fire-to-Super damage changed the physical feet")
	player.invulnerability_left = 0
	player.set_powerup(SmallPowerup.new(), false)
	var progressive := flower_at(level, Vector2(400, -16), true)
	await ticks(3)
	check(not is_instance_valid(progressive), "Progressive flower did not become a mushroom for small Mario")
	var found := false
	for body in level.current_sub_area.get_foreground().get_children():
		if body is Mushroom:
			found = true
			body.queue_free()
	check(found, "Progressive flower discarded its mushroom replacement")
	await ticks(2)


func press_fire() -> void:
	Input.action_release("player_run")
	await ticks(1)
	Input.action_press("player_run")
	await ticks(1)
	Input.action_release("player_run")


func check_input(level: Level) -> void:
	var player := level.hud.player
	park(player)
	player.set_powerup(FirePowerup.new(), false)
	await ticks(3)
	await press_fire()
	check(shots(level).size() == 1 and player.sprite.animation == &"shoot", "Run/throw press did not launch a fireball with its original shoot pose")
	if shots(level).size() == 1:
		check(shots(level)[0].velocity.x == 180 and shots(level)[0].position.x > player.position.x,
				"Ordinary fireball lost its source speed or right-hand spawn")
	await capture_pose(level, player.position)
	Input.action_press("player_run")
	await ticks(5)
	var count := shots(level).size()
	await ticks(5)
	check(shots(level).size() == count, "Holding Run auto-fired repeatedly")
	Input.action_release("player_run")
	await ticks(1)
	await press_fire()
	await press_fire()
	check(shots(level).size() == 2, "Repeated presses exceeded the two-fireball limit")
	await ticks(12)
	check(player.sprite.animation == &"idle" and player.sprite.speed_scale == 1, "Fire pose did not restore idle and the animation clock")
	await capture_pose(level, player.position)
	await clear_shots(level)
	Input.action_press("player_down")
	await ticks(2)
	await press_fire()
	check(player.is_ducking() and player.sprite.animation == &"duck" and shots(level).is_empty(), "Fire Mario duck art/input allowed firing")
	Input.action_release("player_down")
	await ticks(2)
	player.direction = -1
	await press_fire()
	check(shots(level).size() == 1 and shots(level)[0].velocity.x == -180 and player.sprite.flip_h,
			"Leftward fire press lost its direction or mirrored pose")
	await clear_shots(level)
	park(player)
	await ticks(3)
	Input.action_press("player_spin_jump")
	await ticks(1)
	check(player.state_machine.current_state is PlayerSpinJumpingState, "Fire spin input failed to start SMW spin jump")
	await ticks(8)
	check(shots(level).is_empty(), "Fire spin's first shot occurred before tick10")
	await ticks(2)
	check(shots(level).size() == 1 and shots(level)[0].velocity.x == 270, "Spin jump did not emit its first rightward shot")
	await ticks(10)
	check(shots(level).size() == 2 and shots(level).any(func(s): return s.velocity.x == -270), "Spin jump missed its second leftward shot")
	Input.action_release("player_spin_jump")
	await capture_pose(level, player.position)
	await clear_shots(level)
	park(player)
	await ticks(3)


func check_collisions(level: Level) -> void:
	var player := level.hud.player
	var shot := shot_at(level, Vector2(380, -40))
	var bounced := false
	for frame in 40:
		await ticks(1)
		if is_instance_valid(shot) and shot.velocity.y == -120:
			bounced = true
			break
	check(bounced and is_instance_valid(shot), "Actual floor contact did not bounce the player fireball at-120px/s")
	await clear_shots(level)
	var wall := StaticBody2D.new()
	wall.position = Vector2(420, -48)
	wall.add_child(CollisionShape2D.new())
	wall.get_child(0).shape = RectangleShape2D.new()
	wall.get_child(0).shape.size = Vector2(16, 64)
	level.current_sub_area.add(wall)
	await ticks(2)
	shot = shot_at(level, Vector2(400, -50))
	await ticks(12)
	check(not is_instance_valid(shot), "Player fireball passed through a wall")
	wall.queue_free()
	await ticks(2)
	# Source Create rejects a shot already inside solid terrain.
	shot = shot_at(level, Vector2(400, -10))
	await ticks(2)
	check(not is_instance_valid(shot), "Fireball spawned embedded in terrain without bursting")
	for resistant in [false, true]:
		var enemy: Enemy = load("res://scenes/entities/buzzy_beetle.tscn" if resistant else "res://scenes/entities/galoomba.tscn").instantiate()
		enemy.position = Vector2(420, -16)
		level.current_sub_area.add(enemy)
		# Disable AI only; PhysicsServer keeps the actual native body contact.
		enemy.set_physics_process(false)
		for child in enemy.find_children("*", "Node", true, false):
			if child is GravityComponent or child is SlideComponent:
				child.set_physics_process(false)
		await ticks(2)
		var before := player.score
		shot = shot_at(level, Vector2(398, -36))
		await ticks(10)
		check(not is_instance_valid(shot), "Actual enemy contact did not consume a fireball")
		check(is_instance_valid(enemy) == resistant, "Actual fireball ignored a susceptible enemy or defeated fireproof Buzzy")
		check(player.score == before + (0 if resistant else 200), "Fireball enemy scoring did not distinguish resistance")
		if is_instance_valid(enemy):
			enemy.queue_free()
		await ticks(2)
	# Count deferred shots too, before insertion can otherwise admit a third.
	var power := player.get_powerup() as FirePowerup
	check(power.shoot(1) and power.shoot(1) and not power.shoot(1), "Deferred spawn requests bypassed the two-shot limit")
	await ticks(2)
	await clear_shots(level)


func check_blocks(level: Level) -> void:
	var player := level.hud.player
	park(player, Vector2(540, -16))
	for progressive in [false, true]:
		player.set_powerup(SmallPowerup.new(), false)
		var part := QuestionBlockPart.create()
		part.position = Vector2(480, -80)
		part.set_variant(&"progressive_flower" if progressive else &"flower")
		level.current_sub_area.add_part(part)
		part.load()
		part.build()
		await ticks(2)
		var block: QuestionBlock
		for node in level.current_sub_area.get_foreground().get_children():
			if node is QuestionBlock and node.position == part.position:
				block = node
		var component: BlockComponent = block.get_node("%BlockComponent")
		component.activate(player)
		await ticks(65)
		check(not component.enabled, "Flower question block was not consumed once")
		var found := false
		for node in level.current_sub_area.get_foreground().get_children():
			if (node is Mushroom if progressive else node is FireFlower):
				found = true
				if node is FireFlower:
					check(node.sub_area == level.current_sub_area and node.level == level, "Sprouted flower was not bound to its native area")
				node.queue_free()
		check(found, "Question block did not release the selected ordinary/progressive powerup")
		block.queue_free()
		part.queue_free()
		await ticks(2)
	# A flower already sitting on a block responds to the real bump query.
	var block: QuestionBlock = load("res://scenes/tiles/question_block.tscn").instantiate()
	block.position = Vector2(480, -64)
	level.current_sub_area.add(block)
	var resting := flower_at(level, Vector2(488, -64))
	await ticks(4)
	var component: BlockComponent = block.get_node("%BlockComponent")
	component.activate(player)
	await ticks(1)
	check(is_instance_valid(resting) and resting.velocity.y < -150, "The actual block bump did not lift its supported Fire Flower")
	resting.queue_free()
	block.queue_free()
	await ticks(2)


func check_liquids() -> void:
	for theme in [Level.LevelTheme.CASTLE, Level.LevelTheme.BEACH]:
		var level: Level = await LevelProcessor.from_swe(FIXTURE)
		level.current_sub_area.level_theme = theme
		level.current_sub_area.water_start_y = -96
		level.current_sub_area.water_limit_y = -96
		add_child(level)
		await ticks(8)
		var liquid := level.current_sub_area.liquid
		var shot := shot_at(level, Vector2(400, liquid.position.y - 15), Vector2.ZERO)
		shot.set_physics_process(false)
		if theme == Level.LevelTheme.CASTLE:
			check(shot._liquid_contact() and shot.is_queued_for_deletion(), "Fireball missed the inclusive source lava boundary")
		else:
			shot._physics_process(1.0 / 60)
			check(not shot.is_queued_for_deletion() and is_equal_approx(shot.velocity.y, 12), "Player fireball incorrectly inherited the Bro's slower water gravity")
		shot.queue_free()
		level.queue_free()
		await ticks(2)


func check_lifecycle(level: Level) -> void:
	var player := level.hud.player
	park(player)
	player.set_powerup(FirePowerup.new(), false)
	var flower := flower_at(level, Vector2(380, -16))
	var shot := shot_at(level, Vector2(360, -40))
	await ticks(2)
	player.kill()
	await ticks(2)
	var at := shot.position if is_instance_valid(shot) else Vector2.ZERO
	await ticks(5)
	check(is_instance_valid(shot) and shot.position == at and shot.velocity == Vector2.ZERO, "Death did not stop the new physical fireball")
	check(is_instance_valid(flower) and flower.velocity == Vector2.ZERO, "Death did not stop a Fire Flower")
	level.reload()
	await ticks(8)
	check(not is_instance_valid(shot) and not is_instance_valid(flower) and shots(level).is_empty(), "Retry leaked old flowers/projectiles")
	player = level.hud.player
	player.set_powerup(FirePowerup.new(), false)
	player.get_powerup().shoot(1)
	var pending: PlayerFireball
	for spawn in level.current_sub_area._pending_spawns.values():
		if spawn.node is PlayerFireball:
			pending = spawn.node
	level.reload()
	await ticks(4)
	check(not is_instance_valid(pending) and shots(level).is_empty(), "Same-step retry rescued a deferred old fireball")
	# Leaving during a new power pause must release the tree and its snapshots.
	player = level.hud.player
	player.set_powerup(FirePowerup.new(), true)
	check(get_tree().paused, "Fire growth did not own its pause")
	level.reload()
	await ticks(8)
	check(not get_tree().paused and level.hud.player.get_powerup() is SmallPowerup,
			"Retry during Fire growth retained its pause or upgraded player")


func capture_pose(level: Level, at: Vector2) -> void:
	if not capture:
		return
	var mode := level.process_mode
	level.process_mode = Node.PROCESS_MODE_DISABLED
	Utility.camera_scale = Vector2(3, 3)
	Utility.camera_position = at - Vector2(180, 150)
	level._camera_clamp()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var screen := level.current_sub_area.get_foreground().get_global_transform_with_canvas() * at
	var crop := Rect2i(Vector2i(screen) - Vector2i(160, 160), Vector2i(320, 208))
	poses.append(get_viewport().get_texture().get_image().get_region(crop))
	level.process_mode = mode
