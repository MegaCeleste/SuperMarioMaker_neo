# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Spiny editor parity, actual spiked contacts, timed needles and typed helmets.

const NORMAL: SpinyVariant = preload("res://resources/content/smw_spiny.tres")
const EMPTY: SpinyVariant = preload("res://resources/content/smw_spiny_empty.tres")
const FIXTURE := "res://tests/fixtures/port_slice.swe"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await check_editor(false)
	await check_editor(true)
	for wings in [false, true]:
		await check_contact(wings, false)
		await check_contact(wings, true)
	await check_shell_top(false)
	await check_shell_top(true)
	await check_shell_top(false, true)
	await check_shell_top(true, true)
	await check_block_and_recovery()
	await check_ceiling_and_projectiles()
	await check_flight_and_needles()
	await check_needle_lifetime()
	await check_continuous_needle_contact()
	await check_helmet()
	await check_goal_and_lifecycle()
	await finish("SPINY_RESULT")


func make_level() -> Level:
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	var sub := level.current_sub_area
	for part in sub.get_parts().get_children():
		if not part is EditorPlayer and not part is StartingGround:
			part.free()
	for x in range(12, 96):
		var ground := GroundPart.create()
		ground.position = Vector2(x * 16, -96)
		sub.add_part(ground)
	add_child(level)
	# Isolate flight/contact rules from the separately tested room activation.
	sub.actor_activity.enabled = false
	await ticks(8)
	return level


func park(player: Player, pos := Vector2(64, -16)) -> void:
	release_input()
	player.position = pos
	player.previous_position = player.global_position
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)


func spiny_at(level: Level, pos := Vector2(480, -96), wings := false) -> Spiny:
	var body: Spiny = load("res://scenes/level/entities/spiny.tscn").instantiate()
	body.position = pos
	body.get_node("FlightComponent").wings = wings
	level.current_sub_area.add(body)
	return body


func shell_at(level: Level, pos: Vector2, variant := EMPTY) -> KoopaShell:
	var shell: KoopaShell = load("res://scenes/level/entities/koopa_shell.tscn").instantiate()
	shell.position = pos
	shell.variant = variant
	level.current_sub_area.add(shell)
	return shell


func actors(level: Level, script: Script) -> Array:
	return level.current_sub_area.get_foreground().get_children().filter(
		func(n): return n.get_script() == script and not n.is_queued_for_deletion())


func check_editor(modern: bool) -> void:
	var data: Dictionary = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(FIXTURE)).data
	for row in [[NORMAL.object_id, 400, 320, 1, 1], [EMPTY.object_id, 448, 320, 0, 1], [NORMAL.object_id, 496, 208, 0, 0]]:
		data.MAIN.NIVEL.append({"object": row[0], "x_pos": row[1], "y_pos": row[2],
			"wings": row[3], "paracaidas": row[4], "future_spiny": "retain"})
	data.MAIN.SUELO.append({"x_pos": 496, "y_pos": 192, "index": 21})
	if modern:
		data = {"S0": {"S1": data.MAIN.AJUSTES, "S2": data.MAIN.SUELO, "S4": data.MAIN.NIVEL}}
		for entry in data.S0.S4:
			entry.ID = entry.object
			entry.xx = entry.x_pos
			entry.yy = entry.y_pos
			for key in ["object", "x_pos", "y_pos"]:
				entry.erase(key)
	var path := "res://.godot/porting-tests/spiny_%s.swe" % ("modern" if modern else "legacy")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()
	var level := await LevelActionBtn.prepare_level(path, Level.Status.EDITING)
	add_child(level)
	await ticks(8)
	var original: SpinyPart
	var ceiling: SpinyPart
	for part in level.current_sub_area.get_parts().get_children():
		if part is SpinyPart and part.wings:
			original = part
		elif part is SpinyPart and part.position.x == 496:
			ceiling = part
	check(original != null and ceiling != null, "Spiny resource IDs did not become native Parts")
	if original == null or ceiling == null:
		level.queue_free()
		await ticks(2)
		return
	check(ceiling.is_ceiling_attached() and ceiling.get_node("Graphics").get_child(0).flip_v,
			"Spiny did not derive ceiling attachment from native terrain")
	check(original.get_node("Graphics").get_child(0).texture.resource_path.ends_with("frame_002.png"),
			"Spiny editor preview uses another style's frame")
	if not modern:
		var ring: PaletteRing = level.editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
		ring.category = load("res://resources/palette/category_enemies.tres")
		check(not ring.choose(3), "Unimplemented reference Spiketop placeholder became selectable")
		check(ring.choose(4) and level.editor.get_selected_part() == SpinyPart, "Spiny palette entry is still a placeholder")
		original.held = true
		original.set_process(false)
		await ticks(40)
		check(original._window != null, "Spiny long press did not open its native variant window")
		if original._window != null:
			original._window.get_node("Content/Options/spiny_empty").pressed.emit()
		original.held = false
		original.set_process(true)
		check(original.variant == EMPTY and not original.wings and original.parachute,
				"Spiny empty-shell swap failed to keep only the parachute metadata")
		level.editor.history.undo()
		check(original.variant == NORMAL and original.wings and original.parachute,
				"Spiny type undo did not restore its dependent attachment state")
		level.editor.history.redo()
		check(original.variant == EMPTY and original.get_modifiers().size() == 1,
				"Spiny empty shell advertises unsupported wings")
		var next := level.editor.place(Vector2i(34, -8)) as SpinyPart
		check(next != null and next.variant == NORMAL and not next.wings and not next.parachute,
				"Spiny's object swap changed the reference's unchanged card default")
	var expected := {}
	for part in level.current_sub_area.get_parts().get_children():
		if part is SpinyPart:
			expected[part.position.x] = [part.variant.id, part.wings, part.parachute, part.is_ceiling_attached()]
	var saved: Dictionary = await level.editor.save_to_path(path)
	check(saved.error == OK, "Spiny Parts failed signed SWE saving")
	var reopened: Level = await LevelProcessor.from_swe(path)
	var retained := 0
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is SpinyPart:
			check(expected[part.position.x] == [part.variant.id, part.wings, part.parachute, part.is_ceiling_attached()],
					"Spiny attachments, type or ceiling state changed on signed round-trip")
			check(int(part.swe_data.inup) == int(part.is_ceiling_attached()), "Spiny saved a stale inup flag")
			retained += int(part.swe_data.has("future_spiny"))
	check(retained == 3, "Spiny save discarded unknown original fields")
	add_child(reopened)
	for body: Spiny in actors(reopened, Spiny):
		check(not body.get_node("FlightComponent").parachute, "Spiny incorrectly simulates unpassed parachute metadata")
	reopened.queue_free()
	level.queue_free()
	await ticks(2)


func check_contact(wings: bool, spin: bool) -> void:
	var level := await make_level()
	var body := spiny_at(level, Vector2(480, -96), wings)
	await ticks(8)
	var player := level.hud.player
	park(player, body.position + Vector2(-6, -48))
	player.state_machine.switch(PlayerFallingState)
	await ticks(1)
	if spin:
		player.state_machine.switch(PlayerSpinJumpingState)
	player.velocity.y = 120
	await ticks(22)
	check(is_instance_valid(body) and player.score == 0, "Jumping destroyed Spiny or awarded stomp score")
	if spin:
		check(not player.is_dead() and player.velocity.y < 0, "Spin jump did not safely recoil from Spiny")
		check(body.get_node("FlightComponent").wings == wings, "Spiny spin contact stripped its wings")
	else:
		check(player.is_dead(), "A regular jump survived Spiny's spikes")
	level.queue_free()
	await ticks(2)


func check_shell_top(spin: bool, moving := false) -> void:
	var level := await make_level()
	var shell := shell_at(level, Vector2(480, -96))
	await ticks(20)
	check(shell.get_node("CollShape").shape.size == Vector2(11, 14), "Empty Spiny shell lost its source mask")
	var player := level.hud.player
	if moving:
		player.position.x = 460
		shell.launch(player)
	park(player, Vector2(512 if moving else 480, -148))
	player.state_machine.switch(PlayerFallingState)
	await ticks(1)
	if spin:
		player.state_machine.switch(PlayerSpinJumpingState)
	player.velocity.y = 120
	await ticks(18)
	print("SPINY_SHELL_CONTACT spin=", spin, " moving=", moving, " shell=", shell.motion if is_instance_valid(shell) else -1,
		" player=", player.position, " velocity=", player.velocity, " state=", player.state_machine.current_state.name)
	check(is_instance_valid(shell) and shell.motion == (KoopaShell.Motion.MOVING if moving else KoopaShell.Motion.STATIONARY),
			"Top contact kicked or destroyed a spiked empty shell")
	check((not player.is_dead() and player.velocity.y < 0) if spin else player.is_dead(),
			"Empty Spiny shell did not distinguish normal and spin jumps")
	check(player.score == 0, "Spiked shell recoil awarded a false defeat score")
	level.queue_free()
	await ticks(2)


func check_block_and_recovery() -> void:
	var level := await make_level()
	var part := QuestionBlockPart.create()
	part.position = Vector2(472, -144)
	level.current_sub_area.add_part(part)
	part.load()
	part.build()
	var body := spiny_at(level, Vector2(480, -144))
	var player := level.hud.player
	park(player, Vector2(480, -96))
	await ticks(3)
	Input.action_press("player_jump")
	await ticks(22)
	release_input()
	var shells := actors(level, KoopaShell)
	check(player.coins == 1 and player.score == 400 and not is_instance_valid(body) and shells.size() == 1,
			"Real question-block head bump did not flip the supported Spiny")
	park(player)
	if shells.size() == 1:
		check(shells[0].variant == NORMAL and shells[0].inverted, "Block-flipped Spiny lost its occupant or inversion")
		await ticks(650)
		check(not is_instance_valid(shells[0]) and actors(level, Spiny).size() == 1,
				"Flipped Spiny shell failed to restore its typed occupant")
	level.queue_free()
	await ticks(2)


func check_ceiling_and_projectiles() -> void:
	var level := await make_level()
	for x in range(20, 40):
		var ground := GroundPart.create()
		ground.position = Vector2(x * 16, -240)
		level.current_sub_area.add_part(ground)
		ground.load()
		ground.build()
	var part := SpinyPart.create()
	part.position = Vector2(480, -224)
	level.current_sub_area.add_part(part)
	part.load()
	part.build()
	await ticks(30)
	var bodies := actors(level, Spiny)
	check(bodies.size() == 1 and bodies[0].ceiling, "Spiny did not crawl on the ceiling")
	if bodies.size() == 1:
		park(level.hud.player, bodies[0].position + Vector2(24, 8))
		await ticks(2)
		check(is_instance_valid(bodies[0]), "Ceiling Spiny compared native feet instead of the source instance origins")
	if not actors(level, Spiny).is_empty():
		bodies = actors(level, Spiny)
		park(level.hud.player, Vector2(bodies[0].position.x, -96))
		await ticks(2)
		check(actors(level, Spiny).is_empty() and actors(level, KoopaShell).size() == 1,
				"Ceiling Spiny did not drop a shell on a passing Mario")
		park(level.hud.player, Vector2(900, -96))
		await ticks(50)
		var shells := actors(level, KoopaShell)
		check(shells.size() == 1 and shells[0].inverted and shells[0].motion == KoopaShell.Motion.MOVING
				and shells[0].variant == NORMAL, "Dropped Spiny shell did not launch with its correct occupant")
	var body := spiny_at(level, Vector2(700, -96))
	check(body.hit_by_projectile(&"fire", 1), "Spiny body incorrectly acquired Buzzy's fireproof policy")
	var shell := shell_at(level, Vector2(430, -96))
	check(not shell.hit_by_projectile(&"fire", 1), "Empty Spiny shell lost its source hardness")
	body = spiny_at(level, Vector2(500, -96))
	await ticks(20)
	level.hud.player.position.x = 410
	shell.launch(level.hud.player)
	park(level.hud.player)
	await ticks(35)
	check(not is_instance_valid(body) and level.hud.player.score == 200, "A real moving shell failed to defeat Spiny")
	level.queue_free()
	await ticks(2)


func check_flight_and_needles() -> void:
	var level := await make_level()
	var wall := GroundPart.create()
	wall.position = Vector2(240, -224)
	level.current_sub_area.add_part(wall)
	wall.load()
	wall.build()
	var body := spiny_at(level, Vector2(300, -220), true)
	await ticks(125)
	check(body.position.is_equal_approx(Vector2(237.5, -220)) and actors(level, SpinyNeedle).is_empty(),
			"Winged Spiny did not cruise through native terrain at30px/s without premature shots")
	await ticks(3)
	check(body.get_node("Graphics/Sprite").animation == &"ball", "Spiny failed to telegraph its needle attack")
	await ticks(58)
	check(actors(level, SpinyNeedle).is_empty(), "Spiny fired before its60-frame windup")
	await ticks(2)
	var needles := actors(level, SpinyNeedle)
	check(needles.size() == 4, "First Spiny volley did not emit four cardinal needles")
	for needle: SpinyNeedle in needles:
		check(absf(needle.velocity.x) + absf(needle.velocity.y) == 42, "First volley used diagonal or wrong-speed needles")
	await ticks(216)
	needles = actors(level, SpinyNeedle)
	check(needles.filter(func(n): return absf(n.velocity.x) == 42 and absf(n.velocity.y) == 42).size() == 4,
			"Second Spiny volley did not alternate to diagonal component speeds")
	body.position.y += 20
	await ticks(1)
	check(body.velocity.y < 0 and body.collision_mask == 0, "Winged Spiny did not correct displaced altitude independently of terrain")
	level.reload()
	await ticks(5)
	check(actors(level, SpinyNeedle).is_empty(), "Spiny needles leaked across retry")
	level.queue_free()
	await ticks(2)


func check_needle_lifetime() -> void:
	var level := await make_level()
	var needle: SpinyNeedle = load("res://scenes/level/entities/spiny_needle.tscn").instantiate()
	needle.position = Vector2(100, -96)
	level.current_sub_area.add(needle)
	await ticks(361)
	check(is_instance_valid(needle) and needle.modulate.a == 0, "Needle did not begin blinking at six seconds")
	await ticks(7)
	check(is_instance_valid(needle) and needle.modulate.a == 1, "Needle blink cadence is not seven ticks")
	await ticks(115)
	check(not is_instance_valid(needle), "Needle survived its eight-second lifetime")
	var wall := GroundPart.create()
	wall.position = Vector2(128, -112)
	level.current_sub_area.add_part(wall)
	wall.load()
	wall.build()
	needle = load("res://scenes/level/entities/spiny_needle.tscn").instantiate()
	needle.position = Vector2(100, -104)
	needle.velocity.x = 42
	level.current_sub_area.add(needle)
	await ticks(70)
	check(is_instance_valid(needle) and needle.position.x > 148,
			"Independent needle collided with solid native terrain")
	needle.queue_free()
	needle = load("res://scenes/level/entities/spiny_needle.tscn").instantiate()
	needle.position = Vector2(10000, -96)
	level.current_sub_area.add(needle)
	await ticks(2)
	check(not is_instance_valid(needle), "Off-screen needle was not culled")
	level.queue_free()
	await ticks(2)


func check_helmet() -> void:
	var level := await make_level()
	var player := level.hud.player
	park(player, Vector2(400, -96))
	var shell := shell_at(level, Vector2(400, -180))
	await ticks(45)
	check(not is_instance_valid(shell) and player.has_helmet() and player.get_node("BuzzyHelmet").rules.id == &"spiny",
			"Falling empty Spiny shell did not equip its typed helmet")
	var body := spiny_at(level, Vector2(400, -180))
	await ticks(35)
	check(not is_instance_valid(body) and player.has_helmet() and player.score == 200,
			"Spiny helmet did not defeat a real falling enemy exactly once")
	shell = shell_at(level, Vector2(400, -180), NORMAL)
	await ticks(35)
	check(not is_instance_valid(shell) and player.has_helmet() and player.score == 400,
			"Spiny helmet did not defeat the shell-specific stationary object")
	Input.action_press("player_run")
	shell = load("res://scenes/level/entities/koopa_shell.tscn").instantiate()
	shell.variant = NORMAL
	shell.motion = KoopaShell.Motion.MOVING
	shell.position = Vector2(400, -180)
	level.current_sub_area.add(shell)
	await ticks(35)
	check(not is_instance_valid(shell) and player.has_helmet() and player.score == 600,
			"Holding Run incorrectly disabled the Spiny helmet against moving shells")
	release_input()
	var carried: StompedGaloomba = load("res://scenes/level/entities/stomped_galoomba.tscn").instantiate()
	carried.position = Vector2(400, -180)
	level.current_sub_area.add(carried)
	var deflected := false
	for frame in 32:
		await ticks(1)
		deflected = deflected or (is_instance_valid(carried) and carried.velocity.y < 0)
	check(deflected and is_instance_valid(carried) and player.has_helmet() and player.score == 600,
			"Spiny helmet killed a falling hold-parent object instead of deflecting it")
	carried.queue_free()
	var block := QuestionBlockPart.create()
	block.position = Vector2(392, -160)
	level.current_sub_area.add_part(block)
	block.load()
	block.build()
	park(player, Vector2(400, -96))
	await ticks(3)
	Input.action_press("player_jump")
	await ticks(1)
	Input.action_release("player_jump")
	await ticks(24)
	check(player.coins == 1 and player.score == 800 and player.has_helmet(),
			"Spiny helmet did not activate the high question block on a short jump")
	park(player, Vector2(400, -128))
	player.state_machine.switch(PlayerFallingState)
	await ticks(1)
	player.state_machine.switch(PlayerSpinJumpingState)
	player.velocity.y = 0
	var needle: SpinyNeedle = load("res://scenes/level/entities/spiny_needle.tscn").instantiate()
	needle.position = player.position + Vector2(0, -9)
	level.current_sub_area.add(needle)
	await ticks(3)
	check(not player.has_helmet() and not player.is_dead()
			and player.state_machine.current_state is PlayerSpinJumpingState,
			"A spin jump deflected the independent needle instead of damaging helmet armor")
	level.reload()
	await ticks(6)
	player = level.hud.player
	player.set_powerup(SuperPowerup.new(), false)
	shell = shell_at(level, Vector2(400, -96))
	await ticks(20)
	Input.action_press("player_run")
	player.position = Vector2(390, -96)
	player.previous_position = player.position
	await ticks(5)
	Input.action_press("player_down")
	await ticks(3)
	check(player.has_helmet() and player.held_item == null and not is_instance_valid(shell),
			"Carried Spiny shell did not equip through Run+Down")
	release_input()
	player.damage()
	check(not player.has_helmet() and player.get_powerup() is SuperPowerup and not player.is_dead(),
			"Spiny helmet armor shrank the underlying Super power")
	level.queue_free()
	await ticks(2)


func check_continuous_needle_contact() -> void:
	var level := await make_level()
	var player := level.hud.player
	park(player, Vector2(400, -96))
	player.equip_shell_helmet(EMPTY.helmet_rules)
	var needle: SpinyNeedle = load("res://scenes/level/entities/spiny_needle.tscn").instantiate()
	needle.position = player.position + Vector2(0, -9)
	level.current_sub_area.add(needle)
	await ticks(3)
	check(not player.has_helmet() and not player.is_dead(), "Needle contact did not consume armor once")
	await ticks(124)
	check(player.is_dead(), "Remaining in a needle after armor immunity expired failed to damage again")
	level.queue_free()
	await ticks(2)


func check_goal_and_lifecycle() -> void:
	var level: Level = await LevelProcessor.from_swe(FIXTURE)
	add_child(level)
	await ticks(8)
	var player := level.hud.player
	check(player.equip_shell_helmet(EMPTY.helmet_rules), "Spiny helmet could not equip before clear")
	park(player, Vector2(866, -16))
	await ticks(450)
	check(level.is_completed and player.sprite.animation == &"goal_spiny"
			and player.sprite.sprite_frames.get_frame_texture(&"goal_spiny", 0).resource_path.ends_with("frame_002.png")
			and not player.get_node("BuzzyHelmet").visible, "Spiny helmet did not choose the original distinct victory frame")
	level.queue_free()
	await ticks(2)
	level = await make_level()
	var body := spiny_at(level, Vector2(300, -220), true)
	body._fire_needles()
	var pending := level.current_sub_area._pending_spawns.values().duplicate()
	level.free()
	await ticks(2)
	for entry in pending:
		check(not is_instance_valid(entry.node), "Area exit leaked an unparented pending needle")
