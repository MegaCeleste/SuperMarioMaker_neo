extends "res://tests/scripts/port_test.gd"
## Growth keeps Mario's feet fixed; animation cadence follows source distance.

var _capture := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture = "--capture-player-motion" in OS.get_cmdline_user_args() or "--capture-player-growth" in OS.get_cmdline_user_args()
	var level: Level = await LevelProcessor.from_swe("res://tests/fixtures/port_slice.swe")
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await ticks(8)
	for node in level.current_sub_area.get_foreground().get_children():
		if node is Enemy or node is GoalGate or node is Coin or node is QuestionBlock or node is TurnBlockTile:
			node.queue_free()
	await ticks(2)
	var player := level.hud.player
	if "--capture-player-growth" in OS.get_cmdline_user_args():
		for direction in [-1, 1]:
			await capture_motion_sequence(level, player, direction)
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
		await finish("PLAYER_VISUAL_RESULT", level)
		return
	await check_transition_frames(player)
	await check_transition_replacement(player)
	for direction in [-1, 1]:
		await check_growth(level, player, direction)
	await check_airborne_growth(level, player)
	await check_low_ceiling_growth(level, player)
	await check_one_way_growth(level, player)
	for big in [false, true]:
		player.set_powerup(SuperPowerup.new() if big else SmallPowerup.new(), false)
		check_origins(player, big)
		await check_floor_overlap(player, big)
		await check_cadence(player)
	await check_super_mushroom(level, player)
	if _capture:
		for direction in [-1, 1]:
			await capture_motion_sequence(level, player, direction)
	await check_transition_cleanup()
	if _capture:
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("PLAYER_VISUAL_RESULT", level)


func park(player: Player) -> void:
	release_input()
	player.position = Vector2(480, -16)
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)


## Check rendered poses too: stable body coordinates alone miss visual jumps.
func check_transition_frames(player: Player) -> void:
	for direction in [-1, 1]:
		for animation in [&"walk", &"run", &"spin_jump", &"hold_walk"]:
			for grow in [true, false]:
				park(player)
				player.set_powerup(SmallPowerup.new() if grow else SuperPowerup.new(), false)
				await ticks(3)
				player.sprite.play(animation)
				player.sprite.set_frame_and_progress(1, 0.35)
				player.sprite.flip_h = direction < 0
				var pose := player.sprite.sprite_frames.get_frame_texture(animation, 1)
				var offset := player.sprite.offset
				var transform := player.sprite.transform
				player.set_powerup(SuperPowerup.new() if grow else SmallPowerup.new(), true)
				var snapshot: Node2D
				for node in player.get_node("Graphics").get_children():
					if node != player.sprite and node.name != &"GrowthPose" and (node is Sprite2D or node is AnimatedSprite2D):
						snapshot = node
				check(snapshot != null, "Transformation did not retain the outgoing pose")
				if snapshot == null:
					return
				var pose_matches := true
				var exclusive := true
				var camera := Utility.camera_position
				var anchor := player.get_global_transform_with_canvas().origin
				var stable_anchor := true
				var growth_heights: Dictionary = {}
				var only_big_growth := true
				var big_texture := SpriteLibrary.get_frames("spr_mario_big_idle").get_frame_texture(&"default", 0)
				while get_tree().paused:
					if is_instance_valid(snapshot):
						var texture: Texture2D = snapshot.texture if snapshot is Sprite2D else snapshot.sprite_frames.get_frame_texture(snapshot.animation, snapshot.frame)
						pose_matches = pose_matches and texture == pose and snapshot.offset == offset \
								and snapshot.transform == transform and snapshot.flip_h == (direction < 0)
						var visible_count := 0
						for visual in player.get_node("Graphics").get_children():
							if (visual is Sprite2D or visual is AnimatedSprite2D) and visual.is_visible_in_tree():
								visible_count += 1
								if grow:
									only_big_growth = only_big_growth and visual is Sprite2D \
											and visual.name == &"GrowthPose" and visual.texture == big_texture \
											and is_equal_approx(visual.scale.x, player.sprite.scale.x)
								if visual.name == &"GrowthPose":
									growth_heights[roundi(visual.texture.get_image().get_used_rect().size.y * absf(visual.scale.y))] = true
									check(not visual.texture.resource_path.is_empty(), "Growth replaced source pixels with a generated intermediate image")
						exclusive = exclusive and visible_count == 1
					stable_anchor = stable_anchor and Utility.camera_position.is_equal_approx(camera) \
							and player.get_global_transform_with_canvas().origin.is_equal_approx(anchor)
					await get_tree().process_frame
				var description := "%s dir=%d grow=%s" % [animation, direction, grow]
				check(pose_matches, "Transformation changed the outgoing pose/frame/origin: " + description)
				check(exclusive, "Transformation drew both Mario poses or neither in one frame: " + description)
				check(stable_anchor, "Transformation shifted Mario's screen anchor or camera: " + description)
				if grow:
					check(only_big_growth and growth_heights.size() == 4 and growth_heights.has(24) \
							and growth_heights.has(20) and growth_heights.has(26) and growth_heights.has(28),
							"Growth did not use only the original big texture with vertical size changes: " + description)
				await ticks(1)
				check(player.get_node("Graphics").get_child_count() == 1 and player.sprite.visible,
						"Transformation left an outgoing Mario image behind: " + description)


func check_growth(level: Level, player: Player, direction: int) -> void:
	park(player)
	player.set_powerup(SmallPowerup.new(), false)
	await ticks(3)
	Input.action_press("player_right" if direction > 0 else "player_left")
	await ticks(15)
	var mushroom: Mushroom = load("res://scenes/level/entities/mushroom.tscn").instantiate()
	mushroom.position = player.position + Vector2(direction * 12, -8)
	level.current_sub_area.add(mushroom)
	var before := player.position
	for frame in 10:
		await ticks(1)
		if player.get_powerup() is SuperPowerup:
			break
		before = player.position
	check(player.get_powerup() is SuperPowerup, "Physical mushroom overlap did not trigger growth")
	var frozen := player.position
	print("GROWTH_TRACE dir=", direction, " before=", before, " frozen=", frozen,
		" offset=", player.sprite.offset, " anim=", player.sprite.animation)
	check(absf(frozen.x - before.x) <= 1.4 and absf(frozen.y - before.y) <= 0.1,
			"Growth teleported Mario instead of preserving his feet")
	while get_tree().paused:
		await ticks(1)
		if get_tree().paused:
			check(player.position.is_equal_approx(frozen), "Mario moved during the transformation pause")
	# A 30fps render can contain two 60Hz movement ticks on the resume frame.
	var resume_ticks := maxf(1, ceilf(get_process_delta_time() * Engine.physics_ticks_per_second))
	var resume_distance := player.max_walk_speed * resume_ticks / Engine.physics_ticks_per_second + 0.1
	check(absf(player.position.x - frozen.x) <= resume_distance and absf(player.position.y - frozen.y) < 0.1,
			"Mario jumped when the transformation ended")
	release_input()
	await ticks(2)


func check_transition_replacement(player: Player) -> void:
	for animate in [false, true]:
		park(player)
		player.set_powerup(SmallPowerup.new(), false)
		await ticks(3)
		player.set_powerup(SuperPowerup.new(), true)
		await ticks(3)
		player.set_powerup(SmallPowerup.new(), animate)
		check(get_tree().paused == animate, "Replacing a transformation inherited its old pause")
		var exclusive := true
		for frame in 80:
			await get_tree().process_frame
			var visible_count := 0
			for node in player.get_node("Graphics").get_children():
				if node is Sprite2D or node is AnimatedSprite2D:
					visible_count += int(node.is_visible_in_tree())
			exclusive = exclusive and visible_count == 1
		check(exclusive and not get_tree().paused and player.sprite.visible,
				"Interrupted transformation left a ghost, hidden player or stuck pause")
		check(player.get_node("Graphics").get_child_count() == 1,
				"Interrupted transformation retained an old snapshot")
	# A transformation must also preserve a pause owned by something else.
	get_tree().paused = true
	player.set_powerup(SuperPowerup.new(), true)
	for frame in 80:
		await get_tree().process_frame
	check(get_tree().paused and player.sprite.get_child_count() == 0,
			"Transformation resumed an externally paused game or did not finish")
	get_tree().paused = false


func check_airborne_growth(level: Level, player: Player) -> void:
	park(player)
	player.set_powerup(SmallPowerup.new(), false)
	player.position.y = -160
	player.state_machine.switch(PlayerFallingState)
	player.velocity.y = -120
	var mushroom: Mushroom = load("res://scenes/level/entities/mushroom.tscn").instantiate()
	mushroom.position = player.position
	level.current_sub_area.add(mushroom)
	await ticks(3)
	check(player.get_powerup() is SuperPowerup, "Airborne mushroom overlap did not grow Mario")
	var frozen := player.position
	while get_tree().paused:
		await ticks(1)
		if get_tree().paused:
			check(player.position.is_equal_approx(frozen), "Airborne growth moved Mario during the pause")
	check(player.velocity.y < 0 and absf(player.position.x - frozen.x) < 0.1,
			"Airborne growth lost Mario's upward momentum or shifted him sideways")


func check_low_ceiling_growth(level: Level, player: Player) -> void:
	park(player)
	player.set_powerup(SmallPowerup.new(), false)
	var tiles: Array[Node] = []
	var ceiling_parts: Array[GroundPart] = []
	for x in [464, 480, 496]:
		var part := GroundPart.create()
		part.position = Vector2(x, -48)
		level.current_sub_area.add_part(part)
		part.load()
		ceiling_parts.append(part)
	GroundPart.refresh_all(level.current_sub_area.get_parts())
	for part in ceiling_parts:
		part.build()
	# Keep the new ceiling bodies so removing it tests standing up again.
	for node in level.current_sub_area.get_foreground().get_children():
		if node is StaticBody2D and node.position.y == -48:
			tiles.append(node)
	await ticks(4)
	var before := player.position
	await capture("growth_before", player)
	var mushroom: Mushroom = load("res://scenes/level/entities/mushroom.tscn").instantiate()
	mushroom.position = player.position
	level.current_sub_area.add(mushroom)
	var saw_crouched_growth := false
	for frame in 90:
		await get_tree().process_frame
		if get_tree().paused:
			saw_crouched_growth = true
			var big_duck := SpriteLibrary.get_frames("spr_mario_big_duck").get_frame_texture(&"default", 0)
			for visual in player.get_node("Graphics").get_children():
				if (visual is Sprite2D or visual is AnimatedSprite2D) and visual.is_visible_in_tree():
					check(visual is Sprite2D and visual.texture == big_duck
							and visual.scale.y <= player.sprite.scale.y,
							"Blocked growth flashed small art or stretched big art into the ceiling")
		elif saw_crouched_growth:
			break
	check(saw_crouched_growth, "Low-ceiling mushroom never showed the big crouched growth pose")
	await ticks(45)
	print("GROWTH_CEILING_TRACE before=", before, " after=", player.position)
	check(player.get_powerup() is SuperPowerup and player.position.distance_to(before) < 0.15,
			"Growing under a low ceiling pushed Mario out of his position")
	check(player.get_node("CollShape").shape.size.y == 15,
			"Growth expanded Mario's collider into a low ceiling")
	check(player.sprite.animation == &"duck", "Blocked growth did not use the original crouching pose")
	await capture("growth_after", player)
	Input.action_press("player_right")
	for frame in 48:
		await ticks(1)
		check(absf(player.position.y - before.y) < 0.15,
				"Leaving a low ceiling moved Mario's feet vertically")
	release_input()
	check(not player.growth_crouched and player.get_node("CollShape").shape.size.y == 27,
			"Mario did not stand up after walking out from under the ceiling")
	for tile in tiles:
		tile.queue_free()
	await ticks(5)
	check(player.get_node("CollShape").shape.size.y == 27 and absf(player.position.y - before.y) < 0.15,
			"Super Mario did not stand up in place after the ceiling was removed")


func check_origins(player: Player, big: bool) -> void:
	for animation in player.sprite.sprite_frames.get_animation_names():
		player.sprite.play(animation)
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
				"res://resources/content/smw_player_sprites.json"))
		var expected := -SpriteLibrary.get_origin(catalog["super" if big else "small"][String(animation)][0]) - Vector2(0, 31)
		check(player.sprite.offset == expected,
				"Animation origin lagged behind the texture change: %s/%s" % [big, animation])


func check_floor_overlap(player: Player, big: bool) -> void:
	park(player)
	await ticks(5)
	var ray := PhysicsRayQueryParameters2D.create(
			player.global_position - Vector2(0, 2), player.global_position + Vector2(0, 2), 1)
	var floor_hit := player.get_world_2d().direct_space_state.intersect_ray(ray)
	check(player.is_on_floor() and not floor_hit.is_empty(), "Floor alignment needs a real grounded player")
	if floor_hit.is_empty():
		return
	var collider: CollisionShape2D = player.get_node("CollShape")
	var feet: Vector2 = collider.global_position + Vector2(0, collider.shape.size.y / 2)
	var floor_y: float = floor_hit.position.y
	check(absf(feet.y - floor_y) < 0.1, "Sprite alignment moved Mario's physical feet off the floor")
	for direction in [-1, 1]:
		player.sprite.flip_h = direction < 0
		player.sprite.play(&"idle")
		player.sprite.set_frame_and_progress(0, 0)
		var texture := player.sprite.sprite_frames.get_frame_texture(&"idle", 0)
		var pixels := texture.get_image().get_used_rect()
		var shoe_bottom := player.sprite.to_global(player.sprite.offset + Vector2(0, pixels.end.y))
		# The lowest opaque shoe row must cover the first floor row. This
		# checks actual frame pixels against a physics ray, not just origins.
		check(absf(shoe_bottom.y - floor_y - 1) < 0.1,
				"Mario's visible shoes must overlap the floor by 1px: big=%s dir=%s bottom=%s floor=%s"
				% [big, direction, shoe_bottom.y, floor_y])
	await capture("super_idle" if big else "small_idle", player)


func check_one_way_growth(level: Level, player: Player) -> void:
	park(player)
	player.set_powerup(SmallPowerup.new(), false)
	var platform := StaticBody2D.new()
	platform.position = Vector2(480, -34)
	var collider := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 2)
	collider.shape = rect
	collider.one_way_collision = true
	platform.add_child(collider)
	level.current_sub_area.add(platform)
	await ticks(3)
	var before := player.position
	var mushroom: Mushroom = load("res://scenes/level/entities/mushroom.tscn").instantiate()
	mushroom.position = player.position
	level.current_sub_area.add(mushroom)
	await ticks(45)
	check(player.get_powerup() is SuperPowerup and not player.growth_crouched
			and player.position.distance_to(before) < 0.15,
			"The underside of a one-way platform blocked or displaced mushroom growth")
	platform.queue_free()
	await ticks(3)


func check_cadence(player: Player) -> void:
	park(player)
	await ticks(4)
	Input.action_press("player_right")
	await ticks(24)
	var fps := player.sprite.sprite_frames.get_animation_speed(player.sprite.animation) * player.sprite.speed_scale
	print("ANIMATION_TRACE walk vx=", player.velocity.x, " fps=", fps)
	check(absf(fps - 15.6) < 0.05, "Walking cadence differs from abs(hspeed / 5) at walk speed")
	await capture("player_motion" if player.get_powerup() is SuperPowerup else "small_walk", player)
	var advances := [0]
	var count_frames := func(): advances[0] += 1
	player.sprite.frame_changed.connect(count_frames)
	await ticks(60)
	player.sprite.frame_changed.disconnect(count_frames)
	check(advances[0] >= 15 and advances[0] <= 17,
			"Actual walking texture changes do not match the 15.6 fps cadence")
	Input.action_release("player_right")
	await ticks(1)
	fps = player.sprite.sprite_frames.get_animation_speed(player.sprite.animation) * player.sprite.speed_scale
	check(absf(fps - minf(absf(player.velocity.x) / 5, 18)) < 0.05,
			"Entering the coasting state reset the animation cadence for one tick")
	await ticks(1)
	fps = player.sprite.sprite_frames.get_animation_speed(player.sprite.animation) * player.sprite.speed_scale
	print("ANIMATION_TRACE release vx=", player.velocity.x, " fps=", fps)
	check(absf(fps - minf(absf(player.velocity.x) / 5, 18)) < 0.05,
			"Releasing movement accelerated the walking animation")
	Input.action_press("player_right")
	Input.action_press("player_run")
	await ticks(65)
	fps = player.sprite.sprite_frames.get_animation_speed(player.sprite.animation) * player.sprite.speed_scale
	check(absf(fps - 18) < 0.05, "Running animation does not respect the source's 18 fps cap")
	release_input()
	await ticks(70)
	check(player.sprite.animation == &"idle", "Stopped Mario did not return to idle")


func check_super_mushroom(level: Level, player: Player) -> void:
	park(player)
	player.set_powerup(SuperPowerup.new(), false)
	await ticks(3)
	var score := player.score
	var mushroom: Mushroom = load("res://scenes/level/entities/mushroom.tscn").instantiate()
	mushroom.position = player.position
	level.current_sub_area.add(mushroom)
	await ticks(3)
	check(player.score == score + 1000 and not get_tree().paused and player.get_powerup() is SuperPowerup,
			"An extra mushroom restarted growth for an already-super Mario")


func capture(stage: String, player: Player) -> void:
	if not _capture:
		return
	var camera := Utility.camera_position
	camera.x = maxf(0, player.global_position.x - get_viewport().get_visible_rect().size.x / Utility.camera_scale.x / 2)
	Utility.camera_position = camera
	await RenderingServer.frame_post_draw
	var texture := player.sprite.sprite_frames.get_frame_texture(player.sprite.animation, player.sprite.frame)
	print("CAPTURE_SPRITE ", stage, " feet=", player.position, " offset=", player.sprite.offset,
			" frame=", player.sprite.frame, " pixels=", texture.get_image().get_used_rect())
	var path := "res://.godot/porting-tests/slice_%s.png" % stage
	check(get_viewport().get_texture().get_image().save_png(path) == OK, "Could not capture " + stage)


## Record real consecutive frames with normal camera following, without
## recentering it per screenshot (which could hide a screen-space jump).
func capture_motion_sequence(level: Level, player: Player, direction: int) -> void:
	park(player)
	player.set_powerup(SmallPowerup.new(), false)
	player.direction = direction
	player.sprite.flip_h = direction < 0
	Utility.camera_position = Vector2(288, -216)
	await ticks(8)
	var sheet := Image.create(1200, 1120, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("302e42"))
	var trace: Array = []
	var exclusive := true
	var grew := false
	var anchor := Vector2.ZERO
	var stable_anchor := true
	var only_big_growth := true
	var big_texture := SpriteLibrary.get_frames("spr_mario_big_idle").get_frame_texture(&"default", 0)
	var was_paused := false
	var directory := "res://.godot/porting-tests/player_growth_%s_%d" % ["left" if direction < 0 else "right", roundi(1.0 / get_process_delta_time())]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	Input.action_press("player_right" if direction > 0 else "player_left")
	for frame in 120:
		if frame == 22:
			var mushroom: Mushroom = load("res://scenes/level/entities/mushroom.tscn").instantiate()
			mushroom.position = player.position + Vector2(direction * 12, -8)
			level.current_sub_area.add(mushroom)
		if frame == 80:
			Input.action_press("player_run")
		await RenderingServer.frame_post_draw
		var screen := player.sub_area.presentation.canvas_transform_for(player).origin
		var paused := get_tree().paused
		if paused:
			if not was_paused:
				anchor = screen
			stable_anchor = stable_anchor and screen.is_equal_approx(anchor)
		was_paused = paused
		grew = grew or player.get_powerup() is SuperPowerup
		var drawings: Array = []
		for node in player.get_node("Graphics").get_children():
			if (node is Sprite2D or node is AnimatedSprite2D) and node.is_visible_in_tree():
				var texture: Texture2D = node.texture if node is Sprite2D else node.sprite_frames.get_frame_texture(node.animation, node.frame)
				if paused:
					only_big_growth = only_big_growth and texture == big_texture
				drawings.append({"texture": texture.resource_path, "offset": str(node.offset), "source_height": texture.get_image().get_used_rect().size.y,
						"height": roundi(texture.get_image().get_used_rect().size.y * absf(node.scale.y))})
		exclusive = exclusive and drawings.size() == 1
		trace.append({"frame": frame, "paused": paused, "feet": str(player.position),
				"screen": str(screen), "camera": str(Utility.camera_position), "drawings": drawings})
		var region := Rect2i(Vector2i(screen.round()) - Vector2i(50, 90), Vector2i(100, 100))
		var pixels := get_viewport().get_texture().get_image().get_region(region)
		check(pixels.save_png(directory + "/frame_%03d.png" % frame) == OK, "Could not save growth animation frame")
		sheet.blit_rect(pixels, Rect2i(0, 0, 100, 100), Vector2i((frame % 12) * 100, (frame / 12) * 112))
	release_input()
	var stem := "res://.godot/porting-tests/slice_player_motion_" + ("left" if direction < 0 else "right")
	check(sheet.save_png(stem + ".png") == OK, "Could not capture continuous Mario motion")
	var log := FileAccess.open(stem + ".json", FileAccess.WRITE)
	log.store_string(JSON.stringify(trace, "  "))
	log.close()
	check(grew and exclusive and stable_anchor and only_big_growth,
			"Rendered growth used small art, retained a ghost or shifted its anchor")
	print("CAPTURE_MOTION dir=", direction, " frames=120 single_drawing=", exclusive,
			" stable_growth_anchor=", stable_anchor, " only_big_texture=", only_big_growth)


func check_transition_cleanup() -> void:
	var level: Level = await LevelProcessor.from_swe("res://tests/fixtures/port_slice.swe")
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await ticks(8)
	level.hud.player.set_powerup(SuperPowerup.new(), true)
	check(get_tree().paused, "Transformation did not pause before cancellation")
	level.queue_free()
	await ticks(40)
	check(not get_tree().paused, "Leaving during a transformation left the new scene paused")
