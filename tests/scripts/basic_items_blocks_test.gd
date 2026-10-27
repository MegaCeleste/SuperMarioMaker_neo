# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## One batch:1UP, hard/hidden blocks and real container drag/drop ownership.

const FIXTURE := "res://tests/fixtures/port_slice.swe"
var capture := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-basic-items-blocks" in OS.get_cmdline_user_args()
	await check_editor(false)
	if not capture:
		await check_editor(true)
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await ticks(8)
	for body in level.current_sub_area.get_foreground().get_children():
		if body is Enemy or body is Coin or body is QuestionBlock or body is TurnBlockTile or body is GoalGate:
			body.queue_free()
	await ticks(2)
	await check_one_up(level)
	await check_hidden(level)
	await check_hard(level)
	await check_containers(level)
	await check_actor_contacts(level)
	if capture:
		await capture_runtime(level)
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	else:
		await check_cleanup(level)
	await finish("BASIC_ITEMS_BLOCKS_RESULT", level)


func add_part(level: Level, type: Script, at: Vector2) -> Part:
	var part: Part = type.create()
	part.position = at
	level.current_sub_area.add_part(part)
	part.load()
	return part


func drag_into(item: Part, block: ContainerBlockPart) -> void:
	item.held = true
	item.position = block.position
	item.held = false


func check_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	data.MAIN.NIVEL.append({"object": "obj_1up_res", "x_pos": 400, "y_pos": 400, "future_oneup": 17})
	data.MAIN.NIVEL.append({"object": "obj_rock_res", "x_pos": 464, "y_pos": 400, "future_rock": 18})
	data.MAIN.NIVEL.append({"object": "obj_block_hidden_res", "x_pos": 512, "y_pos": 368, "sprout": -18, "future_hidden": 19})
	data.MAIN.NIVEL.append({"object": "obj_block_res", "x_pos": 560, "y_pos": 368, "sprout": -21})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/basic_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(10)
	var editor := level.editor
	var ring: PaletteRing = editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_items.tres")
	check(ring.choose(8) and editor.get_selected_part() == OneUpPart, "1UP palette entry remains unavailable")
	var placed := editor.place(Vector2i(40, -7))
	check(placed is OneUpPart, "1UP palette placement failed")
	editor.history.undo()
	check(not placed.is_inside_tree(), "1UP placement undo failed")
	editor.history.redo()
	ring.category = load("res://resources/palette/category_terrain.tres")
	ring.page_index = 1
	for slot in [2, 3]:
		check(ring.choose(slot), "New block palette entry remains unavailable")
		var part := editor.place(Vector2i(40 + slot * 2, -7))
		check((part is HardBlockPart if slot == 2 else part is HiddenBlockPart), "Block palette chose the wrong type")
		editor.history.undo()
		check(not part.is_inside_tree(), "Block placement undo failed")
		editor.history.redo()
	for type: Script in [QuestionBlockPart, HiddenBlockPart, TurnBlockPart]:
		var block := add_part(level, type, Vector2(656 + 48 * [QuestionBlockPart, HiddenBlockPart, TurnBlockPart].find(type), -64)) as ContainerBlockPart
		for id: StringName in [&"mushroom", &"one_up", &"star", &"flower", &"progressive_flower", &"coin"]:
			var before := block.content_id
			var item := ContainerBlockPart.create_content(id)
			item.position = Vector2(848, -112)
			item.swe_data = {"future_item": 77}
			level.current_sub_area.add_part(item)
			item.load()
			drag_into(item, block)
			var expected := (&"coin" if block is HiddenBlockPart else &"multi_coin") if id == &"coin" else id
			check(block.content_id == expected and not item.is_inside_tree(), "Drag did not transfer item into container")
			editor.history.undo()
			check(block.content_id == before and item.is_inside_tree() and item.position == Vector2(848, -112) \
					and item.swe_data.future_item == 77, "Insertion undo lost item position/data or prior contents")
			editor.history.redo()
			check(block.content_id == expected and not item.is_inside_tree(), "Insertion redo duplicated a loose item")
		# Keep one preview of each container for the editor screenshot.
		block.content_id = &"one_up"
	var inspect := add_part(level, QuestionBlockPart, Vector2(608, -80)) as ContainerBlockPart
	inspect.content_id = &"star"
	Utility.camera_position = Vector2(470, -210)
	await ticks(2)
	inspect.held = true
	inspect.set_process(false)
	await ticks(36)
	check(is_instance_valid(inspect._window), "Long press failed to show stored contents")
	inspect.held = false
	inspect.set_process(true)
	if is_instance_valid(inspect._window):
		var options := inspect._window.get_node("Content/Options")
		check(options.get_child_count() == 1 and options.has_node("StoredContent"), "Long press still offers a contents selection menu")
		if capture:
			await ticks(3)
			await RenderingServer.frame_post_draw
			var rendered := get_viewport().get_texture().get_image()
			rendered.save_png("res://.godot/porting-tests/basic_blocks_editor.png")
			var window_rect: Rect2 = inspect._window.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, inspect._window.size)
			check(get_viewport().get_visible_rect().encloses(window_rect), "Stored-content window was outside the rendered viewport")
			rendered.get_region(Rect2i(window_rect.grow(8))).save_png("res://.godot/porting-tests/basic_stored_content.png")
		inspect._window.get_node("Content/Options/StoredContent").button_down.emit()
		await ticks(1)
		var loose := editor.held_part
		check(loose is StarPart and inspect.content_id == &"coin", "Stored-content drag did not extract the current item")
		if loose != null:
			loose.position = Vector2(784, -80)
			loose.held = false
			editor.history.end_stroke()
			editor.history.undo()
			check(inspect.content_id == &"star" and not loose.is_inside_tree(), "Extraction undo was not atomic")
			editor.history.redo()
			check(inspect.content_id == &"coin" and loose.is_inside_tree() and loose.position == Vector2(784, -80), "Extraction redo lost the loose item's final cell")
	# A hard block does not accept inserted items; failed drops return home.
	var hard := add_part(level, HardBlockPart, Vector2(800, -48))
	var rejected := add_part(level, OneUpPart, Vector2(832, -48))
	rejected.held = true
	rejected.position = hard.position
	rejected.held = false
	check(rejected.is_inside_tree() and rejected.position == Vector2(832, -48), "Non-container consumed an item or permitted overlap")
	var cancel_block := add_part(level, HiddenBlockPart, Vector2(848, -64)) as ContainerBlockPart
	cancel_block.content_id = &"one_up"
	var cancelled := editor.take_content(cancel_block)
	cancelled.position = hard.position
	cancelled.held = false
	editor.history.end_stroke()
	check(cancel_block.content_id == &"one_up" and not cancelled.is_inside_tree(), "Invalid extracted-item drop did not return its contents")
	editor.history.undo()
	check(cancel_block.content_id == &"one_up" and not cancelled.is_inside_tree(), "Cancelled extraction undo duplicated an item")
	editor.history.redo()
	check(cancel_block.content_id == &"one_up" and not cancelled.is_inside_tree(), "Cancelled extraction redo duplicated an item")
	ring.category = load("res://resources/palette/category_items.tres")
	ring.choose(7)
	var from_palette := editor.place(Level.to_grid(cancel_block.position))
	check(from_palette == cancel_block and cancel_block.content_id == &"star", "Palette insertion did not use the same container path")
	editor.history.undo()
	check(cancel_block.content_id == &"one_up", "Palette insertion undo did not restore prior contents")
	var saved: Dictionary = await editor.save_to_path(path)
	check(saved.error == OK, "Batch signed save failed")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var found := [false, false, false, false]
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is OneUpPart and part.position == Vector2(400, -32):
			found[0] = part.swe_data.future_oneup == 17
		elif part is HardBlockPart and part.position == Vector2(464, -32):
			found[1] = part.swe_data.future_rock == 18
		elif part is HiddenBlockPart and part.position == Vector2(512, -64):
			found[2] = part.content_id == &"one_up" and part.swe_data.future_hidden == 19
		elif part is TurnBlockPart and part.position == Vector2(560, -64):
			found[3] = part.content_id == &"star"
	check(not false in found, "Batch round trip lost an object, contents or unknown source fields")
	reopened.free()
	level.queue_free()
	await ticks(2)


func enemy_at(level: Level, scene: String, at: Vector2, direction: int) -> Enemy:
	var enemy: Enemy = load("res://scenes/level/entities/%s.tscn" % scene).instantiate()
	enemy.position = at
	enemy.get_node("SlideComponent").direction = direction
	level.current_sub_area.add(enemy)
	return enemy


func check_actor_contacts(level: Level) -> void:
	var player := level.hud.player
	park(player)
	var names := ["galoomba", "green_koopa", "buzzy_beetle", "spiny"]
	for left in names:
		for right in names:
			if capture and (left != "galoomba" or right != "green_koopa"):
				continue
			var a := enemy_at(level, left, Vector2(420, -16), 1)
			var b := enemy_at(level, right, Vector2(442, -16), -1)
			await ticks(24)
			check(a.get_node("SlideComponent").direction == -1 and b.get_node("SlideComponent").direction == 1 \
					and a.position.x < b.position.x, "Head-on enemy contact passed through or turned only one actor: %s/%s" % [left, right])
			a.queue_free()
			b.queue_free()
			await ticks(2)
	if capture:
		return
	# Creation-order tie breaking separates identical centers in one tick.
	var a := enemy_at(level, "galoomba", Vector2(430, -16), -1)
	var b := enemy_at(level, "galoomba", Vector2(430, -16), -1)
	await ticks(8)
	check(a.get_node("SlideComponent").direction == -1 and b.get_node("SlideComponent").direction == 1,
			"Equal-center contact did not separate by stable instance order")
	a.queue_free()
	b.queue_free()
	await ticks(2)
	# Source bottom-four-pixel exclusion keeps a lower head out of the upper probe.
	a = enemy_at(level, "galoomba", Vector2(420, -31), 1)
	b = enemy_at(level, "green_koopa", Vector2(420, -16), -1)
	a.set_physics_process(false)
	b.set_physics_process(false)
	await ticks(2)
	a.velocity.x = 30
	check(not level.current_sub_area.actor_contacts.turn_enemy(a), "Foot-only vertical contact incorrectly reversed the upper enemy")
	a.queue_free()
	b.queue_free()
	await ticks(2)
	# Stationary shells turn walkers and powerups; attacking shells keep their kill path.
	var shell: KoopaShell = load("res://scenes/level/entities/koopa_shell.tscn").instantiate()
	shell.position = Vector2(450, -16)
	shell._grace = 0
	level.current_sub_area.add(shell)
	a = enemy_at(level, "galoomba", Vector2(420, -16), 1)
	await ticks(52)
	check(a.get_node("SlideComponent").direction == -1 and is_instance_valid(shell), "Resting shell did not turn a walking enemy")
	a.queue_free()
	var item := OneUp.new()
	item.position = Vector2(420, -16)
	level.current_sub_area.add(item)
	await ticks(30)
	check(item.velocity.x == -60, "1UP passed through a resting carryable instead of reversing")
	item.queue_free()
	shell.queue_free()
	await ticks(2)
	shell = load("res://scenes/level/entities/koopa_shell.tscn").instantiate()
	shell.position = Vector2(400, -16)
	shell.motion = KoopaShell.Motion.MOVING
	shell.velocity.x = 180
	shell._target_velocity = 180
	shell._credit = player
	level.current_sub_area.add(shell)
	a = enemy_at(level, "galoomba", Vector2(440, -16), -1)
	var score := player.score
	await ticks(20)
	check(not is_instance_valid(a) and is_instance_valid(shell) and player.score > score, "Moving shell collision lost its defeat/chain policy")
	shell.queue_free()
	await ticks(2)
	# A thrown flipped Galoomba hits; a carried one sacrifices itself as a shield.
	var flipped: StompedGaloomba = load("res://scenes/level/entities/stomped_galoomba.tscn").instantiate()
	flipped.position = Vector2(420, -60)
	flipped.velocity = Vector2(150, -90)
	level.current_sub_area.add(flipped)
	a = enemy_at(level, "galoomba", Vector2(438, -60), -1)
	await ticks(7)
	check(not is_instance_valid(a) and is_instance_valid(flipped), "Thrown Galoomba did not defeat a contacted enemy")
	if is_instance_valid(flipped): flipped.queue_free()
	await ticks(2)
	flipped = load("res://scenes/level/entities/stomped_galoomba.tscn").instantiate()
	flipped.position = Vector2(350, -16)
	level.current_sub_area.add(flipped)
	await ticks(16)
	Input.action_press("player_run")
	player.give_item(flipped)
	player.invulnerability_left = 2
	await ticks(2)
	check(player.held_item == flipped, "Shield collision setup did not establish native holding")
	a = enemy_at(level, "galoomba", flipped.global_position + Vector2(4, 0), -1)
	await ticks(4)
	check(not is_instance_valid(a) and not is_instance_valid(flipped) and player.held_item == null,
			"Carried Galoomba failed to defeat an enemy and release both owners")
	release_input()
	# Collectible powerups pass ordinary enemies and each other.
	a = enemy_at(level, "galoomba", Vector2(440, -16), -1)
	a.set_physics_process(false)
	item = OneUp.new()
	item.position = Vector2(420, -16)
	level.current_sub_area.add(item)
	var mushroom: Mushroom = load("res://scenes/level/entities/mushroom.tscn").instantiate()
	mushroom.position = Vector2(468, -16)
	mushroom.get_node("SlideComponent").direction = -1
	level.current_sub_area.add(mushroom)
	await ticks(42)
	check(item.position.x > 450 and item.velocity.x == 60 and mushroom.position.x < 440,
			"Ordinary enemy/powerup contacts became unwanted solid barriers")
	item.queue_free()
	mushroom.queue_free()
	a.queue_free()
	await ticks(2)


func check_cleanup(level: Level) -> void:
	var player := level.hud.player
	park(player)
	var item := OneUp.new()
	item.position = Vector2(420, -64)
	level.current_sub_area.add(item)
	await ticks(5)
	player.kill()
	await ticks(2)
	var stopped := item.position
	await ticks(10)
	check(item.position == stopped and item.velocity == Vector2.ZERO, "1UP kept moving after forced Mario death")
	level.reload()
	await ticks(5)
	check(not is_instance_valid(item), "Retry retained the old1UP actor")
	player = level.hud.player
	var block := add_part(level, QuestionBlockPart, Vector2(440, -80)) as QuestionBlockPart
	block.content_id = &"one_up"
	block.build()
	await ticks(2)
	for body in level.current_sub_area.get_foreground().get_children():
		if body is QuestionBlock and body.position == block.position:
			body.get_node("%BlockComponent").activate(player)
	await ticks(10)
	level.edit()
	await ticks(40)
	check(level.current_sub_area.get_foreground().get_child_count() == 0 \
			and level.current_sub_area.actor_contacts._bounds.is_empty(), "Editor return retained a pending sprout or stale contact snapshot")


func park(player: Player, at := Vector2(320, -16)) -> void:
	release_input()
	player.position = at
	player.previous_position = at
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)


func check_one_up(level: Level) -> void:
	var player := level.hud.player
	park(player)
	for power in [SmallPowerup.new(), SuperPowerup.new(), FirePowerup.new()]:
		player.set_powerup(power, false)
		var before := player.extra_lives
		var score := player.score
		var item := OneUp.new()
		item.position = player.position
		level.current_sub_area.add(item)
		await ticks(3)
		check(not is_instance_valid(item) and player.extra_lives == before + 1 and player.score == score \
				and player.get_powerup() == power and not get_tree().paused, "1UP pickup duplicated reward or changed power/score/pause")
	park(player)
	var item := OneUp.new()
	item.position = Vector2(420, -64)
	level.current_sub_area.add(item)
	await ticks(40)
	check(item.velocity.x == 60 and item.position.x > 420 and item.is_on_floor(), "1UP did not settle and walk right on native terrain")
	var wall := HardBlock.new()
	wall.sub_area = level.current_sub_area
	wall.position = Vector2(item.position.x + 20, -32)
	level.current_sub_area.add(wall)
	await ticks(30)
	check(item.velocity.x == -60, "Hard block contact did not reverse the1UP")
	item.queue_free()
	wall.queue_free()
	await ticks(2)


func check_hidden(level: Level) -> void:
	var player := level.hud.player
	player.set_powerup(SmallPowerup.new(), false)
	var hidden := HiddenBlock.new()
	hidden.sub_area = level.current_sub_area
	hidden.position = Vector2(440, -80)
	hidden.sprout = OneUpSprout.new()
	level.current_sub_area.add(hidden)
	# Side/falling passages must not reveal the block or become a ceiling.
	park(player, Vector2(448, -100))
	player.state_machine.switch(PlayerFallingState)
	await ticks(13)
	check(is_instance_valid(hidden), "Falling through a hidden block revealed it")
	park(player, Vector2(448, -16))
	await ticks(3)
	Input.action_press("player_jump")
	await ticks(16)
	Input.action_release("player_jump")
	check(not is_instance_valid(hidden), "Actual upward Mario head contact did not reveal the hidden block")
	await ticks(50)
	var used: QuestionBlock
	var reward: OneUp
	for body in level.current_sub_area.get_foreground().get_children():
		if body is QuestionBlock and body.position == Vector2(440, -80): used = body
		if body is OneUp: reward = body
	check(used != null and not used.get_node("%BlockComponent").enabled and used.get_node("%Sprite").animation == &"used",
			"Revealed block did not become a solid used block")
	check(reward != null and reward.level == level, "Hidden1UP did not rise once with its native area context")
	if used != null: used.queue_free()
	if reward != null: reward.queue_free()
	park(player)
	await ticks(2)


func check_hard(level: Level) -> void:
	var player := level.hud.player
	var block := HardBlock.new()
	block.sub_area = level.current_sub_area
	block.position = Vector2(440, -80)
	level.current_sub_area.add(block)
	park(player, Vector2(448, -16))
	await ticks(3)
	Input.action_press("player_jump")
	await ticks(20)
	Input.action_release("player_jump")
	check(is_instance_valid(block) and player.position.y > -55, "Normal head bump broke/passed through a hard block")
	park(player)
	var giant: Thwomp = load("res://scenes/level/entities/thwomp.tscn").instantiate()
	giant.variant = load("res://resources/content/smw_thwomp_giant.tres")
	giant.position = Vector2(448, -128)
	level.current_sub_area.add(giant)
	giant.phase = Thwomp.Phase.ATTACKING
	await ticks(35)
	check(not is_instance_valid(block), "Actual giant Thwomp attack did not break hard terrain")
	giant.queue_free()
	await ticks(2)
	block = HardBlock.new()
	block.sub_area = level.current_sub_area
	block.position = Vector2(440, -80)
	level.current_sub_area.add(block)
	player.equip_shell_helmet(load("res://resources/content/smw_helmet_spiny_rules.tres"))
	park(player, Vector2(448, -16))
	await ticks(3)
	Input.action_press("player_jump")
	await ticks(20)
	Input.action_release("player_jump")
	check(not is_instance_valid(block) and player.has_helmet(), "Spiny shell helmet failed to break hard terrain on a real head bump")
	player._helmet.break_off()
	park(player)
	await ticks(2)


func check_containers(level: Level) -> void:
	var player := level.hud.player
	park(player)
	var turn := add_part(level, TurnBlockPart, Vector2(440, -80)) as TurnBlockPart
	turn.content_id = &"one_up"
	turn.build()
	await ticks(2)
	var tile: TurnBlockTile
	for body in level.current_sub_area.get_foreground().get_children():
		if body is TurnBlockTile: tile = body
	tile.get_node("BlockComponent").activate(player)
	await ticks(55)
	check(not tile.turning and not tile.get_node("BlockComponent").enabled and tile.get_node("Sprite").animation == &"used",
			"Occupied flip block spun instead of releasing its contents and becoming used")
	var item_count := 0
	for body in level.current_sub_area.get_foreground().get_children():
		if body is OneUp:
			item_count += 1
			body.queue_free()
	check(item_count == 1, "Occupied flip block did not emit exactly one1UP")
	tile.queue_free()
	turn.queue_free()
	# Coin insertion creates the source's timed multi-coin window.
	var question := add_part(level, QuestionBlockPart, Vector2(480, -80)) as QuestionBlockPart
	question.content_id = &"multi_coin"
	question.build()
	await ticks(2)
	var coin_tile: QuestionBlock
	for body in level.current_sub_area.get_foreground().get_children():
		if body is QuestionBlock and body.position == question.position: coin_tile = body
	var before := player.coins
	for i in 3:
		coin_tile.get_node("%BlockComponent").activate(player)
		await ticks(15)
	check(player.coins == before + 3 and coin_tile.get_node("%BlockComponent").enabled, "Coin insertion did not allow repeated bumps")
	await ticks(200)
	coin_tile.get_node("%BlockComponent").activate(player)
	await ticks(15)
	check(player.coins == before + 4 and not coin_tile.get_node("%BlockComponent").enabled, "Multi-coin expiry did not finish on the next bump")
	coin_tile.queue_free()
	question.queue_free()
	await ticks(2)


func capture_runtime(level: Level) -> void:
	var area := level.current_sub_area
	# Keep Mario outside the neighbour pair, so this is a living-world reel.
	park(level.hud.player, Vector2(350, -16))
	var a := enemy_at(level, "galoomba", Vector2(428, -16), 1)
	var b := enemy_at(level, "green_koopa", Vector2(450, -16), -1)
	var poses: Array[Image] = []
	for count in [1, 14, 20]:
		await ticks(count)
		Utility.camera_position = Vector2(310, -200)
		await RenderingServer.frame_post_draw
		var center: Vector2 = get_viewport().get_canvas_transform() * Vector2(435, -25)
		poses.append(get_viewport().get_texture().get_image().get_region(Rect2i(Vector2i(center) - Vector2i(150, 100), Vector2i(300, 150))))
	var sheet := Image.create(900, 150, false, Image.FORMAT_RGBA8)
	for index in poses.size():
		sheet.blit_rect(poses[index], Rect2i(0, 0, 300, 150), Vector2i(index * 300, 0))
	check(sheet.save_png("res://.godot/porting-tests/basic_actor_contacts.png") == OK, "Cannot save actor contact reel")
	check(a.get_node("SlideComponent").direction == -1 and b.get_node("SlideComponent").direction == 1, "Rendered contact reel did not reach separated actors")
	check(not level.is_player_dying(), "Contact capture accidentally entered the world-death stop")
	a.queue_free()
	b.queue_free()
	await ticks(2)
	park(level.hud.player, Vector2(410, -16))
	for index in 4:
		var hard := add_part(level, HardBlockPart, Vector2(448 + index * 16, -32))
		hard.build()
	var item := OneUp.new()
	item.position = Vector2(472, -64)
	area.add(item)
	var hidden := add_part(level, HiddenBlockPart, Vector2(528, -80)) as HiddenBlockPart
	hidden.content_id = &"one_up"
	hidden.build()
	await ticks(26)
	Utility.camera_position = Vector2(310, -200)
	await ticks(1)
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_basic_items_blocks.png") == OK, "Cannot save batch runtime capture")
