extends "res://tests/scripts/port_test.gd"
## Fixed-input motion snapshots and independent variable-jump oracles.

var _trace: Dictionary
var _start_x: float


func sample(key: String, player: Player) -> void:
	var expected: Dictionary = _trace[key]
	var dx := player.position.x - _start_x
	print("PHYSICS_TRACE ", key, " dx=", dx, " vx=", player.velocity.x)
	check(absf(dx - expected.dx) < 0.16 and absf(player.velocity.x - expected.vx) < 0.02,
			"Motion trace changed at %s: dx=%s vx=%s" % [key, dx, player.velocity.x])


func jump_height(player: Player, action: String, held_ticks: int) -> float:
	release_input()
	player.position = Vector2(480, -16)
	player.velocity = Vector2.ZERO
	player.state_machine.switch(PlayerIdleState)
	await ticks(4)
	var floor_y := player.position.y
	var apex := floor_y
	Input.action_press(action)
	for frame in 70:
		if frame == held_ticks:
			Input.action_release(action)
		await ticks(1)
		apex = minf(apex, player.position.y)
	release_input()
	return floor_y - apex


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_trace = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/smw_player_trace.json"))
	var level: Level = await LevelProcessor.from_swe("res://tests/fixtures/port_slice.swe")
	check(level != null, "Fixture failed to load")
	if level == null:
		await finish("PLAYER_PHYSICS_RESULT")
		return
	add_child(level)
	await ticks(6)
	var player := level.hud.player
	for node in level.current_sub_area.get_foreground().get_children():
		if node is Galoomba or node is GoalGate or node is Coin or node is QuestionBlock or node is TurnBlockTile:
			node.queue_free()
	await ticks(2)
	_start_x = player.position.x
	Input.action_press("player_right")
	await ticks(10)
	sample("walk_10", player)
	await ticks(14)
	sample("walk_24", player)
	Input.action_press("player_run")
	await ticks(60)
	sample("run_60", player)
	Input.action_release("player_right")
	Input.action_press("player_left")
	await ticks(10)
	sample("reverse_10", player)
	await ticks(20)
	sample("reverse_30", player)
	release_input()
	await ticks(30)
	sample("stop_30", player)
	var short_height := await jump_height(player, "player_jump", 1)
	var long_height := await jump_height(player, "player_jump", 60)
	var spin_height := await jump_height(player, "player_spin_jump", 60)
	print("JUMP_TRACE short=", short_height, " held=", long_height, " spin=", spin_height)
	check(absf(short_height - 26.65) < 0.3, "Released jump no longer follows short-jump gravity")
	check(absf(long_height - 73.05) < 0.3, "Held jump no longer follows long-jump gravity")
	check(absf(spin_height - 49.5) < 0.3, "Spin jump height changed")
	player.position = Vector2(480, -240)
	player.velocity = Vector2(0, 80)
	player.just_fell = false
	player.state_machine.switch(PlayerFallingState)
	await ticks(8)
	player.just_fell = false
	player.state_machine.switch(PlayerFallingState, true)
	Input.action_press("player_jump")
	await ticks(1)
	check(player.velocity.y > 0, "Expired coyote time allowed a mid-air jump")
	await finish("PLAYER_PHYSICS_RESULT", level)
