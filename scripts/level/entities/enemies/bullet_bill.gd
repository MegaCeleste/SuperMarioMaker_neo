# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BulletBill
extends Enemy
## SMW Bullet Bill (source obj_bulletbill): flies straight at 1px/tick through
## terrain. Stomping it bounces Mario and drops it; touching it from the side
## hurts. It leaves once it is well off screen.

const SPEED := 60.0
## Removed this far outside the view, as the source's offscreen check.
const CULL_MARGIN := 96.0

## -1 flies left, 1 right.
var direction := -1


func uses_source_deactivation() -> bool:
	return false


func _ready() -> void:
	super()
	hardness = 1
	var sprite: AnimatedSprite2D = $Graphics/Sprite
	SpriteLibrary.configure_sprite(sprite, &"spr_bulletbill", &"default", 0)
	# configure_sprite offsets by the source origin (8, 0); this puts the 16x16
	# art's top-left at (-8, -16), around the body.
	sprite.position = Vector2(0, -16)
	# Source draws xscale = direct: the art faces right, mirrored when flying left.
	sprite.flip_h = direction < 0


func _physics_process(_delta: float) -> void:
	if source_death_stopped():
		return
	position.x += direction * SPEED / Engine.physics_ticks_per_second
	if not Utility.get_visible_rect().grow(CULL_MARGIN).has_point(global_position):
		queue_free()


func _stomped(player: Player) -> void:
	super(player)
	if not is_queued_for_deletion():
		kill(0.0001 * direction)


func get_defeat_sprite() -> StringName:
	return &"spr_bulletbill"
