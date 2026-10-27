# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"

const FIXTURE := "res://tests/fixtures/port_slice.swe"
var capture := false
var up: SlopePart
var down: SlopePart
var shallow: SlopePart


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-slopes" in OS.get_cmdline_user_args()
	await check_editor(false)
	if not capture:
		await check_editor(true)
	var level := await LevelActionBtn.prepare_level(FIXTURE, Level.Status.EDITING)
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	await ticks(8)
	await check_reported_bugs(level)
	await make_course(level)
	if capture:
		up.set_process(false)
		up.begin_resize(1)
		Utility.camera_position = Vector2(200, -224)
		await ticks(24)
		await RenderingServer.frame_post_draw
		var editor_pixels := get_viewport().get_texture().get_image()
		editor_pixels.save_png("res://.godot/porting-tests/slopes_editor.png")
		for point: Vector2 in up.endpoints():
			var pixel: Vector2i = up.get_global_transform_with_canvas() * (point + Vector2(0, -4))
			var gold := editor_pixels.get_pixelv(pixel)
			# Editor dim/fade overlays change luminance. The gold hue remains
			# distinct from both green grass and the darker brown soil.
			var gold_hue := gold.r > 0.6 and absf(gold.g / gold.r - 223.0 / 255) < 0.03 \
					and absf(gold.b / gold.r - 82.0 / 255) < 0.03
			check(gold_hue, "Slope endpoint handle was hidden behind terrain art")
		up.end_resize()
		up.set_process(true)
	level.play()
	await ticks(5)
	var visual_only := "--slopes-visual-only" in OS.get_cmdline_user_args()
	if not visual_only:
		await check_walk(level)
	await check_jump_slide(level)
	if not visual_only:
		await check_actors(level)
	await check_join(level)
	if capture:
		level.hud.player.invulnerability_left = 0
		park(level.hud.player, Vector2(480, -150))
		await ticks(20)
		Input.action_press("player_down")
		await ticks(12)
		print("SLOPE_CAPTURE_STATE ", level.hud.player.state_machine.current_state.get_script().get_global_name(), " at=", level.hud.player.position, " normal=", level.hud.player.get_floor_normal())
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_slopes.png")
		await check_gpu(level)
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	level.edit()
	await ticks(3)
	check(level.current_sub_area.get_foreground().get_child_count() == 0, "Slope runtime retained bodies on editor return")
	await finish("SLOPES_RESULT", level)


func add_part(level: Level, type: Script, at: Vector2) -> Part:
	var part: Part = type.create()
	part.position = at
	level.current_sub_area.add_part(part)
	part.load()
	return part


func slope(level: Level, at: Vector2, height: int, shallow_type: bool, right: bool) -> SlopePart:
	var part: SlopePart = (GentleSlopePart if shallow_type else SlopePart).create()
	part.position = at
	part.rise = height
	part.rises_right = right
	level.current_sub_area.add_part(part)
	part.load()
	return part


func check_reported_bugs(level: Level) -> void:
	var parts := level.current_sub_area.get_parts()
	for part in parts.get_children():
		if not (part is StartingGround or part is EditorPlayer):
			part.queue_free()
	await ticks(2)
	var terrain: Array[GroundPart] = []
	for x in range(112, 304, 16):
		terrain.append(add_part(level, GroundPart, Vector2(x, -32)))
	GroundPart.refresh_all(parts)
	var stable: Array = []
	for tile in terrain:
		stable.append([tile.swe_atlas, tile.get_node("%Sprite").texture])
	var ramp := slope(level, Vector2(336, -320), 4, false, true)
	ramp.set_process(false)
	# Every length, angle and direction must remain a one-tile ribbon. In
	# particular5x5/6x6 cannot spawn square atlas corners in the empty triangle.
	for gentle_type in [false, true]:
		for right in [false, true]:
			for height in range(1, SlopePart.MAX_RISE + 1):
				ramp.restore_variant_state({"id": &"gentle" if gentle_type else &"steep", "rise": height, "right": right, "position": Vector2(336, -320)})
				var points := ramp.polygon()
				for x in range(1, ramp.width_cells() * 16):
					var top := ramp.surface_y(x)
					check(Geometry2D.is_point_in_polygon(Vector2(x, top + 8), points), "Ribbon lost its middle")
					check(not Geometry2D.is_point_in_polygon(Vector2(x, top + 25), points), "Slope still fills the empty triangle")
				var square_sprites := 0
				for sprite in ramp._art.get_children():
					if sprite.texture is AtlasTexture:
						square_sprites += 1
				check(square_sprites == 2, "Length generated a stray square tile outside the two caps")
				for i in terrain.size():
					check(terrain[i].swe_atlas == stable[i][0] and terrain[i].get_node("%Sprite").texture == stable[i][1], "Resizing rerolled or recreated unrelated ground")
	ramp.restore_variant_state({"id": &"steep", "rise": 4, "right": true, "position": Vector2(336, -320)})
	var monster := add_part(level, GoombaPart, ramp.position + Vector2(64, 48))
	await ticks(2)
	check(SlopePart.space_free(ramp.position, ramp.polygon(), level.get_world_2d(), [ramp.get_rid()]), "Monster one cell below the strip blocked resizing")
	monster.position = ramp.position + Vector2(64, 16)
	await ticks(2)
	check(not SlopePart.space_free(ramp.position, ramp.polygon(), level.get_world_2d(), [ramp.get_rid()]), "Actual monster contact did not block the strip")
	monster.queue_free()
	# Actual endpoint gesture, followed by undo/redo, with the same nearby actor.
	await ticks(2)
	var before := ramp.get_variant_state()
	var fixed := ramp.position + ramp.endpoints()[0]
	monster = add_part(level, GoombaPart, ramp.position + Vector2(64, 48))
	await ticks(2)
	ramp.begin_resize(1)
	ramp.resize_endpoint(fixed + Vector2(7, -6) * 16)
	ramp.end_resize()
	check(ramp.rise == 6, "Endpoint stopped early with a one-cell monster gap")
	monster.position = Vector2(464, -368) # The next cap, beyond the present ribbon.
	await ticks(2)
	ramp.begin_resize(1)
	ramp.resize_endpoint(fixed + Vector2(8, -7) * 16)
	ramp.end_resize()
	check(ramp.rise == 6, "Endpoint extended through an actual monster")
	monster.queue_free()
	level.editor.history.undo()
	check(ramp.get_variant_state() == before, "Ribbon resize undo failed")
	level.editor.history.redo()
	check(ramp.rise == 6, "Ribbon resize redo failed")
	ramp.restore_variant_state(before)
	var stair := add_part(level, GroundPart, ramp.position + Vector2(32, 32)) as GroundPart
	GroundPart.refresh_all(parts)
	var image: Image = stair.get_node("%Sprite").texture.get_image()
	check(image.get_pixel(0, 0).a == 0 and image.get_pixel(15, 15).a > 0, "Overlapping stair terrain was not cut to the slope surface")
	var stair_shape := SlopePart.terrain_polygon(Level.to_grid(stair.position), [ramp])
	check(not Geometry2D.is_point_in_polygon(Vector2(1, 1), stair_shape) and Geometry2D.is_point_in_polygon(Vector2(15, 15), stair_shape), "Fused stair physics differs from the diagonal art")
	level.editor.erase_part(ramp)
	await ticks(2)
	check(stair.get_node("%Sprite").texture is AtlasTexture, "Erasing a slope failed to restore authored stair art")
	level.editor.history.undo()
	await ticks(2)
	check(not stair.get_node("%Sprite").texture is AtlasTexture, "Undo failed to restore stair fusion")
	if capture:
		await capture_ribbons(level)
	print("SLOPE_EDITING_REGRESSIONS lengths=44 stable-ground=12 monster-gap=16px stair-fusion=PASS")


func capture_ribbons(level: Level) -> void:
	for part in level.current_sub_area.get_parts().get_children():
		if not (part is StartingGround or part is EditorPlayer):
			part.queue_free()
	await ticks(2)
	# Real editor art:5x5,6x6 in both directions, steep and gentle standalone,
	# then a staircase union. No triangle fill in the upper row.
	for entry in [[Vector2(144, -368), 4, false, true], [Vector2(272, -368), 5, false, false],
		[Vector2(592, -368), 4, true, true], [Vector2(784, -368), 4, true, false]]:
		slope(level, entry[0], entry[1], entry[2], entry[3])
	var fused_ramps: Array[SlopePart] = []
	for entry in [[Vector2(144, -176), false, true], [Vector2(304, -176), true, false]]:
		var fused := slope(level, entry[0], 4, entry[1], entry[2])
		fused_ramps.append(fused)
		for x in fused.width_cells():
			var top := floori(minf(fused.surface_y(x * 16), fused.surface_y((x + 1) * 16)) / 16)
			for y in range(top, 5):
				add_part(level, GroundPart, fused.position + Vector2(x, y) * 16)
	GroundPart.refresh_all(level.current_sub_area.get_parts())
	Utility.camera_position = Vector2(96, -432)
	await ticks(24)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slopes_ribbons.png")
	Utility.camera_position = Vector2(576, -432)
	await ticks(12)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slopes_ribbons_gentle.png")
	Utility.camera_position = Vector2(96, -224)
	await ticks(12)
	await RenderingServer.frame_post_draw
	var fusion_gpu := get_viewport().get_texture().get_image()
	fusion_gpu.save_png("res://.godot/porting-tests/slopes_stair_fusion.png")
	var grass_samples := 0
	var grass_matches := 0
	for fused in fused_ramps:
		for sprite: Sprite2D in fused._art.get_children():
			if sprite.texture is AtlasTexture:
				continue
			var source := sprite.texture.get_image()
			for x in source.get_width():
				for y in source.get_height():
					var color := source.get_pixel(x, y)
					if color.a < 0.99 or color.g <= color.r or color.g < 0.3:
						continue
					var pixel: Vector2i = sprite.get_global_transform_with_canvas() * Vector2(x + 0.5, y + 0.5)
					if Rect2i(176, 120, 848, 380).has_point(pixel):
						grass_samples += 1
						grass_matches += int(fusion_gpu.get_pixelv(pixel).is_equal_approx(color))
	check(grass_samples > 400 and grass_matches == grass_samples, "Later-placed staircase ground covered the fused slope grass")
	print("SLOPE_FUSION_GPU grass=", grass_matches, "/", grass_samples)
	# Editable starting templates, explicitly outside the automatic override path.
	DirAccess.make_dir_recursive_absolute("res://textures/tiles/slopes/templates")
	for right in [false, true]:
		for filled in [false, true]:
			var template := Image.create(32, 32, false, Image.FORMAT_RGBA8)
			for lower in [false, true]:
				template.blit_rect(SlopePart.surface_texture(true, right, lower, filled).get_image(), Rect2i(0, 0, 32, 16), Vector2i(0, 16 if lower else 0))
			template.save_png("res://textures/tiles/slopes/templates/gentle_%s%s.png" % ["up" if right else "down", "_filled" if filled else ""])


func check_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	data.MAIN.NIVEL.append({"object": "godotwe_slope", "x_pos": 400, "y_pos": 160, "slope_rise": 4, "slope_right": 0, "future_slope": 73})
	data.MAIN.NIVEL.append({"object": "godotwe_gentle_slope", "x_pos": 544, "y_pos": 160, "slope_rise": 3, "slope_right": 1})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for row in data.S0.S4:
			row.ID = row.object
			row.xx = row.x_pos
			row.yy = row.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				row.erase(key)
	var path := "res://.godot/porting-tests/slopes_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_terrain.tres")
	ring.page_index = 0
	for index in [1, 2]:
		check(ring.choose(index), "Slope palette slot is disabled")
		var part := level.editor.place(Vector2i(14 + index * 5, -20)) as SlopePart
		check(part != null and part.gentle == (index == 2), "Palette created the wrong slope angle")
		var before := part.get_variant_state()
		for dx in [-1, 1]:
			for dy in [-1, 1]:
				part.restore_variant_state(before)
				part.begin_resize(1)
				# Disable only the mouse-driven preview; use the same endpoint edit.
				var fixed := part.position + part.endpoints()[0]
				part.resize_endpoint(fixed + Vector2(dx * (3 * (2 if part.gentle else 1) + 1), dy * 3) * 16)
				part.end_resize()
				check(part.rise == 3 and part.rises_right == (dx * dy < 0), "Endpoint did not extend/flip at the fixed angle")
				var after := part.get_variant_state()
				check((part.position + part.endpoints()[0 if dx > 0 else 1]).is_equal_approx(fixed), "Resize moved the untouched endpoint")
				level.editor.history.undo()
				check(part.get_variant_state() == before, "Slope resize undo lost origin/angle/extent")
				level.editor.history.redo()
				check(part.get_variant_state() == after, "Slope resize redo failed")
		part.restore_variant_state(before)
		part.held = true
		part.position += Vector2(16, 0)
		part.held = false
		check(part.position == before.position + Vector2(16, 0), "Slope body could not be moved")
		level.editor.history.undo()
		check(part.position == before.position, "Slope move undo failed")
		level.editor.erase_part(part)
		level.editor.history.undo()
		check(part.is_inside_tree(), "Slope erase undo failed")
	var connected_a := slope(level, Vector2(288, -160), 2, false, true)
	var connected_b := slope(level, Vector2(320, -192), 2, true, true)
	GroundPart.refresh_all(level.current_sub_area.get_parts())
	check(connected_a.trim_right and connected_b.trim_left, "Steep/gentle ramp join retained flat caps")
	var ground := add_part(level, GroundPart, Vector2(272, -128)) as GroundPart
	GroundPart.refresh_all(level.current_sub_area.get_parts())
	var tex: AtlasTexture = ground.get_node("%Sprite").texture
	check(tex.region.position.x != 80, "Adjacent ground still drew its isolated right edge")
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Slope signed save failed")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var found := [false, false]
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is SlopePart and part.position == Vector2(400, -272):
			found[0] = part.rise == 4 and not part.rises_right and part.swe_data.future_slope == 73
		if part is GentleSlopePart and part.position == Vector2(544, -272):
			found[1] = part.rise == 3 and part.rises_right
	check(not false in found, "Slope signed round trip lost geometry or unknown fields")
	reopened.free()
	level.queue_free()
	await ticks(2)


func make_course(level: Level) -> void:
	for part in level.current_sub_area.get_parts().get_children():
		if not (part is StartingGround or part is EditorPlayer):
			part.queue_free()
	await ticks(2)
	for span in [[112, 272, -96], [368, 432, -160], [528, 672, -96], [832, 928, -160]]:
		for x in range(span[0], span[1], 16):
			add_part(level, GroundPart, Vector2(x, span[2]))
	up = slope(level, Vector2(272, -160), 4, false, true)
	# An authored staircase, added AFTER the ramp, exercises the native clipped
	# tile bodies as well as the standalone ribbon courses below.
	for x in up.width_cells():
		var top := floori(minf(up.surface_y(x * 16), up.surface_y((x + 1) * 16)) / 16)
		for y in range(top, 5):
			add_part(level, GroundPart, up.position + Vector2(x, y) * 16)
	down = slope(level, Vector2(432, -160), 4, false, false)
	shallow = slope(level, Vector2(672, -160), 4, true, true)
	GroundPart.refresh_all(level.current_sub_area.get_parts())
	for part in level.current_sub_area.get_parts().get_children():
		if part is EditorPlayer:
			part.position = Vector2(176, -112)


func park(player: Player, at: Vector2) -> void:
	release_input()
	player.state_machine.switch(PlayerIdleState)
	player.position = at
	player.previous_position = at
	player.velocity = Vector2.ZERO


func check_walk(level: Level) -> void:
	var player := level.hud.player
	for entry in [[Vector2(250, -96), "player_right", 380], [Vector2(548, -96), "player_left", 420],
		[Vector2(646, -96), "player_right", 845]]:
		park(player, entry[0])
		await ticks(4)
		Input.action_press(entry[1])
		var worst_gap := 0.0
		var air_ticks := 0
		var contact_samples := 0
		var offset_error := 0.0
		for tick in 250:
			await ticks(1)
			if not player.is_on_floor():
				air_ticks += 1
			worst_gap = maxf(worst_gap, absf(player.position.y - player.previous_position.y))
			for ramp: SlopePart in [up, down, shallow]:
				var x := player.position.x - ramp.position.x
				if player.is_on_floor() and x > 24 and x < ramp.width_cells() * 16 - 24:
					var expected := ramp.position.y + ramp.surface_y(x)
					var actual := Utility.get_bounding_box(player).end.y + SlopeBody.visual_floor_offset(player).y
					offset_error = maxf(offset_error, absf(actual - expected))
					contact_samples += 1
			if (player.position.x >= entry[2] if entry[1] == "player_right" else player.position.x <= entry[2]):
				break
		print("SLOPE_WALK ", entry[1], " x=", player.position.x, " y=", player.position.y, " airticks=", air_ticks)
		check((player.position.x >= entry[2] if entry[1] == "player_right" else player.position.x <= entry[2]), "Mario stalled on slope or cap seam")
		check(air_ticks <= 2 and worst_gap < 4, "Walking slope lost contact or popped vertically")
		check(contact_samples > 5 and offset_error < 0.16, "Slope art foot anchor did not follow the center surface")
	# A full downhill traversal must keep native floor contact as well.
	park(player, Vector2(416, -160))
	await ticks(3)
	Input.action_press("player_right")
	Input.action_press("player_run")
	var air := 0
	for i in 140:
		await ticks(1)
		if player.position.x < 555 and not player.is_on_floor():
			air += 1
		if player.position.x >= 555:
			break
	print("SLOPE_DOWN x=", player.position.x, " air=", air, " velocity=", player.velocity)
	check(player.position.x >= 555 and air <= 2, "Running downhill detached from the slope")
	release_input()


func check_jump_slide(level: Level) -> void:
	var player := level.hud.player
	park(player, Vector2(476, -150))
	await ticks(12)
	Input.action_press("player_down")
	await ticks(15)
	check(player.state_machine.current_state is PlayerSlopeSlideState and player.sprite.animation == &"slide" and player.velocity.x > 30, "Down on slope did not enter downhill sliding")
	var incoming := player.velocity.x
	Input.action_press("player_jump")
	await ticks(2)
	check(player.state_machine.current_state is PlayerJumpingState and player.velocity.y < -100 and player.velocity.x >= incoming - 5, "Slope jump lost its horizontal momentum")
	release_input()
	park(player, Vector2(324, -150))
	await ticks(15)
	Input.action_press("player_jump")
	await ticks(2)
	check(player.velocity.y < -100, "Mario cannot jump off an uphill slope")
	release_input()
	# Sliding defeats an actual overlapping ordinary enemy through its sensor.
	park(player, Vector2(472, -150))
	await ticks(12)
	Input.action_press("player_down")
	await ticks(10)
	var enemy: Galoomba = load("res://scenes/level/entities/galoomba.tscn").instantiate()
	enemy.position = player.position + Vector2(12, 3)
	level.current_sub_area.add(enemy)
	await ticks(5)
	check(not is_instance_valid(enemy) or enemy.is_queued_for_deletion(), "Slope slide did not defeat an ordinary enemy")
	check(not player.is_dead(), "Sliding ordinary contact damaged Mario")
	release_input()


func check_actors(level: Level) -> void:
	var player := level.hud.player
	park(player, Vector2(180, -96))
	player.invulnerability_left = 100
	for type in [MushroomPart, GoombaPart, KoopaPart]:
		if type == KoopaPart:
			# Keep the downhill route inside the source actor-activation strip;
			# a parked camera otherwise suspends the actor around worldx520.
			park(player, Vector2(640, -96))
			await ticks(3)
		var source := type.create() as Part
		source.position = Vector2(416, -176) if type == KoopaPart else Vector2(256, -112)
		if source is KoopaPart:
			source.variant = load("res://resources/content/smw_koopa_red.tres")
		level.current_sub_area.add_part(source)
		source.load()
		source.build()
		await ticks(2)
		var actor: CharacterBody2D
		for body in level.current_sub_area.get_foreground().get_children():
			if (body is Mushroom if type == MushroomPart else body is Koopa if type == KoopaPart else body is Galoomba):
				actor = body
		check(actor != null, "Slope actor fixture did not build")
		actor.get_node("SlideComponent").direction = 1
		var blocked := false
		for i in 440:
			await ticks(1)
			if not is_instance_valid(actor):
				break
			blocked = blocked or actor.is_on_wall()
			if actor.position.x > (555 if type == KoopaPart else 380):
				break
		print("SLOPE_ACTOR ", type.get_global_name(), " alive=", is_instance_valid(actor), " x=", actor.position.x if is_instance_valid(actor) else -1, " wall=", blocked)
		check(is_instance_valid(actor) and actor.position.x > (555 if type == KoopaPart else 380) and not blocked, "Walking enemy/item treated the slope as a wall or false ledge")
		if is_instance_valid(actor):
			actor.queue_free()
		source.queue_free()
		await ticks(2)


func check_join(level: Level) -> void:
	var a := slope(level, Vector2(304, -288), 2, false, true)
	var b := slope(level, Vector2(336, -320), 2, true, true)
	a.build()
	b.build()
	var player := level.hud.player
	park(player, Vector2(311, -256))
	await ticks(4)
	Input.action_press("player_right")
	var air := 0
	var wall := false
	for i in 220:
		await ticks(1)
		air += int(not player.is_on_floor())
		wall = wall or player.is_on_wall()
		if player.position.x > 420:
			break
	check(player.position.x > 420 and air <= 2 and not wall, "Connected steep/gentle slopes retained a ledge or floor gap")
	release_input()
	for body in level.current_sub_area.get_foreground().get_children():
		if body is SlopeBody and body.position in [a.position, b.position]:
			body.queue_free()
	a.queue_free()
	b.queue_free()
	await ticks(2)


func check_gpu(level: Level) -> void:
	# Read actual source-colored diagonal pixels, with the camera transform from
	# frame_pre_draw rather than a later interpolation frame.
	var body: SlopeBody
	var player := level.hud.player
	park(player, Vector2(760, -148))
	await ticks(20)
	for node in level.current_sub_area.get_foreground().get_children():
		if node is SlopeBody and node.position == shallow.position:
			body = node
	var sprites: Array[Sprite2D] = []
	for node in body.get_children():
		if node is Sprite2D and node.texture.get_width() == 32 and node.position.x == 48:
			sprites.append(node)
	check(sprites.size() == 2, "Gentle slope did not retain its paired2:1 grass fringe")
	var sampled := {}
	var sample := func():
		var transforms: Array[Transform2D] = []
		for sprite in sprites:
			transforms.append(sprite.get_global_transform_with_canvas())
		sampled.transforms = transforms
		sampled.hero_world = level.current_sub_area.presentation.global_transform_for(player.sprite)
		sampled.hero_canvas = level.current_sub_area.presentation.canvas_transform_for(player.sprite)
	RenderingServer.frame_pre_draw.connect(sample)
	Utility.camera_position = Vector2(576, -216)
	await ticks(3)
	await RenderingServer.frame_post_draw
	var gpu := get_viewport().get_texture().get_image()
	RenderingServer.frame_pre_draw.disconnect(sample)
	var matched := 0
	var expected := 0
	for index in sprites.size():
		var source := sprites[index].texture.get_image()
		for x in range(2, 30):
			for y in 16:
				var color := source.get_pixel(x, y)
				if color.a < 0.99:
					continue
				var pixel: Vector2i = sampled.transforms[index] * Vector2(x + 0.5, y + 0.5)
				if not Rect2i(Vector2i.ZERO, gpu.get_size()).has_point(pixel):
					continue
				expected += 1
				if gpu.get_pixelv(pixel).is_equal_approx(color):
					matched += 1
	check(expected > 400 and matched == expected, "GPU slope edge pixels diverged from the paired2:1 art")
	print("SLOPE_GPU_PIXELS ", matched, "/", expected)
	var hero := player.sprite.sprite_frames.get_frame_texture(player.sprite.animation, player.sprite.frame).get_image()
	var used := hero.get_used_rect()
	var contact: Vector2 = sampled.hero_world * (player.sprite.offset + Vector2(used.get_center().x, used.end.y))
	var floor_y := shallow.position.y + shallow.surface_y(player.position.x - shallow.position.x)
	check(absf(contact.y - floor_y - 1) < 0.16, "Rendered Mario must overlap the slope center by one pixel")
	var shoe_pixels := 0
	var shoe_matches := 0
	for x in range(used.position.x, used.end.x):
		var color := hero.get_pixel(x, used.end.y - 1)
		if color.a < 0.99:
			continue
		var pixel: Vector2i = sampled.hero_canvas * (player.sprite.offset + Vector2(x + 0.5, used.end.y - 0.5))
		shoe_pixels += 1
		if gpu.get_pixelv(pixel).is_equal_approx(color):
			shoe_matches += 1
	check(shoe_pixels > 0 and shoe_pixels == shoe_matches, "GPU Mario shoes did not match the corrected planted pose")
	print("SLOPE_SHOES ", shoe_matches, "/", shoe_pixels, " overlap=", contact.y - floor_y)
	gpu.save_png("res://.godot/porting-tests/slopes_gentle.png")
	var joins := Image.create(240, 80, false, Image.FORMAT_RGBA8)
	joins.blit_rect(gpu, Rect2i(315, 335, 120, 80), Vector2i.ZERO)
	joins.blit_rect(gpu, Rect2i(680, 155, 120, 80), Vector2i(120, 0))
	joins.resize(720, 240, Image.INTERPOLATE_NEAREST)
	joins.save_png("res://.godot/porting-tests/slopes_connections.png")
