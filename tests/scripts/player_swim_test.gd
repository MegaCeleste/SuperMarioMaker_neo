# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Source oracles use explicit60Hz values, never the new rules resource.

var capture := false
var player: Player
var area: SubArea
var _probe := {}
var _pixel_matches := 0
var _pixel_total := 0
var _sources := {}
var _pixel_cases := {}
var _bad_frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-player-swim" in OS.get_cmdline_user_args()
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(6)
	area = level.current_sub_area
	for part in area.get_parts().get_children():
		if not (part is StartingGround or part is EditorPlayer):
			part.queue_free()
	await ticks(2)
	for x in range(160, 448, 16):
		ground(Vector2(x, -64))
	# A real vertical wall and solid ceiling, rather than mocked floor flags.
	for y in range(-192, -64, 16):
		ground(Vector2(400, y))
	for x in range(288, 368, 16):
		ground(Vector2(x, -240))
	var question := QuestionBlockPart.create()
	question.position = Vector2(336, -160)
	area.add_part(question)
	question.load()
	GroundPart.refresh_all(area.get_parts())
	area.set_theme(Level.LevelTheme.UNDERWATER)
	check(area.level_theme == Level.LevelTheme.UNDERWATER, "Underwater editor theme rejected")
	var path := "res://.godot/porting-tests/swim_course.swe"
	var saved := await level.editor.save_to_path(path)
	check(saved.error == OK, "Swimming course did not save")
	var reopened := await LevelProcessor.from_swe(path)
	check(reopened.current_sub_area.level_theme == Level.LevelTheme.UNDERWATER, "Saved underwater course lost its water environment")
	reopened.free()
	level.play()
	await ticks(5)
	player = level.hud.player
	if capture:
		# The editor-to-play fade is a foreground tint, not source art. Let the
		# native entry transition finish before comparing raw Mario RGB.
		await ticks(30)
		RenderingServer.frame_pre_draw.connect(_sample)
		RenderingServer.frame_post_draw.connect(_pixels)
	await park(Vector2(208, -256))
	check(player.is_swimming(), "Underwater entry kept Mario in the land state")
	player.velocity = Vector2.ZERO
	await ticks(20)
	check(absf(player.velocity.y - 36) < 0.01, "Water gravity is not source0.03px/tick²")
	await snap("small_sink")
	player.velocity.y = 60
	Input.action_press("player_jump")
	await ticks(1)
	check(absf(player.velocity.y + 69) < 0.01, "Sinking stroke must reverse with0.18px plus one gravity step")
	var swim := player.state_machine.current_state as PlayerSwimmingState
	check(swim.stroke_count == 1, "One Jump press did not produce one stroke")
	var frames := {}
	for i in 25:
		if player.sprite.animation == &"swim":
			frames[player.sprite.frame] = true
		await ticks(1)
	check(frames.has(0) and frames.has(1) and frames.has(2) and player.sprite.animation == &"swim_float",
		"Stroke did not show three original poses then return to floating art")
	check(swim.stroke_count == 1, "Held Jump repeated the stroke without a new press")
	release_input()
	Input.action_press("player_spin_jump")
	await ticks(2)
	check(player.is_swimming() and swim.stroke_count == 1, "Underwater Spin triggered an air jump/stroke")
	release_input()
	await park(Vector2(208, -240))
	Input.action_press("player_right")
	Input.action_press("player_run")
	await ticks(24)
	check(absf(player.velocity.x - 60) < 0.01 and player.p_meter == 0,
		"Run increased water speed or filled the land P-meter")
	await snap("small_move")
	release_input()
	await ticks(20)
	check(is_zero_approx(player.velocity.x), "Swim input release retained permanent horizontal drift")
	Input.action_press("player_left", 0.4)
	await ticks(1)
	check(player.direction == -1 and player.sprite.flip_h, "Partial-strength steering lost the signed swim facing")
	release_input()
	for form in ["super", "fire"]:
		await park(Vector2(224, -192))
		player.set_powerup(FirePowerup.new() if form == "fire" else SuperPowerup.new(), false)
		Input.action_press("player_jump")
		await ticks(8)
		await snap(form + "_stroke")
		check(player._sprite_mapping.swim[0] == "spr_mario_%s_swim" % ("fire" if form == "fire" else "big"),
			"Powerup uses the wrong original swim art")
		release_input()
		await ticks(18)
		await snap(form + "_float")
	# Water physics must keep ordinary solid body/block contacts.
	await park(Vector2(390, -136))
	Input.action_press("player_right")
	await ticks(15)
	check(Utility.get_bounding_box(player).end.x <= 400.1, "Swimming passed through the solid wall")
	release_input()
	await park(Vector2(320, -208))
	Input.action_press("player_jump")
	for i in 12:
		Input.action_release("player_jump")
		await ticks(1)
		Input.action_press("player_jump")
		await ticks(1)
	check(Utility.get_bounding_box(player).position.y >= -224.2, "Swimming passed through the solid ceiling")
	release_input()
	await park(Vector2(344, -112))
	var coins := player.coins
	player.velocity.y = -60
	Input.action_press("player_jump")
	await ticks(16)
	check(player.coins == coins + 1, "Actual underwater head bump did not activate the question block")
	release_input()
	await park(Vector2(224, -64))
	await ticks(3)
	Input.action_press("player_right")
	await ticks(18)
	check(player.is_on_floor() and absf(player.velocity.x - 30) < 0.01,
		"Submerged walking must keep the0.5px/tick floor cap")
	release_input()
	Input.action_press("player_down")
	await ticks(3)
	check(player.is_ducking(), "Submerged grounded SMW Mario cannot crouch")
	await snap("floor_duck")
	release_input()
	# Portable object buoyancy and automatic forward motion use the real
	# PickupComponent/reparent/release path.
	await park(Vector2(208, -192))
	var spring: Spring = load("res://scenes/entities/spring.tscn").instantiate()
	spring.position = Vector2(232, -176)
	area.add(spring)
	Input.action_press("player_run")
	player.give_item(spring)
	await ticks(12)
	check(player.held_item == spring and spring.get_parent() == player, "Submerged object pickup lost ownership")
	check(spring.position.is_equal_approx(Vector2(11 * player.direction, -1.5)), "Continuous swim state did not align a newly held item")
	check(absf(player.velocity.y + 58.2) < 0.01 and absf(player.velocity.x - 30) < 0.01,
		"Held swimming lacks source buoyancy/forward drift")
	check(player.sprite.animation == &"swim_float" and player.sprite.frame == 0 and not player.sprite.is_playing(),
		"Rising held swim did not retain the source resting pose")
	await snap("carry_rise")
	Input.action_press("player_down")
	await ticks(10)
	check(player.velocity.y > 60 and player.velocity.y < 98, "Down did not overcome held-item buoyancy")
	await snap("carry_dive")
	player.drop_item()
	release_input()
	await ticks(3)
	check(player.held_item == null and spring.get_parent() == area.get_foreground(), "Swimming throw/drop lost the free object")
	spring.queue_free()
	await park(Vector2(224, -192))
	player.bounce()
	check(player.is_swimming() and absf(player.velocity.y + 100.5) < 0.01, "Water stomp rebound used the land jump impulse/state")
	await park(Vector2(248, -94))
	var enemy: Galoomba = load("res://scenes/entities/galoomba.tscn").instantiate()
	enemy.position = Vector2(248, -64)
	enemy.get_node("SlideComponent").speed = 0
	area.add(enemy)
	player.velocity.y = 60
	var score := player.score
	var rebounded := false
	for i in 24:
		await ticks(1)
		if player.score == score + 200 and player.velocity.y < -80:
			rebounded = true
			break
	check(rebounded and player.is_swimming() and not is_instance_valid(enemy),
		"Real underwater Galoomba stomp did not defeat/rebound through the swim controller")
	for body in area.get_foreground().get_children():
		if body is StompedGaloomba:
			body.queue_free()
	# Source liquid exit exists independently of six-theme UI. Exercise the
	# existing forest-water runtime without adding a new editor theme.
	await surface_crossing(level)
	await park(Vector2(224, -414))
	player.velocity.y = -90
	await ticks(6)
	check(player.position.y >= -416, "Full-water swimming escaped the source room-top limit")
	await park(Vector2(224, -192))
	player.set_powerup(FirePowerup.new(), false)
	Input.action_press("player_run")
	await ticks(2)
	var shot_count := 0
	for body in area.get_foreground().get_children():
		if body is PlayerFireball:
			shot_count += 1
	check(shot_count == 1 and player.is_swimming(), "Fire Mario cannot shoot while swimming")
	await snap("fire_shoot")
	release_input()
	player.damage()
	await ticks(65)
	check(player.get_powerup() is SuperPowerup and player.is_swimming(), "Water damage lost the downgrade or swim state")
	player.invulnerability_left = 0
	check(player.freeze_in_ice(), "Water freeze rejected an otherwise vulnerable player")
	await ticks(1)
	check(player.is_frozen(), "Water resolver overwrote the frozen state")
	player.state_machine.switch(PlayerFallingState)
	player.invulnerability_left = 0
	await ticks(2)
	check(player.is_swimming(), "Thawed Mario did not return to swimming")
	# A real bubble follows the source piecewise path and pops on solids.
	var bubble := PlayerBubble.new()
	bubble.sub_area = area
	bubble.position = Vector2(376, -136)
	area.add(bubble)
	await ticks(8)
	check(bubble.position.x > 379 and bubble.position.y < -140, "Bubble does not follow the initial source path segment")
	await snap("bubble")
	bubble.position = Vector2(402, -128)
	bubble._start = bubble.position
	await ticks(2)
	check(bubble._popping, "Bubble did not pop against solid terrain")
	player.kill()
	await ticks(2)
	check(player.is_dead(), "Water resolver overwrote the death state")
	level.edit()
	await ticks(4)
	check(not is_instance_valid(player) and get_tree().get_nodes_in_group(&"player_bubbles").is_empty(),
		"Editor return retained water actors/bubbles")
	level.play()
	await ticks(4)
	player = level.hud.player
	check(player.is_swimming(), "Retry/replay did not start a fresh underwater Mario")
	if capture:
		check(_pixel_total > 100 and _pixel_matches == _pixel_total, "Actual GPU swim pixels differ from original source art/origins")
		print("SWIM_GPU ", _pixel_matches, "/", _pixel_total)
		print("SWIM_GPU_CASES ", _pixel_cases)
		RenderingServer.frame_pre_draw.disconnect(_sample)
		RenderingServer.frame_post_draw.disconnect(_pixels)
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("PLAYER_SWIM_RESULT", level)


func ground(at: Vector2) -> void:
	var part := GroundPart.create()
	part.position = at
	area.add_part(part)
	part.load(false)


func park(at: Vector2) -> void:
	release_input()
	player.crouching = false
	player.growth_crouched = false
	player.set_powerup_hitbox(not player.get_powerup() is SmallPowerup)
	player.state_machine.switch(PlayerFallingState)
	player.position = at
	player.previous_position = at
	player.velocity = Vector2.ZERO
	await ticks(2)


func surface_crossing(_level: Level) -> void:
	area.level_theme = Level.LevelTheme.FOREST
	area.night_mode = false
	var liquid := LiquidSurface.new()
	liquid.sub_area = area
	area.water_start_y = -204
	area.water_limit_y = -204
	area.liquid = liquid
	area.add_child(liquid)
	await park(Vector2(256, -176))
	check(player.is_swimming(), "Crossing water entry band did not enter swimming")
	player.position.y = liquid.position.y + 11.5
	player.velocity.y = -60
	Input.action_press("player_jump")
	await ticks(1)
	check(not player.is_swimming() and player.velocity.y < -220, "Surface exit did not restore land gravity/surface jump")
	check(player.state_machine.current_state is PlayerJumpingState and absf(player._gravity.gravity.y - 360) < 0.01,
		"Held-Jump surface exit did not retain ordinary variable jump gravity")
	release_input()
	await ticks(1)
	check(absf(player._gravity.gravity.y - 1080) < 0.01, "Released surface jump did not restore ordinary gravity")
	player.position = Vector2(256, -176)
	player.velocity.y = 120
	await ticks(2)
	check(player.is_swimming() and player.velocity.y < 63, "Water reentry retained the land falling speed")
	liquid.queue_free()
	area.liquid = null
	area.level_theme = Level.LevelTheme.UNDERWATER
	await ticks(1)


func snap(label: String) -> void:
	if not capture:
		return
	Utility.camera_position = Vector2(128, -216 if label == "floor_duck" else -304)
	await ticks(2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/swim_%s.png" % label)
	if label == "fire_float":
		get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_player_swim.png")


func _sample() -> void:
	_probe.clear()
	if not is_instance_valid(player) or player.is_queued_for_deletion() or not player.is_swimming() \
			or player.sprite.animation not in [&"swim", &"swim_float"] or player.invulnerability_left > 0 \
			or not player.sprite.is_visible_in_tree() or area.level_theme != Level.LevelTheme.UNDERWATER:
		return
	var size := "small" if player.get_powerup() is SmallPowerup else "fire" if player.get_powerup() is FirePowerup else "big"
	var name := "spr_mario_%s_swim%s" % [size, "_hold" if player.sprite.animation == &"swim_float" else ""]
	if not _sources.has(name):
		_sources[name] = SpriteLibrary.get_frames(name)
	var expected: SpriteFrames = _sources[name]
	var image := expected.get_frame_texture(&"default", player.sprite.frame).get_image()
	var occluders: Array[Rect2] = []
	# Carried objects, bubble pixels and the thaw burst are intentionally drawn
	# in front of Mario. Their covered pixels cannot be a raw-Mario art oracle.
	for node in area.get_foreground().get_children():
		if node is AnimatedSprite2D:
			occluders.append(sprite_rect(node))
		elif node is PlayerBubble and is_instance_valid(node._sprite):
			occluders.append(sprite_rect(node._sprite))
	if player.held_item is Spring:
		occluders.append(sprite_rect(player.held_item._sprite))
	_probe = {"image": image, "transform": area.presentation.canvas_transform_for(player.sprite),
			"frames": expected,
			"offset": -SpriteLibrary.get_origin(name) - Vector2(0, 31),
			"flip_h": player.sprite.flip_h,
			"occluders": occluders,
			"case": "%s_%d_held%s_theme%d" % [name, player.sprite.frame, player.held_item != null, area.level_theme]}


func _pixels() -> void:
	if _probe.is_empty():
		return
	var gpu := get_viewport().get_texture().get_image()
	var image: Image = _probe.image
	var counts: Dictionary = _pixel_cases.get_or_add(_probe.case, {"match": 0, "total": 0})
	var frame_bad := 0
	var diagnostics := []
	# Interior points exclude source alpha edges, so fractional rendering cannot
	# let shadows or an adjacent world sprite masquerade as Mario's pixels.
	for y in range(1, image.get_height() - 1, 3):
		for x in range(1, image.get_width() - 1, 3):
			var color := image.get_pixel(x, y)
			if color.a < 1 or image.get_pixel(x - 1, y).a < 1 or image.get_pixel(x + 1, y).a < 1:
				continue
			var drawn_x := image.get_width() - x - 0.5 if _probe.flip_h else x + 0.5
			var at: Vector2i = Vector2i(_probe.transform * (_probe.offset + Vector2(drawn_x, y + 0.5)))
			if at.x < 200 or at.x > 1080 or at.y < 110 or at.y > 570:
				continue
			var covered := false
			for rect: Rect2 in _probe.occluders:
				if rect.has_point(Vector2(at)):
					covered = true
					break
			if covered:
				continue
			_pixel_total += 1
			counts.total += 1
			if gpu.get_pixelv(at).is_equal_approx(color):
				_pixel_matches += 1
				counts.match += 1
			else:
				frame_bad += 1
				if diagnostics.size() < 3:
					var alternatives := []
					for alternative in _probe.frames.get_frame_count(&"default"):
						var other: Image = _probe.frames.get_frame_texture(&"default", alternative).get_image()
						if gpu.get_pixelv(at).is_equal_approx(other.get_pixel(x, y)):
							alternatives.append(alternative)
					diagnostics.append({"source": Vector2i(x, y), "at": at, "color": color, "gpu": gpu.get_pixelv(at), "other_frames": alternatives})
	if frame_bad > 0 and _bad_frames < 3:
		_bad_frames += 1
		gpu.save_png("res://.godot/porting-tests/swim_mismatch_%d.png" % _bad_frames)
		print("SWIM_MISMATCH ", _probe.case, " bad=", frame_bad, " at=", player.position, " flip=", _probe.flip_h,
				" frame=", Engine.get_physics_frames(), " transform=", _probe.transform, " details=", diagnostics)


func sprite_rect(sprite: AnimatedSprite2D) -> Rect2:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var rect := Rect2(sprite.offset - (texture.get_size() / 2 if sprite.centered else Vector2.ZERO), texture.get_size())
	# Include the existing lower-right world shadow too.
	return (area.presentation.canvas_transform_for(sprite) * rect.grow(3)).abs()
