# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Actual GL alpha readback, current-frame motion and native edit/play lifecycle.
## Run capture_slice.py --pixel-shadows; the dummy renderer cannot test shaders.

var trace: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	check(DisplayServer.get_name() != "headless", "Pixel shadows need the actual renderer")
	if failures.is_empty():
		await check_silhouette()
		await capture_native()
	var file := FileAccess.open("res://.godot/porting-tests/pixel_shadows.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(trace, "  "))
	file.close()
	print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("PIXEL_SHADOWS_RESULT")


func rendered(view: Viewport) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()


func check_silhouette() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(128, 128)
	view.world_2d = World2D.new()
	view.transparent_bg = true
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var area: SubArea = load("res://scenes/templates/sub_area_template.tscn").instantiate()
	view.add_child(area)
	var shadows := PixelShadows.new()
	shadows.sub_area = area
	area.add_child(shadows)
	var parent := Node2D.new()
	area.get_foreground().add_child(parent)
	var pixels := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	pixels.fill_rect(Rect2i(3, 2, 5, 7), Color.RED)
	var alternate := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	alternate.fill(Color.TRANSPARENT)
	alternate.fill_rect(Rect2i(1, 4, 9, 3), Color.BLUE)
	var frames := SpriteFrames.new()
	frames.add_frame(&"default", ImageTexture.create_from_image(pixels))
	frames.add_frame(&"default", ImageTexture.create_from_image(alternate))
	var source := AnimatedSprite2D.new()
	source.sprite_frames = frames
	source.position = Vector2(24, 24)
	source.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(source)
	var overlap := Sprite2D.new()
	var sheet := Image.create(36, 12, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	sheet.blit_rect(pixels, Rect2i(0, 0, 12, 12), Vector2i(6, 0))
	sheet.blit_rect(alternate, Rect2i(0, 0, 12, 12), Vector2i(18, 0))
	overlap.texture = ImageTexture.create_from_image(sheet)
	overlap.region_enabled = true
	overlap.region_rect = Rect2(6, 0, 24, 12)
	overlap.hframes = 2
	overlap.position = source.position + Vector2(2, 0)
	parent.add_child(overlap)
	# An unrelated canvas sprite must stay outside the silhouette.
	var aid := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = overlap.texture
	atlas.region = Rect2(6, 0, 12, 12)
	aid.texture = atlas
	aid.position = Vector2(6, 6)
	view.add_child(aid)
	var atlas_source := Sprite2D.new()
	atlas_source.texture = atlas
	atlas_source.position = Vector2(30, 32)
	parent.add_child(atlas_source)
	for scale_factor: float in [1.0, 2.0, 2.25, 4.0]:
		view.canvas_transform = Transform2D(Vector2(scale_factor, 0), Vector2(0, scale_factor), Vector2.ZERO)
		for pose in 3:
			overlap.frame = pose % 2
			overlap.flip_v = pose == 1
			source.frame = pose % 2
			source.flip_h = pose == 1
			source.flip_v = pose == 2
			source.rotation_degrees = 31.5 if pose == 2 else 0.0
			source.material = SpriteLibrary.ROTATION_MATERIAL if pose == 2 else null
			area.modulate.a = 0.8 if pose == 2 else 1.0
			parent.modulate.a = 0.5 if pose == 2 else 1.0
			source.self_modulate.a = 0.6 if pose == 2 else 1.0
			shadows.hide()
			var before := await rendered(view)
			shadows.show()
			var after := await rendered(view)
			# Render a translated original as the mask oracle. This also checks
			# fractional zoom and oblique edge coverage without rounding offsets.
			shadows.hide()
			parent.position = PixelShadows.OFFSET
			var translated := await rendered(view)
			parent.position = Vector2.ZERO
			var opaque_equal := true
			var alpha_error := 0.0
			var shadow_pixels := 0
			for y in range(12 * scale_factor, 128):
				for x in range(12 * scale_factor, 128):
					var original := before.get_pixel(x, y)
					var actual := after.get_pixel(x, y)
					if original.a == 1:
						opaque_equal = opaque_equal and original == actual
					if actual.a > original.a + 0.01:
						shadow_pixels += 1
					var shifted := translated.get_pixel(x, y).a
					var expected := original.a + shifted * 0.33 * (1 - original.a)
					alpha_error = maxf(alpha_error, absf(actual.a - expected))
			check(opaque_equal and alpha_error < 0.015 and shadow_pixels > 0,
					"Shadow changed solid pixels, compounded overlap alpha or lost the current pose: scale=%s pose=%s error=%s" % [scale_factor, pose, alpha_error])
			check(before.get_region(Rect2i(0, 0, 12 * scale_factor, 12 * scale_factor)).get_data()
					== after.get_region(Rect2i(0, 0, 12 * scale_factor, 12 * scale_factor)).get_data(), "Shadow leaked onto unrelated canvas art")
			trace.append({"probe": "alpha_union", "scale": scale_factor, "pose": pose,
				"max_alpha_error": alpha_error, "opaque_equal": opaque_equal, "shadow_pixels": shadow_pixels})
	# A source that moves/vanishes on this render must leave no stale copy.
	shadows.show()
	await rendered(view)
	var revision: int = shadows._copies[overlap.get_instance_id()].revision
	await rendered(view)
	await rendered(view)
	check(shadows._copies[overlap.get_instance_id()].revision == revision,
			"Static shadow commands were rebuilt without a source redraw")
	view.canvas_transform = Transform2D.IDENTITY
	area.modulate.a = 1
	parent.modulate.a = 1
	shadows.show()
	source.position = Vector2(84, 40)
	overlap.hide()
	atlas_source.hide()
	var moved := await rendered(view)
	check(moved.get_region(Rect2i(14, 14, 24, 24)).is_invisible(), "Moving source left a delayed shadow")
	source.hide()
	var hidden := await rendered(view)
	check(hidden.get_region(Rect2i(74, 30, 24, 24)).is_invisible(), "Hidden source retained a ghost silhouette")
	source.queue_free()
	await ticks(1)
	check(shadows._copies.size() == 2, "Removed source retained a render copy")
	view.queue_free()
	await ticks(2)


func capture_native() -> void:
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(40)
	var floor_y := 0.0
	for part in level.current_sub_area.get_parts().get_children():
		if part is GroundPart:
			floor_y = part.position.y
			break
	for row in [["koopa", 272], ["monty", 368], ["hammer_bro", 448], ["grrrol", 512]]:
		var part: Part = load("res://scenes/level/parts/%s_part.tscn" % row[0]).instantiate()
		part.position = Vector2(row[1], floor_y - (32 if row[0] == "grrrol" else 16))
		level.current_sub_area.add_part(part)
		part.load()
	Utility.camera_scale = Vector2(3, 3)
	Utility.camera_position = Vector2(208, -216)
	var sheet := Image.create(2304, 1296, false, Image.FORMAT_RGBA8)
	for mode in 2:
		if mode == 1:
			level.play()
			await ticks(45)
			var player := level.hud.player
			player.position = Vector2(400, floor_y)
			player.previous_position = player.position
		level.process_mode = Node.PROCESS_MODE_DISABLED
		Utility.camera_position = Vector2(208, -216)
		# The stopped-clock capture changed zoom/camera after the background's
		# process pass; refresh its native draw geometry at the new view bounds.
		for background in level.current_sub_area.background.get_children():
			if background is CanvasItem:
				background.queue_redraw()
		var shadows := level.current_sub_area.pixel_shadows
		var children := level.current_sub_area.get_foreground().get_child_count()
		shadows.hide()
		var before := await rendered(get_viewport())
		shadows.show()
		var after := await rendered(get_viewport())
		check(before.get_data() != after.get_data(), "Native editor/gameplay had no visible pixel shadows")
		check(children == level.current_sub_area.get_foreground().get_child_count(), "Shadow rendering duplicated live actors")
		check(before.get_region(Rect2i(0, 0, 1152, 72)).get_data() == after.get_region(Rect2i(0, 0, 1152, 72)).get_data(),
				"World shadows changed the HUD/editor toolbar")
		sheet.blit_rect(before, Rect2i(0, 0, 1152, 648), Vector2i(0, mode * 648))
		sheet.blit_rect(after, Rect2i(0, 0, 1152, 648), Vector2i(1152, mode * 648))
		after.save_png("res://.godot/porting-tests/slice_pixel_shadows_%s.png" % ("editor" if mode == 0 else "play"))
		level.process_mode = Node.PROCESS_MODE_INHERIT
	check(sheet.save_png("res://.godot/porting-tests/slice_pixel_shadows.png") == OK, "Could not save native shadow comparison")
	level.edit()
	await ticks(2)
	await rendered(get_viewport())
	for entry: Dictionary in level.current_sub_area.pixel_shadows._copies.values():
		var source: Node2D = entry.source.get_ref()
		check(not entry.copy.visible or (is_instance_valid(source) and source.is_visible_in_tree()), "Edit/play transition retained a runtime silhouette")
	level.queue_free()
	await ticks(2)
