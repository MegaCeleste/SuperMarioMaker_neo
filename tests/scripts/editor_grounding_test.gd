# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Real editor Parts: opaque contact, repeated refresh, history and saved state.

var capture := false
var sheet: Image
var traces: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	capture = "--capture-editor-grounding" in OS.get_cmdline_user_args()
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(35)
	for part in level.current_sub_area.get_parts().get_children():
		if not part is EditorPlayer and not part is StartingGround and not part is GoalPolePart:
			part.free()
	Utility.camera_scale = Vector2(4, 4)
	Utility.camera_position = Vector2(336, -224)
	var cases: Array[Dictionary] = []
	for family in [
		["goomba", GoombaPart.VARIANTS], ["koopa", KoopaPart.VARIANTS],
		["buzzy", BuzzyPart.VARIANTS], ["spiny", SpinyPart.VARIANTS],
		["blooper", [null]], ["cheep_cheep", CheepCheepPart.VARIANTS],
		["piranha", PiranhaPart.VARIANTS], ["muncher", MuncherPart.VARIANTS],
		["thwomp", ThwompPart.VARIANTS], ["monty", [MontyPart.VARIANT]],
		["rocky", [RockyPart.VARIANT]], ["hammer_bro", HammerBroPart.VARIANTS],
		["chomp", ChompPart.VARIANTS]]:
		for variant in family[1]:
			var scene: String = "grrrol" if variant is GrrrolVariant and not variant.legacy else family[0]
			cases.append({"scene": scene, "variant": variant, "orientation": 0, "wings": false})
	for family in ["buzzy", "spiny", "piranha"]:
		for orientation in ([1, 2, 3] if family == "piranha" else [1]):
			cases.append({"scene": family, "variant": null, "orientation": orientation, "wings": false})
	for family in ["buzzy", "spiny"]:
		cases.append({"scene": family, "variant": null, "orientation": 0, "wings": true})
	if capture:
		sheet = Image.create(1920, ceili(cases.size() / 6.0) * 320, false, Image.FORMAT_RGBA8)
	for entry in cases:
		await check_preview(level, entry)
	var file := FileAccess.open("res://.godot/porting-tests/editor_grounding.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(traces, "  "))
	file.close()
	if capture:
		check(sheet.save_png("res://.godot/porting-tests/slice_editor_grounding.png") == OK, "Could not save native editor grounding pixels")
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("EDITOR_GROUNDING_RESULT", level)


func snapshot(level: Level) -> Dictionary:
	var result := SWELevelSerializer.snapshot(level, LevelProcessor.SWE_OBJECT_TABLE, LevelProcessor.SWE_GROUND_FRAME_TABLE)
	check(result.error == OK, "Preview refresh made editor state unsaveable")
	return result.get("data", {})


func primary(part: Part) -> Sprite2D:
	return part.get_node("Graphics").get_child(0) as Sprite2D


## Scan source alpha pixels independently of the contact-placement helper.
func visible_bounds(sprite: Sprite2D) -> Rect2:
	var image := sprite.texture.get_image()
	var drawing := sprite.get_rect()
	var points := PackedVector2Array()
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a == 0:
				continue
			var pixel := Vector2(image.get_width() - x - 1 if sprite.flip_h else x,
					image.get_height() - y - 1 if sprite.flip_v else y) + drawing.position
			for corner in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]:
				points.append(sprite.to_global(pixel + corner))
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func overlap(part: Part, orientation: int) -> float:
	var collider: CollisionShape2D = part.get_node("CollShape")
	var placement := collider.shape.get_rect()
	placement.position += collider.global_position
	var art := visible_bounds(primary(part))
	match orientation:
		1: return placement.position.y - art.position.y
		2: return placement.position.x - art.position.x
		3: return art.end.x - placement.end.x
	return art.end.y - placement.end.y


func contact_side(part: Part) -> int:
	if part is PiranhaPart:
		return part.attachment_orientation()
	if part is BuzzyPart or part is SpinyPart:
		return 1 if part.is_ceiling_attached() else 0
	return 0


func check_preview(level: Level, entry: Dictionary) -> void:
	var area := level.current_sub_area
	var part: Part = load("res://scenes/level/parts/%s_part.tscn" % entry.scene).instantiate()
	if entry.variant != null:
		part.set("variant", entry.variant)
		if entry.variant is GrrrolVariant:
			part.set("attack_direction", 2)
	if entry.wings:
		part.set("wings", true)
	part.swe_data = {"future_preview_field": {"keep": 71}}
	part.position = Vector2(480, -144)
	area.add_part(part)
	part.load()
	var collider: CollisionShape2D = part.get_node("CollShape")
	var footprint := collider.shape.get_rect()
	footprint.position += collider.position
	part.position.y = -96 - footprint.end.y if entry.orientation == 0 else -160
	var supports: Array[GroundPart] = []
	if entry.orientation == 0:
		for column in range(-1, 5):
			var ground := GroundPart.create()
			ground.position = Vector2(480 + column * 16, -96)
			area.add_part(ground)
			supports.append(ground)
	else:
		var ground := GroundPart.create()
		ground.position = part.position + [Vector2.ZERO, Vector2(0, -16), Vector2(-16, 0), Vector2(16, 0)][entry.orientation]
		area.add_part(ground)
		supports.append(ground)
	for ground in supports:
		ground.load()
	part.load()
	await ticks(2)
	var label := "%s/%s side=%s wings=%s" % [entry.scene, part.get_variant(), entry.orientation, entry.wings]
	var saved := snapshot(level)
	var at := part.position
	var collision := collider.transform
	var shape_rect := collider.shape.get_rect()
	var grid: Vector2i = part._grid_pos
	var sprite_at := primary(part).position
	for refresh in 3:
		part.load()
	check(primary(part).position.is_equal_approx(sprite_at), "Preview refresh accumulated a draw offset: " + label)
	check(part.position == at and part._grid_pos == grid and collider.transform == collision
			and collider.shape.get_rect() == shape_rect and snapshot(level) == saved,
			"Preview refresh changed placement/collision/source coordinates: " + label)
	for option in part.get_modifiers():
		if option.id not in [&"wings", &"parachute", &"large"] or option.get("disabled", false):
			continue
		var enabled := part.has_modifier(option.id)
		level.editor.history.set_modifier(part, option.id, not enabled)
		check(is_equal_approx(overlap(part, contact_side(part)), 1), "Size/attachment switch lost preview contact: " + label)
		level.editor.history.undo()
		level.editor.history.redo()
		level.editor.history.undo()
		check(primary(part).position.is_equal_approx(sprite_at) and snapshot(level) == saved,
				"Attachment history shifted the preview or saved source: " + label)
	for choice in part.get_variants():
		if choice.id == part.get_variant() or choice.get("disabled", false):
			continue
		level.editor.history.set_variant(part, choice.id)
		check(is_equal_approx(overlap(part, contact_side(part)), 1), "Type switch lost preview contact: " + label)
		level.editor.history.undo()
		level.editor.history.redo()
		level.editor.history.undo()
		check(primary(part).position.is_equal_approx(sprite_at) and snapshot(level) == saved,
				"Type history shifted the preview or saved source: " + label)
	check(Vector2(primary(part).texture.get_image().get_size()) == primary(part).texture.get_size(),
			"Generating type icons resized the shared preview image: " + label)
	# Exercise the actual hold/drop path and native move history.
	part.set_process(false)
	part.held = true
	part._tween.kill()
	part.get_node("Graphics").rotation = 0
	part.position += Vector2(16, 0)
	part.held = false
	part._tween.kill()
	part.get_node("Graphics").scale = Vector2.ONE
	level.editor.history.undo()
	part.set_process(true)
	await ticks(8)
	check(part.position == at and primary(part).position.is_equal_approx(sprite_at)
			and snapshot(level) == saved, "Hold/drop/undo changed preview or saved position: " + label)
	var contact := overlap(part, entry.orientation)
	traces.append({"case": label, "overlap": contact, "part": str(part.position), "draw": str(primary(part).position)})
	check(is_equal_approx(contact, 1), "Editor opaque pixels must overlap the placement surface by1px: %s actual=%s" % [label, contact])
	if capture:
		if is_instance_valid(level.editor.touch_effect):
			level.editor.touch_effect.queue_free()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var pixels := get_viewport().get_texture().get_image()
		var center := part.global_position + footprint.get_center()
		if entry.orientation == 0:
			center.y = -126
		elif entry.orientation == 1:
			center.y = part.position.y + 30
		var screen := Vector2i((get_viewport().canvas_transform * center).round())
		var index := traces.size() - 1
		sheet.blit_rect(pixels, Rect2i(screen - Vector2i(160, 160), Vector2i(320, 320)), Vector2i(index % 6, index / 6) * 320)
	level.editor.history.clear()
	part.free()
	for ground in supports:
		ground.free()
	await ticks(1)
