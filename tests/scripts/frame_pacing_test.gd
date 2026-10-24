# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Wall-clock diagnostics: no fixed FPS, movie writer or image readback.

var _shadow: PixelShadows
var _sync_us: Array[float] = []
var _results: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var fps := 120
	var label := "runtime"
	for arg in args:
		if arg.begins_with("--rate="):
			fps = int(arg.trim_prefix("--rate="))
		if arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
	var configuration := {
		"physics_hz": Engine.physics_ticks_per_second,
		"interpolation": ProjectSettings.get_setting("physics/common/physics_interpolation"),
		"vsync_at_launch": DisplayServer.window_get_vsync_mode(),
		"display_hz": DisplayServer.screen_get_refresh_rate(),
		"renderer": RenderingServer.get_video_adapter_name(),
		"target_fps": fps,
	}
	# A repeatable CPU/render pacing probe, independent of display refresh.
	# This is not a measurement of photon/input latency or compositor timing.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	configuration["probe_vsync"] = DisplayServer.window_get_vsync_mode()
	Engine.max_fps = fps
	var level: Level = await LevelProcessor.from_swe("res://tests/fixtures/port_slice.swe")
	add_child(level)
	await ticks(40)
	for node in level.current_sub_area.get_foreground().get_children():
		if node is Enemy or node is GoalGate or node is Coin or node is QuestionBlock or node is TurnBlockTile:
			node.queue_free()
	await ticks(2)
	_shadow = level.current_sub_area.pixel_shadows
	level.current_sub_area.presentation.enabled = "--no-interpolation" not in args
	configuration["display_interpolation"] = level.current_sub_area.presentation.enabled
	RenderingServer.frame_pre_draw.disconnect(_shadow._sync)
	RenderingServer.frame_pre_draw.connect(_timed_sync)
	var stress: Array[Sprite2D] = []
	for dense in [false, true]:
		if dense:
			# Simulate the art of a long course outside the camera. GPU clipping
			# cannot eliminate a GDScript scan/rebuild of these static sprites.
			var texture: Texture2D = StartingGround.GroundDrawer.GROUND
			for index in 512:
				var sprite := Sprite2D.new()
				sprite.texture = texture
				sprite.position = Vector2(4096 + index * 16, -16)
				level.current_sub_area.get_foreground().add_child(sprite)
				stress.append(sprite)
		for enabled in [true, false]:
			_shadow.visible = enabled
			var player := level.hud.player
			player.position = Vector2(400, -16)
			player.velocity = Vector2.ZERO
			player.state_machine.switch(PlayerMovingState)
			Input.action_press("player_run")
			Input.action_press("player_right")
			await get_tree().create_timer(0.65).timeout
			await RenderingServer.frame_post_draw
			_sync_us.clear()
			var frames: Array[float] = []
			var positions: Array[Dictionary] = []
			var previous := Time.get_ticks_usec()
			var until := previous + 2_000_000
			while Time.get_ticks_usec() < until:
				await RenderingServer.frame_post_draw
				var now := Time.get_ticks_usec()
				frames.append((now - previous) / 1000.0)
				previous = now
				positions.append({"tick": Engine.get_physics_frames(), "physical_x": player.position.x,
					"displayed_x": level.current_sub_area.presentation.global_transform_for(player).origin.x})
			release_input()
			var result := {"dense": dense, "shadows": enabled, "copies": _shadow._copies.size(),
				"frame_ms": stats(frames), "shadow_sync_us": stats(_sync_us),
				"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"intervals_ms": frames, "positions": positions}
			_results.append(result)
			var summary := result.duplicate()
			summary.erase("intervals_ms")
			summary.erase("positions")
			print("PACING_SAMPLE ", JSON.stringify(summary))
	RenderingServer.frame_pre_draw.disconnect(_timed_sync)
	var file := FileAccess.open("res://.godot/porting-tests/pacing_%s_%d.json" % [label, fps], FileAccess.WRITE)
	file.store_string(JSON.stringify({"configuration": configuration, "samples": _results}, "  "))
	file.close()
	await finish("FRAME_PACING_RESULT", level)


func _timed_sync() -> void:
	var before := Time.get_ticks_usec()
	_shadow._sync()
	_sync_us.append(float(Time.get_ticks_usec() - before))


func stats(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	return {"count": sorted.size(), "mean": total / sorted.size(),
		"p50": sorted[int((sorted.size() - 1) * 0.5)], "p95": sorted[int((sorted.size() - 1) * 0.95)],
		"p99": sorted[int((sorted.size() - 1) * 0.99)], "max": sorted.back()}
