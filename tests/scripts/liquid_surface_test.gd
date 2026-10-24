# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Real liquid motion/hold/retry lifecycle and source metadata validation.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for speed in [Level.WaterSpeed.SLOW, Level.WaterSpeed.MEDIUM, Level.WaterSpeed.FAST]:
		await check_cycle(speed)
	await check_metadata()
	await finish("LIQUID_SURFACE_RESULT")


func check_cycle(speed: Level.WaterSpeed) -> void:
	var level: Level = await LevelProcessor.from_swe("res://tests/fixtures/port_slice.swe")
	level.status = Level.Status.EDITING
	var sub := level.current_sub_area
	sub.level_theme = Level.LevelTheme.FOREST
	sub.water_start_y = -112
	sub.water_limit_y = -144
	sub.water_speed = speed
	add_child(level)
	await ticks(8)
	var liquid := sub.liquid
	check(liquid.position.y == -100 and liquid.velocity == 0, "Editor liquid origin must remain start+12")
	level.play()
	level.hud.player.set_physics_process(false)
	await ticks(1)
	check(liquid.phase == LiquidSurface.Phase.RISING and liquid.velocity == -[12, 30, 48][speed], "Liquid failed its source speed/start transition")
	var count := 0
	while liquid.phase == LiquidSurface.Phase.RISING and count < 170:
		await ticks(1)
		count += 1
	check(absf(liquid.position.y + 132) < 0.81 and liquid.phase == LiquidSurface.Phase.HOLD_TOP,
			"Liquid did not stop at limit+12 with at most one source speed step of overshoot")
	var top := liquid.position.y
	await ticks(119)
	check(liquid.position.y == top and liquid.velocity == 0, "Liquid top hold ended before120 ticks")
	await ticks(1)
	check(liquid.phase == LiquidSurface.Phase.FALLING and liquid.velocity > 0, "Liquid did not descend after the source two-second hold")
	count = 0
	while liquid.phase == LiquidSurface.Phase.FALLING and count < 170:
		await ticks(1)
		count += 1
	check(liquid.phase == LiquidSurface.Phase.HOLD_BOTTOM and absf(liquid.position.y + 112) < 0.81,
			"Liquid bottom must use source start, retaining the asymmetric12px endpoint")
	var bottom := liquid.position.y
	await ticks(119)
	check(liquid.position.y == bottom and liquid.velocity == 0, "Liquid bottom hold ended before120 ticks")
	await ticks(1)
	check(liquid.phase == LiquidSurface.Phase.RISING and liquid.velocity < 0, "Liquid cycle failed to repeat")
	level.reload()
	await ticks(1)
	check(absf(liquid.position.y + 100) < 0.81, "Retry did not restore original liquid state")
	level.edit()
	await ticks(3)
	check(liquid.position.y == -100 and liquid.velocity == 0, "Returning to editing left a moving liquid surface")
	level.free()
	await ticks(2)
	check(not is_instance_valid(liquid), "Liquid node leaked after area teardown")


func check_metadata() -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes("res://tests/fixtures/port_slice.swe")).data
	data.MAIN.AJUSTES[0].water_level = "invalid"
	data.MAIN.AJUSTES[0].water_level_limit = 300.5
	data.MAIN.AJUSTES[0].water_level_speed = 99
	var path := "res://.godot/porting-tests/liquid_invalid.swe"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level: Level = await LevelProcessor.from_swe(path)
	check(level.current_sub_area.water_start_y == -16 and level.current_sub_area.water_limit_y == -131.5
			and level.current_sub_area.water_speed == Level.WaterSpeed.SLOW,
			"Invalid liquid metadata must fall back without rounding valid source pixel positions")
	level.free()
	for theme in Level.LevelTheme.values():
		check(LiquidSurface.supports(theme, false) == (theme in [Level.LevelTheme.FOREST, Level.LevelTheme.CASTLE, Level.LevelTheme.BEACH]),
				"Liquid enabled a source theme with no surface")
	check(LiquidSurface.supports(Level.LevelTheme.MOUNTAIN, true), "Night mountain lava surface is missing")
