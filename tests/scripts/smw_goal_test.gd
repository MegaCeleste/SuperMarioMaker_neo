extends "res://tests/scripts/port_test.gd"
## Verify the visible clear sequence and its editor exit with real physics.

var finished_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level: Level = await LevelProcessor.from_swe("res://tests/fixtures/port_slice.swe")
	add_child(level)
	await ticks(6)
	level.completion_finished.connect(func(): finished_count += 1)
	var player := level.hud.player
	player.position = Vector2(866, -16)
	await ticks(3)
	check(level.is_completed, "Crossing the gate did not start the clear sequence")
	check(player.state_machine.current_state is PlayerGoalState, "Player controls were not replaced by the goal state")
	var time_at_goal := level.get_current_time()
	var score_at_goal := player.score
	Input.action_press("player_left")
	Input.action_press("player_jump")
	await ticks(100)
	release_input()
	check(absf(player.position.x - 954) < 0.2 and player.is_on_floor(),
			"Goal walk did not reach end-ground +106 or accepted movement/jump input")
	check(player.sprite.animation == &"idle" and player.sprite.flip_h,
			"Mario did not stop and turn left before posing")
	check(level.get_current_time() == time_at_goal, "The normal level clock kept running during the clear")
	check(level.hud.get_child_count() == 2, "A placeholder result panel was added to the HUD")
	check(MusicPlayer.stream != null and MusicPlayer.stream.resource_path.ends_with("bgm_smwclear.ogg"),
			"SMW clear music is not connected")
	await ticks(130)
	check(level.get_current_time() == time_at_goal, "Time conversion started before the original 240-frame delay")
	await ticks(65)
	check(level.get_current_time() == 0 and player.score - score_at_goal == 9450,
			"Original SMW time-to-score conversion differs for 300 seconds")
	check(finished_count == 0, "Clear sequence returned before the music and pose finished")
	await ticks(155)
	check(player.sprite.animation == &"goal" and player.sprite.frame == 0,
			"SMW victory pose did not appear after 440 frames")
	await ticks(120)
	check(finished_count == 1, "Clear sequence did not finish once after 560 frames")

	# Test-play from the editor returns to editing after the same sequence.
	level.create_editor()
	level.edit()
	level.play()
	await ticks(6)
	level.hud.player.position = Vector2(866, -16)
	await ticks(570)
	check(level.status == Level.Status.EDITING and finished_count == 2,
			"Editor test-play did not return to editing after the clear sequence")
	check(not level.is_completed and level.hud.visible == false,
			"Completion state or HUD remained active after returning to the editor")
	await finish("SMW_GOAL_RESULT", level)
