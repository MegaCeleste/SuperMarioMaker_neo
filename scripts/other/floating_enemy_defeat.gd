# SPDX-License-Identifier: AGPL-3.0-or-later
class_name FloatingEnemyDefeat
extends Node2D
## Blooper's inverted, animated non-spinning defeat (obj_enemy_dead).

var rules: BlooperRules
var underwater := false
var velocity := Vector2.ZERO


func _ready() -> void:
	z_index = GameConstants.Layers.Z_DEAD
	z_as_relative = false
	var sprite := AnimatedSprite2D.new()
	SpriteLibrary.configure_sprite(sprite, rules.defeat_sprite, &"fall", rules.defeat_fps, rules.defeat_offset)
	sprite.flip_v = true
	add_child(sprite)
	velocity.y = rules.defeat_water_launch if underwater else rules.defeat_air_launch


func _physics_process(delta: float) -> void:
	if WorldDeath.active_for(self):
		velocity = Vector2.ZERO
		return
	var gravity := rules.defeat_water_gravity if underwater else \
			(rules.defeat_air_rise_gravity if velocity.y <= 0 else rules.defeat_air_fall_gravity)
	velocity.y = minf(rules.defeat_fall_speed, velocity.y + gravity * delta)
	position += velocity * delta
	if (get_viewport_transform() * global_position).y > get_viewport_rect().end.y \
			+ 32 * get_viewport_transform().get_scale().y:
		queue_free()


func apply_source_death() -> void:
	velocity = Vector2.ZERO
	WorldDeath.pause_sprites(self)
