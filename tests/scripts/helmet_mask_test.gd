# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/thwomp_test.gd"
## Per-frame Buzzy/up masks and normal Spiny ellipse, compared with real
## source pixels and queried through both geometry and the native Area.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for spiny in [false, true]:
		await check_poses(spiny)
		await check_frozen_pose(spiny)
	await finish("HELMET_MASK_RESULT")


func check_poses(spiny: bool) -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_physics_process(false)
	player.state_machine.set_process(false)
	park(player, Vector2(400, -96))
	player.equip_shell_helmet(preload("res://resources/content/smw_helmet_spiny_rules.tres")) if spiny else player.equip_buzzy_helmet()
	var helmet: PlayerHelmet = player.get_node("BuzzyHelmet")
	helmet.set_physics_process(false)
	helmet._area.collision_layer = 1 << 7
	var probe := Entity.new()
	probe.collision_layer = 0
	probe.collision_mask = 0
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(0.02, 0.02)
	collider.shape = rectangle
	probe.add_child(collider)
	level.current_sub_area.add(probe)
	probe.set_physics_process(false)
	for small in [false, true]:
		player.set_powerup(SmallPowerup.new() if small else SuperPowerup.new(), false)
		for frame in 4:
			player.state_machine.switch(PlayerSpinJumpingState, true)
			player.sprite.play(&"spin_jump")
			player.sprite.pause()
			player.sprite.frame = frame
			helmet._sync_visual(0)
			await ticks(1)
			check(helmet._sprite.frame == frame and helmet.position.y == (-17 if small else -23),
					"Helmet spin frame or small/super contact origin changed")
			check_pixels(helmet, probe, &"spr_helmet_spiny" if spiny else &"spr_helmet", frame, spiny)
		player.state_machine.switch(PlayerIdleState)
		player.sprite.play(&"look_up")
		player.sprite.pause()
		helmet._sync_visual(0)
		await ticks(1)
		check(helmet.position.y == (-16 if small else -20), "Looking-up helmet lost the source vertical origin")
		check(absf(helmet._head_bounds().position.y - helmet.global_position.y - (-10 if spiny else -7)) < 0.001,
				"Looking-up helmet reused the normal sprite's bbox_top")
		check_pixels(helmet, probe, &"spr_helmet_spiny_up" if spiny else &"spr_SMW_helmet_up", 0, false)
		player.sprite.play(&"idle")
		player.sprite.pause()
		player.direction = -1
		helmet._angle = 9
		helmet._sync_visual(0)
		await ticks(1)
		check(helmet._sprite.flip_h and is_equal_approx(helmet._sprite.rotation_degrees, 9),
				"Visual-only mask test failed to establish the source flipped/tilted drawing")
		check_pixels(helmet, probe, &"spr_helmet_spiny" if spiny else &"spr_helmet", 0, spiny)
	level.reload()
	await ticks(3)
	check(not is_instance_valid(helmet) and not level.hud.player.has_helmet(), "Helmet shape nodes/cache survived retry ownership")
	level.queue_free()
	await ticks(2)


func check_frozen_pose(spiny: bool) -> void:
	var level := await make_level()
	var player := level.hud.player
	player.set_physics_process(false)
	player.state_machine.set_process(false)
	player.equip_shell_helmet(preload("res://resources/content/smw_helmet_spiny_rules.tres")) if spiny else player.equip_buzzy_helmet()
	var helmet: PlayerHelmet = player.get_node("BuzzyHelmet")
	player.state_machine.switch(PlayerSpinJumpingState)
	player.sprite.play(&"spin_jump")
	player.sprite.pause()
	player.sprite.frame = 3
	player.direction = -1
	helmet._sync_visual(0)
	var captured_position := helmet.position
	var captured_draw_y := player.sprite.offset.y
	check(player.freeze_in_ice(), "Helmet snapshot test failed to freeze Mario")
	await ticks(4)
	check(helmet._sprite.frame == 3 and helmet.position == captured_position and is_zero_approx(helmet._sprite.rotation),
			"Frozen helmet recomputed the captured spin frame, origin or source angle0")
	check(helmet._sprite.flip_h and helmet._sprite.position.y == 0 and player.sprite.flip_h \
			and player.sprite.offset.y == captured_draw_y - 1,
			"Frozen Draw lost the captured direct or incorrectly retained ordinary Mario's y+1")
	player.state_machine.switch(PlayerIdleState)
	await ticks(2)
	check(helmet._sprite.frame == 0, "Thawed helmet failed to resume its live pose")
	check(helmet._sprite.position.y == 1 and player.sprite.offset.y == captured_draw_y,
			"Thaw failed to restore ordinary Mario/helmet's one-pixel drawing overlap")
	level.queue_free()
	await ticks(2)


func check_pixels(helmet: PlayerHelmet, probe: Entity, art: StringName, frame: int, ellipse: bool) -> void:
	var texture := SpriteLibrary.get_frames(art).get_frame_texture(&"default", frame)
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var origin := SpriteLibrary.get_origin(art)
	var transparent := 0
	var blocked_corner := false
	for y in image.get_height():
		for x in image.get_width():
			var local := Vector2(x + 0.5, y + 0.5) - origin
			# spr_helmet_spiny: bbox (3,1)..(22,20), origin (13,12).
			var expected := ((local - Vector2(0, -1)) / 10).length_squared() < 1.0 \
					if ellipse else image.get_pixel(x, y).a > 0
			var query := PhysicsPointQueryParameters2D.new()
			query.position = helmet.global_position + local
			query.collision_mask = 1 << 7
			query.collide_with_areas = true
			query.collide_with_bodies = false
			var actual := not helmet.get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
			check(actual == expected, "Helmet Area disagrees with source %s frame%s pixel %s,%s alpha=%s actual=%s" % [art, frame, x, y, image.get_pixel(x, y).a, actual])
			probe.global_position = query.position
			check(helmet._contacts(probe) == expected, "Direct helmet contact used a bbox/stale frame at %s:%s,%s" % [art, x, y])
			if not expected:
				transparent += 1
				if not blocked_corner and helmet._head_bounds().has_point(query.position):
					probe.velocity = Vector2(0, 120)
					check(not helmet.deflect(probe), "Transparent helmet pixels incorrectly caused a head deflection")
					blocked_corner = true
	check(transparent > 0 and blocked_corner, "Helmet mask regression did not exercise transparent pixels inside its bbox")
