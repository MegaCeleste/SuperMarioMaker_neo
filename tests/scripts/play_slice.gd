extends Node
## Play the local fixture directly without the unfinished Coursebot flow.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var koopa_editor := "--capture-editor-koopa" in args
	var koopa_runtime := "--capture-koopa" in args
	var flight_editor := "--capture-editor-flight" in args
	var flight_runtime := "--capture-flight" in args
	var buzzy_editor := "--capture-editor-buzzy" in args
	var buzzy_runtime := "--capture-buzzy" in args
	var spiny_editor := "--capture-editor-spiny" in args
	var spiny_runtime := "--capture-spiny" in args
	var spiny_completion := "--capture-spiny-completion" in args
	var blooper_editor := "--capture-editor-blooper" in args
	var blooper_runtime := "--capture-blooper" in args
	var cheep_editor := "--capture-editor-cheep-cheep" in args
	var cheep_runtime := "--capture-cheep-cheep" in args
	var cheep_water := "--capture-cheep-water" in args
	var cheep_lava := "--capture-cheep-lava" in args
	var any_cheep := cheep_runtime or cheep_water or cheep_lava
	var piranha_editor := "--capture-editor-piranha" in args
	var piranha_runtime := "--capture-piranha" in args
	var piranha_fire := "--capture-piranha-fire" in args
	var piranha_water := "--capture-piranha-water" in args
	var any_piranha := piranha_runtime or piranha_fire or piranha_water
	var muncher_editor := "--capture-editor-muncher" in args
	var muncher_runtime := "--capture-muncher" in args
	var thwomp_editor := "--capture-editor-thwomp" in args
	var thwomp_runtime := "--capture-thwomp" in args
	var monty_editor := "--capture-editor-monty" in args
	var monty_runtime := "--capture-monty" in args
	var rocky_editor := "--capture-editor-rocky" in args
	var rocky_runtime := "--capture-rocky" in args
	var hammerbro_editor := "--capture-editor-hammerbro" in args
	var hammerbro_runtime := "--capture-hammerbro" in args
	var helmet_completion := "--capture-helmet-completion" in args
	var completion_capture := "--capture-completion" in args or helmet_completion or spiny_completion
	var editor_capture := "--capture-editor" in args or "--capture-editor-enemy" in args or koopa_editor or flight_editor or buzzy_editor or spiny_editor or blooper_editor or cheep_editor or piranha_editor or muncher_editor or thwomp_editor or monty_editor or rocky_editor or hammerbro_editor
	var enemy_capture := "--capture-editor-enemy" in args or flight_editor
	var level: Level = await LevelProcessor.from_swe("res://tests/fixtures/port_slice.swe")
	if level == null:
		get_tree().quit(1)
		return
	if editor_capture:
		level.status = Level.Status.EDITING
	if muncher_editor:
		var part := MuncherPart.create()
		part.position = Vector2(288, -64)
		part.variant = MuncherPart.VARIANTS[1]
		part.wings = true
		part.parachute = true
		level.current_sub_area.add_part(part)
	if muncher_runtime:
		for spec in [[Vector2(160, -32), 0], [Vector2(208, -32), 1],
				[Vector2(256, -32), 0], [Vector2(256, -48), 0], [Vector2(256, -64), 0],
				[Vector2(304, -32), 1], [Vector2(304, -64), 1], [Vector2(352, -240), 1]]:
			var part := MuncherPart.create()
			part.position = spec[0]
			part.variant = MuncherPart.VARIANTS[spec[1]]
			level.current_sub_area.add_part(part)
	if thwomp_editor:
		var part := ThwompPart.create()
		part.position = Vector2(288, -64)
		part.variant = ThwompPart.VARIANTS[1]
		part.attack_direction = 3
		level.current_sub_area.add_part(part)
	if monty_editor:
		var part := MontyPart.create()
		part.position = Vector2(288, -64)
		part.wings = true
		part.parachute = true
		level.current_sub_area.add_part(part)
	if rocky_editor:
		var part := RockyPart.create()
		part.position = Vector2(288, -64)
		level.current_sub_area.add_part(part)
	if hammerbro_editor:
		var part := HammerBroPart.create()
		part.position = Vector2(288, -64)
		part.wings = true
		level.current_sub_area.add_part(part)
	if piranha_editor:
		var part := PiranhaPart.create()
		part.position = Vector2(288, -64)
		part.wings = true
		part.parachute = true
		level.current_sub_area.add_part(part)
	if any_piranha:
		if piranha_water:
			level.current_sub_area.level_theme = Level.LevelTheme.FOREST
			level.current_sub_area.water_start_y = -128
			level.current_sub_area.water_limit_y = -128
		for spec in ([[Vector2(160, -32), 0, false, false], [Vector2(224, -32), 0, true, false],
				[Vector2(320, -144), 0, false, false], [Vector2(304, -96), 0, false, false], [Vector2(352, -96), 0, false, false]] if piranha_runtime \
				else [[Vector2(256, -32), 1, false, false], [Vector2(320, -160), 1, true, true]]):
			var part := PiranhaPart.create()
			part.position = spec[0]
			part.variant = PiranhaPart.VARIANTS[spec[1]]
			part.wings = spec[2]
			part.parachute = spec[3]
			level.current_sub_area.add_part(part)
		if piranha_runtime:
			for pos in [Vector2(320, -160), Vector2(288, -96), Vector2(368, -96)]:
				var ground := GroundPart.create()
				ground.position = pos
				level.current_sub_area.add_part(ground)
	if cheep_editor:
		var part := CheepCheepPart.create()
		part.position = Vector2(288, -64)
		part.wings = true
		part.parachute = true
		level.current_sub_area.add_part(part)
	if any_cheep:
		if cheep_water or cheep_lava:
			level.current_sub_area.level_theme = Level.LevelTheme.FOREST if cheep_water else Level.LevelTheme.CASTLE
			level.current_sub_area.water_start_y = -128
			level.current_sub_area.water_limit_y = -176 if cheep_water else -128
			level.current_sub_area.water_speed = Level.WaterSpeed.MEDIUM
		for spec in [[Vector2(176, -96 if cheep_water else -112 if cheep_lava else -32), false, false, 0],
				[Vector2(256, -96 if cheep_water else -112 if cheep_lava else -48), true, false, 1],
				[Vector2(320, -96 if cheep_water else -112 if cheep_lava else -128), true, true, 0]]:
			var part := CheepCheepPart.create()
			part.position = spec[0]
			part.wings = spec[1]
			part.parachute = spec[2]
			part.variant = CheepCheepPart.VARIANTS[spec[3]]
			level.current_sub_area.add_part(part)
	if blooper_editor or blooper_runtime:
		var part := BlooperPart.create()
		part.position = Vector2(288, -64) if blooper_editor else Vector2(176, -96)
		if blooper_editor:
			part.swe_data = {"wings": 1, "paracaidas": 1}
		level.current_sub_area.add_part(part)
	if buzzy_editor:
		var part := BuzzyPart.create()
		part.position = Vector2(288, -32)
		part.wings = true
		level.current_sub_area.add_part(part)
	if spiny_editor:
		var part := SpinyPart.create()
		part.position = Vector2(288, -32)
		part.wings = true
		part.parachute = true
		level.current_sub_area.add_part(part)
	if spiny_runtime:
		for spec in [[Vector2(208, -32), false, SpinyPart.VARIANTS[0]], [Vector2(168, -32), false, SpinyPart.VARIANTS[1]],
				[Vector2(288, -112), true, SpinyPart.VARIANTS[0]], [Vector2(336, -144), false, SpinyPart.VARIANTS[0]]]:
			var part := SpinyPart.create()
			part.position = spec[0]
			part.wings = spec[1]
			part.variant = spec[2]
			level.current_sub_area.add_part(part)
		for x in range(20, 24):
			var ground := GroundPart.create()
			ground.position = Vector2(x * 16, -160)
			level.current_sub_area.add_part(ground)
	if buzzy_runtime:
		for spec in [[Vector2(144, -32), false, BuzzyPart.VARIANTS[0]], [Vector2(192, -32), false, BuzzyPart.VARIANTS[1]],
				[Vector2(240, -128), true, BuzzyPart.VARIANTS[0]], [Vector2(320, -144), false, BuzzyPart.VARIANTS[0]]]:
			var part := BuzzyPart.create()
			part.position = spec[0]
			part.wings = spec[1]
			part.variant = spec[2]
			level.current_sub_area.add_part(part)
		for x in range(18, 24):
			var ground := GroundPart.create()
			ground.position = Vector2(x * 16, -160)
			level.current_sub_area.add_part(ground)
	if flight_runtime:
		for part in level.current_sub_area.get_parts().get_children():
			if part is GoombaPart:
				part.position = Vector2(208, -112)
				part.variant = GoombaPart.VARIANTS[1]
				part.wings = true
				part.parachute = true
		for spec in [[KoopaPart.VARIANTS[0], Vector2(272, -32)], [KoopaPart.VARIANTS[1], Vector2(336, -96)]]:
			var part := KoopaPart.create()
			part.variant = spec[0]
			part.position = spec[1]
			part.wings = true
			level.current_sub_area.add_part(part)
	if koopa_editor or koopa_runtime:
		var koopa := KoopaPart.create()
		koopa.position = Vector2(288, -32)
		koopa.variant = KoopaPart.VARIANTS[1]
		level.current_sub_area.add_part(koopa)
		if koopa_runtime:
			var green := KoopaPart.create()
			green.position = Vector2(368, -32)
			level.current_sub_area.add_part(green)
	add_child(level)
	if any_piranha:
		for frame in (190 if piranha_runtime else 165):
			if not piranha_runtime and frame == 110:
				Input.action_press("player_jump")
			if frame == 150:
				Input.action_release("player_jump")
			await get_tree().physics_frame
		Input.action_release("player_jump")
	if blooper_runtime:
		for frame in 20:
			await get_tree().physics_frame
		var rising: Blooper = load("res://scenes/entities/blooper.tscn").instantiate()
		rising.position = Vector2(296, -80)
		level.current_sub_area.add(rising)
		var defeated: Blooper = load("res://scenes/entities/blooper.tscn").instantiate()
		defeated.position = Vector2(224, -128)
		level.current_sub_area.add(defeated)
		defeated.kill()
	if thwomp_runtime:
		for frame in 6:
			await get_tree().physics_frame
		for spec in [[Vector2(184, -224), 1, 0], [Vector2(264, -96), 2, 1], [Vector2(344, -96), 3, 1]]:
			var body: Thwomp = load("res://scenes/entities/thwomp.tscn").instantiate()
			body.variant = ThwompPart.VARIANTS[spec[2]]
			body.attack_direction = spec[1]
			body.position = spec[0]
			level.current_sub_area.add(body)
			if spec[1] == 1:
				body.phase = Thwomp.Phase.ATTACKING
	if monty_runtime:
		for frame in 6:
			await get_tree().physics_frame
		for spec in [[Vector2(160, -96), false, false], [Vector2(320, -96), true, false],
				[Vector2(256, -128), false, true]]:
			var body: Monty = load("res://scenes/entities/monty.tscn").instantiate()
			body.wings = spec[1]
			body.parachute = spec[2]
			body.position = spec[0]
			level.current_sub_area.add(body)
	if rocky_runtime:
		for frame in 6:
			await get_tree().physics_frame
		var rocky: Rocky = load("res://scenes/entities/rocky.tscn").instantiate()
		rocky.position = Vector2(240, -96)
		level.current_sub_area.add(rocky)
		var wrench := Wrench.new()
		wrench.position = Vector2(380, -128)
		wrench.direction = 1
		level.current_sub_area.add(wrench)
	if hammerbro_runtime:
		for frame in 6:
			await get_tree().physics_frame
		var specs := [[Vector2(128, -96), 0], [Vector2(184, -96), 1],
				[Vector2(240, -96), 2], [Vector2(296, -96), 3], [Vector2(352, -96), 4]]
		for spec in specs:
			var bro: HammerBro = load("res://scenes/entities/hammer_bro.tscn").instantiate()
			bro.variant = HammerBroPart.VARIANTS[spec[1]]
			bro.position = spec[0]
			level.current_sub_area.add(bro)
	if spiny_runtime or spiny_completion:
		level.hud.player.equip_shell_helmet(SpinyPart.VARIANTS[1].helmet_rules)
	if spiny_runtime:
		for frame in 180:
			await get_tree().physics_frame
	if helmet_completion or buzzy_runtime:
		level.hud.player.equip_buzzy_helmet()
	if buzzy_runtime:
		for frame in 20:
			await get_tree().physics_frame
	if flight_runtime:
		for frame in 20:
			await get_tree().physics_frame
	if koopa_runtime:
		var shell: KoopaShell = load("res://scenes/entities/koopa_shell.tscn").instantiate()
		shell.position = Vector2(192, -16)
		level.current_sub_area.add(shell)
		var beach: BeachKoopa = load("res://scenes/entities/beach_koopa.tscn").instantiate()
		beach.position = Vector2(240, -16)
		level.current_sub_area.add(beach)
		for frame in 20:
			await get_tree().physics_frame
	if editor_capture:
		for frame in 8:
			await get_tree().physics_frame
		if blooper_editor:
			var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
			ring.category = load("res://resources/palette/category_enemies.tres")
			ring.choose(5)
		if cheep_editor:
			var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
			ring.category = load("res://resources/palette/category_enemies.tres")
			ring.choose(6)
		if piranha_editor:
			var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
			ring.category = load("res://resources/palette/category_enemies.tres")
			ring.page_index = 1
			ring.choose(0)
		if muncher_editor:
			var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
			ring.category = load("res://resources/palette/category_enemies.tres")
			ring.page_index = 1
			ring.choose(1)
		if thwomp_editor:
			var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
			ring.category = load("res://resources/palette/category_enemies.tres")
			ring.page_index = 1
			ring.choose(2)
		if monty_editor:
			var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
			ring.category = load("res://resources/palette/category_enemies.tres")
			ring.page_index = 1
			ring.choose(3)
		if rocky_editor:
			var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
			ring.category = load("res://resources/palette/category_enemies.tres")
			ring.page_index = 1
			ring.choose(4)
		if hammerbro_editor:
			var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
			ring.category = load("res://resources/palette/category_enemies.tres")
			ring.page_index = 1
			ring.choose(5)
		for part in level.current_sub_area.get_parts().get_children():
			if muncher_editor and part is MuncherPart:
				pass
			elif thwomp_editor and part is ThwompPart:
				pass
			elif monty_editor and part is MontyPart:
				pass
			elif rocky_editor and part is RockyPart:
				pass
			elif hammerbro_editor and part is HammerBroPart:
				pass
			elif piranha_editor and part is PiranhaPart:
				level.editor.set_part_variant(part, &"fire")
			elif cheep_editor and part is CheepCheepPart:
				level.editor.set_part_variant(part, &"yellow")
				level.editor.set_part_modifier(part, &"parachute", true)
			elif blooper_editor and part is BlooperPart:
				pass # Source has no Blooper variant window.
			elif spiny_editor and part is SpinyPart:
				level.editor.set_part_variant(part, &"spiny")
			elif buzzy_editor and part is BuzzyPart:
				level.editor.set_part_variant(part, &"buzzy")
			elif koopa_editor and part is KoopaPart:
				level.editor.set_part_variant(part, &"red")
			elif enemy_capture and part is GoombaPart:
				level.editor.set_part_variant(part, &"goombud")
				if flight_editor:
					level.editor.set_part_modifier(part, &"wings", true)
					level.editor.set_part_modifier(part, &"parachute", true)
			elif not enemy_capture and not koopa_editor and not buzzy_editor and not spiny_editor and not blooper_editor and not cheep_editor and not piranha_editor and not muncher_editor and not thwomp_editor and not monty_editor and not rocky_editor and not hammerbro_editor and part is QuestionBlockPart and not part.contains_mushroom:
				level.editor.history.set_variant(part, &"mushroom")
			else:
				continue
			part.held = true
			part.set_process(false)
			break
		for frame in 45:
			await get_tree().physics_frame
	if completion_capture:
		for frame in 6:
			await get_tree().physics_frame
		var player := level.hud.player
		Input.action_press("player_right")
		Input.action_press("player_run")
		var jumped := false
		var jump_ticks := 0
		for frame in 480:
			if not jumped and player.position.x >= 248 and player.is_on_floor():
				Input.action_press("player_jump")
				jumped = true
			if jumped:
				jump_ticks += 1
				if jump_ticks == 42:
					Input.action_release("player_jump")
			await get_tree().physics_frame
			if level.is_completed or player.is_dead():
				break
		for action in ["player_right", "player_run", "player_jump"]:
			Input.action_release(action)
		if not level.is_completed:
			push_error("Rendered playthrough did not complete")
			get_tree().quit(1)
			return
		# Capture the original victory pose after the walk and time tally.
		for frame in 455:
			await get_tree().physics_frame
	if "--capture" in args or completion_capture or editor_capture or koopa_runtime or flight_runtime or buzzy_runtime or spiny_runtime or blooper_runtime or any_cheep or any_piranha or muncher_runtime or thwomp_runtime or monty_runtime or rocky_runtime or hammerbro_runtime:
		for frame in 35:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "res://.godot/porting-tests/slice_spiny_completion.png" if spiny_completion \
				else "res://.godot/porting-tests/slice_editor_hammerbro.png" if hammerbro_editor \
				else "res://.godot/porting-tests/slice_hammerbro.png" if hammerbro_runtime \
				else "res://.godot/porting-tests/slice_editor_rocky.png" if rocky_editor \
				else "res://.godot/porting-tests/slice_rocky.png" if rocky_runtime \
				else "res://.godot/porting-tests/slice_editor_monty.png" if monty_editor \
				else "res://.godot/porting-tests/slice_monty.png" if monty_runtime \
				else "res://.godot/porting-tests/slice_editor_thwomp.png" if thwomp_editor \
				else "res://.godot/porting-tests/slice_thwomp.png" if thwomp_runtime \
				else "res://.godot/porting-tests/slice_editor_muncher.png" if muncher_editor \
				else "res://.godot/porting-tests/slice_muncher.png" if muncher_runtime \
				else "res://.godot/porting-tests/slice_editor_piranha.png" if piranha_editor \
				else "res://.godot/porting-tests/slice_piranha.png" if piranha_runtime \
				else "res://.godot/porting-tests/slice_piranha_fire.png" if piranha_fire \
				else "res://.godot/porting-tests/slice_piranha_water.png" if piranha_water \
				else "res://.godot/porting-tests/slice_editor_cheep_cheep.png" if cheep_editor \
				else "res://.godot/porting-tests/slice_cheep_cheep.png" if cheep_runtime \
				else "res://.godot/porting-tests/slice_cheep_water.png" if cheep_water \
				else "res://.godot/porting-tests/slice_cheep_lava.png" if cheep_lava \
				else "res://.godot/porting-tests/slice_helmet_completion.png" if helmet_completion \
				else "res://.godot/porting-tests/slice_completion.png" if level.is_completed \
				else "res://.godot/porting-tests/slice_editor_blooper.png" if blooper_editor \
				else "res://.godot/porting-tests/slice_blooper.png" if blooper_runtime \
				else "res://.godot/porting-tests/slice_editor_spiny.png" if spiny_editor \
				else "res://.godot/porting-tests/slice_spiny.png" if spiny_runtime \
				else "res://.godot/porting-tests/slice_editor_buzzy.png" if buzzy_editor \
				else "res://.godot/porting-tests/slice_buzzy.png" if buzzy_runtime \
				else "res://.godot/porting-tests/slice_editor_flight.png" if flight_editor \
				else "res://.godot/porting-tests/slice_flight.png" if flight_runtime \
				else "res://.godot/porting-tests/slice_editor_koopa.png" if koopa_editor \
				else "res://.godot/porting-tests/slice_koopa.png" if koopa_runtime \
				else "res://.godot/porting-tests/slice_editor_enemy.png" if enemy_capture \
				else "res://.godot/porting-tests/slice_editor.png" if "--capture-editor" in args \
				else "res://.godot/porting-tests/slice_preview.png"
		var error := get_viewport().get_texture().get_image().save_png(path)
		print("CAPTURE_RESULT ", "PASS" if error == OK else "FAIL")
		get_tree().quit(0 if error == OK else 1)
