# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Independent native editor toggles, signed SWE, physical source flight patterns.

const FIXTURE := "res://tests/fixtures/port_slice.swe"
const NORMAL: GoombaVariant = preload("res://resources/content/smw_goomba_normal.tres")
const GOOMBUD: GoombaVariant = preload("res://resources/content/smw_goomba_goombud.tres")
const GREEN: KoopaVariant = preload("res://resources/content/smw_koopa_green.tres")
const RED: KoopaVariant = preload("res://resources/content/smw_koopa_red.tres")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await check_editor_and_save(false)
	await check_editor_and_save(true)
	await check_flight_patterns()
	await check_parachutes()
	await check_flight_collisions()
	await check_stomps_and_lifecycle()
	await finish("ENEMY_FLIGHT_RESULT")


func make_level() -> Level:
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	var sub := level.current_sub_area
	for part in sub.get_parts().get_children():
		if not part is EditorPlayer and not part is StartingGround:
			sub.get_parts().remove_child(part)
			part.free()
	for x in range(12, 96):
		var ground := GroundPart.create()
		ground.position = Vector2(x * 16, -96)
		sub.add_part(ground)
	add_child(level)
	# Trajectory oracles intentionally use high/offscreen spawn positions.
	sub.actor_activity.enabled = false
	await ticks(8)
	return level


func actor_at(level: Level, variant: Resource, pos: Vector2, wings := true, parachute := false) -> Enemy:
	var actor: Enemy = load("res://scenes/entities/galoomba.tscn" if variant is GoombaVariant
			else "res://scenes/entities/green_koopa.tscn").instantiate()
	actor.variant = variant
	actor.position = pos
	actor.get_node("FlightComponent").wings = wings
	actor.get_node("FlightComponent").parachute = parachute
	level.current_sub_area.add(actor)
	return actor


func click(button: Button) -> void:
	var at := button.get_global_transform_with_canvas() * (button.size / 2)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	# Headless windows can be smaller than the logical viewport. Push viewport
	# coordinates through the normal input/GUI pipeline without screen scaling.
	get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await ticks(1)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	get_viewport().push_input(event, true)
	await ticks(1)


func check_editor_and_save(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	for entry in data.MAIN.NIVEL:
		if entry.object == NORMAL.object_id:
			entry.y_pos = 320
			entry.wings = 1
			entry.paracaidas = 1
			entry.future_attachment = "both"
	for spec in [[GOOMBUD.object_id, 400, 1, 0], [GREEN.object_id, 448, 0, 1], [RED.object_id, 496, 1, 1]]:
		data.MAIN.NIVEL.append({"object": spec[0], "x_pos": spec[1], "y_pos": 208,
			"wings": spec[2], "paracaidas": spec[3], "future_attachment": "keep"})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for entry in data.S0.S4:
			entry.ID = entry.object
			entry.xx = entry.x_pos
			entry.yy = entry.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				entry.erase(key)
	var path := "res://.godot/porting-tests/flight_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var original: GoombaPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is GoombaPart and part.variant == NORMAL:
			original = part
	check(original != null and original.wings and original.parachute, "Loader did not restore independent attachment flags")
	if original == null:
		level.queue_free()
		await ticks(2)
		return
	check(original.get_node("Graphics/Attachments").get_child_count() == 2,
			"Imported attached enemy has no editor overlays")
	var editor := level.editor
	if not modern:
		var ring: PaletteRing = editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
		ring.category = load("res://resources/palette/category_enemies.tres")
		ring.choose(0)
		original.held = true
		original.set_process(false)
		await ticks(40)
		var window := original._window
		check(window != null, "Long press failed to open the native attachment window")
		if window != null:
			var wings: Button = window.get_node("Content/Attachments/wings")
			var parachute: Button = window.get_node("Content/Attachments/parachute")
			check(wings.button_pressed and parachute.button_pressed and wings.button_group == null,
					"Attachment toggles incorrectly share a mutually exclusive type group")
			await click(wings)
			check(not original.wings and original.parachute and not window._closing,
					"Actual mouse click closed the window or failed to toggle wings independently")
			await click(parachute)
			check(not original.wings and not original.parachute and not window._closing,
					"Parachute toggle failed to remain independent of wings")
			window.close()
		original.held = false
		original.set_process(true)
		await ticks(8)
		editor.history.undo()
		check(not original.wings and original.parachute, "Parachute undo lost the current wing state")
		editor.history.undo()
		check(original.wings and original.parachute, "Attachment undo lost the other independent flag")
		editor.history.redo()
		check(not original.wings and original.parachute, "Attachment redo did not restore the toggled state")
		editor.set_part_modifier(original, &"wings", true)
		editor.set_part_variant(original, &"goombud")
		check(original.wings and original.parachute and original.variant == GOOMBUD,
				"Changing enemy type dropped the source attachment flags")
		var next := editor.place(Vector2i(34, -10)) as GoombaPart
		check(next.variant == GOOMBUD and not next.wings and not next.parachute,
				"Object attachment toggles incorrectly changed subsequent tool defaults")
	var expected := {}
	for part in level.current_sub_area.get_parts().get_children():
		if part is GoombaPart or part is KoopaPart:
			expected[part.position.x] = [part.variant.id, part.wings, part.parachute]
	var result: Dictionary = await editor.save_to_path(path)
	check(result.error == OK, "Saving attachment flags failed")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var retained := 0
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is GoombaPart or part is KoopaPart:
			check(expected[part.position.x] == [part.variant.id, part.wings, part.parachute],
					"Attachment/type flags changed through signed SWE save/reopen")
			retained += int(part.swe_data.has("future_attachment"))
	check(retained == 4, "Saving attachments discarded unknown source fields")
	add_child(reopened)
	var actors := 0
	for node in reopened.current_sub_area.get_foreground().get_children():
		if node is Galoomba or node is Koopa:
			var flight: EnemyFlightComponent = node.get_node("FlightComponent")
			actors += 1
			check(expected[node.position.x - 8] == [node.variant.id, flight.wings, flight.parachute],
					"SWE Part failed to build its selected runtime attachments")
	check(actors == expected.size(), "Reopened attached Parts failed to build runtime enemies")
	await ticks(8)
	reopened.reload()
	for node in reopened.current_sub_area.get_foreground().get_children():
		if node is Galoomba or node is Koopa:
			var flight: EnemyFlightComponent = node.get_node("FlightComponent")
			check(expected[node.position.x - 8] == [node.variant.id, flight.wings, flight.parachute],
					"Retry failed to restore the editor Part's original attachment flags")
	reopened.queue_free()
	level.queue_free()
	await ticks(2)


func check_flight_patterns() -> void:
	var level := await make_level()
	var green := actor_at(level, GREEN, Vector2(800, -96))
	var red := actor_at(level, RED, Vector2(1200, -240))
	var normal := actor_at(level, NORMAL, Vector2(600, -96))
	var goombud := actor_at(level, GOOMBUD, Vector2(1000, -96))
	var green_launches: Array[float] = []
	var bursts: Array[float] = []
	var green_previous := 0.0
	var burst_previous := 0.0
	var first_burst := -1
	var red_up := false
	var red_down := false
	var red_min := red.position.y
	var red_max := red.position.y
	for frame in 600:
		await ticks(1)
		if green.velocity.y < 0 and green_previous >= 0:
			green_launches.append(green.velocity.y)
		if normal.velocity.y < 0 and burst_previous >= 0:
			bursts.append(normal.velocity.y)
			if first_burst < 0:
				first_burst = frame
		green_previous = green.velocity.y
		burst_previous = normal.velocity.y
		red_min = minf(red_min, red.position.y)
		red_max = maxf(red_max, red.position.y)
		red_up = red_up or red.velocity.y < 0
		red_down = red_down or red.velocity.y > 0
	check(green_launches.size() >= 6, "Winged green Koopa failed to keep bouncing")
	for speed in green_launches:
		check(absf(speed + 247.5) < 13, "Winged green Koopa hop differs from 4.125 px/frame")
	check(red_up and red_down and absf(red.position.x - 1200) < 0.1 and red_min < -275 and red_max > -205,
			"Winged red Koopa did not patrol vertically around its source origin")
	check(first_burst >= 117 and first_burst <= 123 and bursts.size() >= 4,
			"Winged Galoomba ignored its two-second initial pause or hop burst")
	if bursts.size() >= 4:
		for index in 4:
			check(absf(bursts[index] + (240 if index == 3 else 150)) < 13,
					"Galoomba did not perform three small hops followed by one large hop")
	check(goombud.position.x > 800 and goombud.get_node("SlideComponent").direction == -1,
			"Winged Goombud burst direction did not cycle after its long hop")
	check(normal.get_node("Graphics/Wings").visible and red.get_node("Graphics/Wings").visible,
			"Runtime wing overlays are missing")
	check(level.hud.player.score == 0 and not level.hud.player.is_dead(), "Flight motion affected the distant player")
	level.queue_free()
	await ticks(2)


func check_parachutes() -> void:
	for variant in [NORMAL, GOOMBUD, GREEN, RED]:
		var level := await make_level()
		var actor := actor_at(level, variant, Vector2(640, -240), true, true)
		var flight: EnemyFlightComponent = actor.get_node("FlightComponent")
		var left := false
		var right := false
		var landed := false
		for frame in 480:
			await ticks(1)
			if not flight.parachute:
				landed = true
				break
			left = left or actor.velocity.x < 0
			right = right or actor.velocity.x > 0
			check(actor.velocity.y <= 24.01 and absf(actor.position.x - 640) < 42,
					"Parachute ignored its 0.4 px/frame cap or horizontal sway bounds")
			if frame == 90:
				check(actor.get_node("Graphics/Parachute").visible and actor.get_node("Graphics/Wings").visible,
						"Both enabled attachments were not visible together")
				check(absf(actor.get_node("Graphics").rotation_degrees) <= 12.01,
						"Parachute visual swing exceeds the source angle")
				var wing_offset := flight.profile.wings_offset
				if flight.profile.mirror_wings_offset:
					wing_offset.x *= actor.get_node("SlideComponent").direction
				check(actor.get_node("Graphics/Wings").global_position.distance_to(
						actor.global_position + Vector2(0, -15) + wing_offset) < 0.01,
						"Swing rotated a wing's fixed anchor or lost the 1px body contact offset")
		check(landed and left and right and flight.wings, "Parachute did not sway, land and retain the independent wings")
		check(not actor.get_node("Graphics/Parachute").visible and actor.get_node("Graphics").rotation == 0,
				"Landed parachute or swing remained on the enemy")
		await ticks(35)
		if variant == RED:
			check(actor.position.y < -97, "Red Koopa failed to resume vertical flight after parachute landing")
		for node in level.current_sub_area.get_foreground().get_children():
			check(not node is AnimatedSprite2D, "Detached landing parachute failed to finish its short shrink")
		level.queue_free()
		await ticks(2)


func park(player: Player, at := Vector2(64, -16)) -> void:
	player.position = at
	player.previous_position = player.global_position
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)


func add_ground(level: Level, at: Vector2) -> void:
	var part := GroundPart.create()
	part.position = at
	level.current_sub_area.add_part(part)
	part.load()
	part.build()


func check_flight_collisions() -> void:
	var level := await make_level()
	for y in range(-25, -6):
		add_ground(level, Vector2(448, y * 16))
	var floating := actor_at(level, NORMAL, Vector2(480, -224), false, true)
	var reflected := false
	for frame in 70:
		await ticks(1)
		reflected = reflected or (floating.is_on_wall() and floating.velocity.x > 0)
	check(reflected and floating.position.x > 480,
			"Parachute stuck at a wall inside its sway bounds instead of reflecting")
	add_ground(level, Vector2(1184, -160))
	add_ground(level, Vector2(1200, -160))
	var red := actor_at(level, RED, Vector2(1200, -120))
	var floor_hit := false
	var ceiling_hit := false
	for frame in 240:
		await ticks(1)
		floor_hit = floor_hit or (red.is_on_floor() and red.velocity.y == -24)
		ceiling_hit = ceiling_hit or (red.is_on_ceiling() and red.velocity.y == 24)
	check(floor_hit and ceiling_hit and red.position.y >= -128.1 and red.position.y <= -95.9,
			"Vertical Koopa flight did not reverse at real floor/ceiling contacts")
	level.queue_free()
	await ticks(2)


func stomp(player: Player, actor: Enemy, spin := false) -> void:
	park(player, actor.position + Vector2(-6, -48))
	await ticks(1)
	player.state_machine.switch(PlayerSpinJumpingState if spin else PlayerFallingState)
	player.velocity.y = 120
	await ticks(22)


func check_stomps_and_lifecycle() -> void:
	for variant in [NORMAL, GOOMBUD, GREEN, RED]:
		var level := await make_level()
		var actor := actor_at(level, variant, Vector2(480, -96))
		var flight: EnemyFlightComponent = actor.get_node("FlightComponent")
		var player := level.hud.player
		await ticks(5)
		await stomp(player, actor)
		check(is_instance_valid(actor) and not flight.wings and player.score == 200 and not player.is_dead(),
				"First normal stomp should strip wings and preserve the original enemy/type")
		if not is_instance_valid(actor):
			level.queue_free()
			await ticks(2)
			continue
		check(actor.variant == variant, "Wing loss changed the enemy variant")
		for node in level.current_sub_area.get_foreground().get_children():
			check(not node is KoopaShell and not node is StompedGaloomba,
					"First wing stomp incorrectly ejected a shell or flipped the Galoomba")
		park(player)
		await ticks(40)
		await stomp(player, actor)
		check(not is_instance_valid(actor) and player.score == 400,
				"Second normal stomp did not enter the existing unwinged enemy behavior")
		park(player)
		actor = actor_at(level, variant, Vector2(800, -96))
		await ticks(5)
		await stomp(player, actor, true)
		check(not is_instance_valid(actor) and player.score == 600, "Spin stomp merely stripped wings instead of destroying the enemy")
		park(player)
		await ticks(180)
		for node in level.current_sub_area.get_foreground().get_children():
			check(not node is DetachedEnemyAttachment, "Falling detached wings failed to clean up below the level")
		# Queued wing effects must not outlive a restart or an immediate exit.
		actor = actor_at(level, variant, Vector2(1100, -96))
		actor.get_node("FlightComponent").strip_wings()
		level.reload()
		await ticks(8)
		for node in level.current_sub_area.get_foreground().get_children():
			check(not node is DetachedEnemyAttachment, "Old wing effects leaked into the restarted course")
		actor = actor_at(level, variant, Vector2(1100, -96))
		actor.get_node("FlightComponent").strip_wings()
		var pending := level.current_sub_area._pending_spawns.values().duplicate()
		level.free()
		await ticks(2)
		for entry in pending:
			check(not is_instance_valid(entry.node), "Leaving the course leaked an unparented detached wing")
