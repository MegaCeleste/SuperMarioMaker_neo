# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/rocky_test.gd"
## Source-derived liquid, defeat, precise-mask and asymmetric view cases.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--capture-rocky-environment" in OS.get_cmdline_user_args():
		await capture_environment()
		return
	await check_swimming_sample()
	await check_underwater_cycle()
	await check_settlement_edges()
	await check_liquid_replacement()
	for underwater in [false, true]:
		await check_native_defeat(underwater)
	await check_wrench_art_and_mask()
	await check_wrench_arcs_and_alarms()
	await check_wrench_view_clauses()
	await check_wrench_death_and_helmet()
	await check_owned_spawns()
	await finish("ROCKY_ENVIRONMENT_RESULT")


func add_liquid(level: Level, theme: Level.LevelTheme, y: float, night := false) -> LiquidSurface:
	var area := level.current_sub_area
	area.level_theme = theme
	area.night_mode = night
	area.water_start_y = y - 12
	area.water_limit_y = y - 12
	var liquid := LiquidSurface.new()
	liquid.sub_area = area
	area.liquid = liquid
	area.add_child(liquid)
	liquid.set_physics_process(false)
	return liquid


func live_nodes(area: SubArea, type: Script) -> Array[Node]:
	var found: Array[Node] = []
	for node in area.get_foreground().get_children():
		if is_instance_of(node, type) and not node.is_queued_for_deletion():
			found.append(node)
	return found


func effects(area: SubArea, art: StringName) -> Array[AnimatedSprite2D]:
	var found: Array[AnimatedSprite2D] = []
	for node in area.get_foreground().get_children():
		if node is AnimatedSprite2D and node.sprite_frames.get_frame_texture(node.animation, 0) \
				.resource_path.contains("/" + String(art) + "/"):
			found.append(node)
	return found


func make_wrench(level: Level, at: Vector2) -> Wrench:
	var body := Wrench.new()
	body.position = at
	body.direction = 1
	level.current_sub_area.add(body)
	return body


func platform(level: Level, at: Vector2, size: Vector2, one_way := false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	collider.one_way_collision = one_way
	body.add_child(collider)
	level.current_sub_area.add(body)
	return body


func check_swimming_sample() -> void:
	var level := await make_level()
	var area := level.current_sub_area
	var liquid := add_liquid(level, Level.LevelTheme.CASTLE, -160)
	var body := actor(level, Vector2(400, -164))
	body.set_physics_process(false)
	for state in [[Level.LevelTheme.CASTLE, false], [Level.LevelTheme.FOREST, false],
			[Level.LevelTheme.FOREST, true], [Level.LevelTheme.BEACH, false], [Level.LevelTheme.MOUNTAIN, true]]:
		area.level_theme = state[0]
		area.night_mode = state[1]
		check(body._in_water(Vector2(400, liquid.position.y - 4)) \
				and not body._in_water(Vector2(400, liquid.position.y - 4.1)),
				"Rocky swimming must include y+8 == liquid-12 for every source liquid")
	area.level_theme = Level.LevelTheme.CASTLE
	area.night_mode = false
	body.velocity = Vector2.ZERO
	body._physics_process(1.0 / 60)
	check(body.swimming and is_equal_approx(body.velocity.y, 12),
			"Rocky's Create swimming=0 must use one initial air tick before its Step-end sample")
	body._physics_process(1.0 / 60)
	check(is_equal_approx(body.velocity.y, 13.2) and is_equal_approx(body.pop_speed(), 48),
			"Rocky ignored its stored liquid state for water gravity or pop speed")
	body.velocity.y = 120
	body._fall(1.0 / 60)
	check(is_equal_approx(body.velocity.y, 61.2), "Rocky water fall must cap before adding 0.02px/frame²")
	body._throw_wrench()
	await ticks(1)
	var shots := wrenches(level)
	check(shots.size() == 1 and is_equal_approx(absf(shots[0].velocity.x), 30),
			"Rocky did not pass its stored swimming state to the wrench's 0.5px/frame throw")
	body.position.y = 32
	check(not body._is_below_world(), "Rocky room culling must exclude bbox_top-16 == room_height")
	body.position.y += 0.1
	check(body._is_below_world(), "Rocky room culling missed its strict top-edge boundary")
	level.queue_free()
	await ticks(2)


func check_underwater_cycle() -> void:
	var level := await make_level()
	level.current_sub_area.level_theme = Level.LevelTheme.UNDERWATER
	park(level.hud.player, Vector2(600, -96))
	var body := actor(level, Vector2(400, -144))
	var popped := false
	var settled := false
	for frame in 300:
		await ticks(1)
		if body.phase == Rocky.Phase.POP and body.velocity.y < 0 and not popped:
			popped = true
			check(absf(body.velocity.y + 48) < 0.01, "Underwater Rocky launched with its air pop speed")
		if body.phase == Rocky.Phase.WAIT:
			settled = true
			break
	check(popped and settled and absf(body.position.y + 80) < 0.1,
			"Underwater Rocky failed to pop and bury its origin on actual support")
	for frame in 260:
		await ticks(1)
		if not wrenches(level).is_empty():
			break
	var shots := wrenches(level)
	check(shots.size() == 1 and absf(shots[0].velocity.x - 30) < 0.01,
			"Actual underwater emerge/throw cycle lost its slower wrench")
	level.queue_free()
	await ticks(2)


func check_settlement_edges() -> void:
	var level := await make_level()
	var ledge := platform(level, Vector2(404, -152), Vector2(2, 16))
	var body := actor(level, Vector2(409.4, -145))
	body.set_physics_process(false)
	body.phase = Rocky.Phase.POP
	body.velocity.y = 120
	await ticks(2)
	check(body._try_settle(1.0 / 60) and absf(body.position.y + 144) < 0.1,
			"Rocky's full-width post-pop sweep missed a two-pixel support outside its center ray")
	body.position = Vector2(450, -144)
	check(not body._has_support(), "Rocky retained support only because its old home still touched terrain")
	ledge.queue_free()
	var semisolid := platform(level, Vector2(460, -152), Vector2(32, 16), true)
	body.position = Vector2(460, -145)
	body.phase = Rocky.Phase.POP
	body.velocity.y = 120
	await ticks(2)
	check(not body._try_settle(1.0 / 60), "Rocky settled into a static semisolid excluded by source obj_solid/physicssolid")
	semisolid.queue_free()
	level.queue_free()
	await ticks(2)


func check_liquid_replacement() -> void:
	for hidden in [false, true]:
		var level := await make_level()
		var area := level.current_sub_area
		var liquid := add_liquid(level, Level.LevelTheme.CASTLE, -160)
		var body := actor(level, Vector2(440, -154))
		body.set_physics_process(false)
		if hidden:
			body._set_art(body.variant.idle2_sprite)
		check(not body._touches_damaging_liquid(), "Rocky sank at the excluded bbox_top-2 boundary")
		body.position.y += 0.1
		check(body._touches_damaging_liquid(), "Rocky missed its lava top-edge entry")
		area.level_theme = Level.LevelTheme.MOUNTAIN
		area.night_mode = true
		check(not body._touches_damaging_liquid() and body._in_water(body.position),
				"Rocky invented a mountain-lava sink or lost its source liquid swimming flag")
		area.level_theme = Level.LevelTheme.FOREST
		area.night_mode = false
		check(not body._touches_damaging_liquid(), "Ordinary forest water sank Rocky")
		area.night_mode = true
		var source_at := body.position - Vector2(0, 16)
		body.swimming = true
		body.velocity.y = -1.2 # Cancel this tick's gravity at the exact sampled entry.
		body._physics_process(1.0 / 60)
		await ticks(1)
		var sinks := live_nodes(area, SinkingEnemy)
		check(not is_instance_valid(body) and sinks.size() == 1 \
				and effects(area, &"spr_splash_lava_purple").size() == 1,
				"Rocky disappeared instead of creating one source poison sink and splash")
		if sinks.size() == 1:
			var sink: SinkingEnemy = sinks[0]
			check(sink.ellipse_mask and not sink.animate and sink._sprite.frame == 2 \
					and sink.mask_size == Vector2(14, 12 if hidden else 16) \
					and absf(sink.position.y - source_at.y) < 0.1,
					"Rocky sink lost its source origin, elliptical pose mask or frozen style frame")
			await ticks(5)
			check(sink._sprite.frame == 2 and not sink._sprite.is_playing(), "Rocky's source lava exception began cycling styles")
		level.reload()
		await ticks(3)
		check(live_nodes(area, SinkingEnemy).is_empty(), "Rocky's sink survived a level retry")
		level.queue_free()
		await ticks(2)


func check_native_defeat(underwater: bool) -> void:
	var level := await make_level()
	var area := level.current_sub_area
	if underwater:
		area.level_theme = Level.LevelTheme.UNDERWATER
	var body := actor(level, Vector2(400, -144))
	body.set_physics_process(false)
	body.direction = -1
	body.kill(1)
	var pending: SwimmingEnemyDefeat
	for entry in area._pending_spawns.values():
		if entry.node is SwimmingEnemyDefeat:
			pending = entry.node
	check(pending != null and pending.position == Vector2(400, -152), "Rocky defeat did not use source y+8 at its native origin")
	var launch: Array[float] = []
	if pending != null:
		pending.ready.connect(func(): launch.append(pending.velocity.y), CONNECT_ONE_SHOT)
	await ticks(10)
	check(launch == [-96.0 if underwater else -240.0] and is_instance_valid(pending) \
			and pending.position.x == 400 and is_zero_approx(pending.rotation) and pending.get_child(0).frame == 2,
			"SMW Rocky defeat must retain frame2 and facing while falling vertically without spin")
	if is_instance_valid(pending):
		check(pending.get_child(0).flip_h, "Rocky defeat lost the source facing direction")
	level.queue_free()
	await ticks(2)


func check_wrench_art_and_mask() -> void:
	var level := await make_level()
	park(level.hud.player, Vector2(400, -96))
	var body := make_wrench(level, Vector2(400.25, -160.25))
	body._height = 0
	check(body._sprite.is_playing() and body._sprite.frame == 0, "SMW wrench should start its 0.2-frame/tick animation at frame0")
	await ticks(8)
	check(body._sprite.frame == 1 and body._sprite.global_position.is_equal_approx(body.global_position.round()) \
			and not is_zero_approx(body.position.x - roundf(body.position.x)),
			"Wrench froze a style frame or rounded physics instead of only the source drawing")
	body.set_physics_process(false)
	var contact: Area2D = body.get_node("PlayerArea")
	contact.collision_layer = 1 << 7
	await ticks(2)
	var frames := SpriteLibrary.get_frames(&"spr_wrench")
	var images: Array[Image] = []
	for frame in frames.get_frame_count(&"default"):
		var image := frames.get_frame_texture(&"default", frame).get_image()
		if image.is_compressed():
			image.decompress()
		images.append(image)
	var transparent := 0
	for y in 10:
		for x in 10:
			var opaque := false
			for image in images:
				opaque = opaque or image.get_pixel(x, y).a > 0
			var query := PhysicsPointQueryParameters2D.new()
			query.position = body.global_position + Vector2(x - 4.5, y - 4.5)
			query.collision_mask = 1 << 7
			query.collide_with_areas = true
			var collided := not body.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
			check(collided == opaque, "Wrench precise mask disagreed with source alpha union at %s,%s" % [x, y])
			transparent += int(not opaque)
	check(transparent > 0, "Precise wrench regression did not exercise transparent source corners")
	# The ellipse's corner is outside Rocky even though its bbox contains it.
	var rocky := actor(level, Vector2(460, -160))
	rocky.set_physics_process(false)
	await ticks(2)
	var corner := PhysicsPointQueryParameters2D.new()
	corner.position = rocky.position + Vector2(6.5, -15.5)
	corner.collision_mask = 2
	check(rocky.get_world_2d().direct_space_state.intersect_point(corner, 1).is_empty(), "Rocky still has a rectangular corner contact")
	corner.position = rocky.position + Vector2(0, -8)
	check(not rocky.get_world_2d().direct_space_state.intersect_point(corner, 1).is_empty(), "Rocky's real central ellipse contact disappeared")
	level.queue_free()
	await ticks(2)


func check_wrench_arcs_and_alarms() -> void:
	var level := await make_level()
	for height in 5:
		var body := make_wrench(level, Vector2(400, -160))
		body.set_physics_process(false)
		body._height = height
		body.velocity = Vector2.ZERO
		for frame in 66:
			body._physics_process(1.0 / 60)
		var rise: float = [0, 5.25, 13.25, 21.25, 29.25][height]
		check(absf(body.position.y + 160 + rise) < 0.001 and body._height == 0 and body.velocity.y == 0,
				"Wrench arc %s snapped away the source's final quarter-pixel overshoot" % height)
		body.queue_free()
	var blinking := make_wrench(level, Vector2(400, -160))
	blinking.set_physics_process(false)
	blinking._height = 0
	blinking.velocity = Vector2.ZERO
	blinking._age = 6.0 - 1.0 / 60
	blinking._physics_process(1.0 / 60)
	check(not blinking._sprite.visible, "Wrench alarm[0] should hide art immediately on tick360")
	for frame in 6:
		blinking._physics_process(1.0 / 60)
	check(not blinking._sprite.visible, "Wrench blink period ended before seven ticks")
	blinking._physics_process(1.0 / 60)
	check(blinking._sprite.visible, "Wrench did not show art again at alarm[0]=367")
	blinking._age = 8.0 - 1.0 / 60
	blinking._physics_process(1.0 / 60)
	check(blinking.is_queued_for_deletion(), "Wrench did not expire on source alarm[1]=480")
	level.queue_free()
	await ticks(2)


func check_wrench_view_clauses() -> void:
	var level := await make_level()
	park(level.hud.player, Vector2(400, -96))
	await ticks(2)
	level.hud.player.set_physics_process(false)
	var view := Utility.get_visible_rect()
	var left := view.position.x - 128
	var right := view.end.x + 128
	var above := view.position.y - 128
	var below := view.end.y + 128
	for case in [[Vector2(left, -160), false], [Vector2(left - 0.1, -160), true],
			[Vector2(right + 16, -160), false], [Vector2(view.get_center().x, above - 16), false],
			[Vector2(right + 0.1, above - 0.1), true], [Vector2(right + 1, above), false],
			[Vector2(view.get_center().x, below), false], [Vector2(view.get_center().x, below + 0.1), true]]:
		var body := make_wrench(level, case[0])
		body.set_physics_process(false)
		body.velocity = Vector2.ZERO
		body._height = 0
		body._physics_process(1.0 / 60)
		check(body.is_queued_for_deletion() == case[1], "Wrench changed source left OR (right AND above) OR below culling at %s" % case[0])
		body.queue_free()
	var crossing := make_wrench(level, Vector2(left, -160))
	crossing.set_physics_process(false)
	crossing.velocity = Vector2(-60, 0)
	crossing._height = 0
	crossing._physics_process(1.0 / 60)
	check(not crossing.is_queued_for_deletion(), "Wrench tested camera culling after movement instead of at source Step start")
	crossing._physics_process(1.0 / 60)
	check(crossing.is_queued_for_deletion(), "Wrench failed to cull on the next Step after crossing left")
	level.queue_free()
	await ticks(2)


func check_wrench_death_and_helmet() -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_powerup(SuperPowerup.new(), false)
	park(player, Vector2(400, -96))
	player.equip_buzzy_helmet()
	var body := make_wrench(level, player.position + Vector2(0, -28))
	body.set_physics_process(false)
	await ticks(4)
	check(not player.has_helmet() and is_instance_valid(body) and player.score == 0,
			"Wrench inherited a nonexistent helmet deflection or enemy stomp response")
	body.kill(1)
	await ticks(2)
	var living_corpses := live_nodes(level.current_sub_area, SwimmingEnemyDefeat)
	check(living_corpses.size() == 1 and living_corpses[0].velocity.x == 60,
			"Living Wrench Other_10 missed its source horizontal impulse")
	for corpse in living_corpses:
		corpse.queue_free()
	body = make_wrench(level, Vector2(400, -160))
	body.set_physics_process(false)
	player.kill()
	body.position = Vector2(400, -160)
	body._start_y = -160
	body._height = 1
	body.velocity = Vector2(60, -30)
	for frame in 20:
		body._physics_process(1.0 / 60)
	check(is_equal_approx(body.position.x, 400) and absf(body.position.y + 161) < 0.001,
			"Wrench should reset speed during Mario death before still executing its source height branch")
	body.kill(1)
	var pending: SwimmingEnemyDefeat
	for entry in level.current_sub_area._pending_spawns.values():
		if entry.node is SwimmingEnemyDefeat:
			pending = entry.node
	check(pending != null and pending.velocity.x == 60,
			"Death-time Wrench defeat did not create its initial impulse before the central stop")
	await ticks(2)
	var corpses := live_nodes(level.current_sub_area, SwimmingEnemyDefeat)
	check(not is_instance_valid(body) and corpses.size() == 1 and corpses[0].velocity == Vector2.ZERO,
			"The source central death pass did not stop the new Wrench corpse")
	level.queue_free()
	await ticks(2)


func check_owned_spawns() -> void:
	var level := await make_level()
	var area := level.current_sub_area
	var body := actor(level, Vector2(400, -160))
	body._throw_wrench()
	body.queue_free()
	await ticks(2)
	check(wrenches(level).size() == 1, "Already-created wrench was cancelled when Rocky was defeated")
	body = actor(level, Vector2(440, -160))
	body._throw_wrench()
	level.reload()
	await ticks(3)
	check(wrenches(level).is_empty() and area._pending_spawns.is_empty(), "Rocky's deferred wrench survived a runtime retry")
	level.queue_free()
	await ticks(2)


func capture_environment() -> void:
	var level := await make_level()
	park(level.hud.player, Vector2(400, -96))
	var area := level.current_sub_area
	var liquid := add_liquid(level, Level.LevelTheme.CASTLE, -128)
	var sinking := actor(level, Vector2(304, liquid.position.y + 6.5))
	sinking.set_physics_process(false)
	sinking._set_art(sinking.variant.idle2_sprite)
	sinking._sink()
	var defeated := actor(level, Vector2(460, -136))
	defeated.kill(1)
	var wrench := make_wrench(level, Vector2(400, -160))
	wrench._height = 0
	await ticks(8)
	check(live_nodes(area, SinkingEnemy).size() == 1 and live_nodes(area, SwimmingEnemyDefeat).size() == 1 \
			and wrench._sprite.is_playing(), "Rocky environment capture missed native sink/defeat/animated wrench")
	liquid.queue_redraw() # Its test-only frozen physics clock cannot redraw after the camera moves.
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_rocky_environment.png")
	check(error == OK, "Could not save Rocky environment capture")
	print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	level.queue_free()
	await ticks(2)
	get_tree().quit(0 if failures.is_empty() else 1)
