extends "res://tests/scripts/port_test.gd"
## Palette -> paint/move/erase/variant -> undo/redo -> save/reopen, using live Parts.


func part_counts(level: Level) -> Dictionary:
	var counts := {}
	for part in level.current_sub_area.get_parts().get_children():
		var id: String = part.get_script().get_global_name()
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


func shortcut(code: Key, shift := false) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = code
	pressed.ctrl_pressed = true
	pressed.shift_pressed = shift
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await ticks(1)
	var released := pressed.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)
	await ticks(1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fixture := LevelProcessor.decode_swe(FileAccess.get_file_as_bytes("res://tests/fixtures/port_slice.swe"))
	fixture.data.MAIN.NIVEL.insert(1, {"object": "obj_future_unported", "custom": "keep-through-undo"})
	fixture.data.MAIN.NIVEL[0].future_variant = "retained-on-restore"
	var source := "res://.godot/porting-tests/history_source.swe"
	var file := FileAccess.open(source, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(fixture.data))
	file.close()
	var level := await LevelActionBtn.prepare_level(source, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var editor := level.editor
	var ring: PaletteRing = editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	var supported := [GroundPart, CoinPart, QuestionBlockPart, TurnBlockPart, GoombaPart, KoopaPart, BuzzyPart, SpinyPart, BlooperPart, CheepCheepPart, PiranhaPart, MuncherPart, ThwompPart, GrrrolPart, MontyPart, RockyPart, HammerBroPart, ChompPart, MushroomPart, FireFlowerPart, StarPart, OneUpPart, HardBlockPart, HiddenBlockPart, SpikePart, IceBlockPart, CloudPart]
	supported.append_array([DonutPart, NoteBlockPart])
	supported.append_array([SlopePart, GentleSlopePart])
	supported.append(SpringPart)
	supported.append(SemisolidPart)
	supported.append(DoorPart)
	for category_name in ["terrain", "items", "enemies", "gizmos"]:
		var category: PaletteCategory = load("res://resources/palette/category_%s.tres" % category_name)
		for page in category.pages:
			for entry in page.items:
				if entry != null and not entry.disabled:
					check(entry.part in supported, "An unimplemented placeholder is selectable in the palette")
	ring.category = load("res://resources/palette/category_enemies.tres")
	check(ring.choose(0) and editor.get_selected_part() == GoombaPart,
			"Enemy palette did not select the ported Goomba resource")
	var goomba := editor.place(Vector2i(24, -5))
	check(goomba is GoombaPart, "Palette placement created a placeholder enemy")
	editor.history.undo()
	check(not goomba.is_inside_tree(), "Undo did not remove the placed enemy")
	editor.history.redo()
	check(goomba.is_inside_tree(), "Redo did not restore the placed enemy")
	ring.category = load("res://resources/palette/category_items.tres")
	check(ring.choose(3) and editor.get_selected_part() == MushroomPart, "Mushroom palette still points to a placeholder")
	var mushroom := editor.place(Vector2i(26, -5))
	check(mushroom is MushroomPart, "Standalone mushroom placement failed")
	check(not ring.choose(-1), "Palette accepted an invalid sector")

	ring.category = load("res://resources/palette/category_terrain.tres")
	check(ring.choose(0), "Ground could not be selected")
	editor.history.begin_stroke("Paint")
	var tiles: Array[GroundPart] = []
	for x in range(24, 27):
		tiles.append(editor.place(Vector2i(x, -3)))
	editor.history.end_stroke()
	await ticks(2)
	editor.history.undo()
	for tile in tiles:
		check(not tile.is_inside_tree(), "One undo did not remove the entire paint stroke")
	editor.history.redo()
	await ticks(2)
	check(tiles[0].swe_atlas == Vector2(0, 96) and tiles[2].swe_atlas == Vector2(80, 96),
			"Redo lost native terrain connections")

	var before: Vector2 = tiles[0].position
	tiles[0].held = true
	tiles[0].set_process(false)
	tiles[0].position += Vector2(0, -16)
	tiles[0].held = false
	tiles[0].set_process(true)
	check(tiles[0].position == before + Vector2(0, -16), "Valid drag did not move the terrain")
	editor.history.undo()
	check(tiles[0].position == before, "Undo did not restore a dragged part's position")
	# Right-click erase needs Part's mouse_entered signal; GroundPart used to
	# override _ready without super(), which silently killed ground hovering.
	tiles[0].mouse_entered.emit()
	await ticks(1)
	check(editor.hovered_part == tiles[0],
			"Ground tile no longer receives hover; right-click erase would do nothing")
	tiles[0].mouse_exited.emit()
	await ticks(1)
	check(editor.hovered_part == null, "Ground hover did not clear on exit")
	# A rejected drop must preserve the redo branch.
	tiles[0].held = true
	tiles[0].set_process(false)
	tiles[0].position = tiles[1].position
	tiles[0].held = false
	tiles[0].set_process(true)
	check(tiles[0].position == before and editor.history.can_redo(), "Invalid drop changed history or overwrote occupied terrain")
	editor.history.redo()
	await ticks(2)
	editor.history.begin_stroke("Erase")
	editor.erase_part(tiles[0])
	editor.erase_part(tiles[1])
	editor.history.end_stroke()
	check(not tiles[0].is_inside_tree() and not tiles[1].is_inside_tree(), "Eraser did not detach both parts")
	editor.history.undo()
	check(tiles[0].is_inside_tree() and tiles[1].is_inside_tree(), "Erase undo did not restore the full stroke")
	var start: StartingGround = level.current_sub_area.get_parts().get_node("StartingGround")
	editor.erase_part(start)
	check(start.is_inside_tree(), "Eraser removed protected starting ground")
	var original_start := start.position
	var before_resize := part_counts(level)
	editor.history.begin_stroke("Resize starting ground")
	start.resize_to(-32)
	await ticks(2)
	start.resize_to(-48)
	editor.history.end_stroke()
	check(start.position.y == -48 and part_counts(level).GroundPart < before_resize.GroundPart,
			"Resizing did not cover and remove existing terrain")
	editor.history.undo()
	check(start.position == original_start and part_counts(level) == before_resize,
			"Resize undo did not restore the original height and all covered terrain")
	check(start.get_node("%CollShape").shape.size.y == absf(original_start.y),
			"Resize undo left a stale start-ground collider")
	editor.history.redo()
	check(start.position.y == -48, "Resize redo did not restore the final height")
	editor.history.undo()
	await ticks(2)

	var block: QuestionBlockPart
	var coin: CoinPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is QuestionBlockPart and not part.contains_mushroom:
			block = part
		if part is CoinPart and coin == null:
			coin = part
	Utility.camera_position.x = 96
	await ticks(2)
	var dragged_mushroom := MushroomPart.create()
	dragged_mushroom.position = Vector2(384, -112)
	level.current_sub_area.add_part(dragged_mushroom)
	dragged_mushroom.load()
	dragged_mushroom.held = true
	dragged_mushroom.position = block.position
	dragged_mushroom.held = false
	check(not dragged_mushroom.is_inside_tree(), "Dragging into a block did not consume the loose item")
	block.held = true
	block.set_process(false)
	await ticks(40)
	check(is_instance_valid(block._window), "Long press did not open the native variant window")
	if is_instance_valid(block._window):
		var screen_rect: Rect2 = block._window.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, block._window.size)
		check(get_viewport().get_visible_rect().grow(1).encloses(screen_rect),
				"Scrolled variant window was positioned outside the viewport")
		check(block._window.get_node("Content/Options").get_child_count() == 1 \
				and block._window.has_node("Content/Options/StoredContent"),
				"Long press offered a contents picker instead of the stored item")
		block._window.close()
	block.held = false
	block.set_process(true)
	check(block.contains_mushroom and block.get_node("%Graphics/Content").visible,
			"Dragged item did not update block content and preview")
	editor.history.undo()
	check(not block.contains_mushroom, "Undo did not restore the block's previous contents")
	editor.history.redo()
	check(block.contains_mushroom, "Redo did not restore the mushroom contents")

	# A detached Part's old source index must not overwrite another saved row.
	editor.erase_part(coin)
	var path := "res://.godot/porting-tests/history_saved.swe"
	var saved: Dictionary = await editor.save_to_path(path)
	check(saved.error == OK, "Saving after erase failed")
	editor.history.undo()
	check(coin.is_inside_tree(), "Undo after saving did not restore the removed coin")
	saved = await editor.save_to_path(path)
	check(saved.error == OK, "Saving after undo failed")
	var reopened: Level = await LevelProcessor.from_swe(path)
	check(part_counts(reopened) == part_counts(level), "Save after undo corrupted part types or counts")
	var preserved := 0
	var retained_coin := false
	for entry in reopened.source_swe.MAIN.NIVEL:
		if entry.get("object", "") == "obj_future_unported" and entry.get("custom", "") == "keep-through-undo":
			preserved += 1
		if entry.get("future_variant", "") == "retained-on-restore":
			retained_coin = true
	check(preserved == 1 and retained_coin, "Undo/save lost unknown object or restored Part fields")
	var mushroom_blocks := 0
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is QuestionBlockPart and part.contains_mushroom:
			mushroom_blocks += 1
	check(mushroom_blocks == 2, "Block content did not survive undo/redo and save/reopen")
	reopened.free()
	level.play()
	await ticks(8)
	var powerup: Mushroom
	for entity in level.current_sub_area.get_foreground().get_children():
		if entity is Mushroom:
			powerup = entity
	check(powerup != null, "Standalone mushroom Part did not build the existing runtime")
	if powerup != null:
		level.hud.player.position = powerup.position
		await ticks(80)
		check(level.hud.player.get_powerup() is SuperPowerup and not is_instance_valid(powerup),
				"Placed mushroom did not grant the super powerup on physical contact")
	level.edit()
	await ticks(3)

	editor.history.clear()
	check(is_instance_valid(goomba) and goomba.is_inside_tree(), "Clearing history freed an active Part")
	ring.category = load("res://resources/palette/category_items.tres")
	ring.choose(0)
	var discarded := editor.place(Vector2i(30, -5))
	editor.history.undo()
	var replacement := editor.place(Vector2i(31, -5))
	check(not editor.history.can_redo() and not is_instance_valid(discarded),
			"A new edit did not discard and free the undone creation")
	editor.erase_part(replacement)
	editor.history.clear()
	check(not is_instance_valid(replacement), "Clearing history leaked a detached erased Part")
	var keyboard_coin := editor.place(Vector2i(32, -5))
	await shortcut(KEY_Z)
	check(not keyboard_coin.is_inside_tree(), "Ctrl+Z did not undo through the editor input handler")
	await shortcut(KEY_Y)
	check(keyboard_coin.is_inside_tree(), "Ctrl+Y did not redo through the editor input handler")
	ring.category = load("res://resources/palette/category_terrain.tres")
	ring.choose(0)
	var before_paint := part_counts(level)
	editor.history.begin_stroke("Paint")
	for x in range(16, 56):
		editor.place(Vector2i(x, -10))
	editor.history.end_stroke()
	await ticks(2)
	check(not editor.get_node("HistoryControls/Undo").disabled, "Undo button did not become available after painting")
	var started := Time.get_ticks_usec()
	editor.get_node("HistoryControls/Undo").pressed.emit()
	check(part_counts(level) == before_paint, "Undo button did not remove all 40 tiles from one brush stroke")
	await shortcut(KEY_Z, true)
	check(part_counts(level).GroundPart == before_paint.GroundPart + 40,
			"Ctrl+Shift+Z did not restore the complete brush stroke")
	print("BULK_HISTORY_MS ", (Time.get_ticks_usec() - started) / 1000.0)
	await finish("EDITOR_HISTORY_RESULT", level)
