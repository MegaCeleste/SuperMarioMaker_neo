# SPDX-License-Identifier: AGPL-3.0-or-later
class_name WarpPipe
extends StaticBodyExt
## The play-time pipe built from a [PipePart]: solid on every side, drawn over
## Mario while he travels through it, and the entrance check of a linked pipe
## (source obj_tuberia Step).

## Horizontal reach from the pipe's centre line at which Mario can enter an
## upward or downward opening (source 6px probe plus Mario's half width).
const CENTER_REACH := 9.0

var part: PipePart


func _ready() -> void:
	z_as_relative = false
	z_index = GameConstants.Layers.Z_SOLIDS
	var size := part.get_size()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = size
	shape.position = size / 2
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = false
	sprite.texture = PipePart.texture_for(part.color, part.facing, part.segments)
	add_child(sprite)


func _physics_process(_delta: float) -> void:
	var exit := part.get_exit()
	if exit == null or not is_instance_valid(exit.runtime) or not is_instance_valid(part.level):
		return
	var player := part.level.get_living_player()
	if player != null and player.sub_area == part.sub_area and can_enter(player):
		player.enter_pipe(self, exit.runtime)


## Source obj_tuberia Step: Mario must stand on (or, for a downward opening,
## press up against) the opening and push into it. Side openings need him on
## the ground at the bottom of the mouth.
func can_enter(player: Player) -> bool:
	if player.is_traveling() or player.held_item is Spring:
		return false
	var box := Utility.get_bounding_box(player)
	var mouth := part.mouth_rect()
	var center := mouth.get_center()
	match part.facing:
		PipePart.Facing.UP:
			return Input.is_action_pressed(&"player_down") and player.is_on_floor() \
					and absf(player.global_position.y - mouth.position.y) <= 1.0 \
					and absf(player.global_position.x - center.x) < CENTER_REACH
		PipePart.Facing.DOWN:
			return Input.is_action_pressed(&"player_up") and absf(box.position.y - mouth.end.y) <= 2.0 \
					and absf(player.global_position.x - center.x) < CENTER_REACH
		PipePart.Facing.RIGHT:
			return Input.is_action_pressed(&"player_left") and player.is_on_floor() \
					and absf(player.global_position.y - mouth.end.y) <= 1.0 \
					and box.position.x >= mouth.end.x - 1.0 and box.position.x <= mouth.end.x + 2.0
		_:
			return Input.is_action_pressed(&"player_right") and player.is_on_floor() \
					and absf(player.global_position.y - mouth.end.y) <= 1.0 \
					and box.end.x <= mouth.position.x + 1.0 and box.end.x >= mouth.position.x - 2.0
