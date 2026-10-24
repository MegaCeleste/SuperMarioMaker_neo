# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Independent fractional-position oracle plus optional GPU pixel readback.

var _presentation: WorldPresentation
var _fraction := 0.0


func _forced_presentation() -> void:
	_presentation.present(_fraction)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var capture := "--capture-world-presentation" in OS.get_cmdline_user_args()
	var level: Level = await LevelProcessor.from_swe("res://tests/fixtures/port_slice.swe")
	add_child(level)
	await ticks(35)
	var area := level.current_sub_area
	_presentation = area.presentation
	RenderingServer.frame_pre_draw.disconnect(_presentation.present)
	RenderingServer.frame_pre_draw.connect(_forced_presentation)
	level.hud.player.set_physics_process(false)
	_presentation.set_physics_process(false)
	get_tree().physics_frame.disconnect(_presentation._before_physics)
	var body := CharacterBodyExt.new()
	body.position = Vector2(560, -80)
	area.get_foreground().add_child(body)
	var sprite := Sprite2D.new()
	var pixels := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.MAGENTA)
	sprite.texture = ImageTexture.create_from_image(pixels)
	sprite.centered = false
	body.add_child(sprite)
	Utility.camera_position = Vector2(400, -216)
	await ticks(2)
	_presentation._before_physics()
	body.position += Vector2(8, -4)
	Utility.camera_position += Vector2(4, -2)
	var physical := body.position
	var camera := Utility.camera_position
	var trace: Array[Dictionary] = []
	for alpha: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		_fraction = alpha
		_presentation.present(alpha)
		if capture:
			await RenderingServer.frame_post_draw
		var expected := Vector2(560, -80) + Vector2(8, -4) * alpha
		var expected_camera := Vector2(400, -216) + Vector2(4, -2) * alpha
		check(_presentation.global_transform_for(sprite).origin.is_equal_approx(expected),
				"Actor display did not advance between physics ticks")
		check(body.position == physical and Utility.camera_position.is_equal_approx(camera),
				"Display interpolation changed the collision/AI state")
		var screen := (expected - expected_camera) * Utility.camera_scale
		check(_presentation.canvas_transform_for(sprite).origin.is_equal_approx(screen),
				"Camera and actor use different display times")
		var row := {"fraction": alpha, "physical": str(physical), "displayed": str(expected), "screen": str(screen)}
		if capture:
			var image := get_viewport().get_texture().get_image()
			if is_equal_approx(alpha, 0.5):
				image.save_png("res://.godot/porting-tests/slice_world_presentation.png")
			var found := Rect2i()
			for y in range(roundi(screen.y) - 2, roundi(screen.y) + 28):
				for x in range(roundi(screen.x) - 2, roundi(screen.x) + 28):
					var color := image.get_pixel(x, y)
					if color.r > 0.95 and color.g < 0.05 and color.b > 0.95:
						found = Rect2i(Vector2i(x, y), Vector2i.ONE) if found.size == Vector2i.ZERO else found.expand(Vector2i(x, y))
			check(found.size.x >= 23 and absi(found.position.x - roundi(screen.x)) <= 1
					and absi(found.position.y - roundi(screen.y)) <= 1,
					"GPU pixels did not follow the fractional display position: " + str(found))
			row["pixels"] = str(found)
			image.get_region(Rect2i(460, 380, 80, 70)).save_png("res://.godot/porting-tests/presentation_%d.png" % roundi(alpha * 4))
		trace.append(row)
	# Pauses hold the displayed pose, including a transformation's child swaps.
	_fraction = 0.25
	_presentation.present(_fraction)
	var paused_at := _presentation.canvas_transform_for(sprite).origin
	get_tree().paused = true
	_presentation.present(0.9)
	check(_presentation.canvas_transform_for(sprite).origin.is_equal_approx(paused_at), "Pause snapped an interpolated actor")
	get_tree().paused = false
	_presentation._before_physics()
	_presentation.present(0)
	check(_presentation.canvas_transform_for(sprite).origin.is_equal_approx(paused_at), "Resume discarded the held display pose")
	var fresh := CharacterBodyExt.new()
	area.get_foreground().add_child(fresh)
	fresh.position = Vector2(640, -80) # Factory assigns placement after insertion.
	_presentation._before_physics()
	get_tree().paused = true
	_presentation.present(0.5)
	check(_presentation.global_transform_for(fresh).origin == fresh.global_position,
			"First-tick pause moved a newly placed actor back to its temporary origin")
	get_tree().paused = false
	_presentation._before_physics()
	fresh.queue_free()
	# Teleports and editor transitions must be immediate, never long sweeps.
	_presentation._before_physics()
	body.position.x += 96
	Utility.camera_position += Vector2(100, 0)
	_presentation.present(0.25)
	check(_presentation.global_transform_for(sprite).origin.is_equal_approx(body.global_position), "Teleport smeared across the course")
	level.status = Level.Status.EDITING
	_presentation.present(0.25)
	check(Utility.camera_render_offset == Vector2.ZERO and _presentation.global_transform_for(sprite).origin == body.global_position,
			"Editor inherited a gameplay display offset")
	body.reparent(level.hud.player)
	check(not _presentation._tracks.has(body.get_instance_id()), "Reparented body retained an old world transform")
	body.queue_free()
	RenderingServer.frame_pre_draw.disconnect(_forced_presentation)
	RenderingServer.frame_pre_draw.connect(_presentation.present)
	get_tree().physics_frame.connect(_presentation._before_physics)
	if capture:
		var file := FileAccess.open("res://.godot/porting-tests/world_presentation.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(trace, "  "))
		file.close()
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("WORLD_PRESENTATION_RESULT", level)
