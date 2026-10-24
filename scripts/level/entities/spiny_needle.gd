# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SpinyNeedle
extends Entity
## obj_espina is an independent damage projectile, with no terrain/enemy mask.

@export var variant: SpinyVariant = preload("res://resources/content/smw_spiny.tres")
var draw_angle := 0.0
var _age := 0.0


func _ready() -> void:
	var sprite := SpriteLibrary.make_sprite(variant.needle_sprite)
	sprite.material = SpriteLibrary.ROTATION_MATERIAL
	sprite.pause()
	sprite.frame = 2
	sprite.rotation_degrees = draw_angle
	add_child(sprite)
	$PlayerArea.body_entered.connect(func(body):
		if body is Player:
			body.damage())


func _physics_process(delta: float) -> void:
	_age += delta
	if level.hud.player.is_dead():
		velocity = Vector2.ZERO
	position += velocity * delta
	for body in $PlayerArea.get_overlapping_bodies():
		if body is Player:
			body.damage()
	if _age >= variant.needle_blink_time:
		modulate.a = 0 if int((_age - variant.needle_blink_time) * 60 / 7) % 2 == 0 else 1
	var view_position := get_viewport_transform() * global_position
	var scale := get_viewport_transform().get_scale()
	var bounds := get_viewport_rect().grow(32 * scale.x)
	if _age >= variant.needle_lifetime or view_position.x < bounds.position.x \
			or view_position.x > bounds.end.x or view_position.y > bounds.end.y:
		queue_free()
