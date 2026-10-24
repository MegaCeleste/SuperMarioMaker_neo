# SPDX-License-Identifier: AGPL-3.0-or-later
class_name DetachedEnemyAttachment
extends Node2D
## obj_wings_dead's falling, rocking wing; owned by the current SubArea.

var velocity := Vector2.ZERO
var gravity := 540.0
var terminal_speed := 108.0
var turn_direction := 1.0
var _rock_direction := 1.0


func _physics_process(delta: float) -> void:
	velocity.y = minf(terminal_speed, velocity.y + gravity * delta)
	position += velocity * delta
	rotation_degrees += 300 * turn_direction * _rock_direction * delta
	if absf(rotation_degrees) >= 90:
		rotation_degrees = 90 * turn_direction
		_rock_direction = -1
	elif _rock_direction < 0 and absf(rotation_degrees) <= 50:
		rotation_degrees = 50 * turn_direction
		_rock_direction = 1
	if global_position.y > Player.VOID_LEVEL + 32:
		queue_free()
