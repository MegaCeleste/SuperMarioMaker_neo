extends Node
## Small fixed-tick harness shared by the porting regression scenes.

var failures: PackedStringArray = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
	await get_tree().process_frame


func release_input() -> void:
	for action in ["player_left", "player_right", "player_run", "player_jump", "player_spin_jump", "player_up", "player_down"]:
		Input.action_release(action)


func finish(marker: String, level: Level = null) -> void:
	release_input()
	get_tree().paused = false
	if is_instance_valid(level):
		level.queue_free()
		await get_tree().process_frame
	print(marker, " ", "PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
