# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Real directional input, independent smoke/pose thresholds, audio teardown,
## crouching masks/ceilings/jumps/held helmets, and native palette UI.

var capture := false
var poses: Array[Image] = []
var trace: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-player-controls" in OS.get_cmdline_user_args() or "--capture-braking-dust" in OS.get_cmdline_user_args()
	var level: Level = await LevelProcessor.from_swe("res://tests/fixtures/port_slice.swe")
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await ticks(8)
	for node in level.current_sub_area.get_foreground().get_children():
		if node is Enemy or node is GoalGate or node is Coin or node is QuestionBlock or node is TurnBlockTile:
			node.queue_free()
	await ticks(2)
	if "--capture-braking-dust" in OS.get_cmdline_user_args():
		await check_dust_pixels()
		await capture_braking_reel(level)
		await capture_braking_reel(level, true)
		var dust_file := FileAccess.open("res://.godot/porting-tests/player_controls.json", FileAccess.WRITE)
		dust_file.store_string(JSON.stringify(trace, "  "))
		dust_file.close()
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
		await finish("PLAYER_CONTROLS_RESULT", level)
		return
	for big in [false, true]:
		for facing in [-1, 1]:
			await check_braking(level, big, facing)
		await check_crouch(level, big)
	await check_dust(level)
	await check_dust_modes(level)
	if capture:
		await check_dust_pixels()
		await capture_braking_reel(level)
		await capture_braking_reel(level, true)
	await check_audio_lifetime(level)
	level.queue_free()
	await ticks(3)
	await check_palette()
	if capture and not poses.is_empty():
		var sheet := Image.create(960, ceili(poses.size() / 3.0) * 208, false, Image.FORMAT_RGBA8)
		for index in poses.size():
			sheet.blit_rect(poses[index], Rect2i(0, 0, 320, 208), Vector2i(index % 3 * 320, index / 3 * 208))
		check(sheet.save_png("res://.godot/porting-tests/slice_player_controls.png") == OK, "Could not save controls capture")
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	var file := FileAccess.open("res://.godot/porting-tests/player_controls.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(trace, "  "))
	file.close()
	await finish("PLAYER_CONTROLS_RESULT")


func park(level: Level, big := false) -> Player:
	release_input()
	var player := level.hud.player
	player.position = Vector2(480, -16)
	player.velocity = Vector2.ZERO
	player.invulnerability_left = 0
	player.crouching = false
	player.state_machine.switch(PlayerIdleState)
	player.set_powerup(SuperPowerup.new() if big else SmallPowerup.new(), false)
	await ticks(4)
	return player


func moving(player: Player) -> PlayerMovingState:
	return Utility.find_child_by_class(player.state_machine, PlayerMovingState)


func smoke(level: Level) -> Array[SkidSmoke]:
	var result: Array[SkidSmoke] = []
	for node in level.current_sub_area.get_foreground().get_children():
		if node is SkidSmoke and not node.is_queued_for_deletion():
			result.append(node)
	return result


func clear_smoke(level: Level) -> void:
	for node in smoke(level):
		node.queue_free()
	await ticks(2)


func check_braking(level: Level, big: bool, facing: int) -> void:
	var player := await park(level, big)
	await clear_smoke(level)
	for speed in [36.0, 78.0, 180.0]:
		player.velocity = Vector2(-facing * speed, 0)
		player.p_meter = 7 if speed > 78 else 0
		player.state_machine.switch(PlayerMovingState, true)
		Input.action_press("player_left" if facing < 0 else "player_right")
		if speed > 78:
			Input.action_press("player_run")
		await ticks(1)
		var pose := player.sprite.animation
		var dust_count := smoke(level).size()
		var sound_on := is_instance_valid(moving(player).skid_sound) and moving(player).skid_sound.playing
		check(player.direction == facing and player.sprite.flip_h == (facing < 0), "A reversal lost Mario's requested facing")
		check(pose == (&"skid" if speed > 78 else &"walk"), "Walking reversal used skid art, or full running reversal lost it")
		check((dust_count > 0) == (speed >= 60), "Braking dust did not distinguish slow/fast walking independently of running")
		check(sound_on == (speed > 78), "Skid sound did not follow the running skid pose")
		trace.append({"big": big, "facing": facing, "incoming_speed": speed, "pose": pose, "dust": dust_count, "audio": sound_on})
		if facing == 1 and speed in [78.0, 180.0]:
			await capture_pose("%s %s TURN" % ["SUPER" if big else "SMALL", "RUN" if speed > 78 else "WALK"], level, player.global_position)
		# Match the existing momentum again: no opposing force, no skid loop.
		release_input()
		Input.action_press("player_right" if facing < 0 else "player_left")
		await ticks(1)
		check(not moving(player).skid_sound.playing if is_instance_valid(moving(player).skid_sound) else true,
				"Skid loop continued after steering back with the momentum")
		release_input()
		await clear_smoke(level)


func check_crouch(level: Level, big: bool) -> void:
	var player := await park(level, big)
	var floor_y := player.global_position.y
	Input.action_press("player_down")
	await ticks(3)
	check(player.sprite.animation == &"duck", "Down did not crouch %s Mario" % ("super" if big else "small"))
	var collider: CollisionShape2D = player.get_node("CollShape")
	check(collider.shape.size == Vector2(12, 15 if big else 13), "Crouching did not use the source small/super duck mask")
	check(absf(player.global_position.y - floor_y) < 0.1, "Crouching displaced Mario's feet")
	var image := player.sprite.sprite_frames.get_frame_texture(&"duck", 0).get_image()
	var art := image.get_used_rect()
	var shoe_y := player.sprite.global_position.y + player.sprite.offset.y + art.end.y
	check(absf(shoe_y - (floor_y + 1)) < 0.1, "Crouching lost the one-pixel shoe overlap")
	await capture_pose("%s CROUCH" % ("SUPER" if big else "SMALL"), level, player.global_position)
	Input.action_press("player_right")
	await ticks(8)
	check(absf(player.velocity.x) < 0.01 and player.sprite.animation == &"duck", "Crouching accelerated into a normal walk")
	player.velocity.x = 78
	await ticks(5)
	check(player.velocity.x > 0 and player.velocity.x < 78, "Crouching did not retain and slow existing momentum")
	Input.action_release("player_right")
	Input.action_press("player_spin_jump")
	await ticks(2)
	check(not player.state_machine.current_state is PlayerSpinJumpingState and player.is_on_floor(), "Spin input bypassed the crouching ground guard")
	Input.action_release("player_spin_jump")
	Input.action_press("player_jump")
	await ticks(5)
	check(player.velocity.y < 0 and player.sprite.animation == &"duck", "Crouch jump lost its pose or failed to jump")
	Input.action_release("player_down")
	await ticks(3)
	check(player.sprite.animation == &"duck", "Crouch jump stood up before the descending phase")
	Input.action_release("player_jump")
	await ticks(55)
	check(player.sprite.animation != &"duck" and collider.shape.size.y == (27 if big else 15), "Released crouch did not restore normal art/body")
	Input.action_press("player_down")
	await ticks(2)
	player.state_machine.switch(PlayerJumpingState)
	player.position.y = floor_y - 1
	player.velocity = Vector2(0, 60)
	Input.action_press("player_spin_jump")
	await ticks(3)
	check(not player.state_machine.current_state is PlayerSpinJumpingState, "A buffered spin bypassed crouch restrictions on landing")
	release_input()
	# A real low ceiling retains the crouch mask after releasing Down.
	player = await park(level, big)
	Input.action_press("player_down")
	await ticks(2)
	var ceiling := StaticBody2D.new()
	ceiling.collision_layer = 1
	var ceiling_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(48, 8)
	ceiling_shape.shape = rectangle
	ceiling.add_child(ceiling_shape)
	ceiling.position = player.position - Vector2(0, (19 if big else 17))
	level.current_sub_area.add(ceiling)
	await ticks(3)
	Input.action_release("player_down")
	await ticks(3)
	check(player.sprite.animation == &"duck" and absf(player.global_position.y - floor_y) < 0.1,
			"Standing under a low ceiling shifted the player or enlarged the mask into it")
	ceiling.queue_free()
	await ticks(4)
	check(not player.is_ducking() and collider.shape.size.y == (27 if big else 15), "Mario failed to stand when the ceiling cleared")
	# Both crouch poses must carry the existing shell and helmet with them.
	Input.action_press("player_down")
	Input.action_press("player_run")
	var shell: KoopaShell = load("res://scenes/level/entities/koopa_shell.tscn").instantiate()
	shell.position = Vector2(700, -16)
	level.current_sub_area.add(shell)
	await ticks(20) # Native shell spawn immunity must expire before pickup.
	player.give_item(shell)
	await ticks(2) # Item ownership reparents on the native deferred path.
	player.state_machine.switch(PlayerIdleState, true)
	player.equip_buzzy_helmet()
	await ticks(4)
	check(player.held_item == shell and player.sprite.animation == &"hold_duck", "Holding a shell prevented the small/super crouch pose")
	check(absf(player._helmet.position.y - ((16 if big else 19) - 32)) < 0.01, "Crouching helmet no longer follows the held pose")
	await capture_pose("%s HELD DUCK" % ("SUPER" if big else "SMALL"), level, player.global_position)
	player.detach_held_item()
	await ticks(2)
	shell.queue_free()
	await ticks(3)
	check(absf(player._helmet.position.y - ((20 if big else 21) - 32)) < 0.01, "Crouching helmet did not follow the unheld head")
	player._helmet.break_off()
	release_input()
	await ticks(5)


func check_dust(level: Level) -> void:
	var player := await park(level)
	for node in level.current_sub_area.get_foreground().get_children():
		if node is DeadEntity:
			node.queue_free() # Prior helmet-drop checks must not cover the cloud.
	await ticks(2)
	var puff: SkidSmoke = load("res://scenes/level/particles/skid_smoke.tscn").instantiate()
	puff.position = player.position + Vector2(40, 1)
	level.current_sub_area.add(puff)
	var anchor := puff.global_position
	var start := puff.body_size
	while puff._age < 0.03:
		await get_tree().process_frame
	await capture_pose("DUST: GROW", level, puff.global_position)
	while puff._age < 0.05:
		await get_tree().process_frame
	var peak := puff.body_size
	check(peak > 0.95 and peak > start * 3, "Dust did not quickly grow from a small puff to its peak")
	check(absf(puff.global_position.y - (player.global_position.y + 1)) < 0.1, "Dust is not anchored one pixel lower at shoe level")
	await capture_pose("DUST: PEAK", level, puff.global_position)
	while puff._age < 0.24:
		await get_tree().process_frame
	check(is_instance_valid(puff) and puff.body_size < peak / 2 and puff.modulate.a == 1.0, "Dust must shrink while retaining the reference's opaque white interior")
	check(puff.global_position == anchor, "Dust followed Mario instead of staying on the ground")
	await capture_pose("DUST: SHRINK", level, puff.global_position)
	trace.append({"dust_size_start": start, "dust_size_peak": peak, "dust_size_end": puff.body_size, "anchor": anchor})
	await ticks(9)
	check(not is_instance_valid(puff), "Finished skid dust leaked into the course")


func start_skid(player: Player) -> void:
	release_input()
	player.velocity = Vector2(180, 0)
	player.p_meter = 7
	Input.action_press("player_run")
	Input.action_press("player_left")
	player.state_machine.switch(PlayerMovingState, true)
	await ticks(1)
	check(is_instance_valid(moving(player).skid_sound) and moving(player).skid_sound.playing, "Audio lifetime test never entered a real skid")


func check_dust_modes(level: Level) -> void:
	for big in [false, true]:
		for facing in [-1, 1]:
			var counts: Array[int] = []
			for running in [false, true]:
				var player := await park(level, big)
				await clear_smoke(level)
				player.velocity = Vector2(-facing * (180 if running else 78), 0)
				player.p_meter = 7 if running else 0
				# Holding Run alone must not turn a walking reversal into running dust.
				Input.action_press("player_run")
				Input.action_press("player_left" if facing < 0 else "player_right")
				player.state_machine.switch(PlayerMovingState, true)
				var emitted: Dictionary = {}
				var slow_emissions := 0
				for tick in 28:
					await ticks(1)
					for puff in smoke(level):
						var id := puff.get_instance_id()
						if not emitted.has(id):
							emitted[id] = true
							if absf(player.velocity.x) < 60 and player.velocity.x * facing < 0:
								slow_emissions += 1
							check((puff.lifetime < SkidSmoke.LIFETIME) == running,
									"Walk/run dust lost its distinct lifetime")
				counts.append(emitted.size())
				check(not moving(player).running_skid_dust, "Running dust persisted after the reversal finished")
				check((slow_emissions > 0) == running, "Running dust switched to sparse walking dust before Mario finished braking")
				trace.append({"dust_mode": "run" if running else "walk", "big": big,
						"facing": facing, "puffs_per_brake": emitted.size(), "slow_emissions": slow_emissions})
				release_input()
				await ticks(18)
				check(smoke(level).is_empty(), "Braking clouds survived their cleanup interval")
			check(counts[0] > 0 and counts[1] > counts[0] and counts[1] <= 5,
					"Running brake lost its distinct cluster or returned to excessive emission")


func check_audio_lifetime(level: Level) -> void:
	for reason in ["release", "jump", "duck", "power", "freeze", "stop"]:
		var player := await park(level, true)
		await start_skid(player)
		match reason:
			"release": release_input()
			"jump": Input.action_press("player_jump")
			"duck": Input.action_press("player_down")
			"power": player.set_powerup(SmallPowerup.new(), true)
			"freeze": player.freeze_in_ice()
			"stop": player.velocity.x = 0
		await ticks(2)
		check(not moving(player).skid_sound.playing, "Skid audio survived %s" % reason)
		if reason == "power":
			while get_tree().paused:
				await ticks(1)
		if reason == "freeze":
			player.state_machine.switch(PlayerIdleState)
		release_input()
		await ticks(3)
	var player := await park(level)
	await start_skid(player)
	var voice := moving(player).skid_sound
	var old_clouds := smoke(level).map(func(puff): return puff.get_instance_id())
	player.kill()
	check(not voice.playing, "Skid audio survived death")
	# No timer callbacks may create new clouds after the state has ended.
	await ticks(25)
	check(smoke(level).all(func(puff): return puff.get_instance_id() in old_clouds), "Skid timer emitted dust after Mario left the movement state")
	level.reload()
	await ticks(8)
	check(not is_instance_valid(voice), "Retry retained the old skid audio player")
	player = await park(level)
	await start_skid(player)
	voice = moving(player).skid_sound
	level.complete(player, player.global_position.x + 96)
	check(not voice.playing, "Skid audio survived the native completion transition")
	release_input()


func check_palette() -> void:
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(25)
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	ring.page_index = 1
	check(ring.choose(5), "Native palette could not select Hammer Bro")
	var bro := HammerBroPart.create()
	bro.position = Vector2(480, -96)
	level.current_sub_area.add_part(bro)
	for variant in HammerBroPart.VARIANTS:
		var original := SpriteLibrary.get_frames(variant.editor_sprite).get_frame_texture(&"default", variant.editor_frame)
		var original_size := original.get_size()
		var original_image := original.get_image().duplicate() as Image
		if not bro.variant.sledge and not variant.sledge:
			level.editor.set_part_variant(bro, variant.id)
		else:
			bro.set_variant(variant.id)
		level.editor._remember_palette_variant(bro)
		var icon := level.editor.get_palette_icon(HammerBroPart)
		check(icon.get_size() == Vector2(60, 60) and icon.get_image().get_used_rect().size.y == 48, "Bro palette art did not use the native 60px canvas / 48px body")
		check(original.get_size() == original_size and original.get_image().get_data() == original_image.get_data(), "Palette normalization mutated source enemy art")
		for card: EditorCard in level.editor.get_node("%Cards").get_children():
			if card.part == HammerBroPart:
				check(card.get_node("%Icon").texture == icon, "Top card and palette used different Bro icon sizes")
	bro.set_variant(&"hammer")
	level.editor._remember_palette_variant(bro)
	if capture:
		level.editor.get_node("PaletteMenu").show()
		ring.set_process(false)
		ring.selected = 5
		await ticks(30)
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_player_controls_palette.png") == OK, "Could not save actual palette UI")
	level.editor.get_node("PaletteMenu").hide()
	level.play()
	await ticks(10)
	var player := await park(level)
	await start_skid(player)
	var voice := moving(player).skid_sound
	level.edit()
	await ticks(3)
	check(not is_instance_valid(voice), "Returning to the editor retained the skid audio player")
	release_input()
	level.queue_free()
	await ticks(3)


func check_dust_pixels() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(160, 100)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.canvas_transform = Transform2D(Vector2(8, 0), Vector2(0, 8), Vector2(80, 80))
	var puff: SkidSmoke = load("res://scenes/level/particles/skid_smoke.tscn").instantiate()
	viewport.add_child(puff)
	puff.set_process(false)
	var times := [0.0, 0.02, 0.05, 0.10, 0.16, 0.23, 0.28, 0.31]
	var areas: Array[int] = []
	var sheet := Image.create(1280, 100, false, Image.FORMAT_RGBA8)
	for index in times.size():
		puff._age = times[index]
		puff._update_envelope()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var pixels := viewport.get_texture().get_image()
		sheet.blit_rect(pixels, Rect2i(0, 0, 160, 100), Vector2i(index * 160, 0))
		var opaque := 0
		for y in pixels.get_height():
			for x in pixels.get_width():
				if pixels.get_pixel(x, y).a > 0.95:
					opaque += 1
		areas.append(opaque)
		if index in [2, 3, 4, 5]:
			var center := Vector2i(80, 80 - roundi(2 * puff.body_size * 8))
			var color := pixels.get_pixelv(center)
			check(color.a > 0.98 and color.r > 0.98 and color.g > 0.98,
					"Rendered dust became a hollow ring or translucent square instead of a filled white puff")
	check(areas[2] > areas[0] * 10 and areas[2] > areas[1], "Actual rendered puff did not expand quickly")
	check(areas[5] < areas[2] / 4 and areas[6] < areas[5] and areas[7] == 0, "Actual rendered puff did not contract and disappear")
	trace.append({"dust_sample_seconds": times, "dust_opaque_pixels": areas})
	check(sheet.save_png("res://.godot/porting-tests/player_controls_dust_profile.png") == OK, "Could not save actual dust pixel profile")
	viewport.queue_free()
	await get_tree().process_frame


func capture_braking_reel(level: Level, running := false) -> void:
	var player := await park(level)
	await clear_smoke(level)
	Utility.camera_scale = Vector2(4, 4)
	Utility.camera_position = player.global_position - Vector2(144, 80)
	Input.action_press("player_right")
	if running:
		Input.action_press("player_run")
	await ticks(95 if running else 35) # Reach the actual speed through normal input.
	check(absf(player.velocity.x) >= (179 if running else 77), "Continuous dust capture did not reach its walk/run speed")
	Input.action_release("player_right")
	Input.action_press("player_left")
	var fps := roundi(1.0 / get_process_delta_time())
	var directory := "res://.godot/porting-tests/player_controls_%sreel_%d" % ["run_" if running else "", fps]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var elapsed := 0.0
	var index := 0
	var released: Dictionary = {}
	var emitted: Dictionary = {}
	while elapsed < 0.65:
		await RenderingServer.frame_post_draw
		for puff in smoke(level):
			var id := puff.get_instance_id()
			emitted[id] = true
			if released.has(id):
				check(puff.global_position == released[id], "Released dust continued sliding after Mario")
			else:
				released[id] = puff.global_position
		var screen := player.sub_area.presentation.canvas_transform_for(player).origin
		var crop := Rect2i(Vector2i(screen) - Vector2i(160, 160), Vector2i(320, 208))
		var pixels := get_viewport().get_texture().get_image().get_region(crop)
		check(pixels.save_png(directory + "/frame_%03d.png" % index) == OK, "Could not save continuous braking frame")
		elapsed += get_process_delta_time()
		index += 1
		await get_tree().process_frame
	trace.append({"braking_reel_fps": fps, "running": running, "frame_count": index,
			"seconds": elapsed, "puffs": emitted.size(), "stationary_clouds": released.size()})
	release_input()


func capture_pose(title: String, level: Level, at: Vector2) -> void:
	if not capture:
		return
	var mode := level.process_mode
	level.process_mode = Node.PROCESS_MODE_DISABLED
	Utility.camera_scale = Vector2(4, 4)
	Utility.camera_position = at - Vector2(144, 80)
	level._camera_clamp()
	await get_tree().process_frame
	var screen := level.current_sub_area.get_foreground().get_global_transform_with_canvas() * at
	var crop := Rect2i(Vector2i(screen) - Vector2i(160, 160), Vector2i(320, 208))
	var overlay := CanvasLayer.new()
	var label := Label.new()
	label.text = title
	label.position = Vector2(crop.position) + Vector2(6, 6)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.add_theme_color_override(&"font_shadow_color", Color.BLACK)
	label.add_theme_constant_override(&"shadow_offset_x", 1)
	label.add_theme_constant_override(&"shadow_offset_y", 1)
	add_child(overlay)
	overlay.add_child(label)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	poses.append(get_viewport().get_texture().get_image().get_region(crop))
	overlay.queue_free()
	level.process_mode = mode
