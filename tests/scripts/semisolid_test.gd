# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"

var capture := false
var area: SubArea
var panels: Array[SemisolidPart] = []
var _pixels := 0
var _matches := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-semisolid" in OS.get_cmdline_user_args()
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	area = level.current_sub_area
	for part in area.get_parts().get_children():
		if not (part is StartingGround or part is EditorPlayer):
			part.queue_free()
	await ticks(2)
	var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_terrain.tres")
	check(ring.choose(6) and level.editor.get_selected_part() == SemisolidPart, "Semisolid palette entry is not usable")
	var panel := level.editor.place(Vector2i(12, -12)) as SemisolidPart
	check(panel != null and panel.dimensions == Vector2i(3, 3), "Semisolid initial placement is not3x3")
	level.editor.history.undo()
	check(not panel.is_inside_tree(), "Platform placement undo failed")
	level.editor.history.redo()
	check(panel.is_inside_tree(), "Platform placement redo failed")
	panel.set_process(false) # Drive this endpoint gesture deterministically.
	panel.begin_resize()
	panel.resize_to(Vector2(272, -240))
	check(panel.dimensions == Vector2i(6, 6) and panel.position == Vector2(192, -240),
		"Resize did not preserve the bottom-left corner")
	var snapshot := SWELevelSerializer.snapshot(level, LevelProcessor.SWE_OBJECT_TABLE, LevelProcessor.SWE_GROUND_FRAME_TABLE)
	check(snapshot.error != OK, "Saving an unfinished resize gesture was allowed")
	panel.end_resize()
	level.editor.history.undo()
	check(panel.dimensions == Vector2i(3, 3) and panel.position == Vector2(192, -192), "One resize undo did not restore the complete geometry")
	level.editor.history.redo()
	check(panel.dimensions == Vector2i(6, 6) and panel.position.y == -240, "Resize redo lost dependent position")
	panel.begin_resize()
	panel.resize_to(Vector2(-100, 300))
	panel.end_resize()
	check(panel.dimensions == Vector2i(3, 3), "Resize crossed the minimum3x3 size")
	panel.begin_resize()
	panel.resize_to(Vector2(10000, -10000))
	panel.end_resize()
	check(panel.dimensions.x == 21 and panel.position.y == -432 and panel.fits_bounds(panel.position), "Resize ignored source maximum or room bounds")
	panel.restore_variant_state({"id": &"first", "dimensions": Vector2i(4, 5), "position": Vector2(192, -192)})
	var window: EditorWindow = load("uid://dyw1evq8k8n58").instantiate()
	window.part = panel
	window.target_position = panel.position
	level.editor.get_node("%WindowLayer").add_child(window)
	await ticks(2)
	check(window.get_node("Content/Options").get_child_count() == 3, "Native variant window has no three appearance buttons")
	window.select(&"third")
	await ticks(8)
	check(panel.appearance == 2 and panel.dimensions == Vector2i(4, 5), "Variant window changed geometry or lost the selected style")
	level.editor.history.undo()
	check(panel.appearance == 0 and panel.dimensions == Vector2i(4, 5), "Style undo lost geometry")
	level.editor.history.redo()
	var next := level.editor.place(Vector2i(20, -12)) as SemisolidPart
	check(next.appearance == 2, "Palette did not remember the chosen platform appearance")
	level.editor.erase_part(next)
	panel.swe_data.future_platform = {"keep": 17}
	level.source_swe.MAIN.PLATAFORMAS = [{"object": "obj_future_platform", "custom": 99}]
	var path := "res://.godot/porting-tests/semisolid_roundtrip.swe"
	var saved := await level.editor.save_to_path(path)
	check(saved.error == OK, "Legacy platform save failed")
	await check_saved(path, Vector2i(4, 5), 2)
	# Erasing/re-saving drops only this represented row, including after the
	# source index/revision changes; undo can restore the detached platform.
	level.editor.erase_part(panel)
	saved = await level.editor.save_to_path(path)
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(path)).data
	check(data.MAIN.PLATAFORMAS.size() == 1 and data.MAIN.PLATAFORMAS[0].custom == 99, "Platform erase/save removed an unknown source row")
	level.editor.history.undo()
	saved = await level.editor.save_to_path(path)
	await check_saved(path, Vector2i(4, 5), 2)
	await check_modern(path)
	# Ordinary placement remains possible through the entire decorative area.
	var dirt := GroundPart.create()
	dirt.position = panel.position + Vector2(16, 16)
	area.add_part(dirt)
	dirt.load()
	await ticks(2)
	check(panel.foreground_at(dirt.position + Vector2(8, 8)) == dirt, "Background platform stole foreground Part picking")
	check(CoinPart.is_placeable(Level.to_grid(panel.position + Vector2(32, 16)), area.get_world_2d()), "Decorative platform body blocked ordinary object placement")
	panel.position = dirt.position
	panel._check_validity()
	check(panel._valid_space, "Platform cannot overlap ordinary ground")
	dirt.queue_free()
	panel.position = Vector2(176, -208)
	panel.dimensions = Vector2i(3, 3)
	panel.appearance = 0
	panel.refresh_environment()
	panels.append(panel)
	for i in range(1, 3):
		var part := SemisolidPart.create()
		part.appearance = i
		part.dimensions = Vector2i(4, 5) if i == 1 else Vector2i(7, 4)
		part.position = Vector2(256 if i == 1 else 352, -208)
		area.add_part(part)
		part.load()
		panels.append(part)
	for theme in SMWTheme.CHOICES:
		area.set_theme(theme)
		for part in panels:
			check_art(part, theme)
		if capture:
			await snap("editor_" + SMWTheme.info(theme).key)
	area.set_theme(Level.LevelTheme.OVERWORLD)
	# A lower top must draw in front, even when the existing nodes were created
	# in the opposite order. This also catches flattening everything to one z
	# without retaining source depth.
	panels[0].position = Vector2(256, -208)
	panels[1].position = Vector2(256, -224)
	panels[0].refresh_environment()
	panels[1].refresh_environment()
	await ticks(2)
	check(panels[0].get_index() > panels[1].get_index(), "Platform top-y order did not update after moving")
	if capture:
		await snap("overlap")
	# Real player/item/enemy bodies, an ordinary floor and one-way top.
	for other in panels.slice(1):
		other.queue_free()
	panels.resize(1)
	await ticks(1)
	panel.restore_variant_state({"id": &"first", "dimensions": Vector2i(4, 3), "position": Vector2(208, -96)})
	for x in range(160, 512, 16):
		var floor_part := GroundPart.create()
		floor_part.position = Vector2(x, -32)
		area.add_part(floor_part)
		floor_part.load(false)
	GroundPart.refresh_all(area.get_parts())
	level.play()
	await ticks(8)
	var player := level.hud.player
	park(player, Vector2(232, -32))
	await ticks(3)
	Input.action_press("player_jump")
	var crossed := false
	var peak := player.position.y
	for i in 80:
		await ticks(1)
		peak = minf(peak, player.position.y)
		crossed = crossed or (player.position.y > -96 and Utility.get_bounding_box(player).position.y < -96 and player.velocity.y < 0)
	check(crossed and peak < -100 and player.is_on_floor() and absf(player.position.y + 96) < 0.2,
		"Real jump could not pass upward and land on the one-way top")
	release_input()
	if capture:
		await snap("stand")
	Input.action_press("player_right")
	await ticks(58)
	release_input()
	check(player.position.x > 280 and player.position.y > -80, "Platform side or decorative body blocked movement")
	park(player, Vector2(176, -32))
	var item: Mushroom = load("res://scenes/entities/mushroom.tscn").instantiate()
	item.position = Vector2(240, -144)
	item.get_node("SlideComponent").speed = 0
	area.add(item)
	var enemy: Galoomba = load("res://scenes/entities/galoomba.tscn").instantiate()
	enemy.position = Vector2(260, -144)
	enemy.get_node("SlideComponent").speed = 0
	area.add(enemy)
	await ticks(45)
	check(item.is_on_floor() and absf(item.position.y + 96) < 0.2 and enemy.is_on_floor() and absf(enemy.position.y + 96) < 0.2,
		"Existing item/enemy gravity did not use the native platform top")
	if capture:
		await snap("actors")
	level.edit()
	await ticks(4)
	check(area.get_foreground().get_child_count() == 0, "Editor return retained semisolid runtime bodies")
	level.play()
	await ticks(4)
	var count := 0
	for node in area.get_foreground().get_children():
		if String(node.name).begins_with("SemisolidPlatform"):
			count += 1
	check(count == 1, "Replay lost or duplicated the platform top")
	if capture:
		check(_pixels > 200 and _matches == _pixels, "Actual GL platform pixels differ from original source tiles")
		print("SEMISOLID_GPU ", _matches, "/", _pixels)
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("SEMISOLID_RESULT", level)


func check_art(part: SemisolidPart, theme: Level.LevelTheme) -> void:
	var source := SpriteLibrary.get_frames(StringName("spr_ssp%d_%s" % [part.appearance + 1, SMWTheme.info(theme).key]))
	var actual: Image = part.get_node("Graphics/Sprite").texture.get_image()
	actual.convert(Image.FORMAT_RGBA8)
	var originals: Array[Image] = []
	for i in 12:
		var original := source.get_frame_texture(&"default", i).get_image()
		original.convert(Image.FORMAT_RGBA8)
		originals.append(original)
	# Independent imperative source sequence, not SemisolidPart.frame_at().
	var row := 3
	for y in part.dimensions.y:
		var middle := row
		for x in part.dimensions.x:
			var edge := 0 if x == 0 else 2 if x == part.dimensions.x - 1 else 1
			var frame := edge if y == 0 else 9 + edge if y == part.dimensions.y - 1 else middle + edge
			check(actual.get_region(Rect2i(Vector2i(x, y) * 16, Vector2i(16, 16))).get_data() == originals[frame].get_data(),
					"Theme/style/width parity picked the wrong original platform tile")
			middle = 6 if middle == 3 else 3
		row = 6 if middle == 3 else 3


func check_saved(path: String, size: Vector2i, appearance: int) -> void:
	var reopened := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(reopened)
	await ticks(2)
	var found := false
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is SemisolidPart:
			found = part.dimensions == size and part.appearance == appearance and part.swe_data.future_platform.keep == 17
	check(found, "Signed platform roundtrip lost geometry/style/unknown fields")
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(path)).data
	var wrapper: Dictionary = data.get("S0", data.get("MAIN"))
	var entries: Array = wrapper.get("S7", wrapper.get("PLATAFORMAS"))
	check(entries.size() == 2 and entries[0].custom == 99, "Platform roundtrip lost source order/unknown rows")
	reopened.free()


func check_modern(path: String) -> void:
	var source: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(path)).data.MAIN
	var data := {"S0": {"S1": source.AJUSTES, "S2": source.SUELO, "S4": source.NIVEL, "S7": source.PLATAFORMAS}}
	for row in data.S0.S7:
		row.ID = row.object
		row.erase("object")
		if row.has("x_pos"):
			row.xx = row.x_pos
			row.yy = row.y_pos
			row.erase("x_pos")
			row.erase("y_pos")
	var modern := "res://.godot/porting-tests/semisolid_modern.swe"
	var file := FileAccess.open(modern, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var reopened := await LevelProcessor.from_swe(modern)
	var saved := await LevelProcessor.save_swe(reopened, modern)
	check(saved.error == OK, "Modern signed platform save failed")
	reopened.free()
	await check_saved(modern, Vector2i(4, 5), 2)


func park(player: Player, at: Vector2) -> void:
	release_input()
	player.position = at
	player.previous_position = at
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)


func snap(label: String) -> void:
	Utility.camera_position = Vector2(128, -264 if label.begins_with("editor") else -216)
	await ticks(26 if label == "editor_overworld" else 2)
	var sampled := []
	var sample := func():
		for panel in ([panels[0]] if label == "overlap" else panels):
			var sprite: Sprite2D = panel.get_node("Graphics/Sprite")
			sampled.append({"image": sprite.texture.get_image(), "transform": sprite.get_global_transform_with_canvas(),
					"handle": panel._handle.sprite_frames.get_frame_texture(panel._handle.animation, panel._handle.frame).get_image() if panel._handle.is_visible_in_tree() else null,
					"handle_transform": panel._handle.get_global_transform_with_canvas(), "handle_offset": panel._handle.offset})
	RenderingServer.frame_pre_draw.connect(sample, CONNECT_ONE_SHOT)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var before := Vector2i(_matches, _pixels)
	if label.begins_with("editor") or label in ["stand", "overlap"]:
		for entry: Dictionary in sampled:
			var original: Image = entry.image
			for y in range(3, original.get_height(), 8):
				for x in range(3, original.get_width(), 8):
					var color := original.get_pixel(x, y)
					var at := Vector2i(entry.transform * Vector2(x + 0.5, y + 0.5))
					if color.a < 1 or at.x < 180 or at.x > 1080 or at.y < 120 or at.y > 550:
						continue
					if entry.handle != null:
						var local := Vector2i(entry.handle_transform.affine_inverse() * (Vector2(at) + Vector2(0.5, 0.5)) - entry.handle_offset)
						if Rect2i(Vector2i.ZERO, entry.handle.get_size()).has_point(local) and entry.handle.get_pixelv(local).a > 0:
							continue
					_pixels += 1
					if image.get_pixelv(at).is_equal_approx(color):
						_matches += 1
		print("SEMISOLID_VIEW ", label, " ", _matches - before.x, "/", _pixels - before.y)
	image.save_png("res://.godot/porting-tests/semisolid_%s.png" % label)
	if label == "actors":
		image.save_png("res://.godot/porting-tests/slice_semisolid.png")
