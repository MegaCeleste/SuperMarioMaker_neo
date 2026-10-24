extends "res://tests/scripts/port_test.gd"
## Native type selection + signed SWE round-trip + physical ledge/stun behavior.

const FIXTURE := "res://tests/fixtures/port_slice.swe"
const NORMAL: GoombaVariant = preload("res://resources/content/smw_goomba_normal.tres")
const GOOMBUD: GoombaVariant = preload("res://resources/content/smw_goomba_goombud.tres")


func write_data(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()


func enemies(level: Level) -> Array[Galoomba]:
	var found: Array[Galoomba] = []
	for node in level.current_sub_area.get_foreground().get_children():
		if node is Galoomba:
			found.append(node)
	return found


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await check_editor_and_save()
	await check_runtime()
	await finish("GOOMBA_VARIANTS_RESULT")


func check_editor_and_save() -> void:
	var raw := LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE))
	raw.data.MAIN.NIVEL.append({"object": "obj_goombrat_res", "x_pos": 400, "y_pos": 400,
		"future_variant": "retain-goombud", "direct_t": 0})
	var path := "res://.godot/porting-tests/goomba_variants_source.swe"
	write_data(path, raw.data)
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var editor := level.editor
	var original: GoombaPart
	var imported: GoombaPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is GoombaPart:
			if part.variant.id == &"goombud":
				imported = part
			else:
				original = part
	check(imported != null and original != null, "SWE object IDs did not restore distinct Goomba types")
	check(imported.get_node("Graphics").get_child(0).texture.resource_path.contains("spr_galoomba2"),
			"Imported Goombud preview uses the normal sprite")
	var ring: PaletteRing = editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	ring.choose(0)
	var normal := editor.place(Vector2i(28, -3)) as GoombaPart
	check(normal.variant.id == &"galoomba", "The initial Goomba tool default changed")
	original.held = true
	original.set_process(false)
	await ticks(40)
	check(is_instance_valid(original._window), "Goomba long press did not open its native variant window")
	if is_instance_valid(original._window):
		original._window.get_node("Content/Options/goombud").pressed.emit()
	original.held = false
	original.set_process(true)
	check(original.variant.id == &"goombud", "Window selection did not change the Goomba type")
	editor.history.undo()
	check(original.variant.id == &"galoomba", "Undo did not restore the original enemy type")
	editor.history.redo()
	check(original.variant.id == &"goombud", "Redo did not restore the selected enemy type")
	check(editor.get_palette_icon(GoombaPart) == GOOMBUD.icon,
			"The Goomba card did not retain the selected type")
	var next := editor.place(Vector2i(30, -3)) as GoombaPart
	check(next.variant.id == &"goombud", "Subsequent placement ignored the selected type")
	path = "res://.godot/porting-tests/goomba_variants_saved.swe"
	var saved: Dictionary = await editor.save_to_path(path)
	check(saved.error == OK, "Saving Goomba variants failed")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var ids := {}
	var retained := false
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is GoombaPart:
			ids[part.variant.id] = int(ids.get(part.variant.id, 0)) + 1
			if part.swe_data.get("future_variant", "") == "retain-goombud":
				retained = true
	check(ids == {&"galoomba": 1, &"goombud": 3} and retained,
			"Enemy types/counts or unknown variant fields changed on save/reopen")
	for entry in reopened.source_swe.MAIN.NIVEL:
		if entry.get("object", "") in ["obj_goomba_res", "obj_goombrat_res"]:
			check(entry.direct_t == 0, "A fabricated facing direction was written to SWE")
	reopened.free()
	level.queue_free()
	await ticks(2)


func check_runtime() -> void:
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	var sub := level.current_sub_area
	for part in sub.get_parts().get_children():
		if not part is EditorPlayer and not part is StartingGround:
			sub.get_parts().remove_child(part)
			part.free()
	for x in range(12, 20):
		var ground := GroundPart.create()
		ground.position = Vector2(x * 16, -96)
		sub.add_part(ground)
	for spec in [[NORMAL, 224], [GOOMBUD, 272]]:
		var part := GoombaPart.create()
		part.variant = spec[0]
		part.position = Vector2(spec[1], -112)
		sub.add_part(part)
	add_child(level)
	await ticks(8)
	var normal: Galoomba
	var goombud: Galoomba
	for enemy in enemies(level):
		if enemy.variant.id == &"goombud":
			goombud = enemy
		else:
			normal = enemy
	check(normal != null and goombud != null, "Parts did not build both runtime types")
	check(normal.get_node("CollShape").shape.size.x == 10 and goombud.get_node("CollShape").shape.size.x == 10,
			"Goomba collision width does not match its source sprite mask")
	var stayed := true
	var turned := false
	for frame in 240:
		await ticks(1)
		if not is_instance_valid(goombud):
			stayed = false
			break
		stayed = stayed and goombud.position.y < -95.5 and goombud.position.x >= 192 and goombud.position.x <= 320
		turned = turned or goombud.get_node("SlideComponent").direction == 1
	check(stayed and turned, "Goombud fell from the platform or never turned at its ledge")
	check(not is_instance_valid(normal) or normal.position.y > -80,
			"Normal Galoomba incorrectly acquired Goombud's ledge avoidance")
	if not is_instance_valid(goombud):
		level.queue_free()
		await ticks(2)
		return
	var player := level.hud.player
	player.position = goombud.position + Vector2(0, -48)
	player.velocity = Vector2(0, 120)
	player.state_machine.switch(PlayerFallingState)
	await ticks(20)
	var flipped: StompedGaloomba
	for node in sub.get_foreground().get_children():
		if node is StompedGaloomba:
			flipped = node
	check(flipped != null and flipped.variant.id == &"goombud", "Normal stomp lost the Goombud type")
	if flipped == null:
		level.queue_free()
		await ticks(2)
		return
	check(flipped.get_node("Graphics/Sprite").sprite_frames.get_frame_texture("walk", 0)
			.resource_path.contains("spr_galoomba_hold2"), "Flipped Goombud uses the normal held sprite")
	player.position = Vector2(64, -16)
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)
	await ticks(520)
	check(is_instance_valid(flipped) and flipped.get_node("Graphics/Sprite").position.x == 0,
			"Stunned enemy recovered or shook before the original nine-second warning")
	await ticks(50)
	check(is_instance_valid(flipped) and absf(flipped.get_node("Graphics/Sprite").position.x) == 1,
			"Stunned enemy did not shake during the last second before recovery")
	player.position = flipped.position
	player.velocity = Vector2.ZERO
	Input.action_press("player_run")
	await ticks(6)
	check(player.held_item == flipped, "The flipped Goombud could not be picked up")
	await ticks(620)
	check(is_instance_valid(flipped) and player.held_item == flipped,
			"Goombud recovered while being carried instead of resetting its warning timer")
	Input.action_release("player_run")
	player.drop_item()
	await ticks(2)
	player.position = Vector2(64, -16)
	player.velocity = Vector2.ZERO
	await ticks(610)
	var recovered := enemies(level)
	check(not is_instance_valid(flipped) and recovered.size() == 1 and recovered[0].variant.id == &"goombud",
			"Released Goombud did not recover into its original walking type")
	check(not player.is_dead() and player.score == 200, "Type/recovery transitions duplicated score or damaged the distant player")
	if recovered.size() == 1:
		player.position = recovered[0].position + Vector2(0, -64)
		player.velocity = Vector2.ZERO
		player.state_machine.switch(PlayerSpinJumpingState)
		player.velocity.y = 120
		await ticks(20)
		check(enemies(level).is_empty() and player.score == 400,
				"Spin stomp did not destroy Goombud and award points once")
	var retiring: StompedGaloomba = load("res://scenes/entities/stomped_galoomba.tscn").instantiate()
	retiring.variant = GOOMBUD
	retiring.position = Vector2(240, -96)
	sub.add(retiring)
	retiring._recover()
	level.reload()
	await ticks(8)
	check(enemies(level).size() == 2, "A queued recovery leaked an enemy into the restarted course")
	release_input()
	var pending: Galoomba = load("res://scenes/entities/galoomba.tscn").instantiate()
	sub.add_deferred(pending)
	level.free()
	await ticks(2)
	check(not is_instance_valid(pending), "Exiting a course leaked a pending unparented enemy")
