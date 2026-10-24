# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"

var capture := false
var spring: Spring
var _probe: Dictionary = {}
var _foot_error := 0.0
var _shoe_matches := 0
var _shoe_samples := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-spring" in OS.get_cmdline_user_args()
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_gizmos.tres")
	check(ring.choose(0) and level.editor.get_selected_part() == SpringPart, "Spring palette entry is not usable")
	var part := level.editor.place(Vector2i(16, -12)) as SpringPart
	check(part != null and part.get_node("Graphics/Sprite").texture != null, "Spring placement has no source art")
	level.editor.history.undo()
	check(not part.is_inside_tree(), "Spring place undo failed")
	level.editor.history.redo()
	check(part.is_inside_tree(), "Spring place redo failed")
	part.swe_data.future_spring = 91
	var path := "res://.godot/porting-tests/spring_roundtrip.swe"
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Spring signed save failed: %s" % saved)
	if saved.error != OK:
		await finish("SPRING_RESULT", level)
		return
	var reopened: Level = await LevelProcessor.from_swe(path)
	var restored := false
	for candidate in reopened.current_sub_area.get_parts().get_children():
		if candidate is SpringPart:
			restored = candidate.position == part.position and candidate.swe_data.future_spring == 91
	check(restored, "Spring signed roundtrip lost placement/unknown fields")
	reopened.free()
	if not capture:
		await check_modern(path)
	else:
		Utility.camera_position = Vector2(144, -256)
		await ticks(24) # Let the native editor entry fade finish before capturing.
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/spring_editor.png")
	for candidate in level.current_sub_area.get_parts().get_children():
		if not (candidate is StartingGround or candidate is EditorPlayer):
			candidate.queue_free()
	await ticks(2)
	for x in range(112, 480, 16):
		var ground := GroundPart.create()
		ground.position = Vector2(x, -64)
		level.current_sub_area.add_part(ground)
		ground.load()
	part = SpringPart.create()
	part.position = Vector2(240, -80)
	level.current_sub_area.add_part(part)
	part.load()
	GroundPart.refresh_all(level.current_sub_area.get_parts())
	level.play()
	await ticks(8)
	for node in level.current_sub_area.get_foreground().get_children():
		if node is Spring:
			spring = node
	check(spring != null and absf(spring.position.y + 64) < 0.2, "Spring gravity/floor support failed")
	var player := level.hud.player
	if capture:
		RenderingServer.frame_pre_draw.connect(_sample_contact.bind(level))
		RenderingServer.frame_post_draw.connect(_check_pixels)
	park(player, spring.position + Vector2(-16, 0))
	Input.action_press("player_run")
	await ticks(5)
	check(player.held_item == spring and spring._surface.collision_layer == 0, "Run/side-contact did not carry spring or kept its solid surface")
	if capture:
		await ticks(24)
		await snap("carry", level)
	Input.action_press("player_down")
	player.drop_item()
	Input.action_release("player_run")
	await ticks(3)
	check(player.held_item == null and spring.get_parent() == level.current_sub_area.get_foreground() and spring._surface.collision_layer == 1,
		"Releasing spring did not restore free motion/surface")
	release_input()
	await ticks(16)
	park(player, spring.position + Vector2(-16, 0))
	Input.action_press("player_run")
	await ticks(4)
	check(player.held_item == spring, "Dropped spring could not be picked up after immunity")
	Input.action_press("player_up")
	player.drop_item()
	Input.action_release("player_run")
	await ticks(2)
	check(player.held_item == null and spring.velocity.y < -300 and spring._surface.collision_layer == 1,
		"Upward spring throw lost its native impulse or surface")
	release_input()
	spring.position = Vector2(248, -64)
	spring.velocity = Vector2.ZERO
	var normal := await bounce(level, false)
	var high := await bounce(level, true)
	var spin_high := await bounce(level, true, true)
	# The measurement begins after the first5px launch tick (313.5px/s).
	check(normal > 34 and high > normal + 50 and absf(spin_high - high) < 1,
		"Holding Jump/Spin did not produce the higher spring launch")
	park(player, Vector2(160, -64))
	var item: Mushroom = load("res://scenes/entities/mushroom.tscn").instantiate()
	item.position = spring.position + Vector2(0, -30)
	item.get_node("SlideComponent").speed = 0
	level.current_sub_area.add(item)
	var item_bounced := false
	for tick in 40:
		await ticks(1)
		if item.velocity.y < -280:
			item_bounced = true
			break
	check(item_bounced, "Falling ordinary item did not bounce on spring")
	print("SPRING_HEIGHT normal=", normal, " held=", high, " actor=", item_bounced)
	if capture:
		check(_foot_error < 0.2 and _shoe_samples > 40 and _shoe_matches == _shoe_samples,
			"Rendered spring compression separated Mario's shoes from its surface")
		print("SPRING_SHOES ", _shoe_matches, "/", _shoe_samples, " anchor_error=", _foot_error)
	if capture:
		await snap("idle", level)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_spring.png")
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	if capture:
		RenderingServer.frame_pre_draw.disconnect(_sample_contact.bind(level))
		RenderingServer.frame_post_draw.disconnect(_check_pixels)
	await ticks(16)
	park(player, spring.position + Vector2(-16, 0))
	Input.action_press("player_run")
	await ticks(4)
	check(player.held_item == spring, "Spring could not be carried again after compression")
	level.edit()
	await ticks(3)
	check(level.current_sub_area.get_foreground().get_child_count() == 0, "Spring retained bodies on editor return")
	await finish("SPRING_RESULT", level)

func check_modern(legacy_path: String) -> void:
	var legacy: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(legacy_path)).data.MAIN
	var data := {"S0": {"S1": legacy.AJUSTES, "S2": legacy.SUELO, "S4": legacy.NIVEL}}
	for row in data.S0.S4:
		row.ID = row.object
		row.xx = row.x_pos
		row.yy = row.y_pos
		for key in ["object", "x_pos", "y_pos"]:
			row.erase(key)
	var path := "res://.godot/porting-tests/spring_modern.swe"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelProcessor.from_swe(path)
	var saved := await LevelProcessor.save_swe(level, path)
	check(saved.error == OK, "Modern Spring signed save failed")
	level.free()
	var reopened := await LevelProcessor.from_swe(path)
	var found := false
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is SpringPart:
			found = part.position == Vector2(256, -192) and part.swe_data.future_spring == 91
	check(found, "Modern spring roundtrip lost type/origin/unknown fields")
	reopened.free()

func _sample_contact(level: Level) -> void:
	_probe.clear()
	var player := level.hud.player
	if not is_instance_valid(player) or not player.state_machine.current_state is PlayerSpringState:
		return
	var presentation := level.current_sub_area.presentation
	var hero := player.sprite.sprite_frames.get_frame_texture(player.sprite.animation, player.sprite.frame).get_image()
	var used := hero.get_used_rect()
	var hero_world := presentation.global_transform_for(player.sprite)
	var surface := presentation.global_transform_for(spring).origin.y - 15 + spring.compression
	var contact := hero_world * (player.sprite.offset + Vector2(used.get_center().x, used.end.y))
	_foot_error = maxf(_foot_error, absf(contact.y - surface - 1))
	_probe = {"hero": hero, "used": used, "transform": presentation.canvas_transform_for(player.sprite), "offset": player.sprite.offset}

func _check_pixels() -> void:
	if _probe.is_empty():
		return
	var gpu := get_viewport().get_texture().get_image()
	var used: Rect2i = _probe.used
	for x in range(used.position.x, used.end.x):
		var color: Color = _probe.hero.get_pixel(x, used.end.y - 1)
		if color.a < 0.99:
			continue
		var pixel: Vector2i = _probe.transform * (_probe.offset + Vector2(x + 0.5, used.end.y - 0.5))
		if Rect2i(Vector2i.ZERO, gpu.get_size()).has_point(pixel):
			_shoe_samples += 1
			if gpu.get_pixelv(pixel).is_equal_approx(color):
				_shoe_matches += 1

func park(player: Player, at: Vector2) -> void:
	release_input()
	player.state_machine.switch(PlayerIdleState)
	player.position = at
	player.previous_position = at
	player.velocity = Vector2.ZERO

func bounce(level: Level, jump: bool, spin := false) -> float:
	var player := level.hud.player
	park(player, Vector2(spring.position.x, spring.top_y() - 20))
	player.state_machine.switch(PlayerFallingState)
	player.velocity.y = 60
	if jump:
		Input.action_press("player_spin_jump" if spin else "player_jump")
	var entered := false
	var launched := false
	var frames := {}
	var peak := 0.0
	var launch_y := 0.0
	for tick in 120:
		await ticks(1)
		frames[spring._sprite.frame] = true
		if player.state_machine.current_state is PlayerSpringState:
			entered = true
			check(absf(player.position.y - spring.top_y()) < 0.3, "Spring compression lost rider foot contact")
			if capture and not jump and spring._sprite.frame in [1, 2]:
				await snap("compressed_%d" % spring._sprite.frame, level)
		if entered and player.velocity.y < -280 and not launched:
			launched = true
			check(player.state_machine.current_state is PlayerSpinJumpingState if spin else player.state_machine.current_state is PlayerJumpingState,
				"Spring launch did not preserve ordinary/spin input selection")
			launch_y = player.position.y
			if capture:
				await ticks(3) # Capture the airborne pose, after native state entry.
				await snap("launch_spin" if spin else "launch_high" if jump else "launch", level)
		if launched:
			peak = maxf(peak, launch_y - player.position.y)
			if player.velocity.y >= 0:
				break
	check(entered and launched and frames.has(1) and frames.has(2), "Spring did not compress, then launch through native player state")
	release_input()
	return peak

func snap(label: String, _level: Level) -> void:
	Utility.camera_position = Vector2(96, -208)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/spring_%s.png" % label)
