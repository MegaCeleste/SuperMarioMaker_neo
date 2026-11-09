# SPDX-License-Identifier: AGPL-3.0-or-later
class_name HeldBobOmb
extends StompedGaloomba
## A stomped SMW Bob-omb (source obj_bobomb_hold, a child of obj_galoomba_hold).
## It is carried, thrown and touch-kicked like a stunned Galoomba. Its fuse
## stops the animation after 240 ticks (alarm[2]) and explodes after 300
## (alarm[1]). A spin jump on top bounces Mario and kicks it away at
## 4.2px/frame; an ordinary landing does nothing (Other_11 with hitpoint 0).
## Derived from OpenWE obj_bobomb_hold (AGPL-3.0-or-later).

## obj_bobomb_hold alarm[2] and alarm[1].
const STILL_TICKS := 240
const FUSE_TICKS := 300
## Other_11 kick: 4.2px/frame.
const KICK_SPEED := 252.0

## Ticks since the bomb was stomped.
var fuse := 0
## Source direct: the way it faces, kept from the walking Bob-omb.
var direct := 1


func _init() -> void:
	variant = GoombaVariant.new()
	variant.held_sprite = &"spr_bobomb_hold"
	variant.dead_sprite = &"spr_bobomb_hold_deads"
	stomp_margin = 12


func _ready() -> void:
	super()
	if SpriteLibrary.has_sprite(variant.held_sprite):
		var sprite: AnimatedSprite2D = $Graphics/Sprite
		# Source image_speed 0.1: 6 frames per second.
		SpriteLibrary.configure_sprite(sprite, variant.held_sprite, &"walk", 6, Vector2(0, -16))
		sprite.position.y = SpriteLibrary.contact_draw_y(variant.held_sprite)
		sprite.play()
	recovery_direction = direct
	_face()


func _tick_timer(_delta: float, holder: Player) -> bool:
	fuse += 1
	if fuse == STILL_TICKS:
		var sprite: AnimatedSprite2D = $Graphics/Sprite
		sprite.pause()
		sprite.frame = 0
	if fuse >= FUSE_TICKS:
		if holder != null:
			holder.forget_held_item(self)
		explode()
		return true
	if holder != null:
		direct = holder.direction
	elif velocity.x != 0:
		direct = 1 if velocity.x > 0 else -1
	_face()
	# Source Step_0: lava sets it off at once.
	if _in_lava():
		explode()
		return true
	return false


func _face() -> void:
	$Graphics/Sprite.flip_h = direct < 0


func _in_lava() -> bool:
	var liquid := sub_area.liquid
	return is_instance_valid(liquid) and not liquid.is_water() \
			and Utility.get_bounding_box(self).end.y - 8 > liquid.global_position.y - 12


## Other_11 with hitpoint 0: only a spin jump (stompstyle 1) reacts.
func _stomped_by(player: Player) -> void:
	if not player.state_machine.current_state is PlayerSpinJumpingState:
		return
	player.bounce()
	player.sounds.stream = preload("uid://c345xnns7om3m")
	player.sounds.play()
	player.spawn_spin_thump(player.global_position)
	kick_away(player)


## Other_11 kick: away from Mario at 4.2px/frame.
func kick_away(player: Player) -> void:
	direct = -1 if Utility.get_bounding_box(player).get_center().x > Utility.get_bounding_box(self).get_center().x else 1
	velocity.x = KICK_SPEED * direct
	recovery_direction = direct
	_face()


## The fuse never lets it stand up again.
func _recover() -> void:
	explode()


func explode() -> void:
	if is_queued_for_deletion():
		return
	_recovering = true
	BobOmb.blast(self, global_position + Vector2(0, -8))
	queue_free()
