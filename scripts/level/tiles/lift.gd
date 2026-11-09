# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Lift
extends AnimatableBody2D
## SMW lifts: a one-way platform Mario rides.
## - Moving lift (source obj_plataforma): 0.6px/tick in its direction,
##   turning back 32px above or below its start, or 48px either side.
## - Falling lift (source obj_plataforma_blue): 15 ticks after Mario stands
##   on it, it falls with 0.06px/tick² up to 2px/tick; once below the room it
##   comes back at its start 180 ticks later.

enum Kind { DOWN, RIGHT, UP, LEFT, FALLING }

const SPEED := 36.0
const VERTICAL_RANGE := 32.0
const HORIZONTAL_RANGE := 48.0
const FALL_DELAY_TICKS := 15
const FALL_GRAVITY := 216.0
const MAX_FALL := 120.0
const RESPAWN_TICKS := 180

var kind := Kind.RIGHT
## Width in 16px cells; source size_x.
var width := 4
var _level: Level
var _start := Vector2.ZERO
var _velocity := Vector2.ZERO
var _fall_clock := -1
var _respawn_clock := 0
var _shape: CollisionShape2D


func setup(area: SubArea, lift_kind: Kind, cells: int) -> void:
	_level = area.level
	kind = lift_kind
	width = cells


func _ready() -> void:
	z_as_relative = false
	z_index = GameConstants.Layers.Z_ONE_WAYS
	collision_layer = 1
	collision_mask = 0
	# Moved in the physics step like the spring surface; a synced body stalls
	# when the rider it carries is pressed against a wall.
	sync_to_physics = false
	_start = position
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	_shape.shape.size = Vector2(width * 16, 6)
	_shape.position = Vector2(width * 8, 3)
	_shape.one_way_collision = true
	_shape.one_way_collision_margin = 2
	add_child(_shape)
	var frames := SpriteLibrary.get_frames(&"spr_platform_blue" if kind == Kind.FALLING else &"spr_platform")
	for cell in width:
		var piece := Sprite2D.new()
		piece.centered = false
		piece.texture = frames.get_frame_texture(&"default", 0 if cell == 0 else 2 if cell == width - 1 else 1)
		piece.position = Vector2(cell * 16, 0)
		add_child(piece)
	# Source Alarm_0: the first move is down, right, up or left.
	_velocity = [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.ZERO][kind] * SPEED


func _physics_process(delta: float) -> void:
	if _level.status != Level.Status.PLAYING:
		return
	if kind != Kind.FALLING:
		position += _velocity * delta
		var offset := position - _start
		if (kind in [Kind.DOWN, Kind.UP] and absf(offset.y) > VERTICAL_RANGE) \
				or (kind in [Kind.LEFT, Kind.RIGHT] and absf(offset.x) > HORIZONTAL_RANGE):
			_velocity = -_velocity
		return
	if _respawn_clock > 0:
		_respawn_clock -= 1
		if _respawn_clock == 0:
			position = _start
			_velocity = Vector2.ZERO
			_fall_clock = -1
			visible = true
			_shape.set_deferred(&"disabled", false)
		return
	if _fall_clock < 0:
		if is_ridden():
			_fall_clock = FALL_DELAY_TICKS
		return
	if _fall_clock > 0:
		_fall_clock -= 1
		return
	_velocity.y = minf(MAX_FALL, _velocity.y + FALL_GRAVITY * delta)
	position += _velocity * delta
	if global_position.y > Player.VOID_LEVEL + 64:
		visible = false
		_shape.set_deferred(&"disabled", true)
		_respawn_clock = RESPAWN_TICKS


## Mario stands on the top (source: touching the top band while grounded).
func is_ridden() -> bool:
	var player := _level.get_living_player()
	if player == null or not player.is_on_floor():
		return false
	var feet := player.global_position
	return feet.x >= global_position.x - 6 and feet.x <= global_position.x + width * 16 + 6 \
			and absf(feet.y - global_position.y) <= 2
