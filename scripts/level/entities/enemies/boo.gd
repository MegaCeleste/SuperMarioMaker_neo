# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Boo
extends Enemy
## SMW Boo (source obj_boo, Other_18). While Mario faces away it speeds up
## toward him at 0.015px/tick² to at most 0.4px/tick; while he faces it, it
## covers its face and slows by 0.025px/tick. It floats through terrain,
## cannot be stomped and shrugs off fireballs; star power defeats it.

const ACCELERATION := 0.015 * 3600
const MAX_SPEED := 0.4 * 60
const BRAKE := 0.025 * 3600

## True while Mario faces it (source movenow).
var shy := false


func _ready() -> void:
	super()
	stomp_behavior = Stompability.NONE
	hardness = 100
	fireproof = true
	var sprite: AnimatedSprite2D = $Graphics/Sprite
	SpriteLibrary.configure_sprite(sprite, &"spr_boo", &"default", 0, Vector2(0, -8))
	sprite.stop()


func uses_source_deactivation() -> bool:
	return false


func _physics_process(delta: float) -> void:
	if source_death_stopped():
		return
	var player := level.get_living_player()
	var sprite: AnimatedSprite2D = $Graphics/Sprite
	if player != null:
		var to_right := player.global_position.x > global_position.x + 4
		var to_left := player.global_position.x < global_position.x - 4
		shy = (to_right and player.direction == -1) or (to_left and player.direction == 1)
		if not shy:
			if player.global_position.x > global_position.x + 8:
				velocity.x += ACCELERATION * delta
			elif player.global_position.x < global_position.x - 8:
				velocity.x -= ACCELERATION * delta
			# Source compares Mario's top-origin y + 16..20 with the Boo's centre.
			var target := player.global_position.y - 12
			if target > global_position.y - 8:
				velocity.y += ACCELERATION * delta
			elif target < global_position.y - 12:
				velocity.y -= ACCELERATION * delta
			velocity = velocity.limit_length(MAX_SPEED)
		if velocity.x != 0:
			sprite.flip_h = velocity.x < 0
	if shy or player == null:
		velocity = velocity.move_toward(Vector2.ZERO, BRAKE * delta)
	# Frame 0 chases, frame 1 hides its face.
	sprite.frame = 1 if shy else 0
	position += velocity * delta


func hit_by_projectile(kind: StringName, launch_direction := 0.0) -> bool:
	if kind == &"star":
		kill(launch_direction)
		return true
	return false


func get_defeat_sprite() -> StringName:
	return &"spr_boo"
