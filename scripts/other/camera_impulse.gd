# SPDX-License-Identifier: AGPL-3.0-or-later
class_name CameraImpulse
extends Node
## obj_levelmanager/Alarm_11: ten camera positions, two source ticks apart.

const OFFSETS := [8.0, 7.0, 0.0, 4.0, 3.0, 0.0, 2.0, 0.0, 1.0, 0.0]
var _phase := -1
var _left := 0.0
var _strength := 1.0


func start(strength: float) -> void:
	if _phase >= 0:
		return
	_strength = strength
	_phase = 0
	_left = 1.0 / 60


func _physics_process(delta: float) -> void:
	if _phase < 0:
		return
	_left -= delta
	if _left > 0.00001:
		return
	Utility.camera_effect = Vector2(0, OFFSETS[_phase] * _strength)
	_phase += 1
	_left += 2.0 / 60
	if _phase == OFFSETS.size():
		_phase = -1


## Cancel also clears the render offset when a playable foreground is replaced.
func cancel() -> void:
	_phase = -1
	Utility.camera_effect = Vector2.ZERO


func _exit_tree() -> void:
	cancel()
