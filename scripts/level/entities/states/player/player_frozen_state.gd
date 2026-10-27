# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerFrozenState
extends PlayerState
## obj_frozenmario: hold the captured pose, shake at 120 ticks, thaw at 180.
## The source ice block has no physics parent and remains at its contact point.

const ICE_CONTACT_LAYER := 1 << 4

var remaining := 3.0
var _layer := 4
var _front: AnimatedSprite2D
var _back: AnimatedSprite2D
var _graphics: Node2D
var _graphics_origin: Vector2
var _ice_body: StaticBody2D
var _melt_pending := false


func start() -> Script:
	player = node as Player
	player.detach_held_item()
	super()
	remaining = 3.0
	_melt_pending = false
	_layer = player.collision_layer
	player.set_deferred("collision_layer", 0)
	player.velocity = Vector2.ZERO
	player.sprite.pause()
	player.sprite.flip_h = player.direction < 0
	_graphics = player.get_node("Graphics")
	_graphics_origin = _graphics.position
	var art: StringName = &"spr_frozenblock_32x32_2" if player.get_powerup() is SmallPowerup \
			else &"spr_frozenblock_32x48"
	_back = SpriteLibrary.make_sprite(art)
	_back.pause()
	_back.frame = 2
	_back.position.y = -32
	_back.z_index = -1
	_graphics.add_child(_back)
	_front = _back.duplicate()
	_front.z_index = 2
	_front.modulate.a = 0.3
	_graphics.add_child(_front)
	# The source replacement object is still a snowball collision target.
	# Its dedicated layer never blocks movement or re-enables Mario contacts.
	_ice_body = StaticBody2D.new()
	_ice_body.name = "FrozenPlayerContact"
	_ice_body.collision_layer = ICE_CONTACT_LAYER
	_ice_body.collision_mask = 0
	_ice_body.set_meta(&"frozen_player", weakref(player))
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = _ice_bounds().size
	collider.shape = rectangle
	_ice_body.add_child(collider)
	_ice_body.position = player.sub_area.get_foreground().to_local(_ice_bounds().get_center())
	player.sub_area.add_deferred(_ice_body)
	EnemyEffect.sound_once(player.sub_area,
			SoundLibrary.path("snd_NSMBU_snowball_freeze"))
	return null


func physics_process(delta: float) -> Script:
	if _melt_pending:
		remaining = 0
	remaining -= delta
	player.velocity = Vector2.ZERO
	if remaining <= 0.00001:
		return PlayerIdleState if player.is_on_floor() else PlayerFallingState
	if remaining <= 1.0:
		_graphics.position.x = _graphics_origin.x + int((1.0 - remaining) * 30) % 2
	if is_instance_valid(_ice_body) and _ice_body.is_inside_tree():
		_ice_body.global_position = _ice_bounds().get_center()
	var liquid := player.sub_area.liquid
	if is_instance_valid(liquid) and not liquid.is_water() \
			and player.sub_area.level_theme in [Level.LevelTheme.CASTLE, Level.LevelTheme.FOREST] \
			and _ice_bounds().end.y - 9 > liquid.global_position.y - 12:
		EnemyEffect.play_once(player.sub_area, liquid.rules.poison_splash_sprite \
				if player.sub_area.level_theme == Level.LevelTheme.FOREST else liquid.rules.lava_splash_sprite,
				Vector2(player.global_position.x, liquid.global_position.y - 26), liquid.rules.splash_fps, false)
		_melt_pending = true # Source alarm[1]=1, rather than immediate thaw.
	return null


func end() -> void:
	_dispose_contact()
	_graphics.position = _graphics_origin
	_back.queue_free()
	_front.queue_free()
	player.set_deferred("collision_layer", _layer)
	EnemyEffect.play_once(player.sub_area, &"spr_smokespin", player.global_position + Vector2(-8, -24), 12)
	EnemyEffect.sound_once(player.sub_area,
			SoundLibrary.path("snd_estalactita_break"))
	super()


func input(_event: InputEvent) -> Script:
	return null


func _ice_bounds() -> Rect2:
	var texture := _back.sprite_frames.get_frame_texture(_back.animation, _back.frame)
	return Rect2(_back.global_position + _back.offset, texture.get_size())


func _dispose_contact() -> void:
	if is_instance_valid(_ice_body):
		_ice_body.queue_free()


func _exit_tree() -> void:
	_dispose_contact()
