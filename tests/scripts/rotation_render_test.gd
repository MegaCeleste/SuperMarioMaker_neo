# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/grrrol_test.gd"
## Real-GL readback: equal cardinal pixels, edge coverage, alpha and controls.
## Run with capture_slice.py --rotation-render (headless cannot test shaders).

const ANGLES := [0.0, 3.5, 14.0, 31.5, 45.0, -45.0, 90.0, 180.0]
const CELL := 288
var render_trace: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	check(DisplayServer.get_name() != "headless", "Rotation pixels need the real OpenGL renderer")
	if not failures.is_empty():
		await finish("ROTATION_RENDER_RESULT")
		return
	await check_edge_coverage()
	await capture_source_angles()
	await check_existing_rotating_art()
	var log := FileAccess.open("res://.godot/porting-tests/rotation_render.json", FileAccess.WRITE)
	log.store_string(JSON.stringify(render_trace, "  "))
	log.close()
	print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("ROTATION_RENDER_RESULT")


func rendered(view: Viewport) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()


func check_existing_rotating_art() -> void:
	var level := await rolling_level()
	await ticks(40)
	var enemy: Galoomba = load("res://scenes/entities/galoomba.tscn").instantiate()
	enemy.position = Vector2(340, -150)
	level.current_sub_area.add(enemy)
	enemy.kill(1)
	var shell: KoopaShell = load("res://scenes/entities/koopa_shell.tscn").instantiate()
	shell.position = Vector2(450, -96)
	level.current_sub_area.add(shell)
	await ticks(1)
	var corpses := live_nodes(level.current_sub_area, DeadEntity)
	check(corpses.size() == 1, "Old enemy defeat did not create its actual rotating corpse")
	if corpses.is_empty():
		level.queue_free()
		await ticks(2)
		return
	var corpse := corpses[0] as DeadEntity
	corpse._spin.pause()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	var shell_sprite := shell.get_node("Graphics/Sprite") as AnimatedSprite2D
	for pair in [[corpse, corpse.get_child(0)], [shell_sprite, shell_sprite]]:
		var pivot: Node2D = pair[0]
		var sprite: AnimatedSprite2D = pair[1]
		check(sprite.material == SpriteLibrary.ROTATION_MATERIAL, "Existing corpse/shell missed rotation sampling")
		for degrees in [0.0, 31.5]:
			pivot.rotation_degrees = degrees
			sprite.material = null
			var before := await rendered(get_viewport())
			sprite.material = SpriteLibrary.ROTATION_MATERIAL
			var after := await rendered(get_viewport())
			var at := Vector2i(sprite.get_global_transform_with_canvas().origin.round())
			var crop := Rect2i(at - Vector2i(64, 64), Vector2i(128, 128))
			var equal := before.get_region(crop).get_data() == after.get_region(crop).get_data()
			check(equal == (degrees == 0), "Actual old corpse/shell rotation lost crisp axes or oblique edge sampling")
			render_trace.append({"probe": "old_corpse" if pivot == corpse else "shell",
				"degrees": degrees, "pixels_equal": equal})
	level.queue_free()
	await ticks(2)


func check_edge_coverage() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(96, 96)
	view.world_2d = World2D.new()
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var background := ColorRect.new()
	background.size = Vector2(96, 96)
	background.color = Color.GREEN
	view.add_child(background)
	# Transparent black around solid red exposes dark alpha-interpolation halos.
	var source := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	source.fill(Color(0, 0, 0, 0))
	source.fill_rect(Rect2i(4, 4, 4, 4), Color.RED)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(source)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(48.5, 48.5)
	view.add_child(sprite)
	for scale_factor in [1.0, 2.25, 4.0]:
		sprite.scale = Vector2.ONE * scale_factor
		for degrees in [0.0, 90.0, 180.0, 270.0]:
			sprite.rotation_degrees = degrees
			sprite.material = null
			var before := await rendered(view)
			sprite.material = SpriteLibrary.ROTATION_MATERIAL
			var after := await rendered(view)
			check(before.get_data() == after.get_data(), "Cardinal rotation blurred at %s degrees, scale %s" % [degrees, scale_factor])
	sprite.scale = Vector2(4, 4)
	sprite.rotation_degrees = 22.5
	sprite.material = null
	var before := await rendered(view)
	sprite.material = SpriteLibrary.ROTATION_MATERIAL
	var after := await rendered(view)
	var edge_pixels := 0
	var solid_pixels := 0
	var old_edge_pixels := 0
	var clean_alpha := true
	for y in view.size.y:
		for x in view.size.x:
			var color := after.get_pixel(x, y)
			var old_color := before.get_pixel(x, y)
			if old_color.r > 0.01 and old_color.r < 0.99:
				old_edge_pixels += 1
			if color.r > 0.01 and color.r < 0.99:
				edge_pixels += 1
			if color.r > 0.99:
				solid_pixels += 1
			clean_alpha = clean_alpha and absf(color.r + color.g - 1) < 0.012 and color.b < 0.012
	check(old_edge_pixels == 0 and edge_pixels > 10, "Rotated texture edges still use hard nearest coverage")
	check(solid_pixels > 150, "Rotation filtering blurred solid texel interiors")
	check(clean_alpha, "Transparent black RGB introduced a dark fringe around rotated art")
	render_trace.append({"probe": "red_on_green", "old_edge_pixels": old_edge_pixels,
		"filtered_edge_pixels": edge_pixels, "solid_pixels": solid_pixels, "clean_alpha": clean_alpha})
	sprite.self_modulate = Color(0.5, 1, 1, 0.5)
	var tinted := await rendered(view)
	var center := tinted.get_pixel(48, 48)
	check(absf(center.r - 0.25) < 0.012 and absf(center.g - 0.5) < 0.012,
			"Rotated rendering lost CanvasItem color/alpha modulation")
	view.queue_free()
	await ticks(2)


func capture_source_angles() -> void:
	var level := await rolling_level()
	await ticks(40)
	var bodies: Array[Grrrol] = []
	for index in PROFILES.size():
		bodies.append(rolling(level, PROFILES[index], Vector2([330, 440, 525][index], -96)))
	level.process_mode = Node.PROCESS_MODE_DISABLED
	var sheet := Image.create(CELL * ANGLES.size(), CELL * 2 * PROFILES.size(), false, Image.FORMAT_RGBA8)
	var player_crop := Rect2i(Vector2i(level.hud.player.sprite.get_global_transform_with_canvas().origin) - Vector2i(60, 100), Vector2i(120, 120))
	# Stay outside the rollers' rotated drawing bounds: their art can extend
	# below the fixed masks and legitimately cover the floor at oblique angles.
	var ground_crop := Rect2i(8, 365, 100, 30)
	for column in ANGLES.size():
		for body in bodies:
			body.angle = -ANGLES[column]
			body._update_visuals()
			check(body._sprite.material == SpriteLibrary.ROTATION_MATERIAL, "A source Grrrol missed the rotation material")
			body._sprite.material = null
		var before := await rendered(get_viewport())
		for body in bodies:
			body._sprite.material = SpriteLibrary.ROTATION_MATERIAL
		var after := await rendered(get_viewport())
		check(before.get_region(player_crop).get_data() == after.get_region(player_crop).get_data(),
				"Rotation filtering changed actual Mario pixels")
		check(before.get_region(ground_crop).get_data() == after.get_region(ground_crop).get_data(),
				"Rotation filtering changed actual terrain pixels")
		for index in bodies.size():
			var body := bodies[index]
			var center := Vector2i(body._sprite.get_global_transform_with_canvas().origin.round())
			var crop := Rect2i(center - Vector2i(CELL / 2, CELL / 2), Vector2i(CELL, CELL))
			var old_pixels := before.get_region(crop)
			var new_pixels := after.get_region(crop)
			var equal := old_pixels.get_data() == new_pixels.get_data()
			check(equal == (fmod(absf(ANGLES[column]), 90) == 0),
					"Source rotation did not retain cardinal/change oblique sampling: %s, %s" % [body.variant.object_id, ANGLES[column]])
			check(body.get_node("CollShape").rotation == 0 and body.get_node("PlayerArea/CollShape").rotation == 0,
					"Rotation renderer changed the source's fixed collision masks")
			sheet.blit_rect(old_pixels, Rect2i(0, 0, CELL, CELL), Vector2i(column * CELL, index * CELL * 2))
			sheet.blit_rect(new_pixels, Rect2i(0, 0, CELL, CELL), Vector2i(column * CELL, (index * 2 + 1) * CELL))
			render_trace.append({"object": body.variant.object_id, "degrees": ANGLES[column],
				"pixels_equal": equal, "source_origin": str(SpriteLibrary.get_origin(body.variant.body_sprite)),
				"sprite_position": str(body._sprite.global_position)})
	check(sheet.save_png("res://.godot/porting-tests/slice_rotation_render.png") == OK, "Could not save actual rotation comparisons")
	level.queue_free()
	await ticks(2)
