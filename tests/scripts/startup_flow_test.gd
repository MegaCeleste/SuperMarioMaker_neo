# SPDX-License-Identifier: AGPL-3.0-or-later
extends "res://tests/scripts/port_test.gd"
## Exercise real scene transitions and a cursor waiting for its Level context.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# SceneManager may unload the current scene. Keep this test beside it.
	get_tree().current_scene = null
	var cursor: EditorPlayer = load("res://scenes/level/parts/editor_player.tscn").instantiate()
	add_child(cursor)
	await ticks(2)
	check(cursor.level == null, "Unbound cursor probe unexpectedly acquired a Level")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	cursor._input_event(get_viewport(), click, 0)
	remove_child(cursor)
	get_tree().current_scene = null
	# Read the project entry from disk rather than this test scene's path.
	var project := ConfigFile.new()
	check(project.load("res://project.godot") == OK, "Could not read the configured startup scene")
	var menu: PackedScene = load(project.get_value("application", "run/main_scene"))
	SceneManager.fade_to_scene(menu, SceneManager.Transition.NONE, SceneManager.Transition.NONE)
	await ticks(320) # Four-second notice plus its outgoing fade.
	var intro := get_tree().current_scene as Intro
	check(intro != null, "Main scene did not reach the intro")
	if intro == null:
		cursor.free()
		await finish("STARTUP_FLOW_RESULT")
		return
	intro._skip()
	intro.get_node("UI/Center/PlayBtn")._pressed()
	await ticks(110)
	var level := get_tree().current_scene as Level
	check(level != null and level.title_screen, "Intro Play did not reach the title course")
	if level == null:
		cursor.free()
		await finish("STARTUP_FLOW_RESULT")
		return
	var marker := level.current_sub_area.get_parts().get_node("EditorPlayer") as EditorPlayer
	check(marker.level == level and marker.sub_area == level.current_sub_area,
			"Title cursor did not receive its Level/SubArea context")
	level.get_node("TitleLayer/Title/StartBtn")._pressed()
	await ticks(22)
	level.get_node("TitleLayer/Title/Clapperboards/EditBtn")._pressed()
	await ticks(160)
	check(level.status == Level.Status.EDITING and level.editor != null,
			"Title Edit did not create a working editor")
	var before := marker.position
	Input.action_press("player_right")
	await ticks(3)
	release_input()
	check(marker.position.x > before.x, "Initialized editor cursor did not respond to movement")
	# A part can enter the tree before its factory assigns context. It must
	# wait safely, then work after it is inserted into the real area.
	level.current_sub_area.add_part(cursor)
	cursor.load()
	await ticks(2)
	check(cursor.level == level, "Waiting cursor could not bind to the real editor")
	cursor.queue_free()
	await ticks(1)
	level.play()
	await ticks(12)
	check(is_instance_valid(marker.player) and marker.player.is_on_floor(),
			"Title editor could not enter playable Mario")
	level.edit()
	await ticks(3)
	check(level.status == Level.Status.EDITING and is_instance_valid(marker),
			"Returning from title test-play lost the editor cursor")
	# An open editor panel can disable interaction after the player is freed.
	level.editor.part_interact = false
	await ticks(2)
	level.editor.part_interact = true
	marker.player = null
	await ticks(2)
	if "--capture-startup-flow" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_startup_flow.png") == OK,
				"Could not capture the real startup editor")
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	get_tree().current_scene = null
	await finish("STARTUP_FLOW_RESULT", level)
