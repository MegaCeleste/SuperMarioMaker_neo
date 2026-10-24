# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Source-derived variants, real physics contacts and shell lifecycle regression.

const FIXTURE := "res://tests/fixtures/port_slice.swe"
const GREEN: KoopaVariant = preload("res://resources/content/smw_koopa_green.tres")
const RED: KoopaVariant = preload("res://resources/content/smw_koopa_red.tres")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await check_editor()
	await check_ledge_and_stomp()
	await check_motion_and_blocks()
	await check_carry()
	await check_contacts()
	await check_beach_contacts()
	await check_reentry()
	await finish("KOOPA_RESULT")


func make_level(ledge := false) -> Level:
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	var sub := level.current_sub_area
	for part in sub.get_parts().get_children():
		if not part is EditorPlayer and not part is StartingGround:
			sub.get_parts().remove_child(part)
			part.free()
	for x in range(12, 20 if ledge else 96):
		var ground := GroundPart.create()
		ground.position = Vector2(x * 16, -96)
		sub.add_part(ground)
	add_child(level)
	# These motion/reentry/long-chain oracles span multiple camera regions.
	# Match source instance_deactivate=0; actor_activity_test covers enabled play.
	sub.actor_activity.enabled = false
	await ticks(8)
	return level


func shell_at(level: Level, pos := Vector2(320, -96), variant := GREEN) -> KoopaShell:
	var shell: KoopaShell = load("res://scenes/entities/koopa_shell.tscn").instantiate()
	shell.variant = variant
	shell.position = pos
	level.current_sub_area.add(shell)
	return shell


func koopa_at(level: Level, pos: Vector2, variant := GREEN) -> Koopa:
	var koopa: Koopa = load("res://scenes/entities/green_koopa.tscn").instantiate()
	koopa.variant = variant
	koopa.position = pos
	level.current_sub_area.add(koopa)
	return koopa


func beach_at(level: Level, pos: Vector2, variant := GREEN) -> BeachKoopa:
	var beach: BeachKoopa = load("res://scenes/entities/beach_koopa.tscn").instantiate()
	beach.variant = variant
	beach.position = pos
	level.current_sub_area.add(beach)
	return beach


func find_actors(level: Level, script: Script) -> Array:
	var found := []
	for node in level.current_sub_area.get_foreground().get_children():
		if node.get_script() == script and not node.is_queued_for_deletion():
			found.append(node)
	return found


func park(player: Player, pos := Vector2(64, -16)) -> void:
	player.position = pos
	player.previous_position = player.global_position
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)


func check_editor() -> void:
	var raw := LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE))
	for spec in [["obj_koopa_res", 400], ["obj_koopa_red_res", 448]]:
		raw.data.MAIN.NIVEL.append({"object": spec[0], "x_pos": spec[1], "y_pos": 400,
			"direct_t": 0, "future_koopa": spec[0]})
	var path := "res://.godot/porting-tests/koopa_source.swe"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(raw.data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var editor := level.editor
	var green: KoopaPart
	var red: KoopaPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is KoopaPart:
			if part.variant.id == &"red":
				red = part
			else:
				green = part
	check(green != null and red != null, "SWE did not map both Koopa resource IDs")
	if green == null or red == null:
		level.queue_free()
		await ticks(2)
		return
	check(red.get_node("Graphics").get_child(0).texture.resource_path.contains("spr_koopa_red"),
			"Imported red Koopa has the wrong preview")
	var ring: PaletteRing = editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	ring.choose(1)
	check(editor.place(Vector2i(30, -3)) is KoopaPart, "Koopa palette entry is not usable")
	green.held = true
	green.set_process(false)
	await ticks(40)
	check(is_instance_valid(green._window), "Koopa long press did not open the native type window")
	if is_instance_valid(green._window):
		green._window.get_node("Content/Options/red").pressed.emit()
	green.held = false
	green.set_process(true)
	check(green.variant == RED, "Type window did not select red Koopa")
	editor.history.undo()
	check(green.variant == GREEN, "Undo lost the original Koopa type")
	editor.history.redo()
	check(green.variant == RED and editor.get_palette_icon(KoopaPart) == RED.icon,
			"Redo or the Koopa tool's selected icon is incorrect")
	var next := editor.place(Vector2i(32, -3)) as KoopaPart
	check(next.variant == RED, "Koopa placement ignored the tool's selected type")
	path = "res://.godot/porting-tests/koopa_saved.swe"
	var saved: Dictionary = await editor.save_to_path(path)
	check(saved.error == OK, "Saving Koopa variants failed")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var ids := {}
	var retained := 0
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is KoopaPart:
			ids[part.variant.id] = int(ids.get(part.variant.id, 0)) + 1
			retained += int(part.swe_data.has("future_koopa"))
	check(ids == {&"green": 1, &"red": 3} and retained == 2,
			"Koopa types or retained unknown fields changed on save/reopen")
	for entry in reopened.source_swe.MAIN.NIVEL:
		if entry.get("object", "") in [GREEN.object_id, RED.object_id]:
			check(entry.direct_t == 0, "Koopa save fabricated a facing preference")
	add_child(reopened)
	reopened.current_sub_area.actor_activity.enabled = false
	await ticks(20)
	var runtime_types := {}
	for koopa in find_actors(reopened, Koopa):
		runtime_types[koopa.variant.id] = int(runtime_types.get(koopa.variant.id, 0)) + 1
		check(koopa.is_on_floor() and koopa.position.y < -15.5,
				"Reopened Koopa is embedded in the source course's ground")
	check(runtime_types == ids, "Reopened Koopa Parts did not build the selected runtime types")
	reopened.queue_free()
	level.queue_free()
	await ticks(2)


func check_ledge_and_stomp() -> void:
	var level := await make_level(true)
	var green := koopa_at(level, Vector2(224, -96))
	var red := koopa_at(level, Vector2(272, -96), RED)
	check(green.get_node("CollShape").shape.size == Vector2(16, 16), "Koopa mask differs from spr_enemymask")
	check(red.get_node("Graphics/Sprite").sprite_frames.get_animation_speed("walk") == 9,
			"Red Koopa animation speed is not the source's nine FPS")
	var stayed := true
	var turned := false
	for frame in 240:
		await ticks(1)
		stayed = stayed and is_instance_valid(red) and red.position.y < -95.5
		if is_instance_valid(red):
			turned = turned or red.get_node("SlideComponent").direction == 1
	check(stayed and turned, "Red Koopa failed to reverse at a ledge")
	check(not is_instance_valid(green) or green.position.y > -80, "Green Koopa incorrectly avoided a ledge")
	level.queue_free()
	await ticks(2)
	for variant in [GREEN, RED]:
		level = await make_level()
		var koopa := koopa_at(level, Vector2(320, -96), variant)
		await ticks(8)
		var player := level.hud.player
		park(player, koopa.position + Vector2(0, -48))
		player.state_machine.switch(PlayerFallingState)
		player.velocity.y = 120
		await ticks(18)
		var shells := find_actors(level, KoopaShell)
		var beaches := find_actors(level, BeachKoopa)
		check(not is_instance_valid(koopa) and shells.size() == 1 and beaches.size() == 1,
				"Normal SMW stomp must create both an empty shell and a beach Koopa")
		check(player.score == 200 and not player.is_dead(), "Koopa stomp scored more than once or damaged Mario")
		if shells.size() == 1 and beaches.size() == 1:
			check(shells[0].variant == variant and beaches[0].variant == variant,
					"Koopa stomp lost its colour on the shell or ejected actor")
			check(shells[0].get_node("CollShape").shape.size == Vector2(10, 16), "Shell source mask is incorrect")
			park(player)
			beaches[0].queue_free()
			await ticks(620)
			check(is_instance_valid(shells[0]) and find_actors(level, Koopa).is_empty(),
					"An empty SMW shell incorrectly woke by itself")
		koopa = koopa_at(level, Vector2(640, -96), variant)
		await ticks(8)
		park(player, koopa.position + Vector2(0, -64))
		await ticks(1)
		player.state_machine.switch(PlayerSpinJumpingState)
		player.velocity.y = 120
		await ticks(20)
		check(not is_instance_valid(koopa) and find_actors(level, BeachKoopa).is_empty() and player.score == 400,
				"Spin stomp ejected a beach Koopa or failed to award points once")
		level.queue_free()
		await ticks(2)


func check_motion_and_blocks() -> void:
	var level := await make_level()
	var sub := level.current_sub_area
	var player := level.hud.player
	var falling := koopa_at(level, Vector2(1200, -400))
	var idle_fall := shell_at(level, Vector2(1300, -400))
	var moving_fall := shell_at(level, Vector2(1400, -400))
	moving_fall.launch(player)
	await ticks(10)
	# obj_physicsparent/Other_14 (.2) versus obj_holdparent/Other_14 (.15).
	check(absf(falling.velocity.y - 120) <= 12 and absf(moving_fall.velocity.y - 120) <= 12,
			"Koopa/moving shell free-fall does not use 0.2 px/frame squared")
	check(absf(idle_fall.velocity.y - 90) <= 9, "Idle shell free-fall does not use 0.15 px/frame squared")
	falling.queue_free()
	idle_fall.queue_free()
	moving_fall.queue_free()
	var right := shell_at(level)
	var left := shell_at(level, Vector2(640, -96))
	await ticks(20)
	player.position.x = 300
	player.velocity.x = 0
	right.launch(player)
	player.position.x = 660
	left.launch(player)
	park(player)
	check(right.velocity.x == 120 and left.velocity.x == -120, "Idle side kicks start at the wrong speeds")
	await ticks(15)
	check(is_equal_approx(right.velocity.x, 150) and is_equal_approx(left.velocity.x, -120),
			"Shell acceleration differs from the reference's signed spd behavior")
	right.queue_free()
	left.queue_free()
	await ticks(2)
	var block_part := QuestionBlockPart.create()
	block_part.position = Vector2(480, -112)
	sub.add_part(block_part)
	block_part.load()
	block_part.build()
	var shell := shell_at(level, Vector2(420, -96))
	await ticks(20)
	player.position.x = 400
	shell.launch(player)
	park(player)
	await ticks(28)
	check(is_instance_valid(shell) and shell.velocity.x < 0, "Moving shell failed to ricochet from a solid block")
	check(player.coins == 1 and player.score == 200, "Shell impact did not activate the coin question block once")
	shell.queue_free()
	var turn_part := TurnBlockPart.create()
	turn_part.position = Vector2(640, -112)
	sub.add_part(turn_part)
	turn_part.load()
	turn_part.build()
	shell = shell_at(level, Vector2(580, -96))
	await ticks(20)
	player.position.x = 560
	shell.launch(player)
	park(player)
	await ticks(32)
	var turning := false
	for node in sub.get_foreground().get_children():
		if node is TurnBlockTile:
			turning = node.turning
	check(turning, "Shell impact did not turn the native turn block")
	level.queue_free()
	await ticks(2)


func check_carry() -> void:
	var level := await make_level()
	var player := level.hud.player
	for release in [PickupComponent.ReleaseType.KICKED, PickupComponent.ReleaseType.THROWN_UP, PickupComponent.ReleaseType.DROPPED]:
		var shell := shell_at(level)
		await ticks(20)
		Input.action_press("player_run")
		park(player, Vector2(310, -96))
		await ticks(5)
		check(player.held_item == shell and shell.motion == KoopaShell.Motion.CARRIED,
				"Holding Run did not physically pick up a stationary shell")
		player.direction = 1
		player.velocity = Vector2.ZERO
		var released_velocity: Array[Vector2] = []
		shell.get_node("PickupComponent").dropped.connect(func(_holder, _type): released_velocity.append(shell.velocity))
		if release == PickupComponent.ReleaseType.THROWN_UP:
			Input.action_press("player_up")
		elif release == PickupComponent.ReleaseType.DROPPED:
			Input.action_press("player_down")
		Input.action_release("player_run")
		player.drop_item()
		await ticks(2)
		check(player.held_item == null and shell.get_parent() == level.current_sub_area.get_foreground(),
				"Releasing a carried shell lost its parent or retained a held reference")
		if release == PickupComponent.ReleaseType.KICKED:
			check(shell.motion == KoopaShell.Motion.MOVING and released_velocity == [Vector2(120, 6)],
					"Idle carried release used guessed generic pickup velocities")
		elif release == PickupComponent.ReleaseType.THROWN_UP:
			check(released_velocity == [Vector2(0, -367.5)], "Up throw differs from the source's 6.125 px/frame")
		else:
			check(shell.motion == KoopaShell.Motion.STATIONARY and released_velocity == [Vector2(30, 0)],
					"Down release did not gently drop the shell")
		release_input()
		park(player)
		shell.queue_free()
		await ticks(2)
	var shell := shell_at(level)
	await ticks(20)
	player.direction = -1
	player.velocity.x = -180
	shell.launch(player, true)
	check(shell.velocity.x == -222 and shell._target_velocity == -192,
			"Running release lost its source launch speed or capped target")
	shell.queue_free()
	park(player)
	level.queue_free()
	await ticks(2)


func check_contacts() -> void:
	var level := await make_level()
	var player := level.hud.player
	var shell := shell_at(level)
	for x in [390, 450]:
		var enemy: Galoomba = load("res://scenes/entities/galoomba.tscn").instantiate()
		enemy.position = Vector2(x, -96)
		level.current_sub_area.add(enemy)
	await ticks(20)
	player.position.x = 300
	shell.launch(player)
	park(player)
	await ticks(55)
	check(find_actors(level, Galoomba).is_empty() and player.score == 600,
			"Physical shell hits failed to defeat enemies or award the 200/400 chain")
	for index in 6:
		var enemy: Galoomba = load("res://scenes/entities/galoomba.tscn").instantiate()
		enemy.position = shell.position + Vector2(80 + 50 * index, 0)
		level.current_sub_area.add(enemy)
	await ticks(150)
	check(find_actors(level, Galoomba).is_empty() and player.score == 16400 and player.extra_lives == 1,
			"A continuing shell chain lost its 800..8000 scores or eighth-hit 1UP reward")
	shell.queue_free()
	await ticks(2)
	# A carried shell shields Mario, is consumed, and clears his held reference.
	shell = shell_at(level)
	await ticks(20)
	Input.action_press("player_run")
	park(player, Vector2(310, -96))
	await ticks(5)
	var shield_pos := shell.global_position
	var enemy := koopa_at(level, shield_pos + Vector2(8, 0))
	await ticks(5)
	check(not is_instance_valid(shell) and not is_instance_valid(enemy) and player.held_item == null,
			"Carried shell failed to consume an enemy and clear the held item safely")
	check(not player.is_dead(), "An enemy bypassed a carried shell shield")
	release_input()
	park(player)
	# Moving shells destroy one another; the pair must not generate duplicate hits.
	var a := shell_at(level, Vector2(500, -96))
	var b := shell_at(level, Vector2(620, -96), RED)
	await ticks(20)
	player.position.x = 480
	a.launch(player)
	player.position.x = 640
	b.launch(player)
	park(player)
	await ticks(40)
	check(not is_instance_valid(a) and not is_instance_valid(b), "Two moving shells did not destroy each other")
	# Normal top contact stops a moving shell; a spin jump destroys it.
	shell = shell_at(level)
	await ticks(20)
	player.position.x = 300
	shell.launch(player)
	park(player, Vector2(360, -176))
	player.state_machine.switch(PlayerFallingState)
	player.velocity.y = 120
	await ticks(20)
	check(is_instance_valid(shell) and shell.motion == KoopaShell.Motion.STATIONARY and not player.is_dead(),
			"A normal top stomp failed to stop a moving shell")
	if is_instance_valid(shell):
		park(player, shell.position + Vector2(0, -64))
		await ticks(1)
		player.state_machine.switch(PlayerSpinJumpingState)
		player.velocity.y = 120
		await ticks(20)
		check(not is_instance_valid(shell), "Spin stomp did not destroy a shell")
	level.queue_free()
	await ticks(2)
	# Moving side contact must still damage Mario when he has no shield.
	level = await make_level()
	player = level.hud.player
	shell = shell_at(level)
	await ticks(20)
	player.position.x = 300
	shell.launch(player)
	park(player, Vector2(390, -96))
	await ticks(30)
	check(player.is_dead(), "Moving shell side contact did not damage Mario")
	level.queue_free()
	await ticks(2)


func check_beach_contacts() -> void:
	for variant in [GREEN, RED]:
		var level := await make_level()
		var player := level.hud.player
		var beach := beach_at(level, Vector2(320, -96), variant)
		park(player, Vector2(310, -96))
		await ticks(20)
		check(is_instance_valid(beach) and player.score == 0 and not player.is_dead(),
				"Ejected Koopa's first half-second of contact immunity is missing")
		await ticks(15)
		check(not is_instance_valid(beach) and player.score == 200 and not player.is_dead(),
				"Lingering contact after eject immunity failed to kick the crawling Koopa")
		park(player)
		beach = beach_at(level, Vector2(500, -96), variant)
		var shell := shell_at(level, Vector2(440, -96), variant)
		await ticks(20)
		player.position.x = 420
		shell.launch(player)
		park(player)
		await ticks(30)
		check(is_instance_valid(beach), "A moving shell incorrectly defeated a crawling beach Koopa")
		shell.queue_free()
		await ticks(65)
		check(beach.is_walking(), "Stationary beach Koopa did not become a walking enemy")
		park(player, beach.position + Vector2(0, -48))
		player.state_machine.switch(PlayerFallingState)
		player.velocity.y = 120
		await ticks(18)
		var flat: AnimatedSprite2D
		for node in level.current_sub_area.get_foreground().get_children():
			if node is AnimatedSprite2D and node.sprite_frames.get_frame_texture(&"default", 0).resource_path.contains(variant.beach_stomp_sprite):
				flat = node
		check(not is_instance_valid(beach) and flat != null and player.score == 400,
				"Beach Koopa stomp lost its coloured flattened sprite or score")
		park(player)
		await ticks(35)
		check(not is_instance_valid(flat), "The half-second flattened Koopa effect failed to expire")
		level.queue_free()
		await ticks(2)


func check_reentry() -> void:
	for variant in [GREEN, RED]:
		var level := await make_level()
		var sub := level.current_sub_area
		var beach := beach_at(level, Vector2(420, -96), variant)
		beach.direction = 1
		beach.velocity.x = 180
		await ticks(55)
		check(beach.phase == BeachKoopa.Phase.SLIDING, "Beach Koopa ended its eject slide too early")
		await ticks(10)
		check(beach.phase == BeachKoopa.Phase.WAITING, "Beach Koopa did not wait after its eject slide")
		await ticks(95)
		check(beach.is_walking(), "Beach Koopa did not hop into its walking phase")
		# Give the walking actor enough distance to land before approaching its shell.
		var shell := shell_at(level, beach.position + Vector2(50, 0), variant)
		shell.position.y = -96
		var entered := false
		var inside_time := 0
		for frame in 240:
			await ticks(1)
			if is_instance_valid(shell) and shell._entry_left >= 0:
				entered = true
				inside_time += 1
			if not is_instance_valid(shell):
				break
		var restored := find_actors(level, Koopa)
		check(entered and not is_instance_valid(beach) and restored.size() == 1 and restored[0].variant == variant,
				"Beach Koopa did not physically hop into a matching shell and restore its type")
		check(absi(inside_time - int(round(variant.reentry_time * 60))) <= 2,
				"Shell reentry ignored the green/red source recovery delays")
		# Different colours cannot reenter, and restarting discards a queued restoration.
		shell = shell_at(level, Vector2(900, -96), variant)
		check(not shell.begin_entry(RED if variant == GREEN else GREEN), "A beach Koopa entered a different-colour shell")
		check(shell.begin_entry(variant), "A matching shell refused reentry")
		shell._restore_koopa()
		level.reload()
		await ticks(8)
		check(find_actors(level, Koopa).is_empty() and find_actors(level, KoopaShell).is_empty(),
				"A pending shell restoration leaked into a restarted course")
		var pending: Koopa = load("res://scenes/entities/green_koopa.tscn").instantiate()
		sub.add_deferred(pending)
		level.free()
		await ticks(2)
		check(not is_instance_valid(pending), "Area teardown leaked a pending shell occupant")
