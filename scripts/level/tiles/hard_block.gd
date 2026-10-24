# SPDX-License-Identifier: AGPL-3.0-or-later
class_name HardBlock
extends StaticBodyExt
## obj_rockparent is a solid, not a bumpable block-parent container.

var sub_area: SubArea


func sprite_name() -> StringName:
	return HardBlockPart.sprite_for(sub_area)


func shard_name() -> StringName:
	return &"spr_shard_th" if sub_area.level_theme in [Level.LevelTheme.MANSION, Level.LevelTheme.AIRSHIP] else &"spr_shard_g"


func _ready() -> void:
	collision_layer = 1
	z_index = 20
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(16, 16)
	shape.position = Vector2(8, 8)
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = SpriteLibrary.get_frames(sprite_name()).get_frame_texture(&"default", 0)
	sprite.position = Vector2(8, 8)
	add_child(sprite)
	just_collided.connect(_head_bump)


func _head_bump(hit: KinematicCollision2D) -> void:
	if hit.get_local_shape().get_parent() is Player and hit.get_normal().y > 0:
		var player: Player = hit.get_local_shape().get_parent()
		if player.has_helmet() and player._helmet.rules.id == &"spiny":
			break_from_impact()
		else:
			EnemyEffect.sound_once(sub_area, "res://assets/openwe/sounds/snd_bump.ogg")


func break_from_impact() -> void:
	BlockBreakRequest.arm(sub_area, self, shard_name(), shard_name(), true)
