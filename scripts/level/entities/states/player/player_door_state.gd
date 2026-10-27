# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerDoorState
extends PlayerState
## Mario going through a door to its partner (source
## obj_doormario, obj_doormario_exit and the obj_door alarms). Mario stands in
## front of the opening door, reappears at the partner under the circle
## curtain, and takes control back once that door starts closing.

## Source obj_door alarm[0]: Mario stays at the entrance for 55 ticks.
const ENTER_TICKS := 55
## Source alarm[1]: the exit door starts closing 15 ticks after arrival.
const CLOSE_TICKS := 15
## Source obj_doormario_exit alarm[0]: control returns after 25 ticks.
const EXIT_TICKS := 25

var entry: WarpDoor
var _exit: WarpDoor
var _ticks := 0
var _arrived := false
var _layer := 0


func start() -> Script:
	super()
	_layer = player.collision_layer
	player.set_deferred(&"collision_layer", 0)
	player.velocity = Vector2.ZERO
	player.crouching = false
	_ticks = 0
	_arrived = false
	_exit = entry.get_exit()
	entry.open()
	_pose()
	return null


func end() -> void:
	player.collision_layer = _layer
	player.level.get_node(^"%LevelTimer").paused = false
	super()


func input(_event: InputEvent) -> Script:
	return null


func physics_process(_delta: float) -> Script:
	_ticks += 1
	if not _arrived:
		if _ticks >= ENTER_TICKS:
			_arrived = true
			_ticks = 0
			entry.reset()
			player.direction = 1
			player.global_position = _exit.position + Vector2(8, 32)
			player.previous_position = player.global_position
			player.snap_camera()
			CurtainTransition.open(player.level, _exit.position + Vector2(8, 16))
			player.level.get_node(^"%LevelTimer").paused = false
			_pose()
		return null
	if _ticks == CLOSE_TICKS:
		_exit.close()
	if _ticks >= EXIT_TICKS:
		return PlayerIdleState
	return null


## Source draws scr_marioidle (or the carrying pose) facing Mario's direction.
func _pose() -> void:
	player.sprite.play(&"hold_idle" if player.held_item != null else &"idle")
	player.sprite.speed_scale = 1
	player.sprite.flip_h = player.direction < 0
