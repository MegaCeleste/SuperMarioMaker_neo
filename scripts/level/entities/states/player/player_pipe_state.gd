# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerPipeState
extends PlayerState
## Mario entering a linked pipe, crossing to the other world and leaving its
## partner (source obj_player_warp and obj_tuberia alarms). Movement is
## scripted at 1px/tick through vertical pipes and 0.6px/tick through side
## pipes; Mario draws behind the pipe and touches nothing meanwhile.

const VERTICAL_SPEED := 60.0
const SIDE_SPEED := 36.0
## Source alarm[1] before the crossing: 35 ticks vertical, 45 ticks sideways.
const ENTER_TICKS := 35
const SIDE_ENTER_TICKS := 45
## Source alarm[0]: the arriving Mario waits before moving out.
const EXIT_WAIT_TICKS := 30
## Source distances: hidden after 32px down / 24px sideways, out after
## 32px up, 20px down or 24px sideways.
const SIDE_TRAVEL := 24.0
const UP_TRAVEL := 32.0
const DOWN_TRAVEL := 20.0

enum Phase { ENTER, WAIT, EXIT }

var entry: WarpPipe
var exit: WarpPipe
var _phase := Phase.ENTER
var _ticks := 0
var _start := Vector2.ZERO
var _layer := 0
var _mask := 0
var _z := 0


func start() -> Script:
	super()
	_layer = player.collision_layer
	_mask = player.collision_mask
	_z = player.z_index
	player.set_deferred(&"collision_layer", 0)
	player.collision_mask = 0
	player.velocity = Vector2.ZERO
	player.z_as_relative = false
	player.z_index = GameConstants.Layers.Z_SOLIDS - 1
	player.crouching = false
	_phase = Phase.ENTER
	_ticks = 0
	_start = player.global_position
	player.sounds.stream = SoundLibrary.stream("snd_warp")
	player.sounds.play()
	_pose(entry)
	return null


func end() -> void:
	player.collision_layer = _layer
	player.collision_mask = _mask
	player.z_index = _z
	player.visible = true
	super()


func input(_event: InputEvent) -> Script:
	return null


func physics_process(delta: float) -> Script:
	_ticks += 1
	match _phase:
		Phase.ENTER:
			var into := -PipePart.axis(entry.part.facing)
			_step(into, delta, entry)
			var moved := (player.global_position - _start).dot(into)
			var hide_after := SIDE_TRAVEL if _side(entry) else (UP_TRAVEL if into == Vector2.DOWN else _height())
			if moved >= hide_after:
				player.visible = false
			if _ticks >= (SIDE_ENTER_TICKS if _side(entry) else ENTER_TICKS):
				_cross()
		Phase.WAIT:
			if _ticks >= EXIT_WAIT_TICKS:
				_phase = Phase.EXIT
				_ticks = 0
				_start = player.global_position
		Phase.EXIT:
			var out := PipePart.axis(exit.part.facing)
			_step(out, delta, exit)
			var moved := (player.global_position - _start).dot(out)
			var travel := SIDE_TRAVEL if _side(exit) else (UP_TRAVEL if out == Vector2.UP else DOWN_TRAVEL)
			if moved >= travel:
				return PlayerFallingState
	return null


## Moves Mario into the partner pipe's world, inside its opening, and starts
## the source curtain (obj_curtainin) centred on that opening.
func _cross() -> void:
	var mouth := exit.part.mouth_rect()
	var at := mouth.get_center()
	match exit.part.facing:
		PipePart.Facing.UP:
			at = Vector2(at.x, mouth.position.y + UP_TRAVEL)
		PipePart.Facing.DOWN:
			at = Vector2(at.x, mouth.end.y)
		PipePart.Facing.RIGHT:
			at = Vector2(mouth.end.x - 16, mouth.end.y)
			player.direction = 1
		PipePart.Facing.LEFT:
			at = Vector2(mouth.position.x + 16, mouth.end.y)
			player.direction = -1
	player.move_to_area(exit.part.sub_area, at)
	player.visible = true
	CurtainTransition.open(player.level, mouth.get_center())
	_phase = Phase.WAIT
	_ticks = 0
	_pose(exit)


func _step(way: Vector2, delta: float, pipe: WarpPipe) -> void:
	player.global_position += way * (SIDE_SPEED if _side(pipe) else VERTICAL_SPEED) * delta
	if not _side(pipe):
		# Source pos_center: vertical travel pulls Mario onto the pipe's centre.
		var center := pipe.part.mouth_rect().get_center().x
		player.global_position.x += (center - player.global_position.x) * 0.4


## Source obj_player_warp Step_2: standing pose through vertical pipes, a
## slow walk through side pipes; held items keep their carrying pose.
func _pose(pipe: WarpPipe) -> void:
	var holding := player.held_item != null
	if _side(pipe):
		player.sprite.play(&"hold_walk" if holding else &"walk")
		player.sprite.speed_scale = 9.0 / player.sprite.sprite_frames.get_animation_speed(player.sprite.animation)
	else:
		player.sprite.play(&"hold_idle" if holding else &"idle")
		player.sprite.speed_scale = 0
		player.sprite.frame = 0
	player.sprite.flip_h = player.direction < 0


func _side(pipe: WarpPipe) -> bool:
	return pipe.part.facing in [PipePart.Facing.LEFT, PipePart.Facing.RIGHT]


## Source altura: an upward entry hides Mario once his whole body is inside.
func _height() -> float:
	return Utility.get_bounding_box(player).size.y + 2
