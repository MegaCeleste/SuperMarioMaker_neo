# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Actual spin contacts plus rendered growth/shrinkage of the flash and stars.

var capture := false
var trace: Array[Dictionary] = []


func _ready() -> void:
	capture = "--capture-spin-effects" in OS.get_cmdline_user_args()
	for kind in ["spiny", "spiny_shell", "galoomba", "green_koopa"]:
		await check_contact(kind)
	await check_teardown()
	if capture:
		await check_pixels()
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	var file := FileAccess.open("res://.godot/porting-tests/spin_effects.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(trace, "  "))
	file.close()
	await finish("SPIN_EFFECTS_RESULT")


func make_level() -> Level:
	var level: Level = await LevelProcessor.from_swe("res://tests/fixtures/port_slice.swe")
	var area := level.current_sub_area
	for part in area.get_parts().get_children():
		if not part is EditorPlayer and not part is StartingGround:
			part.free()
	for x in range(12, 80):
		var ground := GroundPart.create()
		ground.position = Vector2(x * 16, -96)
		area.add_part(ground)
	add_child(level)
	area.actor_activity.enabled = false
	await ticks(8)
	return level


func check_contact(kind: String) -> void:
	var level := await make_level()
	var area := level.current_sub_area
	var body: Enemy = load("res://scenes/entities/%s.tscn" % ("koopa_shell" if kind == "spiny_shell" else kind)).instantiate()
	if kind == "spiny_shell":
		body.variant = preload("res://resources/content/smw_spiny_empty.tres")
	body.position = Vector2(480, -96)
	area.add(body)
	await ticks(20)
	var impact := body.global_position
	var player := level.hud.player
	player.global_position = impact - Vector2(0, 48)
	player.previous_position = player.global_position
	player.state_machine.switch(PlayerFallingState)
	await ticks(1) # Clear the old floor contact before beginning the falling spin.
	Input.action_press("player_spin_jump")
	player.state_machine.switch(PlayerSpinJumpingState)
	player.velocity = Vector2(0, 120)
	var recoil := kind in ["spiny", "spiny_shell"]
	var ids: Dictionary = {}
	var contacts: Array[Dictionary] = []
	var sizes: Array[float] = []
	var bounced := false
	var elapsed := 0.0
	var frame_index := 0
	var fps := roundi(1.0 / get_process_delta_time())
	var directory := "res://.godot/porting-tests/spin_effects_%s_%d" % [kind, fps]
	var save_reel := capture and kind in ["spiny", "galoomba"]
	if save_reel:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		Utility.camera_scale = Vector2(3, 3)
		Utility.camera_position = impact - Vector2(144, 80)
	while elapsed < 0.55:
		if capture:
			await RenderingServer.frame_post_draw
		bounced = bounced or player.velocity.y < 0
		for node in area.get_foreground().get_children():
			if node is SpinThump or node is SpinSmoke:
				if not ids.has(node.get_instance_id()):
					contacts.append({"seconds": elapsed, "position": player.position, "velocity": player.velocity})
				ids[node.get_instance_id()] = true
				check((node is SpinThump) == recoil, "Spin contact chose the wrong flash/star effect")
				sizes.append(node.pulse_size if node is SpinThump else node.star_size)
		if save_reel:
			var at := area.get_foreground().get_global_transform_with_canvas() * (impact - Vector2(0, 26))
			var crop := Rect2i(Vector2i(at) - Vector2i(160, 120), Vector2i(320, 240))
			var pixels := get_viewport().get_texture().get_image().get_region(crop)
			check(pixels.save_png(directory + "/frame_%03d.png" % frame_index) == OK, "Could not save spin contact frame")
		elapsed += get_process_delta_time()
		frame_index += 1
		await get_tree().process_frame
	check(bounced and not player.is_dead(), "Visual correction changed spin recoil/bounce physics")
	check(is_instance_valid(body) == recoil, "Spiked recoil or spin defeat changed its enemy outcome")
	check(ids.size() == 1 and sizes.size() >= 3, "A spin contact omitted or duplicated its effect")
	if not sizes.is_empty():
		var peak: float = sizes.max()
		check(peak > 0.95 and sizes[0] < peak * 0.65 and sizes[-1] < peak * 0.3,
				"Spin contact effect did not grow from small to full size and shrink before disappearing")
		trace.append({"kind": kind, "effects": ids.size(), "contacts": contacts, "first": sizes[0], "peak": peak,
				"last": sizes[-1], "frames": frame_index, "fps": fps})
	# Stop the observer before a stationary shell receives the next real bounce.
	# Audio playback uses wall time even when headless fixed-fps simulation runs faster.
	player.set_physics_process(false)
	var cleanup_deadline := Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < cleanup_deadline and area.get_foreground().get_children().any(func(node): return node is SpinThump or node is SpinSmoke):
		await ticks(1)
	check(area.get_foreground().get_children().all(func(node): return not node is SpinThump and not node is SpinSmoke),
			"Finished spin effect or its audio owner leaked")
	release_input()
	level.queue_free()
	await ticks(2)


func check_teardown() -> void:
	var level := await make_level()
	level.create_editor()
	var player := level.hud.player
	player.spawn_spin_thump()
	var stars := SpinSmoke.create()
	level.current_sub_area.add(stars)
	await ticks(2)
	var effects := level.current_sub_area.get_foreground().get_children().filter(func(node): return node is SpinThump or node is SpinSmoke)
	check(effects.size() == 2, "Spin effects are outside their runtime area's ownership")
	level.edit()
	await ticks(2)
	check(effects.all(func(node): return not is_instance_valid(node)), "Editor return retained a spin effect/audio owner")
	level.play()
	await ticks(8)
	level.hud.player.spawn_spin_thump()
	level.edit() # Invalidate the collision callback's pending insertion.
	await ticks(2)
	check(level.current_sub_area.get_foreground().get_child_count() == 0, "Deferred impact reappeared after editor return")
	level.queue_free()
	await ticks(2)


func check_pixels() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(160, 100)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.canvas_transform = Transform2D(Vector2(2, 0), Vector2(0, 2), Vector2(80, 50))
	var times := [0.0, 0.025, 0.06, 0.10, 0.15, 0.185, 0.26, 0.28]
	var sheet := Image.create(1280, 200, false, Image.FORMAT_RGBA8)
	for stars in [false, true]:
		var effect: Node2D = SpinSmoke.create() if stars else load("res://scenes/particles/spin_thump.tscn").instantiate()
		viewport.add_child(effect)
		effect.set_process(false)
		if stars:
			effect._tween.pause()
			effect.get_node("Sound").stop()
			effect.pause()
			effect.sprite_frames = SpriteFrames.new() # Read back the four stars separately from the smoke.
		var areas: Array[int] = []
		for index in times.size():
			if stars:
				effect._progress = minf(1.0, times[index] / SpinSmoke._LENGTH)
				effect.queue_redraw()
			else:
				effect._age = times[index]
				effect._update_size()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var pixels := viewport.get_texture().get_image()
			sheet.blit_rect(pixels, Rect2i(0, 0, 160, 100), Vector2i(index * 160, 100 if stars else 0))
			var opaque := 0
			for y in pixels.get_height():
				for x in pixels.get_width():
					if pixels.get_pixel(x, y).a > 0.95:
						opaque += 1
			areas.append(opaque)
		check(areas[2] > areas[0] * 4 and areas[2] > areas[1], "Actual flash/star pixels did not expand")
		check(areas[5] < areas[2] / 2 and areas[7] == 0, "Actual flash/star pixels did not shrink to nothing")
		trace.append({"stars": stars, "sample_seconds": times, "opaque_pixels": areas})
		effect.queue_free()
		await get_tree().process_frame
	check(sheet.save_png("res://.godot/porting-tests/slice_spin_effects.png") == OK, "Could not save effect size profile")
	viewport.queue_free()
	await get_tree().process_frame
