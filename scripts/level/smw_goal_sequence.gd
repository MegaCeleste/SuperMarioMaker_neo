# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SMWGoalSequence
extends Node
## Original SMW goal timing: count time at frame 240, pose at 440, exit at 560.
## References: obj_goalgate alarms and obj_player_goal_smw's create/step events.

signal finished

var level: Level
var player: Player
var finish_x := 0.0
var remaining_time := 0
var _state: PlayerGoalState
var _counter: AudioStreamPlayer
var _tick := 0
var _tick_fraction := 0.0
var _next_count := 240


func _ready() -> void:
	_state = player.get_node("StateMachine/Goal")
	_state.finish_x = finish_x
	player.state_machine.switch(PlayerGoalState)
	MusicPlayer.stop()
	MusicPlayer.stream = _audio("bgm_smwclear.ogg")
	if MusicPlayer.stream != null:
		MusicPlayer.play()
	_counter = AudioStreamPlayer.new()
	add_child(_counter)


func _physics_process(delta: float) -> void:
	_tick_fraction += delta * 60.0
	while _tick_fraction >= 1:
		_tick_fraction -= 1
		_tick += 1
		if _tick >= _next_count and remaining_time > 0:
			_count_time()
		if _tick == 440:
			_state.pose = true
		if _tick == 560:
			set_physics_process(false)
			finished.emit()


func _count_time() -> void:
	if _tick == 240:
		_counter.stream = _audio("snd_count.wav")
		if _counter.stream != null:
			_counter.play()
	if remaining_time > 4:
		player.score += 250
		remaining_time = maxi(0, remaining_time - 8)
		_next_count = _tick + 1
	else:
		player.score += 50
		remaining_time -= 1
		_next_count = _tick + 2
	if remaining_time == 0:
		_counter.stop()
		_counter.stream = _audio("snd_countend.wav")
		if _counter.stream != null:
			_counter.play()


func _audio(file_name: String) -> AudioStream:
	var path := "res://assets/openwe/sounds/" + file_name
	return load(path) as AudioStream if ResourceLoader.exists(path) else null
