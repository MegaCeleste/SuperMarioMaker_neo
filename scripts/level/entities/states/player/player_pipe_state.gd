# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerPipeState
extends PlayerState
## Mario travelling through a linked pipe into the other world, timed from
## SMM2 (SMW style) recordings at 60fps: he moves into the opening, the screen
## fades to black, stays black while he crosses, an iris opens on the exit,
## and after a short pause he moves out. Whatever he carries goes with him.
## Mario draws behind the pipe and touches nothing meanwhile.

## Measured: about 0.5px/frame through vertical openings, 1px/frame sideways.
const VERTICAL_SPEED := 30.0
const SIDE_SPEED := 60.0
## Measured: the fade starts about 5 frames after Mario is fully inside a
## vertical pipe and about 16 frames after a side pipe, then lasts 26 frames.
const VERTICAL_FADE_DELAY := 5
const SIDE_FADE_DELAY := 16
const FADE_TICKS := 26
## Measured: about 76 frames of black, then the iris takes about 35 frames.
const BLACK_TICKS := 76
const IRIS_TICKS := 35
## Pause between the iris finishing and Mario moving out (side exits show it).
const EXIT_WAIT_TICKS := 12
## How far Mario moves out: past the opening, then normal physics takes over.
const SIDE_TRAVEL := 24.0
const UP_TRAVEL := 32.0
const DOWN_TRAVEL := 20.0
## A side pipe's body is about 2px shorter than its lip at the bottom, so Mario
## travels that much above the opening's bottom edge to keep his feet hidden.
const SIDE_LIFT := 2.0

enum Phase { ENTER, FADE, BLACK, WAIT, EXIT }

var entry: WarpPipe
var exit: WarpPipe
var _phase := Phase.ENTER
var _ticks := 0
var _hidden_ticks := -1
var _start := Vector2.ZERO
var _layer := 0
var _mask := 0
var _z := 0
var _fade: FadeTransition
var _curtain: CurtainTransition


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
	_hidden_ticks = -1
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
	if is_instance_valid(_fade):
		_fade.queue_free()
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
			if _hidden_ticks < 0 and moved >= _hide_distance(into):
				_hidden_ticks = 0
				player.visible = false
			if _hidden_ticks >= 0:
				_hidden_ticks += 1
				if _hidden_ticks >= (SIDE_FADE_DELAY if _side(entry) else VERTICAL_FADE_DELAY):
					_phase = Phase.FADE
					_fade = FadeTransition.start(player.level, FADE_TICKS)
		Phase.FADE:
			if not is_instance_valid(_fade) or _fade.is_done():
				_cross()
		Phase.BLACK:
			if not is_instance_valid(_curtain):
				_phase = Phase.WAIT
				_ticks = 0
		Phase.WAIT:
			if _ticks >= EXIT_WAIT_TICKS:
				_phase = Phase.EXIT
				_ticks = 0
				_start = player.global_position
				# SMM2 plays the pipe sound again as Mario comes out.
				player.sounds.stream = SoundLibrary.stream("snd_warp")
				player.sounds.play()
		Phase.EXIT:
			var out := PipePart.axis(exit.part.facing)
			_step(out, delta, exit)
			var moved := (player.global_position - _start).dot(out)
			var travel := SIDE_TRAVEL if _side(exit) else (UP_TRAVEL if out == Vector2.UP else DOWN_TRAVEL)
			if moved >= travel:
				return PlayerFallingState
	return null


## Moves Mario into the partner pipe's world, inside its opening, and opens the
## iris on that opening behind the black screen.
func _cross() -> void:
	var mouth := exit.part.mouth_rect()
	var at := mouth.get_center()
	match exit.part.facing:
		PipePart.Facing.UP:
			at = Vector2(at.x, mouth.position.y + UP_TRAVEL)
		PipePart.Facing.DOWN:
			at = Vector2(at.x, mouth.end.y)
		PipePart.Facing.RIGHT:
			at = Vector2(mouth.end.x - 16, mouth.end.y - SIDE_LIFT)
			player.direction = 1
		PipePart.Facing.LEFT:
			at = Vector2(mouth.position.x + 16, mouth.end.y - SIDE_LIFT)
			player.direction = -1
	player.move_to_area(exit.part.sub_area, at)
	player.visible = true
	_curtain = CurtainTransition.open(player.level, mouth.get_center(), BLACK_TICKS,
			CurtainTransition.END_RADIUS / IRIS_TICKS)
	if is_instance_valid(_fade):
		_fade.queue_free()
	_phase = Phase.BLACK
	_ticks = 0
	_pose(exit)


func _step(way: Vector2, delta: float, pipe: WarpPipe) -> void:
	player.global_position += way * (SIDE_SPEED if _side(pipe) else VERTICAL_SPEED) * delta
	if _side(pipe) and _phase == Phase.ENTER:
		player.global_position.y = move_toward(player.global_position.y, pipe.part.mouth_rect().end.y - SIDE_LIFT, 1)
	if not _side(pipe):
		# Vertical travel pulls Mario onto the pipe's centre line.
		var center := pipe.part.mouth_rect().get_center().x
		player.global_position.x += (center - player.global_position.x) * 0.4


## Standing pose through vertical pipes and a slow walk through side pipes;
## a held item keeps its carrying pose.
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


## Mario is hidden once his whole body has passed the opening.
func _hide_distance(into: Vector2) -> float:
	if _side(entry):
		return SIDE_TRAVEL
	return Utility.get_bounding_box(player).size.y + 2 if into == Vector2.DOWN else UP_TRAVEL
