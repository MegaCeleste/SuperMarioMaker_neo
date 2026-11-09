# SPDX-License-Identifier: AGPL-3.0-or-later
class_name FireBar
extends StaticBodyExt
## SMW Fire Bar (source obj_firebar): a solid base block with a row of
## fireballs 8px apart that turns 1 degree per tick, counter-clockwise by
## default. Each fireball hurts Mario at two points 4px either side of its
## centre; a starred Mario passes through.

## Fireballs in the bar; source size_x, 4 by default.
var length := 4
## Source direct_t: false turns counter-clockwise (direction += 1).
var clockwise := false
## Current angle in degrees, source direction (0 points right, counter-clockwise up).
var angle := 0.0
var _level: Level
var _balls: Array[Sprite2D] = []


func setup(area: SubArea, balls: int, turn_clockwise: bool, start_angle: float) -> void:
	_level = area.level
	length = balls
	clockwise = turn_clockwise
	angle = start_angle


func _ready() -> void:
	z_as_relative = false
	z_index = GameConstants.Layers.Z_SOLIDS
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(16, 16)
	add_child(shape)
	var base := Sprite2D.new()
	base.texture = SpriteLibrary.get_frames(&"spr_firebar_base").get_frame_texture(&"default", 2)
	add_child(base)
	var ball_texture := SpriteLibrary.get_frames(&"spr_firebar").get_frame_texture(&"default", 2)
	for i in length:
		var ball := Sprite2D.new()
		ball.texture = ball_texture
		ball.z_as_relative = false
		ball.z_index = GameConstants.Layers.Z_FIRE
		add_child(ball)
		_balls.append(ball)
	_place()


func _physics_process(_delta: float) -> void:
	if _level.status != Level.Status.PLAYING:
		return
	angle += -1.0 if clockwise else 1.0
	_place()
	var player := _level.get_living_player()
	if player == null or player.has_star() or player.invulnerability_left > 0:
		return
	var box := Utility.get_bounding_box(player)
	for ball in _balls:
		var at := ball.global_position
		if box.has_point(at + Vector2(-4, -4)) or box.has_point(at + Vector2(4, 4)):
			player.damage()
			return


# Source lengthdir: angle 0 points right and grows counter-clockwise (up).
func _place() -> void:
	var step := Vector2(cos(deg_to_rad(angle)), -sin(deg_to_rad(angle))) * 8
	for i in _balls.size():
		_balls[i].position = step * i
		_balls[i].rotation_degrees = -angle * 15
