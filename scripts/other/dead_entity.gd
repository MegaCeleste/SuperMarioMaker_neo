# SPDX-License-Identifier: AGPL-3.0-or-later
class_name DeadEntity
extends Node2D

var velocity: Vector2
var _spin: Tween


func _ready() -> void:
	# Only converted full frames opt in; native fallback atlases stay untouched.
	for sprite: AnimatedSprite2D in find_children("*", "AnimatedSprite2D", true, false):
		var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if texture != null and not texture is AtlasTexture and texture.resource_path.begins_with("res://assets/openwe/sprites/"):
			sprite.material = SpriteLibrary.ROTATION_MATERIAL
	var tween = create_tween()
	_spin = tween
	tween.tween_property(self, "rotation", 0, 0)
	tween.tween_property(self, "rotation", TAU, 2/3.0)
	tween.set_loops()
	var grav_comp = GravityComponent.new()
	add_child(grav_comp)
	grav_comp.owner = self


func _physics_process(delta: float) -> void:
	if WorldDeath.active_for(self):
		velocity = Vector2.ZERO
		return
	position += velocity * delta
	if global_position.y >= Player.VOID_LEVEL:
		queue_free()


func apply_source_death() -> void:
	velocity = Vector2.ZERO
	if _spin != null:
		_spin.pause()
	WorldDeath.pause_sprites(self)
