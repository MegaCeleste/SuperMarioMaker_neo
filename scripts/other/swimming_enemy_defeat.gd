# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SwimmingEnemyDefeat
extends Node2D
## Shared obj_enemy_dead spinning motion, including source liquid policy.

var variant: EnemyDefeatStyle
var sub_area: SubArea
var direction := -1.0
var velocity := Vector2.ZERO
var _rotation_speed := 2.0
var _in_lava := false


func _ready() -> void:
	z_index = GameConstants.Layers.Z_DEAD
	z_as_relative = false
	var sprite := SpriteLibrary.make_sprite(variant.dead_sprite)
	if variant.dead_spins:
		sprite.material = SpriteLibrary.ROTATION_MATERIAL
	sprite.pause()
	sprite.frame = variant.dead_frame
	sprite.flip_h = direction < 0
	add_child(sprite)
	# obj_enemy_dead Create samples its default spr_beachkoopa mask before
	# the caller assigns the family art. Alarm0 uses that saved sample.
	velocity.y = -96 if _swimming(true) else -240


func _swimming(initial := false) -> bool:
	if sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (sub_area.night_mode and sub_area.level_theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP]):
		return true
	var liquid := sub_area.liquid
	return is_instance_valid(liquid) and liquid.is_water() \
			and global_position.y + (7 if initial else _water_offset()) > liquid.global_position.y - 12


func _water_offset() -> float:
	return (Transform2D(rotation, Vector2.ZERO) * variant.dead_mask_rect).end.y - 9 \
			if variant.dead_mask_rect.has_area() else variant.dead_water_offset


func _liquid_contact() -> void:
	var liquid := sub_area.liquid
	if not is_instance_valid(liquid):
		return
	var edge := global_position.y + _water_offset()
	if _in_lava and edge < liquid.global_position.y - 14:
		_in_lava = false
	var poison := sub_area.level_theme == Level.LevelTheme.FOREST and sub_area.night_mode
	if edge > liquid.global_position.y - 12 \
			and ((sub_area.level_theme == Level.LevelTheme.CASTLE and not _in_lava) or poison):
		# Source poison repeats this effect; castle guards its first entry.
		EnemyEffect.play_once(sub_area, liquid.rules.poison_splash_sprite if poison else liquid.rules.lava_splash_sprite,
				Vector2(global_position.x, liquid.global_position.y - 26), liquid.rules.splash_fps, false)
		_in_lava = true


func _physics_process(delta: float) -> void:
	if WorldDeath.active_for(self):
		velocity = Vector2.ZERO
		return
	_liquid_contact()
	var swimming := _swimming() or _in_lava
	if variant.dead_spins:
		rotation_degrees += (360 * _rotation_speed if swimming else 960) * signf(velocity.x) * delta
	_rotation_speed = maxf(1, _rotation_speed - 0.6 * delta)
	var liquid := sub_area.liquid
	# Source Step checks only an already-descending corpse, before its automatic
	# motion. A rising corpse can re-enter the camera from below.
	if velocity.y > 0:
		if swimming and is_instance_valid(liquid) and liquid.velocity > 0 \
				and global_position.y <= liquid.global_position.y + 16:
			global_position.y = liquid.global_position.y + 16
		if global_position.y > Utility.get_visible_rect().position.y + 248 \
				or (is_instance_valid(liquid) and global_position.y > liquid.global_position.y + 32 \
				and (sub_area.level_theme == Level.LevelTheme.CASTLE \
				or (sub_area.level_theme == Level.LevelTheme.FOREST and sub_area.night_mode))):
			queue_free()
			return
	# The original caps before its built-in gravity advances this tick.
	velocity.y = minf(60 if swimming else 240, velocity.y) + (72 if swimming else 720) * delta
	if _in_lava:
		velocity.x = 0
	position += velocity * delta


func apply_source_death() -> void:
	velocity = Vector2.ZERO
	WorldDeath.pause_sprites(self)
