extends "res://tests/scripts/port_test.gd"
## Load -> build -> spawn -> fixed-input jump -> full course -> goal -> retry.

const LEVEL_PATH := "res://tests/fixtures/port_slice.swe"
const EXPECTED := {
	"EditorPlayer": 1, "StartingGround": 1, "GroundPart": 60, "CoinPart": 2,
	"QuestionBlockPart": 2, "TurnBlockPart": 1, "GoombaPart": 1, "GoalPolePart": 1,
}

var completion_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level: Level = await LevelProcessor.from_swe(LEVEL_PATH)
	check(level != null, "LevelProcessor returned null")
	if level == null:
		await finish("SLICE001_RESULT")
		return
	var sub := level.current_sub_area
	var counts := {}
	for part in sub.get_parts().get_children():
		var key: String = part.get_script().get_global_name()
		counts[key] = int(counts.get(key, 0)) + 1
	print("PART_COUNTS ", counts)
	check(counts == EXPECTED, "Fixture Parts differ: %s" % counts)
	check(level.game_style == Level.GameStyle.SMW, "Stored style was not restored")
	check(sub.level_theme == Level.LevelTheme.OVERWORLD, "ground theme alias was not restored")
	check(level.time == 300, "Stored cronometro was not restored")
	level.completed.connect(func(_player: Player): completion_count += 1)
	add_child(level)
	await ticks(6)
	var player := level.hud.player
	check(player != null and player.is_on_floor(), "Player did not spawn on the ground")
	check(player.position.distance_to(Vector2(64, -16)) < 0.2, "Course spawn was not derived from starting ground")
	check(level.get_current_time() == 300, "Timer has an off-by-one at start")
	var loaded_ground: GroundPart
	for part in sub.get_parts().get_children():
		if part is GroundPart:
			loaded_ground = part
			break
	var ground_texture: Texture2D = loaded_ground.get_node("%Sprite").texture
	check(ground_texture is AtlasTexture and ground_texture.atlas.resource_path ==
			"res://textures/tiles/ground.png", "Terrain bypassed GodotWE's native atlas")
	for part in sub.get_parts().get_children():
		if part is GroundPart:
			check(part.swe_atlas.y == 0 and part.swe_atlas.x >= 16,
					"Loaded floor has an isolated edge or a seam at %s" % part.position)
	check(player.sprite.sprite_frames.get_frame_texture("idle", 0).resource_path.begins_with("res://assets/openwe/"),
			"Converted player sprites are not wired to small power")

	var floor_y := player.position.y
	var apex := floor_y
	Input.action_press("player_jump")
	for frame in 65:
		await ticks(1)
		apex = minf(apex, player.position.y)
	Input.action_release("player_jump")
	print("JUMP_HEIGHT ", floor_y - apex)
	check(absf((floor_y - apex) - 73.05) < 0.3,
			"Held idle jump no longer reaches its known 60Hz height (73.05px)")
	check(player.is_on_floor(), "Player did not land after a scripted jump")

	# Traverse the fixture with run/right/jump input, clearing the moving enemy.
	level.reload()
	await ticks(6)
	player = level.hud.player
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
		await ticks(1)
		if level.is_completed or player.is_dead():
			break
	release_input()
	print("PLAYTHROUGH x=", player.position.x, " complete=", level.is_completed)
	check(level.is_completed, "Fixed-input playthrough did not reach the goal")
	check(completion_count == 1, "Goal completion must emit exactly once")
	check(level.status == Level.Status.COMPLETED, "Level did not enter COMPLETED")
	var remaining := level.get_current_time()
	level.complete(player)
	await ticks(65)
	check(completion_count == 1 and level.get_current_time() == remaining,
			"Completion was repeated or the timer kept counting down")
	level.reload()
	await ticks(6)
	check(not level.is_completed and level.status == Level.Status.PLAYING, "Retry did not reset completion")
	check(level.hud.player != player and level.hud.player.is_on_floor(), "Retry did not rebuild a grounded player")
	await finish("SLICE001_RESULT", level)
