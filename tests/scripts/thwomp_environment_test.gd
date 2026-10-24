# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/thwomp_test.gd"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--capture-thwomp-environment" in OS.get_cmdline_user_args():
		await capture_environment()
		return
	for variant in [SMALL, GIANT]:
		for direction in [1, 2, 3]:
			await check_source_pixels(variant, direction)
			await check_return_stop(variant, direction)
		await check_snap_boundary(variant)
		await check_splash_clock(variant)
		await check_defeat_motion(variant)
	await check_liquid_masks()
	await finish("THWOMP_ENVIRONMENT_RESULT")


func box(level: Level, at: Vector2, size: Vector2, one_way := false, moving := false) -> PhysicsBody2D:
	var body: PhysicsBody2D = AnimatableBody2D.new() if moving else StaticBody2D.new()
	if body is AnimatableBody2D:
		body.sync_to_physics = false
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


func effects(area: SubArea, art: StringName) -> Array[AnimatedSprite2D]:
	var found: Array[AnimatedSprite2D] = []
	for node in area.get_foreground().get_children():
		if node is AnimatedSprite2D and node.sprite_frames.get_frame_texture(node.animation, 0).resource_path.contains("/" + String(art) + "/"):
			found.append(node)
	return found


func add_liquid(level: Level, y: float, theme := Level.LevelTheme.CASTLE, night := false) -> LiquidSurface:
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


func check_source_pixels(variant: ThwompVariant, direction: int) -> void:
	var level := await make_level()
	var body := actor(level, variant, direction, Vector2(400, -224))
	body.set_physics_process(false)
	body.hitbox.collision_layer = 1 << 7
	await ticks(2)
	# obj_thwomp has a fixed mask sprite. obj_thwomp_b has no override.
	var art: StringName = &"spr_thwomp" if not variant.giant else &"spr_thwomp_b" if direction == 1 else &"spr_thwomp_h_b"
	var frames := SpriteLibrary.get_frames(art)
	var images: Array[Image] = []
	for frame in frames.get_frame_count(&"default"):
		var source := frames.get_frame_texture(&"default", frame).get_image()
		if source.is_compressed():
			source.decompress()
		images.append(source)
	var transparent := 0
	for y in images[0].get_height():
		for x in images[0].get_width():
			var expected := false
			for source in images:
				expected = expected or source.get_pixel(x, y).a > 0
			for area_query in [false, true]:
				var query := PhysicsPointQueryParameters2D.new()
				query.position = body.global_position + Vector2(x + 0.5, y + 0.5) \
						- SpriteLibrary.get_origin(art) - Vector2(0, 64 if variant.giant else 16)
				query.collision_mask = 1 << 7 if area_query else 2
				query.collide_with_areas = area_query
				query.collide_with_bodies = not area_query
				var actual := not body.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
				check(actual == expected, "Thwomp %s dir%s mask Area=%s disagrees with source pixel %s,%s" % [variant.id, direction, area_query, x, y])
			transparent += int(not expected)
	check(transparent > 0, "Thwomp mask regression did not inspect transparent source corners")
	level.queue_free()
	await ticks(2)


func check_return_stop(variant: ThwompVariant, direction: int) -> void:
	var level := await make_level()
	var body := actor(level, variant, direction, Vector2(400, -224))
	body.set_physics_process(false)
	var axis := Vector2.DOWN if direction == 1 else Vector2.LEFT if direction == 2 else Vector2.RIGHT
	body.position += axis * 40
	var bounds := Utility.get_bounding_box(body)
	var obstacle_at := Vector2(bounds.get_center().x, bounds.position.y - 3) if direction == 1 \
			else Vector2(bounds.end.x + 1.25 if direction == 2 else bounds.position.x - 1.25, bounds.get_center().y)
	var size := Vector2(bounds.size.x + 8, 4) if direction == 1 else Vector2(2, bounds.size.y + 8)
	box(level, obstacle_at, size)
	await ticks(2)
	body.phase = Thwomp.Phase.RETURNING
	body.velocity = -axis * 60
	var before := body.position
	body._physics_process(1.0 / 60)
	check(body.phase == Thwomp.Phase.WAITING and body.position.is_equal_approx(before),
			"Thwomp return should stop at its source leading probe before advancing into obstruction")
	check(body._home == before, "Thwomp did not retain its blocked return origin")
	if direction != 1:
		var home_y := body._home.y
		body.position.y -= 8
		body.phase = Thwomp.Phase.RETURNING
		body.velocity = -axis * 60 + Vector2(0, -120)
		body._physics_process(1.0 / 60)
		check(body._home.y == home_y and body.velocity.y < 0,
				"Horizontal return obstruction erased an independent helmet bounce or changed ystart")
	else:
		var home_x := body._home.x
		body.position.x += 8
		body.phase = Thwomp.Phase.RETURNING
		body.velocity.y = -60
		body._physics_process(1.0 / 60)
		check(body._home.x == home_x, "Vertical return obstruction changed the source xstart")
	level.queue_free()
	await ticks(2)
	# An ordinary semisolid underside is outside obj_solid/physicssolid.
	if direction == 1:
		level = await make_level()
		body = actor(level, variant, direction, Vector2(400, -224))
		body.set_physics_process(false)
		body.position.y += 40
		bounds = Utility.get_bounding_box(body)
		var semisolid := box(level, Vector2(400, bounds.position.y - 3), Vector2(bounds.size.x + 8, 4), true)
		await ticks(2)
		body.phase = Thwomp.Phase.RETURNING
		body.velocity.y = -60
		before = body.position
		body._physics_process(1.0 / 60)
		check(body.phase == Thwomp.Phase.RETURNING and body.position.y < before.y,
				"Thwomp return incorrectly stopped under a static semisolid")
		semisolid.queue_free()
		body.position = before
		box(level, Vector2(400, bounds.position.y - 3), Vector2(bounds.size.x + 8, 4), true, true)
		await ticks(2)
		body.phase = Thwomp.Phase.RETURNING
		body.velocity.y = -60
		body._physics_process(1.0 / 60)
		check(body.phase == Thwomp.Phase.WAITING, "Source physicssolid should obstruct return even with a one-way native collider")
		level.queue_free()
		await ticks(2)


func check_snap_boundary(variant: ThwompVariant) -> void:
	var level := await make_level()
	var body := actor(level, variant, 1, Vector2(400, -224))
	body.set_physics_process(false)
	body.position.y += 1
	body.phase = Thwomp.Phase.RETURNING
	body.velocity.y = -60
	body._physics_process(1.0 / 60)
	check(body.phase == Thwomp.Phase.RETURNING and absf(body.position.y + 224) < 0.001,
			"Thwomp used <=1 instead of the source strict home+1 return boundary")
	park(level.hud.player, Vector2(400, -96))
	level.hud.player.set_physics_process(false)
	body._physics_process(1.0 / 60)
	check(body.phase == Thwomp.Phase.WAITING, "Returning Thwomp retriggered an attack in the same source Step")
	body._physics_process(1.0 / 60)
	check(body.phase == Thwomp.Phase.ATTACKING, "Thwomp failed to accept the next Step's player trigger")
	level.queue_free()
	await ticks(2)


func check_splash_clock(variant: ThwompVariant) -> void:
	var level := await make_level()
	park(level.hud.player, Vector2(400, -96))
	await ticks(2)
	var area := level.current_sub_area
	var liquid := add_liquid(level, -192)
	var body := actor(level, variant, 1, Vector2(400, -176))
	body.set_physics_process(false)
	body._tick_splashes(1.0 / 60)
	for frame in 3:
		body._tick_splashes(1.0 / 60)
	await ticks(1)
	check(effects(area, &"spr_SMB3_megasplash_lava").is_empty(), "Static liquid incorrectly emitted Thwomp's periodic splash")
	liquid.velocity = 30
	body._tick_splashes(1.0 / 60)
	await ticks(1)
	var splashes := effects(area, &"spr_SMB3_megasplash_lava")
	check(splashes.size() == 2, "Moving liquid should create a pair after the source one-tick retry")
	if splashes.size() == 2:
		check(splashes[0].position == Vector2(384, -208) and splashes[1].position == Vector2(416, -208),
				"Thwomp splash positions changed x±16/liquid-16 for one of its sizes")
	for frame in 11:
		body._tick_splashes(1.0 / 60)
	await ticks(1)
	check(effects(area, &"spr_SMB3_megasplash_lava").size() == 2, "Thwomp repeated its liquid splash before 12 ticks")
	body._tick_splashes(1.0 / 60)
	await ticks(1)
	check(effects(area, &"spr_SMB3_megasplash_lava").size() == 4, "Thwomp did not repeat its source liquid alarm at tick12")
	# Both exits are strict in the source lava object's 384x16 pixel mask.
	var surface := liquid.source_contact_bounds()
	var bounds := Utility.get_bounding_box(body)
	body.position.x += surface.end.x - bounds.position.x
	body._tick_splashes(1.0 / 60)
	check(not body._splash_contact, "Thwomp splash probe included a liquid x boundary outside its source mask")
	body.position.x -= 0.25
	body._tick_splashes(1.0 / 60)
	check(body._splash_contact, "Thwomp splash probe excluded a real sliver of source liquid overlap")
	body.position.x = 400
	bounds = Utility.get_bounding_box(body)
	body.position.y += liquid.position.y + 1 - bounds.end.y
	body._tick_splashes(1.0 / 60)
	check(not body._splash_contact, "Splash probe included an excluded lower-edge contact")
	body.position.y += 0.25
	body._tick_splashes(1.0 / 60)
	check(body._splash_contact, "Splash probe missed an interior lower-edge overlap")
	bounds = Utility.get_bounding_box(body)
	body.position.y += liquid.position.y + 14 - bounds.position.y
	body._tick_splashes(1.0 / 60)
	check(not body._splash_contact, "Splash probe included the source liquid mask's excluded bottom edge")
	body.position.y -= 0.25
	body._tick_splashes(1.0 / 60)
	check(body._splash_contact, "Splash probe missed an interior upper-edge overlap")
	level.reload()
	await ticks(3)
	check(effects(area, &"spr_SMB3_megasplash_lava").is_empty(), "Thwomp splash effects survived a retry")
	level.queue_free()
	await ticks(2)


func check_liquid_masks() -> void:
	# SMW forest/beach use 32px surfaces; lava/poison use 16px. Create scales x24.
	for entry in [
		[Level.LevelTheme.FOREST, false, 768],
		[Level.LevelTheme.BEACH, false, 768],
		[Level.LevelTheme.FOREST, true, 384],
		[Level.LevelTheme.CASTLE, false, 384],
		[Level.LevelTheme.MOUNTAIN, true, 384],
	]:
		var level := await make_level()
		var liquid := add_liquid(level, -192, entry[0], entry[1])
		var surface := liquid.source_contact_bounds()
		check(surface == Rect2(Vector2(Utility.get_visible_rect().position.x, -192), Vector2(entry[2], 16)),
				"Liquid contact mask lost its theme-specific source sprite width or camera origin")
		var body := actor(level, SMALL, 1, Vector2(surface.position.x + 550, -176))
		body.set_physics_process(false)
		body._tick_splashes(1.0 / 60)
		check(body._splash_contact == (entry[2] == 768),
				"Thwomp used the lava width for forest/beach water beyond x384")
		var bounds := Utility.get_bounding_box(body)
		body.position.x += surface.end.x - bounds.position.x
		body._tick_splashes(1.0 / 60)
		check(not body._splash_contact, "The theme's exact liquid right boundary counted as interior")
		body.position.x -= 0.25
		body._tick_splashes(1.0 / 60)
		check(body._splash_contact, "Thwomp missed a sliver inside the theme's liquid right boundary")
		level.queue_free()
		await ticks(2)


func check_defeat_motion(variant: ThwompVariant) -> void:
	var level := await make_level()
	var body := actor(level, variant, 3, Vector2(400, -176))
	body.set_physics_process(false)
	body.phase = Thwomp.Phase.ATTACKING
	body._update_visuals()
	var source_at := variant.source_position(body.position)
	body.kill(1)
	var dead: SwimmingEnemyDefeat
	for pending in level.current_sub_area._pending_spawns.values():
		if pending.node is SwimmingEnemyDefeat:
			dead = pending.node
	check(dead != null and dead.position == source_at, "Thwomp corpse was spawned at feet instead of its source origin")
	await ticks(8)
	check(is_instance_valid(dead) and dead.position.x == 400 and is_zero_approx(dead.rotation) \
			and dead.get_child(0).frame == 2 and dead.get_child(0).flip_h,
			"Thwomp dead_h=1 should retain pose/facing and move vertically without a horizontal spin")
	check(effects(level.current_sub_area, &"spr_spinthump").size() == 1, "Thwomp defeat omitted the source dead_h smoke")
	level.queue_free()
	await ticks(2)


func capture_environment() -> void:
	var level := await make_level()
	park(level.hud.player, Vector2(400, -96))
	level.hud.player.equip_buzzy_helmet()
	level.hud.player.invulnerability_left = 999
	await ticks(3)
	var liquid := add_liquid(level, -160)
	liquid.velocity = 30
	var giant := actor(level, GIANT, 1, Vector2(304, -112))
	giant.set_physics_process(false)
	giant._tick_splashes(1.0 / 60)
	giant._tick_splashes(1.0 / 60)
	var small := actor(level, SMALL, 3, Vector2(464, -144))
	small.set_physics_process(false)
	await ticks(3)
	liquid.queue_redraw()
	check(effects(level.current_sub_area, &"spr_SMB3_megasplash_lava").size() == 2, "Thwomp render missed its actual paired splash")
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_thwomp_environment.png")
	check(error == OK, "Could not save Thwomp environment capture")
	print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	level.queue_free()
	await ticks(2)
	get_tree().quit(0 if failures.is_empty() else 1)
