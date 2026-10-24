# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/bro_environment_test.gd"
## Source editor origins, free motion, history, masks and compound defeat.

const SMALL := preload("res://resources/content/smw_chomp_small.tres")
const GIANT := preload("res://resources/content/smw_chomp_giant.tres")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--capture-chomp" in OS.get_cmdline_user_args():
		await capture_chomps()
		return
	if "--capture-editor-chomp" in OS.get_cmdline_user_args():
		await capture_chomp_editor()
		return
	for modern in [false, true]:
		await check_chomp_editor(modern)
	for data: ChompVariant in [SMALL, GIANT]:
		await check_build_and_mask(data)
		await check_start_and_hops(data)
		await check_trailing_links(data)
		await check_liquid_rules(data)
		await check_chomp_water_defeat(data)
		for facing in [-1, 1]:
			await check_compound_defeat(data, facing)
		await check_source_contacts(data)
		await check_death_history(data)
		await check_chomp_cull(data)
	await check_chomp_neighbours()
	await check_chomp_activation()
	await check_chomp_retry()
	await finish("CHOMP_RESULT")


func chomp_level() -> Level:
	var level := await make_level()
	level.current_sub_area.actor_activity.enabled = false
	var player := level.hud.player
	player.set_physics_process(false)
	player.collision_layer = 0
	player.position = Vector2(260, -96)
	player.previous_position = player.position
	return level


func chomp(level: Level, data: ChompVariant, at := Vector2(480, -176), automatic := false) -> ChainChomp:
	var body: ChainChomp = load("res://scenes/entities/chain_chomp.tscn").instantiate()
	body.variant = data
	body.position = at
	level.current_sub_area.add(body)
	body.set_physics_process(automatic)
	return body


func click_chomp(button: Button) -> void:
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
	await ticks(2)


func check_chomp_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	data.MAIN.NIVEL.append({"object": SMALL.object_id, "x_pos": 426.5, "y_pos": 273.25,
		"wings": 1, "paracaidas": 1, "future_chomp": {"keep": 23}})
	data.MAIN.NIVEL.append({"object": GIANT.object_id, "x_pos": 543.25, "y_pos": 245.5,
		"wings": 1, "paracaidas": 0})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/chomp_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var parts: Array[ChompPart] = []
	for part in level.current_sub_area.get_parts().get_children():
		if part is ChompPart:
			parts.append(part)
	check(parts.size() == 2, "Both source Chomp IDs must load typed native Parts")
	if parts.size() == 2:
		check(parts[0].variant == SMALL and parts[0].position == Vector2(426.5, -158.75)
				and parts[0].wings and parts[0].parachute, "Small Chomp import snapped its origin or lost flags")
		check(parts[1].variant == GIANT and parts[1].position == Vector2(543.25, -186.5)
				and parts[1].wings and not parts[1].parachute, "Giant Chomp import shifted its source origin")
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	ring.page_index = 1
	check(ring.choose(6) and level.editor.get_selected_part() == ChompPart,
			"Chain Chomp page2 slot6 still selects a placeholder")
	var probe := level.editor.place(Vector2i(43, -12)) as ChompPart
	level.editor.set_part_modifier(probe, &"wings", true)
	level.editor.set_part_modifier(probe, &"parachute", true)
	var before := probe.position
	probe.held = true
	probe.set_process(false)
	await ticks(45)
	check(is_instance_valid(probe._window), "Chomp long press opened no native window")
	if is_instance_valid(probe._window):
		check(probe.get_variants().is_empty() and probe._window.get_node("Content/Attachments").get_child_count() == 3,
				"Source Chomp window must contain size/wings/parachute, without invented types")
		await click_chomp(probe._window.get_node("Content/Attachments/large"))
	probe.held = false
	probe.set_process(true)
	check(probe.variant == GIANT and probe.position == before - Vector2(0, 16)
			and not probe.wings and not probe.parachute, "Size swap did not shift y-16 and reset both fresh-resource flags")
	check(probe.get_node("CollShape").position == Vector2(16, 16)
			and probe.get_node("CollShape").shape.size == Vector2(32, 32), "Giant editor selection does not cover four cells")
	level.editor.history.undo()
	check(probe.variant == SMALL and probe.position == before and probe.wings and probe.parachute,
			"Chomp size undo lost dependent position/flags")
	level.editor.history.redo()
	check(probe.variant == GIANT and probe.position == before - Vector2(0, 16)
			and not probe.wings and not probe.parachute, "Chomp size redo failed to restore the full replacement")
	var blocker := GroundPart.create()
	blocker.position = probe.position + Vector2(16, 16)
	level.current_sub_area.add_part(blocker)
	await ticks(2)
	probe._check_validity()
	check(not probe._valid_space, "Giant Chomp accepted an occupied lower-right cell")
	blocker.free()
	var next := level.editor.place(Vector2i(47, -12)) as ChompPart
	check(next.variant == SMALL and not next.wings and not next.parachute, "Chomp popup changed the palette card's fresh default")
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Chomp signed SWE saving failed")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var counts := {&"small": 0, &"giant": 0}
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is ChompPart:
			counts[part.variant.id] += 1
			if part.position.x == 426.5:
				check(part.position.y == -158.75 and part.wings and part.parachute
						and part.swe_data.future_chomp.keep == 23, "Chomp save/reopen lost fractional coordinates or unknown fields")
			if part.position.x == 543.25:
				check(part.position.y == -186.5 and part.variant == GIANT and part.wings and not part.parachute,
						"Giant Chomp save/reopen changed its origin/type/flags")
	check(counts == {&"small": 2, &"giant": 2}, "Signed SWE changed Chomp count or sizes")
	reopened.free()
	level.queue_free()
	await ticks(2)


func point_on_chomp(body: ChainChomp, at: Vector2, sensor: bool) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = body.to_global(at)
	query.collision_mask = 1 << 7 if sensor else 2
	query.collide_with_areas = sensor
	query.collide_with_bodies = not sensor
	return not body.get_world_2d().direct_space_state.intersect_point(query, 4).is_empty()


func check_build_and_mask(data: ChompVariant) -> void:
	var level := await chomp_level()
	var part := ChompPart.create()
	part.variant = data
	part.position = Vector2(480.25, -180.5)
	part.wings = true
	part.parachute = true
	level.current_sub_area.add_part(part)
	part.build()
	var bodies := live_nodes(level.current_sub_area, ChainChomp)
	check(bodies.size() == 1, "Chomp Part did not build exactly one native actor")
	var body: ChainChomp = bodies[0]
	body.set_physics_process(false)
	body.get_node("PlayerArea").collision_layer = 1 << 7
	await ticks(2)
	check(body.position == part.position + data.part_to_feet(), "Native feet do not preserve source Chomp build +8/+16 origin")
	check(body.source_origin() == part.position + data.canvas_size / 2, "Chomp source origin changed its editor anchor")
	var bounds := Utility.get_bounding_box(body)
	check(bounds == Rect2(body.global_position + data.mask_rect.position, data.mask_rect.size), "Chomp live mask ignored source bbox")
	for sensor in [false, true]:
		check(point_on_chomp(body, data.mask_rect.get_center(), sensor)
				and not point_on_chomp(body, data.mask_rect.position + Vector2(0.5, 0.5), sensor),
				"Source Chomp ellipse became a square or lost its center")
	check(body._links.size() == 4 and body.find_children("*", "CollisionShape2D", true, false).size() == 2
			and body.find_children("*", "AnimatedSprite2D", true, false).size() == 1,
			"Chomp acquired chain collisions, a stake or runtime editor decorations")
	var sprite: AnimatedSprite2D = body.get_node("Graphics/Sprite")
	check(sprite.sprite_frames.get_animation_speed(&"chomp") == 9 and sprite.offset == -data.canvas_size / 2,
			"Chomp head lost source 9fps animation or center origin")
	level.current_sub_area.night_mode = true
	part._process(0)
	check(part.get_node("Graphics/Sprite").texture.resource_path.contains("/" + String(data.dark_editor_sprite) + "/")
			and part.get_node("Graphics/Sprite").offset == -data.editor_origin,
			"Night Chomp preview lost its own editor resource/origin")
	var night := chomp(level, data, Vector2(550, -176))
	check(night.dark and night._links[0].texture.resource_path.ends_with("frame_000.png")
			and night._sprite.sprite_frames.get_frame_texture(&"chomp", 0).resource_path.contains("/" + String(data.head_sprite) + "/"),
			"SMW dark Chomp must wrap the one-frame chain subimage and retain ordinary head art")
	level.queue_free()
	await ticks(2)


func check_start_and_hops(data: ChompVariant) -> void:
	var level := await chomp_level()
	var body := chomp(level, data)
	await ticks(1)
	body._physics_process(1.0 / 60)
	check(body.velocity.is_equal_approx(Vector2(0, 7.5)), "Chomp moved horizontally before its two-tick startup or used generic gravity")
	var speeds := [-73.2, -68.4, -63.6, -60.0, -60.0]
	for speed in speeds:
		body._physics_process(1.0 / 60)
		check(is_equal_approx(body.velocity.x, speed), "Chomp startup/deceleration differs from source: %s vs %s" % [body.velocity.x, speed])
	# It keeps its direction when Mario crosses behind it; no chase behavior.
	level.hud.player.position.x = 600
	body._physics_process(1.0 / 60)
	check(body.velocity.x == -60 and body.direction == -1 and body._sprite.flip_h, "Free Chomp acquired a Mario chase")
	var wall := StaticBody2D.new()
	wall.position = Vector2(416, -176)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 160)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	wall.add_child(collider)
	level.current_sub_area.add(wall)
	await ticks(2)
	var reversed := false
	var bounced := false
	for frame in 100:
		body._physics_process(1.0 / 60)
		reversed = reversed or body.velocity.x > 0
		bounced = bounced or body.velocity.y <= -data.hop_speed + 0.01
	check(reversed and bounced, "Free Chomp failed to reverse at a real wall and hop from a real floor")
	check(body._sprite.global_position.x == roundf(body.global_position.x)
			and is_equal_approx(body._sprite.global_position.y, body.source_origin().y + 1),
			"Head drawing lost rounded x, unrounded y or its 1px contact offset")
	level.queue_free()
	await ticks(2)


func check_trailing_links(data: ChompVariant) -> void:
	var level := await chomp_level()
	var body := chomp(level, data)
	body._wake_left = INF
	body.velocity.x = 60
	var positions: Array[Vector2] = [body.source_origin()]
	for frame in 65:
		positions.append(body.source_origin())
		body._physics_process(1.0 / 60)
		for index in 4:
			var sample := maxi(0, frame + 2 - (index + 1) * data.link_spacing)
			check(body._links[index].global_position.is_equal_approx(positions[sample]),
					"Chomp chain link %s did not draw its pre-motion source history at frame%s (%s)" % [index, frame, data.id])
	check(body._history.size() == data.history_length + 1, "Chomp history omitted the source's final shifted slot")
	level.queue_free()
	await ticks(2)


func check_liquid_rules(data: ChompVariant) -> void:
	for environment in ["underwater", "night_sky", "night_airship", "forest", "beach"]:
		var level := await chomp_level()
		var area := level.current_sub_area
		var full: bool = environment in ["underwater", "night_sky", "night_airship"]
		if full:
			area.level_theme = Level.LevelTheme.UNDERWATER if environment == "underwater" else \
					Level.LevelTheme.SKY if environment == "night_sky" else Level.LevelTheme.AIRSHIP
			area.night_mode = environment != "underwater"
		else:
			add_liquid(level, Level.LevelTheme.FOREST if environment == "forest" else Level.LevelTheme.BEACH, -160)
		var body := chomp(level, data, Vector2(480, -176) if full else Vector2(480, -144 + data.source_to_feet))
		body._physics_process(1.0 / 60)
		body._physics_process(1.0 / 60)
		var expected := -43.2 if full else -48.0 if environment == "forest" else -73.2
		check(body.swimming and is_equal_approx(body.velocity.x, expected) and is_equal_approx(body.velocity.y, 15),
				"Chomp water startup/gravity lost the forest/beach/full-water distinction: " + environment)
		for frame in 4:
			body._physics_process(1.0 / 60)
		check(is_equal_approx(body.velocity.x, -30 if full else -48 if environment == "forest" else -60),
				"Chomp applied full-water horizontal cap to the wrong environment: " + environment)
		body.position = Vector2(480, -176)
		body.velocity.y = 180
		body._physics_process(1.0 / 60)
		check(is_equal_approx(body.velocity.y, 67.5 if full else 187.5),
				"Chomp did not override inherited water gravity with .125/frame")
		body.position = Vector2(480, -96)
		body.velocity.y = 0
		body._physics_process(1.0 / 60)
		check(is_equal_approx(body.velocity.y, -data.water_hop_speed) and body.position.y < -97,
				"Chomp water floor hop ignored its source size/swimming branch")
		if not full:
			body.position.y = area.liquid.position.y - 20 + data.source_to_feet
			check(body._is_swimming(), "Chomp liquid swimming boundary must be inclusive")
			body.position.y -= 0.01
			check(not body._is_swimming(), "Chomp started swimming above source y+8 threshold")
			body.position.y = area.liquid.position.y + 4 + data.source_to_feet
			check(not body._water_launch(), "Chomp forest launch boundary must be strict; beach is excluded")
			body.position.y += 0.01
			check(body._water_launch() == (environment == "forest"), "Chomp forest/beach startup condition changed")
		level.queue_free()
		await ticks(2)
	for theme in [Level.LevelTheme.CASTLE, Level.LevelTheme.FOREST, Level.LevelTheme.MOUNTAIN]:
		var level := await chomp_level()
		var area := level.current_sub_area
		var liquid := add_liquid(level, theme, -150, theme != Level.LevelTheme.CASTLE)
		var body := chomp(level, data, Vector2(480, liquid.position.y - 20 + data.source_to_feet - 0.01))
		check(not body._touches_damaging_liquid(), "Chomp sank above its inherited source y+8 boundary")
		body.position.y += 0.01
		var origin := body.source_origin()
		body._physics_process(1.0 / 60)
		for entry in area._pending_spawns.values():
			if entry.node is SinkingEnemy:
				entry.node.ready.connect(func(): entry.node.set_physics_process(false), CONNECT_ONE_SHOT)
		await ticks(2)
		var sinks := live_nodes(area, SinkingEnemy)
		check(not is_instance_valid(body) and sinks.size() == 1 and live_nodes(area, SwimmingEnemyDefeat).is_empty(),
				"Damaging liquid must replace only Chomp's head, without four dead chain links")
		if sinks.size() == 1:
			var sink: SinkingEnemy = sinks[0]
			check(sink.position == origin and sink.mask_size == data.mask_rect.size
					and sink.mask_center == data.source_mask().get_center() and sink._sprite.frame == 0,
					"Chomp sinking replacement shifted its origin, mask or initial frame")
		level.queue_free()
		await ticks(2)


func hold_chomp_corpses(area: SubArea) -> Array[SwimmingEnemyDefeat]:
	var found: Array[SwimmingEnemyDefeat] = []
	for entry in area._pending_spawns.values():
		if entry.node is SwimmingEnemyDefeat:
			var effect: SwimmingEnemyDefeat = entry.node
			effect.ready.connect(func(): effect.set_physics_process(false), CONNECT_ONE_SHOT)
			found.append(effect)
	return found


func check_compound_defeat(data: ChompVariant, facing: int) -> void:
	var level := await chomp_level()
	var area := level.current_sub_area
	area.night_mode = facing > 0
	var body := chomp(level, data, Vector2(480, -176))
	body._wake_left = INF
	body.velocity.x = facing * 60
	for frame in 30:
		body._physics_process(1.0 / 60)
	body.direction = facing
	body._sprite.frame = 1
	var points: Array[Vector2] = [body.source_origin()]
	for link in body._links:
		points.append(link.global_position)
	check(not body.hit_by_projectile(&"fire", -facing) and not body.is_queued_for_deletion(),
			"Source fireball must be rejected by both Chomp sizes")
	body.hit_by_projectile(&"shell", -facing)
	var corpses := hold_chomp_corpses(area)
	check(corpses.size() == 5 and effects(area, &"spr_spinthump").is_empty(), "Chomp defeat did not create a head plus four links")
	for index in corpses.size():
		var corpse := corpses[index]
		check(corpse.position.is_equal_approx(points[index]) and corpse.direction == facing
				and (absf(corpse.velocity.x) == 60 if index == 0 else corpse.velocity.x == -60),
				"Chomp corpse used collision-partner facing/impulse or lost a historical link position")
	await ticks(2)
	for index in corpses.size():
		var corpse := corpses[index]
		var sprite: AnimatedSprite2D = corpse.get_child(0)
		check(sprite.frame == (1 if index == 0 else 0) and sprite.flip_h == (facing < 0)
				and not sprite.is_playing() and corpse.velocity.y == -240, "Chomp corpse lost current head/dark chain frame, facing or launch")
		var x := corpse.position.x
		corpse._physics_process(1.0 / 60)
		check(is_equal_approx(absf(corpse.position.x - x), 1) and is_equal_approx(absf(corpse.rotation_degrees), 16),
				"Chomp head/link corpse failed shared source motion/spin")
	level.queue_free()
	await ticks(2)


func check_source_contacts(data: ChompVariant) -> void:
	var level := await chomp_level()
	var area := level.current_sub_area
	var player := level.hud.player
	var body := chomp(level, data)
	check(not body.hit_by_projectile(&"pow"), "Airborne Chomp accepted a ground POW")
	body.position.y = -96
	body.velocity.y = 0
	body.hit_by_projectile(&"pow")
	var corpses := hold_chomp_corpses(area)
	check(corpses.size() == 5 and effects(area, &"spr_spinthump").is_empty(), "Chomp POW must use normal compound defeat despite dead_h")
	await ticks(2)
	for corpse in corpses:
		corpse.queue_free()
	body = chomp(level, data, Vector2(480, -96))
	player.state_machine.switch(PlayerSpinJumpingState)
	player.velocity.y = 60
	body._stomped(player)
	check(not body.is_queued_for_deletion() and player.velocity.y < 0,
			"Spin jump must recoil from a Chomp without killing the head or chains")
	player.state_machine.switch(PlayerIdleState)
	var block: QuestionBlock = load("res://scenes/tiles/question_block.tscn").instantiate()
	block.position = Vector2(528, -176)
	area.add(block)
	body.queue_free()
	body = chomp(level, data, Vector2(528, -160))
	body.position.y = Utility.get_bounding_box(block).position.y
	await ticks(2)
	var component: BlockComponent = block.get_node("BlockComponent")
	component.sprout.empty = true
	var score := player.score
	component.activate(player)
	corpses = hold_chomp_corpses(area)
	check(corpses.size() == 5 and player.score == score + 200, "Actual block bump missed Chomp's compound defeat/points")
	level.queue_free()
	await ticks(2)
	# Real moving-shell overlap uses the same typed five-part death path.
	level = await chomp_level()
	area = level.current_sub_area
	body = chomp(level, data, Vector2(480, -96))
	var shell: KoopaShell = load("res://scenes/entities/koopa_shell.tscn").instantiate()
	shell.position = Vector2(450, -96)
	area.add(shell)
	level.hud.player.direction = 1
	shell.launch(level.hud.player, false)
	shell.velocity.x = 240
	await ticks(12)
	check(not is_instance_valid(body) and live_nodes(area, SwimmingEnemyDefeat).size() == 5,
			"Actual moving shell did not defeat the head and all four chain links")
	level.queue_free()
	await ticks(2)
	# Actual normal stomp damages Mario, while a Spiny helmet defeats the head.
	for helmet in [false, true]:
		level = await chomp_level()
		area = level.current_sub_area
		player = level.hud.player
		player.collision_layer = 4
		if helmet:
			player.equip_shell_helmet(preload("res://resources/content/smw_helmet_spiny_rules.tres"))
			await ticks(2)
			var hat: PlayerHelmet = player.get_node("BuzzyHelmet")
			body = chomp(level, data, Vector2(player.position.x + 3, -180))
			body.position.y += hat._head_bounds().position.y + 2 - Utility.get_bounding_box(body).end.y
			body.velocity.y = 60
		else:
			player.set_powerup(SmallPowerup.new(), false)
			body = chomp(level, data, Vector2(480, -96))
			player.position = Vector2(480, -160)
			player.previous_position = player.position
			player.velocity = Vector2(0, 120)
			player.state_machine.switch(PlayerFallingState)
			player.set_physics_process(true)
		await ticks(20 if not helmet else 3)
		check((not is_instance_valid(body) and live_nodes(area, SwimmingEnemyDefeat).size() == 5 and player.has_helmet()) if helmet
				else (is_instance_valid(body) and player.is_dead()), "Actual Chomp/normal-Mario or Spiny helmet contact failed")
		level.queue_free()
		await ticks(2)


func check_death_history(data: ChompVariant) -> void:
	var level := await chomp_level()
	var body := chomp(level, data, Vector2(480, -176), true)
	await ticks(16)
	level.hud.player.kill()
	await ticks(1)
	var at := body.position
	var history := body._history.duplicate()
	var links: Array[Vector2] = []
	for link in body._links:
		links.append(link.global_position)
	await ticks(12)
	check(body.can_process() and body.position == at and body.velocity == Vector2.ZERO
			and not body._follow and body._wake_left == INF and not body._sprite.is_playing() and body._history == history,
			"WorldDeath failed to stop Chomp history, startup alarm, art and automatic motion while retaining events")
	for index in 4:
		check(body._links[index].global_position == links[index], "A trailing chain link moved during Mario death")
	# An explicit source y-- at a supported head is retained once; stale native
	# is_on_floor must not lift it another pixel on every subsequent stopped tick.
	body.position.y = -96
	await ticks(1)
	check(is_equal_approx(body.position.y, -97), "Stopped Chomp omitted the explicit source supported y--")
	await ticks(8)
	check(is_equal_approx(body.position.y, -97), "Stopped Chomp replayed a stale floor flag and drifted upwards")
	level.queue_free()
	await ticks(2)


func check_chomp_neighbours() -> void:
	var level := await chomp_level()
	var body := chomp(level, SMALL, Vector2(480, -160))
	var neighbour := chomp(level, SMALL, Vector2(484, -160))
	var held: StompedGaloomba = load("res://scenes/entities/stomped_galoomba.tscn").instantiate()
	held.position = Vector2(476, -160)
	level.current_sub_area.add(held)
	held.set_physics_process(false)
	held.get_node("GravityComponent").set_physics_process(false)
	await ticks(2)
	body._wake_left = INF
	body.velocity.x = 60
	held.get_node("PickupComponent").pickup_immunity_left = 0
	body._physics_process(1.0 / 60)
	check(body.velocity.x == 60, "Held-parent contact did not supersede the ordinary enemy turn")
	body.position = Vector2(480, -160)
	body.velocity.x = 60
	held.get_node("PickupComponent").pickup_immunity_left = INF
	body._physics_process(1.0 / 60)
	check(body.velocity.x == -60, "Immune held-parent contact should leave the ordinary enemy's turn")
	for full_water in [false, true]:
		level.current_sub_area.level_theme = Level.LevelTheme.UNDERWATER if full_water else Level.LevelTheme.OVERWORLD
		body.position = Vector2(480, -160)
		body.direction = 1
		body.velocity.x = 48 if full_water else 78
		body._physics_process(1.0 / 60)
		check(body.velocity.x == (-48 if full_water else -78), "Neighbour reversal must retain source old-direct overspeed for one tick")
		body._physics_process(1.0 / 60)
		check(is_equal_approx(body.velocity.x, -43.2 if full_water else -73.2), "Reversed Chomp failed to resume source deceleration on the following tick")
	level.current_sub_area.level_theme = Level.LevelTheme.OVERWORLD
	held.queue_free()
	body.position = Vector2(480, -160)
	neighbour.position = body.position
	await ticks(2)
	body.velocity.x = 60
	body._physics_process(1.0 / 60)
	check(body.velocity.x == -60, "Equal-center Chomps lost source instance-order separation")
	level.queue_free()
	await ticks(2)


func check_chomp_cull(data: ChompVariant) -> void:
	var level := await chomp_level()
	var body := chomp(level, data, Vector2(800, 16 - data.mask_rect.position.y))
	body._wake_left = INF
	body.velocity.y = 120
	check(not body._is_below_world(), "Chomp culling boundary must retain equality")
	body._physics_process(1.0 / 60)
	check(not body.is_queued_for_deletion(), "Chomp culled after moving across its source top-edge boundary")
	var after := body.position
	body._physics_process(1.0 / 60)
	check(body.is_queued_for_deletion() and body.position == after, "Chomp did not cull before the next automatic move")
	level.queue_free()
	await ticks(2)


func check_chomp_water_defeat(data: ChompVariant) -> void:
	var level := await chomp_level()
	var area := level.current_sub_area
	var liquid := add_liquid(level, Level.LevelTheme.FOREST, -150)
	for offset in [0.0, 0.01]:
		var body := chomp(level, data, Vector2(480, liquid.position.y - 19 + data.source_to_feet + offset))
		body.kill(1)
		var corpses := hold_chomp_corpses(area)
		await ticks(2)
		check(corpses.size() == 5, "Chomp water defeat did not produce five separate source corpses")
		for index in corpses.size():
			var corpse := corpses[index]
			check(corpse.velocity.y == (-240 if offset == 0 else -96), "A Chomp head/link lost Create's strict initial beach-mask water sample")
			var edge := data.source_mask().end.y - 9 if index == 0 else data.canvas_size.y / 4 - 9
			check(is_equal_approx(corpse._water_offset(), edge), "Chomp corpse water sampling ignored its own head/link mask")
			corpse.position.y = liquid.position.y - 12 - edge
			check(not corpse._swimming(), "Chomp corpse used inclusive water contact instead of strict selected-mask contact")
			corpse.position.y += 0.01
			check(corpse._swimming(), "Chomp corpse did not switch to its selected mask after Create")
			corpse.queue_free()
		await ticks(2)
	level.queue_free()
	await ticks(2)


func check_chomp_activation() -> void:
	var level := await chomp_level()
	var area := level.current_sub_area
	area.actor_activity.enabled = true
	Utility.camera_position = Vector2(208, -216)
	var body := chomp(level, GIANT, Vector2(1050, -176), true)
	await ticks(4)
	var history := body._history.duplicate()
	var clock := body._wake_left
	var at := body.position
	await ticks(8)
	check(not body.can_process() and not body.visible and body.position == at
			and body._history == history and body._wake_left == clock, "Offscreen Chomp did not preserve startup/history in native activation")
	Utility.camera_position = Vector2(800, -216)
	await ticks(4)
	check(body.can_process() and body.visible and body.position != at, "Chomp failed to resume through native activation")
	level.queue_free()
	await ticks(2)


func check_chomp_retry() -> void:
	var level := await chomp_level()
	var area := level.current_sub_area
	var body := chomp(level, SMALL)
	body.kill(1)
	level.reload()
	await ticks(3)
	check(not is_instance_valid(body) and live_nodes(area, SwimmingEnemyDefeat).is_empty() and area._pending_spawns.is_empty(),
			"Deferred Chomp head/links survived a same-step retry")
	level.queue_free()
	await ticks(2)


func save_chomp_capture(level: Level, name: String) -> void:
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_" + name + ".png") == OK,
			"Could not save real-renderer Chomp capture")
	print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	level.queue_free()
	await ticks(2)
	get_tree().quit(0 if failures.is_empty() else 1)


func capture_chomps() -> void:
	var level := await chomp_level()
	Utility.camera_position = Vector2(208, -216)
	await ticks(40)
	chomp(level, SMALL, Vector2(400, -96), true)
	chomp(level, GIANT, Vector2(548, -96), true)
	await ticks(65)
	var dead := chomp(level, SMALL, Vector2(430, -156))
	dead._wake_left = INF
	dead.velocity.x = 60
	for frame in 25:
		dead._physics_process(1.0 / 60)
	dead.kill(-1)
	await ticks(5)
	check(live_nodes(level.current_sub_area, ChainChomp).size() == 2
			and live_nodes(level.current_sub_area, SwimmingEnemyDefeat).size() == 5,
			"Chomp capture missed live sizes or compound defeat")
	await save_chomp_capture(level, "chomp")


func capture_chomp_editor() -> void:
	var level := await LevelActionBtn.prepare_level(FIXTURE, Level.Status.EDITING)
	add_child(level)
	await ticks(35)
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	ring.page_index = 1
	ring.choose(6)
	var small := level.editor.place(Vector2i(14, -7)) as ChompPart
	var large := level.editor.place(Vector2i(18, -7)) as ChompPart
	level.editor.set_part_modifier(large, &"large", true)
	level.editor.set_part_modifier(large, &"wings", true)
	level.editor.set_part_modifier(large, &"parachute", true)
	small.held = true
	small.set_process(false)
	await ticks(50)
	check(is_instance_valid(small._window), "Chomp editor capture opened no native size/attachment window")
	await save_chomp_capture(level, "editor_chomp")
