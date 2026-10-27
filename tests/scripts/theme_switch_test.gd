# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"

var capture := false
var terrain_samples: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-theme-switch" in OS.get_cmdline_user_args()
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(30)
	var area := level.current_sub_area
	var editor := level.editor
	var panel = editor.get_node("LeftPanel/LevelThemePanel")
	var start: StartingGround
	for part in area.get_parts().get_children():
		if part is StartingGround:
			start = part
	var ground := GroundPart.create()
	ground.position = Vector2(176, -32)
	area.add_part(ground)
	ground.load()
	var block := HiddenBlockPart.create()
	block.position = Vector2(208, -96)
	block.content_id = &"star"
	area.add_part(block)
	block.load()
	var muncher := MuncherPart.create()
	muncher.position = Vector2(304, -48)
	muncher.wings = true
	area.add_part(muncher)
	muncher.load()
	var ramp := SlopePart.create()
	ramp.position = Vector2(352, -64)
	area.add_part(ramp)
	ramp.load()
	# Previous acceptance had a thin floor and checked only atlas identity.
	# Exercise the source roles on actual thick terrain and both narrow strips.
	for x in 6:
		for y in 5:
			var frame := 43
			if y == 0:
				frame = 9 if x == 0 else 10 if x == 5 else 21
			elif y == 4:
				frame = 8 if x == 0 else 11 if x == 5 else 27
			elif x == 0 or x == 5:
				frame = 18 if x == 0 else 24
			put_terrain(area, Vector2(176 + x * 16, -192 + y * 16), frame)
	for x in 6:
		put_terrain(area, Vector2(288 + x * 16, -192), 1 if x == 0 else 3 if x == 5 else 46)
	for y in 5:
		put_terrain(area, Vector2(400, -192 + y * 16), 2 if y == 0 else 0 if y == 4 else 45)
	put_terrain(area, Vector2(352, -128), 44)
	GroundPart.refresh_all(area.get_parts())
	var count := area.get_parts().get_child_count()
	var region := ground.swe_atlas
	for theme: Level.LevelTheme in SMWTheme.CHOICES:
		var before := area.level_theme
		var before_environment := area.theme_state()
		panel.open()
		await ticks(18)
		check(panel.choices.size() == 10 and not panel.choices[theme].disabled, "Native theme panel lacks one of SMM2's ten choices")
		check(panel.choices[theme].text.is_empty() and panel.choices[theme].size.x > panel.choices[theme].size.y,
			"Theme menu regressed to text buttons instead of landscape cards")
		if capture and theme == Level.LevelTheme.UNDERGROUND:
			await snap("menu", level)
		panel.choices[theme].pressed.emit()
		await ticks(18)
		check_ground_frames(area)
		check(area.level_theme == theme and editor.part_interact, "Theme button did not apply or close its native popout")
		check(area.get_parts().get_child_count() == count and ground.position == Vector2(176, -32)
				and block.content_id == &"star" and muncher.wings, "Theme change lost authored objects, contents or variants")
		check(ground.swe_atlas == region and ground._tex.atlas == SMWTheme.atlas(area), "Theme replaced native terrain rules or kept stale art")
		check((start.terrain_textures[Vector2i.ZERO] as AtlasTexture).atlas == ground._tex.atlas, "Starting and authored ground disagree on theme")
		check(MusicPlayer.stream == SMWTheme.music_for(area, true), "Theme edit music did not switch")
		check(is_instance_valid(area.liquid) == (theme in [Level.LevelTheme.CASTLE, Level.LevelTheme.FOREST]),
			"Theme switch retained/omitted a liquid surface")
		if theme in [Level.LevelTheme.CASTLE, Level.LevelTheme.FOREST]:
			check(area.water_start_y == -16 and area.liquid.position.y == -4, "Entering castle reused a stale non-liquid water height")
		if theme != before:
			editor.history.undo()
			check(area.theme_state() == before_environment, "Theme undo lost the previous environment or liquid settings")
			editor.history.redo()
			check(area.level_theme == theme, "Theme redo failed")
			await ticks(2)
		var path := "res://.godot/porting-tests/theme_%s.swe" % SMWTheme.info(theme).key
		var saved := await editor.save_to_path(path)
		check(saved.error == OK, "Theme signed save failed")
		var reopened := await LevelProcessor.from_swe(path)
		check(reopened.current_sub_area.level_theme == theme, "SWE reopening restored a stale theme")
		reopened.free()
		if capture:
			await snap("editor_%s" % SMWTheme.info(theme).key, level)
		level.play()
		await ticks(20)
		check(MusicPlayer.stream == SMWTheme.music_for(area, false), "Theme play music did not switch")
		check(not panel.choose(Level.LevelTheme.OVERWORLD), "Theme picker accepted a runtime change")
		var matching_ground := 0
		for node in area.get_foreground().get_children():
			var sprite := node.get_node_or_null("Sprite") as Sprite2D
			if sprite != null and sprite.texture is AtlasTexture and sprite.texture.atlas == SMWTheme.atlas(area):
				matching_ground += 1
		check(matching_ground > 10, "Theme editor art did not reach runtime ground")
		if capture:
			await snap("play_%s" % SMWTheme.info(theme).key, level)
		level.edit()
		await ticks(4)
		check(MusicPlayer.stream == SMWTheme.music_for(area, true), "Editor return kept play music")
		check(area.get_foreground().get_child_count() == 0, "Theme play/return retained runtime bodies")
	await check_night(level, panel)
	if not capture:
		await check_modern(level)
	if capture:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_theme_switch.png")
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("THEME_SWITCH_RESULT", level)

func put_terrain(area: SubArea, at: Vector2, frame: int) -> void:
	var tile := GroundPart.create()
	tile.position = at
	area.add_part(tile)
	tile.load()
	terrain_samples.append({"tile": tile, "frame": frame})

func check_ground_frames(area: SubArea) -> void:
	if area.level_theme == Level.LevelTheme.OVERWORLD:
		check(SMWTheme.atlas(area) == SMWTheme.GROUND, "Overworld must retain the original native atlas")
		return
	# Independent source roles: scr_auto_tile returns43 for filled dirt,44 for
	# isolated,45 vertical and46 horizontal. SWE's saved-frame table differs.
	var source := SpriteLibrary.get_frames(SMWTheme.ground_sprite(area))
	var pixels := SMWTheme.atlas(area).get_image()
	var roles := {Vector2i(5, 10): 44, Vector2i(5, 8): 45,
		Vector2i(0, 0): 9, Vector2i(5, 0): 10, Vector2i(0, 5): 8, Vector2i(5, 5): 11}
	for column in range(1, 5):
		roles[Vector2i(column, 0)] = 21
		roles[Vector2i(column, 1)] = 43
		roles[Vector2i(column, 5)] = 27
		roles[Vector2i(column, 6)] = 46
	for row in range(1, 5):
		roles[Vector2i(0, row)] = 18
		roles[Vector2i(5, row)] = 24
	for cell: Vector2i in roles:
		var expected := source.get_frame_texture(&"default", roles[cell]).get_image()
		var actual := pixels.get_region(Rect2i(cell * 16, Vector2i(16, 16)))
		expected.convert(Image.FORMAT_RGBA8)
		actual.convert(Image.FORMAT_RGBA8)
		check(actual.get_data() == expected.get_data(), "Theme %s native slot%s uses wrong source frame (expected%d)" % [SMWTheme.info(area.level_theme).key, cell, roles[cell]])
	for probe in terrain_samples:
		var actual: Image = probe.tile.get_node("%Sprite").texture.get_image()
		var expected := source.get_frame_texture(&"default", probe.frame).get_image()
		actual.convert(Image.FORMAT_RGBA8)
		expected.convert(Image.FORMAT_RGBA8)
		check(actual.get_data() == expected.get_data(), "Connected theme terrain at%s has wrong material/edge role%d" % [probe.tile.position, probe.frame])

func check_night(level: Level, panel) -> void:
	var area := level.current_sub_area
	var editor := level.editor
	var semisolid := SemisolidPart.create()
	semisolid.position = Vector2(480, -64)
	area.add_part(semisolid)
	semisolid.load()
	await ticks(2)
	for theme: Level.LevelTheme in SMWTheme.CHOICES:
		panel.choose(theme)
		await ticks(18)
		var data := SMWTheme.info(theme)
		var day_music := SMWTheme.music_for(area, true)
		var before := area.theme_state()
		panel.open()
		await ticks(18)
		check(not panel.night_toggle.disabled and not panel.night_toggle.night, "Night toggle missing or stuck on night")
		panel.night_toggle.pressed.emit()
		await ticks(18)
		check(area.night_mode and area.level_theme == theme and editor.part_interact, "Night toggle did not apply or close its popout")
		check(MusicPlayer.stream == day_music, "Night toggle changed edit music, which has no night variant")
		check(SMWTheme.ground_sprite(area) == data.get("night_ground", data.ground), "Night ground sprite rule wrong for " + data.key)
		if theme != Level.LevelTheme.OVERWORLD:
			check_ground_frames(area)
		if capture:
			await snap("editor_night_%s" % data.key, level)
		var backdrop := area.background.get_child(0) as SMWTheme.ThemeBackground
		check(backdrop != null and backdrop.frames.size() == data.night_backgrounds.size()
				and backdrop.frames[0] == SpriteLibrary.get_frames(data.night_backgrounds[0]).get_frame_texture(&"default", 0),
			"Night background missing or not the source loop for " + data.key)
		var ssp := String(SemisolidPart.sprite_name(area, 0))
		check(SpriteLibrary.has_sprite(ssp) and (ssp == "spr_ssp1_snow_night") == (theme == Level.LevelTheme.SNOW),
			"Night semisolid art rule wrong for " + data.key)
		if theme == Level.LevelTheme.FOREST:
			check(is_instance_valid(area.liquid) and not area.liquid.is_water() and area.water_start_y == before.start,
				"Forest night did not turn its water to poison at the same height")
		editor.history.undo()
		check(area.theme_state() == before, "Night undo lost the day environment")
		editor.history.redo()
		check(area.night_mode, "Night redo failed")
		var path := "res://.godot/porting-tests/theme_%s_night.swe" % data.key
		var saved := await editor.save_to_path(path)
		check(saved.error == OK, "Night save failed")
		var reopened := await LevelProcessor.from_swe(path)
		check(reopened.current_sub_area.level_theme == theme and reopened.current_sub_area.night_mode,
			"SWE reopening lost night mode")
		reopened.free()
		level.play()
		await ticks(20)
		check(MusicPlayer.stream == SMWTheme.music_for(area, false)
				and MusicPlayer.stream.resource_path.ends_with("_night.ogg"), "Night play music did not switch for " + data.key)
		level.edit()
		await ticks(4)
		panel.toggle_night()
		await ticks(18)
		check(not area.night_mode, "Night toggle did not return to day")
	semisolid.erase(true)
	await ticks(2)

func check_modern(level: Level) -> void:
	var data: Dictionary = level.source_swe.MAIN
	var modern := {"S0": {"S1": data.AJUSTES, "S2": data.SUELO, "S4": data.NIVEL}}
	for row in modern.S0.S4:
		row.ID = row.object
		row.xx = row.x_pos
		row.yy = row.y_pos
		for key in ["object", "x_pos", "y_pos"]:
			row.erase(key)
	modern.S0.S1[0].gametheme = "ghost"
	modern.S0.S1[0].erase("entorno")
	modern.S0.S1[0].future_theme = 73
	var path := "res://.godot/porting-tests/theme_modern.swe"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(modern))
	file.close()
	var reopened := await LevelProcessor.from_swe(path)
	check(reopened.current_sub_area.level_theme == Level.LevelTheme.MANSION, "Modern ghost alias was not restored")
	reopened.status = Level.Status.EDITING
	reopened.current_sub_area.level = reopened
	reopened.current_sub_area.set_theme(Level.LevelTheme.UNDERGROUND)
	var saved := await LevelProcessor.save_swe(reopened, path)
	check(saved.error == OK, "Modern theme save failed")
	var decoded: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(path)).data
	check(decoded.S0.S1[0].gametheme == "underground" and decoded.S0.S1[0].future_theme == 73, "Modern theme save lost alias/unknown fields")
	reopened.free()

func snap(label: String, _level: Level) -> void:
	# Keep the fixture's upper corners below the toolbar for terrain captures.
	Utility.camera_position = Vector2(64, -216 if label == "menu" else -248)
	await ticks(2)
	var sampled := {}
	var backdrop := _level.current_sub_area.background.get_child(0) as Background
	var sample := func():
		var transform := backdrop.get_global_transform_with_canvas()
		# WorldPresentation supplies this display-only correction on the server.
		transform.origin += transform.basis_xform(-(Vector2.ONE - backdrop.follow_scale) * Utility.camera_render_offset / Utility.camera_scale)
		sampled.transform = transform
		sampled.source = backdrop.texture.get_image()
		sampled.camera = Utility.camera_position
		sampled.terrain = _level.current_sub_area.get_foreground().get_global_transform_with_canvas()
	RenderingServer.frame_pre_draw.connect(sample)
	await RenderingServer.frame_post_draw
	RenderingServer.frame_pre_draw.disconnect(sample)
	var gpu := get_viewport().get_texture().get_image()
	if label.begins_with("editor_") or label.begins_with("play_"):
		var source: Image = sampled.source
		var matched := 0
		for x in [620, 700, 780, 860, 940, 1000]:
			for y in [130, 170, 210, 250, 290]:
				var at: Vector2 = sampled.transform.affine_inverse() * Vector2(x + 0.5, y + 0.5)
				at -= (Vector2.ONE - backdrop.follow_scale) * sampled.camera
				var color := source.get_pixel(posmod(floori(at.x), source.get_width()), posmod(floori(at.y), source.get_height()))
				if gpu.get_pixel(x, y).is_equal_approx(color):
					matched += 1
		check(matched >= 10, "Theme backdrop actual pixels do not match in clear areas: %s %d/30" % [label, matched])
		print("THEME_GPU ", label, " background=", matched, "/30")
		var terrain_matched := 0
		var terrain_total := 0
		var area := _level.current_sub_area
		var source_frames := SpriteLibrary.get_frames(SMWTheme.ground_sprite(area))
		for probe in terrain_samples:
			var expected: Image = probe.tile.get_node("%Sprite").texture.get_image() if area.level_theme == Level.LevelTheme.OVERWORLD else source_frames.get_frame_texture(&"default", probe.frame).get_image()
			# Stay clear of editor grid lines and exterior shadows; compare actual
			# opaque source pixels, independently of the adapter's atlas metadata.
			for x in [3, 7, 11]:
				for y in [3, 7, 11]:
					var pixel := Vector2i(sampled.terrain * (probe.tile.position + Vector2(x + 0.5, y + 0.5)))
					if pixel.x < 170 or pixel.x > 1040 or pixel.y < 110 or pixel.y > 575:
						continue
					var color := expected.get_pixel(x, y)
					if color.a < 1:
						continue
					terrain_total += 1
					if gpu.get_pixelv(pixel).is_equal_approx(color):
						terrain_matched += 1
		check(terrain_total > 100 and terrain_matched == terrain_total, "Actual theme terrain pixels wrong: %s %d/%d" % [label, terrain_matched, terrain_total])
		print("THEME_TERRAIN_GPU ", label, " pixels=", terrain_matched, "/", terrain_total)
	gpu.save_png("res://.godot/porting-tests/theme_%s.png" % label)
