# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Native editor/SWE, physical solid stacks, hazardous contacts and source effects.

const FIXTURE := "res://tests/fixtures/port_slice.swe"
const SMALL = preload("res://resources/content/smw_muncher_small.tres")
const GIANT = preload("res://resources/content/smw_muncher_giant.tres")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for modern in [false, true]:
		await check_editor(modern)
	for variant in [SMALL, GIANT]:
		for water in [false, true]:
			await check_motion(variant, water)
		for spin in [false, true]:
			await check_contact(variant, spin)
		for spiny in [false, true]:
			await check_helmet(variant, spiny)
		await check_crush(variant)
	await check_stacks()
	await check_platforms()
	await check_other_crushes()
	await check_giant_landing()
	await check_shell_and_block()
	await check_liquid_and_death()
	await check_camera_and_cleanup()
	await finish("MUNCHER_RESULT")


func make_level(theme := Level.LevelTheme.OVERWORLD) -> Level:
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	var sub := level.current_sub_area
	for part in sub.get_parts().get_children():
		if not part is EditorPlayer and not part is StartingGround:
			part.free()
	for x in range(12, 50):
		var part := GroundPart.create()
		part.position = Vector2(x * 16, -96)
		sub.add_part(part)
	sub.level_theme = theme
	sub.water_start_y = -200
	sub.water_limit_y = -200
	add_child(level)
	# Contact/crush oracles include actors outside the camera strip.
	sub.actor_activity.enabled = false
	await ticks(8)
	return level


func park(player: Player, at := Vector2(64, -16)) -> void:
	release_input()
	player.position = at
	player.previous_position = player.global_position
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)


func actor(level: Level, variant := SMALL, at := Vector2(320, -96)) -> Muncher:
	var body: Muncher = load("res://scenes/level/entities/muncher.tscn").instantiate()
	body.variant = variant
	body.position = at
	level.current_sub_area.add(body)
	return body


func actors(level: Level, script: Script) -> Array:
	return level.current_sub_area.get_foreground().get_children().filter(
			func(node): return node.get_script() == script and not node.is_queued_for_deletion())


func click(button: Button) -> void:
	var at := button.get_global_transform_with_canvas() * (button.size / 2)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await ticks(1)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	get_viewport().push_input(event, true)
	await ticks(1)


func check_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	data.MAIN.NIVEL.append({"object": SMALL.object_id, "x_pos": 400, "y_pos": 272,
		"wings": 1, "paracaidas": 1, "direct_t": 3, "inup": 7, "future_muncher": {"keep": 23}})
	data.MAIN.NIVEL.append({"object": GIANT.object_id, "x_pos": 528, "y_pos": 272,
		"wings": 1, "paracaidas": 1})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/muncher_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var small: MuncherPart
	var giant: MuncherPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is MuncherPart:
			if part.variant == SMALL:
				small = part
			else:
				giant = part
	check(small != null and giant != null, "Both source Muncher IDs must load native Parts")
	check(small.position == Vector2(400, -160) and giant.position == Vector2(512, -160),
			"Giant source origin must convert to the native lower-left cell")
	check(small.wings and small.parachute and giant.wings and giant.parachute, "Import lost legacy Muncher flags")
	check(giant.get_node("CollShape").position == Vector2(16, 0)
			and giant.get_node("CollShape").shape.size == Vector2(32, 32), "Giant editor bounds do not cover its four cells")
	check(giant.get_node("Graphics/Sprite").offset == Vector2(-16, -16)
			and giant.get_node("Graphics/Sprite").texture.resource_path.ends_with("frame_004.png"), "Giant preview origin/style frame changed")
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	ring.page_index = 1
	check(ring.choose(1) and level.editor.get_selected_part() == MuncherPart, "Native Muncher page2 slot1 is disabled")
	var placed := level.editor.place(Vector2i(38, -10)) as MuncherPart
	level.editor.set_part_modifier(placed, &"wings", true)
	level.editor.set_part_modifier(placed, &"parachute", true)
	var before := placed.position
	placed.held = true
	placed.set_process(false)
	await ticks(45)
	check(is_instance_valid(placed._window), "Muncher long press did not open its native size/flag window")
	if is_instance_valid(placed._window):
		await click(placed._window.get_node("Content/Attachments/parachute"))
		check(placed.wings and not placed.parachute, "Muncher GUI flags are not independent")
		await click(placed._window.get_node("Content/Attachments/parachute"))
		await click(placed._window.get_node("Content/Options/giant"))
	placed.held = false
	placed.set_process(true)
	check(placed.variant == GIANT and not placed.wings and not placed.parachute and placed.position == before,
			"Source giant swap must grow upward/right and clear both fresh-resource flags")
	level.editor.history.undo()
	check(placed.variant == SMALL and placed.wings and placed.parachute
			and placed.get_node("CollShape").shape.size == Vector2(16, 16), "Size undo lost dependent flags or dimensions")
	level.editor.history.redo()
	var next := level.editor.place(Vector2i(43, -10)) as MuncherPart
	check(next.variant == SMALL and not next.wings and not next.parachute, "Muncher size must not alter the source card default")
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Muncher native save failed")
	var reread := LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(path))
	var rows: Array = reread.data.S0.S4 if modern else reread.data.MAIN.NIVEL
	var giant_row: Dictionary = rows.filter(func(row): return row.get("ID", row.get("object")) == GIANT.object_id)[0]
	check(giant_row.get("xx", giant_row.get("x_pos")) == 528, "SWE giant instance x-origin was rewritten")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var counts := {&"small": 0, &"giant": 0}
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is MuncherPart:
			counts[part.variant.id] += 1
			if part.position.x == 400:
				check(part.wings and part.parachute and part.swe_data.direct_t == 3
						and part.swe_data.inup == 7 and part.swe_data.future_muncher.keep == 23,
						"Muncher round-trip lost flags, aliases or unknown fields")
	check(counts == {&"small": 2, &"giant": 2}, "Save/reopen changed Muncher sizes or counts")
	add_child(reopened)
	await ticks(4)
	check(actors(reopened, Muncher).size() == 4, "Reopened Munchers did not build physical solids")
	for body in actors(reopened, Muncher):
		check(body.get_child_count() == 2, "Source runtime unexpectedly received editor wing/parachute overlays")
	var blocker := GroundPart.create()
	blocker.position = placed.position + Vector2(16, -16)
	level.current_sub_area.add_part(blocker)
	blocker.load()
	placed._check_validity()
	check(not placed._valid_space, "Giant drag validation ignored its upper-right occupied cell")
	reopened.queue_free()
	level.queue_free()
	await ticks(2)


func check_motion(variant: MuncherVariant, water: bool) -> void:
	var level := await make_level(Level.LevelTheme.UNDERWATER if water else Level.LevelTheme.OVERWORLD)
	var body := actor(level, variant, Vector2(320, -300))
	var expected_y := body.position.y
	var expected_speed := 0.0
	for frame in 24:
		expected_speed = minf(60 if water else 240, expected_speed) + (72 if water else 720) / 60.0
		expected_y += expected_speed / 60
		await ticks(1)
		check(absf(body.position.y - expected_y) < 0.12 and absf(body.velocity.y - expected_speed) < 0.05,
				"Muncher fall differs from source pre-gravity cap: %s water=%s tick=%s" % [variant.id, water, frame])
	var newer := actor(level, variant, Vector2(400, -260))
	level.animation_time = 0.17
	body._process(0)
	newer._process(0)
	check(body._sprite.frame == 1 and newer._sprite.frame == 1, "Munchers must share the source banim2 clock")
	body.position = Vector2(320, -96)
	body.velocity = Vector2.ZERO
	await ticks(5)
	check(body.is_on_floor() and absf(body.position.y + 96) < 0.15, "Native Muncher did not rest on ground")
	body.velocity.x = 120
	await ticks(1)
	check(absf(body.velocity.x - 114) < 0.05, "Grounded Muncher horizontal drag differs from source 0.1/frame")
	level.queue_free()
	await ticks(2)


func check_contact(variant: MuncherVariant, spin: bool) -> void:
	var level := await make_level()
	var body := actor(level, variant)
	var player := level.hud.player
	player.set_powerup(SuperPowerup.new(), false)
	park(player, Vector2(320, -180))
	player.state_machine.switch(PlayerSpinJumpingState if spin else PlayerFallingState)
	player.velocity.y = 120
	await ticks(70)
	check(player.get_powerup() is SmallPowerup and not player.is_dead(), "Normal and spin contact must both hurt on Munchers")
	check(is_instance_valid(body) and player.score == 0, "A jump defeated or scored on a physical Muncher")
	player.set_powerup(SuperPowerup.new(), false)
	player.invulnerability_left = 0
	park(player, Vector2(260, -96))
	Input.action_press("player_right")
	await ticks(80)
	release_input()
	check(player.get_powerup() is SmallPowerup and player.position.x < 311, "Muncher side failed native blocking/damage")
	level.queue_free()
	await ticks(2)


func check_helmet(variant: MuncherVariant, spiny: bool) -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_powerup(SuperPowerup.new(), false)
	park(player, Vector2(320, -96))
	await ticks(3)
	if spiny:
		player.equip_shell_helmet(SpinyPart.VARIANTS[1].helmet_rules)
	else:
		player.equip_buzzy_helmet()
	Input.action_press("player_run")
	var body := actor(level, variant, Vector2(320, -180))
	var deflected := false
	for frame in 60:
		await ticks(1)
		if not is_instance_valid(body):
			break
		if body.velocity.y < 0:
			deflected = true
			break
	print("MUNCHER_HELMET_TRACE size=", variant.id, " spiny=", spiny, " helmet=", player.has_helmet(),
			" power=", player.get_powerup().get_script().get_global_name(), " dead=", player.is_dead(),
			" player=", player.position, " actor=", body.position if is_instance_valid(body) else Vector2.INF,
			" deflected=", deflected)
	check(player.has_helmet() and player.get_powerup() is SuperPowerup and not player.is_dead(), "Muncher head contact bypassed the worn helmet")
	if spiny:
		check(not is_instance_valid(body) and player.score == 200, "Spiny's dedicated Muncher collision must defeat/score")
	else:
		check(deflected and is_instance_valid(body) and player.score == 0, "Buzzy must deflect falling Munchers even while Run is held")
	release_input()
	level.queue_free()
	await ticks(2)


func check_crush(variant: MuncherVariant) -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_powerup(SuperPowerup.new(), false)
	park(player, Vector2(320, -96))
	await ticks(3)
	actor(level, variant, Vector2(320, -180))
	for frame in 45:
		await ticks(1)
		if player.is_dead():
			break
	check(player.is_dead() and player.get_powerup() is SuperPowerup, "A falling physical solid must crush grounded Mario directly")
	level.queue_free()
	await ticks(2)


func check_stacks() -> void:
	var level := await make_level()
	for variant in [SMALL, GIANT]:
		var x := 256 if variant == SMALL else 400
		var bottom := actor(level, variant, Vector2(x, -96))
		var middle := actor(level, variant, Vector2(x, -96 - variant.canvas_size.y))
		var top := actor(level, variant, Vector2(x, -96 - variant.canvas_size.y * 2))
		await ticks(8)
		check(middle.support == bottom and top.support == middle, "Muncher stack did not lock native lower actors")
		bottom.velocity.x = 120
		await ticks(6)
		check(absf(top.position.x - bottom.position.x) < 0.1
				and absf(top.position.y - bottom.position.y + variant.canvas_size.y * 2) < 0.1,
				"A moving Muncher stack split apart")
		var old_y := top.position.y
		bottom.queue_free()
		await ticks(35)
		check(is_instance_valid(top) and top.position.y > old_y + 5, "Removing the base must drop, not destroy, a Muncher column")
	level.queue_free()
	await ticks(2)


func check_shell_and_block() -> void:
	var level := await make_level()
	var body := actor(level)
	check(not body.hit_by_projectile(&"fire") and not body.hit_by_projectile(&"shell"), "Ordinary projectiles must not defeat Munchers")
	var shell: KoopaShell = load("res://scenes/level/entities/koopa_shell.tscn").instantiate()
	shell.position = Vector2(260, -96)
	level.current_sub_area.add(shell)
	shell.launch(level.hud.player)
	shell.velocity.x = 180
	for frame in 35:
		await ticks(1)
		if shell.velocity.x < 0:
			break
	check(shell.velocity.x < 0 and is_instance_valid(body), "A moving shell must ricochet off a solid Muncher")
	var shot := PlantFireball.new()
	shot.variant = PiranhaPart.VARIANTS[1]
	shot.position = Vector2(280, -108)
	shot.velocity = Vector2(60, 0)
	level.current_sub_area.add(shot)
	await ticks(35)
	check(not is_instance_valid(shot) and is_instance_valid(body), "Actual plant fireball must burst against solid Munchers")
	var block := QuestionBlockPart.create()
	block.position = Vector2(448, -160)
	level.current_sub_area.add_part(block)
	block.load()
	block.build()
	var above := actor(level, SMALL, Vector2(456, -160))
	var player := level.hud.player
	park(player, Vector2(456, -96))
	await ticks(4)
	Input.action_press("player_jump")
	var bounced := false
	for frame in 40:
		await ticks(1)
		if above.velocity.y < 0:
			bounced = true
			break
	release_input()
	check(bounced and player.coins == 1 and is_instance_valid(above), "An actual head-bumped block must launch, not kill, its Muncher")
	level.queue_free()
	await ticks(2)


func check_liquid_and_death() -> void:
	var level := await make_level(Level.LevelTheme.FOREST)
	var body := actor(level, SMALL, Vector2(320, -140))
	await ticks(10)
	check(body.swimming and absf(body.velocity.y - 12) < 0.05, "Forest water depth must select source solid water gravity")
	level.queue_free()
	await ticks(2)
	level = await make_level(Level.LevelTheme.CASTLE)
	for variant in [SMALL, GIANT]:
		body = actor(level, variant, Vector2(320 if variant == SMALL else 400, -96))
		await ticks(10)
		check(is_instance_valid(body) and not body.swimming, "Muncher's override must retain lava immunity")
		check(body.hit_by_projectile(&"pow"), "A stationary Muncher must accept the source POW defeat")
		await ticks(1)
		var effects := actors(level, SwimmingEnemyDefeat)
		var effect: SwimmingEnemyDefeat = effects.back()
		check(effect.variant == variant and is_zero_approx(effect.velocity.x)
				and effect.get_child(0).frame == 4, "Muncher POW defeat lost its source size/frame/stationary launch")
	level.queue_free()
	await ticks(2)


func check_camera_and_cleanup() -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_process(false)
	player.set_physics_process(false)
	var base := Utility.camera_position
	var position := player.global_position
	level.shake_camera(2)
	for index in CameraImpulse.OFFSETS.size():
		await ticks(1 if index == 0 else 2)
		check(Utility.camera_effect == Vector2(0, CameraImpulse.OFFSETS[index] * 2)
				and Utility.camera_position.is_equal_approx(base) and player.global_position == position,
				"Source impact shake changed timing, camera tracking or physical coordinates at tick %s" % index)
		if index == 4:
			level.shake_camera(10) # The source ignores another impulse mid-sequence.
	check(Utility.camera_effect == Vector2.ZERO, "Source camera impulse did not return exactly to zero")
	level.shake_camera(2)
	await ticks(1)
	var body := actor(level, GIANT)
	body.kill(-1)
	level.reload()
	check(Utility.camera_effect == Vector2.ZERO, "Retry retained the old level's camera impulse")
	await ticks(3)
	check(actors(level, SwimmingEnemyDefeat).is_empty(), "Pending Muncher defeat crossed a retry revision")
	level.shake_camera(2)
	await ticks(1)
	level.edit()
	check(Utility.camera_effect == Vector2.ZERO, "Returning to the editor retained the play camera impulse")
	level.play()
	level.shake_camera(2)
	await ticks(1)
	level.queue_free()
	await ticks(2)
	check(Utility.camera_effect == Vector2.ZERO, "Leaving a shaking level retained a global camera offset")


func check_platforms() -> void:
	var level := await make_level()
	var platform := MovingFloor.new()
	platform.collision_layer = 1
	platform.collision_mask = 0
	platform.sync_to_physics = false
	platform.position = Vector2(320, -160)
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(96, 2)
	collider.shape = rectangle
	collider.position.y = 1
	collider.one_way_collision = true
	platform.add_child(collider)
	level.current_sub_area.add(platform)
	var body := actor(level, SMALL, Vector2(320, -190))
	await ticks(45)
	var before := body.position
	await ticks(30)
	print("MUNCHER_PLATFORM_TRACE before=", before, " after=", body.position)
	check(body.is_on_floor() and absf(body.position.y + 160) < 0.15 and absf(body.position.x - before.x - 15) < 0.6,
			"Native moving one-way platform failed to carry a Muncher")
	body.position = Vector2(platform.position.x, -144)
	body.velocity = Vector2(0, -180)
	await ticks(12)
	check(body.position.y < -160, "Muncher must pass upward through a one-way platform")
	await ticks(35)
	check(body.is_on_floor() and absf(body.position.y + 160) < 0.15, "Muncher did not land back on the semisolid")
	platform.speed = Vector2.ZERO
	var ceiling := StaticBody2D.new()
	ceiling.position = Vector2(body.position.x, -176)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(48, 2)
	shape.shape = box
	ceiling.add_child(shape)
	level.current_sub_area.add(ceiling)
	await ticks(2)
	body.bumped_from_below(level.hud.player)
	check(body.velocity.y >= 0, "A block bump launched Muncher into an occupied ceiling")
	ceiling.queue_free()
	await ticks(2)
	body.bumped_from_below(level.hud.player)
	check(body.velocity.y == -180, "Free Muncher block impulse differs from source -3/frame")
	level.queue_free()
	await ticks(2)


func check_other_crushes() -> void:
	var level := await make_level()
	var enemy: Galoomba = load("res://scenes/level/entities/galoomba.tscn").instantiate()
	enemy.position = Vector2(320, -96)
	level.current_sub_area.add(enemy)
	enemy.get_node("SlideComponent").speed = 0
	var mushroom: Mushroom = load("res://scenes/level/entities/mushroom.tscn").instantiate()
	mushroom.position = Vector2(448, -96)
	level.current_sub_area.add(mushroom)
	mushroom.get_node("SlideComponent").speed = 0
	var flipped: Array[StompedGaloomba] = []
	for index in 2:
		var item: StompedGaloomba = load("res://scenes/level/entities/stomped_galoomba.tscn").instantiate()
		item.variant = GoombaPart.VARIANTS[index]
		item.position = Vector2(576 + index * 64, -96)
		level.current_sub_area.add(item)
		flipped.append(item)
	await ticks(5)
	actor(level, SMALL, Vector2(320, -180))
	actor(level, GIANT, Vector2(448, -180))
	for item in flipped:
		actor(level, SMALL, item.position - Vector2(0, 84))
	await ticks(40)
	check(not is_instance_valid(enemy) and not is_instance_valid(mushroom), "Physical-solid crush failed native enemy/powerup destruction")
	for item in flipped:
		check(not is_instance_valid(item), "Physical-solid crush failed a flipped carryable Galoomba/Goombud")
	check(level.hud.player.score == 0, "Environmental crush incorrectly credited Mario")
	for variant in GoombaPart.VARIANTS:
		var carried: StompedGaloomba = load("res://scenes/level/entities/stomped_galoomba.tscn").instantiate()
		carried.variant = variant
		level.current_sub_area.add(carried)
		Input.action_press("player_run")
		await ticks(15) # The held enemy's inherited initial alarm3 immunity.
		level.hud.player.give_item(carried)
		await ticks(2)
		check(level.hud.player.held_item == carried, "Crush ownership test did not hold its native flipped body")
		carried.kill(1)
		check(level.hud.player.held_item == null, "Destroying a carried body left Mario holding a freed entity")
		await ticks(2)
		var corpses := actors(level, DeadEntity)
		var found := false
		for corpse in corpses:
			var sprite: AnimatedSprite2D = corpse.get_child(0)
			found = found or (sprite.sprite_frames == SpriteLibrary.get_frames(variant.dead_sprite) and sprite.frame == 2)
		check(not is_instance_valid(carried) and found, "Flipped-body defeat lost its typed SMW art/frame")
	release_input()
	level.queue_free()
	await ticks(2)


func check_giant_landing() -> void:
	var level := await make_level()
	var body := actor(level, GIANT, Vector2(320, -220))
	var shook := false
	var sound_count := 0
	for frame in 90:
		await ticks(1)
		shook = shook or Utility.camera_effect != Vector2.ZERO
		var sounds := level.current_sub_area.get_foreground().get_children().filter(func(node):
			return node is AudioStreamPlayer and node.stream.resource_path == SoundLibrary.path(GIANT.landing_sound))
		sound_count = maxi(sound_count, sounds.size())
	check(body.is_on_floor() and shook and sound_count == 1, "Giant landing must emit one original thwomp sound and camera impulse")
	var player := level.hud.player
	player.equip_shell_helmet(SpinyPart.VARIANTS[1].helmet_rules)
	park(player, Vector2(400, -96))
	var rising := actor(level, SMALL, Vector2(400, -130))
	rising.velocity.y = -30
	rising.set_physics_process(false)
	check(not player.helmet_deflects(rising) and not rising.is_queued_for_deletion(), "Spiny helmet must not defeat an ascending Muncher")
	# obj_helmet_spiny/Collision_obj_muncher uses +5, while Buzzy's
	# physics-parent handler uses +8. Probe the actual native body bounds.
	var helmet: PlayerHelmet = player.get_node("BuzzyHelmet")
	var head_top := helmet.global_position.y + helmet.rules.head_top
	rising.position.y = head_top + 6
	rising.velocity.y = 0
	check(not player.helmet_deflects(rising) and not rising.is_queued_for_deletion(), "Spiny hit a Muncher outside its source 5px head margin")
	rising.position.y = head_top + 5
	check(not player.helmet_deflects(rising), "Spiny's source head-height boundary must remain strict")
	rising.position.y = head_top + 4
	check(player.helmet_deflects(rising) and rising.is_queued_for_deletion(), "Spiny rejected a Muncher inside its source 5px head margin")
	level.queue_free()
	await ticks(2)


class MovingFloor extends AnimatableBody2D:
	var speed := Vector2(30, 0)


	func _physics_process(delta: float) -> void:
		position += speed * delta
