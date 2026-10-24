# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## A fixed screen crop exposes camera/body jitter hidden by actor-relative crops.

const SAMPLE_FRAMES := 32
var _capture := false
var _trace: Array = []
var _sheets: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture = "--capture-player-render" in OS.get_cmdline_user_args()
	var level: Level = await LevelProcessor.from_swe("res://tests/fixtures/port_slice.swe")
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await ticks(40)
	for node in level.current_sub_area.get_foreground().get_children():
		if node is Enemy or node is GoalGate or node is Coin or node is QuestionBlock or node is TurnBlockTile:
			node.queue_free()
	await ticks(2)
	var player := level.hud.player
	var rules := player.animation_rules
	player.animation_rules = rules.duplicate()
	for big in [false, true]:
		for speed in [78.0, 180.0]:
			for fixed_pose in [true, false]:
				for direction in [-1, 1]:
					await check_motion(player, big, speed, fixed_pose, direction)
	await check_camera_bounds(player)
	player.animation_rules = rules
	var fps := roundi(1.0 / get_process_delta_time())
	var stem := ("res://.godot/porting-tests/slice_player_run_%d" if _capture
			else "res://.godot/porting-tests/player_render_%d") % fps
	var log := FileAccess.open(stem + ".json", FileAccess.WRITE)
	log.store_string(JSON.stringify(_trace, "  "))
	log.close()
	for name: String in _sheets:
		check(_sheets[name].save_png(stem + "_" + name + ".png") == OK, "Could not save fixed-crop running frames")
	if _capture:
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("PLAYER_RENDER_RESULT", level)


func check_motion(player: Player, big: bool, speed: float, fixed_pose: bool, direction: int) -> void:
	release_input()
	player.set_powerup(SuperPowerup.new() if big else SmallPowerup.new(), false)
	player.position = Vector2(480, -16)
	player.velocity = Vector2(speed * direction, 0)
	player.direction = direction
	player.p_meter = 7 if speed > 78 else 3
	player.state_machine.switch(PlayerMovingState)
	player.animation_rules.max_locomotion_fps = 0 if fixed_pose else 18
	var animation: StringName = &"run" if speed > 78 else &"walk"
	player.sprite.play(animation)
	player.sprite.set_frame_and_progress(0, 0)
	player.sprite.flip_h = direction < 0
	# Seed the existing 0.1-per-physics-tick follower at its constant-speed lag.
	var half_width := get_viewport().get_visible_rect().size.x / Utility.camera_scale.x / 2
	Utility.camera_position = Vector2(480 - half_width - direction * speed * 0.15, -216)
	Input.action_press("player_left" if direction < 0 else "player_right")
	if speed > 78:
		Input.action_press("player_run")
	var center := player.sub_area.presentation.canvas_transform_for(player.sprite).origin
	var crop := Rect2i(Vector2i(center.round()) - Vector2i(75, 105), Vector2i(150, 120))
	var previous_tick := -1
	var previous_screen := 0.0
	var min_screen := INF
	var max_screen := -INF
	var min_red := INF
	var max_red := -INF
	var between_ticks_stable := true
	var actual_animation := true
	var seen_frames: Dictionary = {}
	var record := _capture and big and speed > 78
	var sheet_name := "fixed" if fixed_pose else "animated"
	if record and not _sheets.has(sheet_name):
		var sheet := Image.create(1200, 960, false, Image.FORMAT_RGBA8)
		sheet.fill(Color("302e42"))
		_sheets[sheet_name] = sheet
	for frame in SAMPLE_FRAMES:
		if _capture:
			await RenderingServer.frame_post_draw
		else:
			await get_tree().process_frame
		var screen := player.sub_area.presentation.canvas_transform_for(player.sprite).origin.x
		var tick := Engine.get_physics_frames()
		if tick == previous_tick:
			between_ticks_stable = between_ticks_stable and absf(screen - previous_screen) < 0.01
		previous_tick = tick
		previous_screen = screen
		min_screen = minf(min_screen, screen)
		max_screen = maxf(max_screen, screen)
		actual_animation = actual_animation and player.sprite.animation == animation
		seen_frames[player.sprite.frame] = true
		var red_x := -1
		if record:
			var pixels := get_viewport().get_texture().get_image().get_region(crop)
			for y in 100:
				for x in pixels.get_width():
					var color := pixels.get_pixel(x, y)
					if color.r > 0.6 and color.g < 0.45 and color.b < 0.5:
						red_x = x if red_x < 0 else mini(red_x, x)
			if red_x >= 0:
				min_red = minf(min_red, red_x)
				max_red = maxf(max_red, red_x)
			var index := frame + (SAMPLE_FRAMES if direction > 0 else 0)
			_sheets[sheet_name].blit_rect(pixels, Rect2i(0, 0, 150, 120), Vector2i((index % 8) * 150, (index / 8) * 120))
		_trace.append({"big": big, "speed": speed, "fixed_pose": fixed_pose, "direction": direction,
			"render": Engine.get_process_frames(), "physics": tick, "feet_x": player.position.x,
			"camera_x": Utility.camera_position.x, "screen_x": screen, "red_left": red_x,
			"animation": String(player.sprite.animation), "frame": player.sprite.frame})
	var description := "big=%s speed=%s fixed=%s dir=%s" % [big, speed, fixed_pose, direction]
	check(between_ticks_stable, "Camera moved Mario backwards between physics ticks: " + description)
	# Separate floor tiles can recover the body's safe margin by ~0.02 world
	# pixels at a seam. Allow that real motion, below 0.15 screen pixels;
	# motion between unchanged physics ticks must still be effectively zero.
	check(max_screen - min_screen < 0.15, "Steady locomotion oscillated on screen: " + description)
	check(actual_animation, "Steady locomotion did not exercise the requested animation: " + description)
	if fixed_pose:
		check(seen_frames.size() == 1, "The fixed-pose control changed animation frames")
		if record:
			check(is_finite(min_red) and max_red - min_red <= 1,
					"Actual fixed-pose pixels shifted inside the fixed screen crop: " + description)
	else:
		check(seen_frames.size() > 1, "Animated locomotion never advanced its source frames")
	print("RENDER_TRACE ", description, " screen_range=", max_screen - min_screen,
			" between_ticks_stable=", between_ticks_stable, " frame_count=", seen_frames.size())
	release_input()


func check_camera_bounds(player: Player) -> void:
	release_input()
	player.position = Vector2(16, -16)
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)
	Utility.camera_position = Vector2(-40, 0)
	await ticks(2)
	var viewport_height := get_viewport().get_visible_rect().size.y / Utility.camera_scale.y
	check(Utility.camera_position.x >= 0 and Utility.camera_position.y <= -viewport_height,
			"Physics camera following exposed out-of-level bounds before rendering")
