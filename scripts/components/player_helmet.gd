# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerHelmet
extends Node2D
## SMW typed shell helmets, independent of Mario's small/super power.

enum ContactFeedback { NONE, SOUND, SPARK }

var rules: HelmetRules = preload("res://resources/content/smw_helmet_rules.tres")
var active := false
var _player: Player
var _sprite: AnimatedSprite2D
var _area: Area2D
var _sound: AudioStreamPlayer
var _angle := 0.0
var _rock_direction := -1.0
var _sprite_name: StringName
var _bounced: Dictionary = {}
var _contact_shapes: Array[ConvexPolygonShape2D] = []
var _shape_cache: Dictionary = {}
var _shape_key := ""
var _shape_pending := false
var _contact_bounds := Rect2()


func _ready() -> void:
	_player = get_parent()
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.z_index = 1
	add_child(_sprite)
	_sound = AudioStreamPlayer.new()
	add_child(_sound)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 3
	_area.monitoring = false
	add_child(_area)
	visible = false


func activate(data: HelmetRules = null) -> void:
	if data != null:
		rules = data
	_sprite_name = &""
	_shape_key = ""
	_shape_cache.clear()
	_bounced.clear()
	active = true
	_area.set_deferred("monitoring", true)
	visible = true
	_sync_visual(0)
	_play_sound(rules.equip_sound)
	if SpriteLibrary.has_sprite(rules.equip_sprite):
		_spawn_effect(rules.equip_sprite, _player.global_position + rules.equip_offset, 15)


func _apply_head_shape() -> void:
	_shape_pending = false
	for child in _area.get_children():
		_area.remove_child(child)
		child.queue_free()
	SpriteCollision.add_shapes(_area, _contact_shapes)


func _sync_head_shape() -> void:
	var key := "%s:%s" % [_sprite_name, _sprite.frame]
	if key == _shape_key:
		return
	_shape_key = key
	if not _shape_cache.has(key):
		if rules.head_ellipse and _sprite_name == rules.normal_sprite:
			_shape_cache[key] = [SpriteCollision.ellipse(rules.head_size, rules.head_center)] as Array[ConvexPolygonShape2D]
		else:
			_shape_cache[key] = SpriteCollision.precise(_sprite_name, Vector2.ZERO, _sprite.frame)
	_contact_shapes = _shape_cache[key]
	var first := true
	for shape in _contact_shapes:
		_contact_bounds = shape.get_rect() if first else _contact_bounds.merge(shape.get_rect())
		first = false
	if not _shape_pending:
		_shape_pending = true
		_apply_head_shape.call_deferred()


func _head_bounds() -> Rect2:
	var looking_up := _sprite_name == rules.up_sprite
	var size := rules.head_up_size if looking_up else rules.head_size
	var center := rules.head_up_center if looking_up else rules.head_center
	# Source bbox metadata is shared across subimages; only the precise
	# collision silhouette varies per frame. Draw-only flips/angles do not.
	return Rect2(global_position + center - size / 2, size)


func _contacts(body: CollisionObject2D) -> bool:
	if _contact_shapes.is_empty() or not Rect2(_contact_bounds.position + global_position, _contact_bounds.size).intersects(Utility.get_bounding_box(body)):
		return false
	var head_transform := Transform2D(0, global_position)
	for shape_owner in body.get_shape_owners():
		if body.is_shape_owner_disabled(shape_owner):
			continue
		var body_transform := body.global_transform * body.shape_owner_get_transform(shape_owner)
		for index in body.shape_owner_get_shape_count(shape_owner):
			var body_shape := body.shape_owner_get_shape(shape_owner, index)
			for head_shape in _contact_shapes:
				if head_shape.collide(head_transform, body_shape, body_transform):
					return true
	return false


func _physics_process(delta: float) -> void:
	if not active:
		return
	if _player.is_frozen():
		# obj_frozenmario draws the captured helmet frame/facing at angle0.
		_angle = 0
		_sprite.rotation = 0
		_sprite.position.y = 0
		_sprite.flip_h = _player.direction < 0
		return
	_sync_visual(delta)
	for id in _bounced.keys():
		if not is_instance_id_valid(id) or Engine.get_physics_frames() - int(_bounced[id].frame) > 2:
			_bounced.erase(id)
	if _player.is_dead() or _player.is_frozen() or _player.level.status != Level.Status.PLAYING or not _area.monitoring:
		return
	for body in _area.get_overlapping_bodies():
		if not _contacts(body):
			continue
		if body is Entity:
			deflect(body)
		elif _player.velocity.y < 0:
			var block: BlockComponent = Utility.find_child_by_class(body, BlockComponent)
			if block != null:
				block.activate(_player)


func _process(_delta: float) -> void:
	if active:
		_sprite.modulate.a = _player.sprite.modulate.a


func _sync_visual(delta: float) -> void:
	_sprite.position.y = 1
	var small := _player.get_powerup() is SmallPowerup
	var looking_up := String(_player.sprite.animation).contains("look_up")
	var spin := _player.state_machine.current_state is PlayerSpinJumpingState
	var offset := (rules.small_up_y if small else rules.super_up_y) if looking_up \
			else (rules.small_y if small else rules.super_y)
	if _player.is_ducking():
		offset = (rules.small_hold_duck_y if small else rules.super_hold_duck_y) if _player.held_item != null \
				else (rules.small_duck_y if small else rules.super_duck_y)
	position = Vector2(0, offset - 32)
	var name: StringName = rules.up_sprite if looking_up else rules.normal_sprite
	if name != _sprite_name:
		_sprite_name = name
		SpriteLibrary.configure_sprite(_sprite, name, &"helmet", 0, Vector2(0, 1))
		_sprite.stop()
	_sprite.frame = _player.sprite.frame % 4 if spin else 0
	_sprite.flip_h = false if spin else _player.direction < 0
	if spin:
		_angle = 0
	elif _player.velocity.y > 0 and not _player.is_on_floor():
		_angle = move_toward(_angle, rules.falling_angle * _player.direction, rules.falling_rotation_speed * delta)
	elif not is_zero_approx(_player.velocity.x) and _player.is_on_floor():
		_angle += _rock_direction * (absf(_player.velocity.x) + 60) * delta
		if absf(_angle) >= rules.walking_angle:
			_angle = clampf(_angle, -rules.walking_angle, rules.walking_angle)
			_rock_direction *= -1
	else:
		_angle = move_toward(_angle, 0, rules.falling_rotation_speed * delta)
	_sprite.rotation_degrees = _angle
	_sync_head_shape()
	visible = not _player.is_dead() and _player.sprite.animation != rules.goal_animation


## obj_helmet/Collision_obj_physicsparent and Collision_obj_holdparent.
## [param previous_bottom] is the actor's bottom edge before this physics step.
## Godot reports an Area overlap one step after the crossing, while the source
## fires its collision event on the first overlapping step. A 240px/s fall can
## therefore be a whole step (4px) past the source 5px head window by the time
## the overlap is readable, so the swept edge is accepted as well.
func deflect(enemy: Entity, previous_bottom := INF) -> bool:
	if not active or _player.is_dead() or _player.is_frozen() or _player.level.status != Level.Status.PLAYING \
			or enemy.is_queued_for_deletion():
		return false
	_sync_visual(0)
	if not _contacts(enemy):
		return false
	if enemy.has_method("deflect_from_helmet"):
		var head := _head_bounds()
		var bounds := Utility.get_bounding_box(enemy)
		if not head.intersects(bounds):
			return false
		var feedback: int = enemy.deflect_from_helmet(_player, head.position.y, rules)
		if feedback == ContactFeedback.NONE:
			return false
		if not enemy.is_queued_for_deletion():
			_bounced[enemy.get_instance_id()] = {"frame": Engine.get_physics_frames(), "bottom": bounds.end.y}
		if feedback == ContactFeedback.SPARK:
			_spawn_spark()
		_play_sound(rules.deflect_sound)
		return true
	if enemy.velocity.y < 0 and (not rules.defeat_on_head or enemy is KoopaShell):
		return false
	if enemy is KoopaShell and Input.is_action_pressed("player_run") \
			and (not rules.defeat_on_head or enemy.motion == KoopaShell.Motion.STATIONARY):
		return false
	if not enemy is Enemy and (enemy.collision_layer & 1) == 0 and Input.is_action_pressed("player_run"):
		return false
	var bounds := Utility.get_bounding_box(enemy)
	var bottom := minf(bounds.end.y, previous_bottom)
	var top := _head_bounds().position.y
	var margin := 8.0
	# Physical solids can supply their dedicated source handler's strict bounds.
	if enemy.has_method("get_helmet_hit_margin"):
		margin = enemy.get_helmet_hit_margin(rules.defeat_on_head)
		if bottom >= top - _player.velocity.y / 60 + margin:
			return false
	if bottom > top - _player.velocity.y / 60 + margin \
			or bounds.end.x < global_position.x - 10 or bounds.position.x > global_position.x + 10:
		return false
	if rules.defeat_on_head and enemy.has_method("hit_by_projectile"):
		var defeated: bool = enemy.hit_by_actor(&"helmet", _area, _player.direction) if enemy is Enemy \
				else enemy.hit_by_projectile(&"helmet", _player.direction)
		if not defeated:
			return false
		_player.score += 200
		_play_sound(rules.deflect_sound)
		return true
	if enemy is KoopaShell and enemy.motion == KoopaShell.Motion.CEILING_DROP:
		enemy.velocity.x = 0
	else:
		var bounce := -rules.head_bounce_speed if _player.velocity.y >= 0 \
				else _player.velocity.y - rules.rising_bounce_extra
		if enemy.has_method("helmet_bounce_velocity"):
			bounce = enemy.helmet_bounce_velocity(bounce)
		enemy.velocity.y = bounce
		# Native Area reports can persist for two steps after the source edge
		# crossing. Retain only that retreating contact, not timed invincibility.
		_bounced[enemy.get_instance_id()] = {"frame": Engine.get_physics_frames(), "bottom": bounds.end.y}
		if enemy is KoopaShell:
			enemy.velocity.x = rules.shell_deflect_speed * signf(enemy.global_position.x - global_position.x)
	_spawn_spark()
	_play_sound(rules.deflect_sound)
	return true


## Source obj_enemyparent/Collision_obj_mario has a 3px falling-head guard.
## obj_helmet is explicitly non-solid. The short retreat guard only bridges
## native Area latency; a later side contact must still consume the helmet.
func shields(enemy: Entity, previous_bottom := INF) -> bool:
	if not active or _player.is_dead() or _player.is_frozen() or _player.level.status != Level.Status.PLAYING \
			or enemy.is_queued_for_deletion():
		return false
	var id := enemy.get_instance_id()
	var bounds := Utility.get_bounding_box(enemy)
	var player_bounds := Utility.get_bounding_box(_player)
	var in_head_width := bounds.end.x >= global_position.x - 10 and bounds.position.x <= global_position.x + 10
	if _bounced.has(id):
		var contact: Dictionary = _bounced[id]
		if enemy.velocity.y < 0 and Engine.get_physics_frames() - int(contact.frame) <= 2 \
				and bounds.end.y <= float(contact.bottom) + 0.01 \
				and bounds.end.y < player_bounds.position.y + 5 and in_head_width:
			return true
		_bounced.erase(id)
	var bottom := minf(bounds.end.y, previous_bottom)
	return enemy.velocity.y > 0 and in_head_width \
			and bottom < player_bounds.position.y - _player.velocity.y / 60 + 3


func break_off() -> void:
	active = false
	_bounced.clear()
	_area.set_deferred("monitoring", false)
	visible = false
	var dead := Node2D.new()
	dead.set_script(DeadEntity)
	dead.z_index = GameConstants.Layers.Z_DEAD
	dead.z_as_relative = false
	dead.velocity = Vector2(60 * _player.direction, -240)
	dead.position = _player.sub_area.get_foreground().to_local(global_position)
	dead.add_child(_sprite.duplicate())
	_player.sub_area.add_deferred(dead)
	_play_sound(rules.remove_sound)


func _spawn_spark() -> void:
	if SpriteLibrary.has_sprite(rules.spark_sprite):
		_spawn_effect(rules.spark_sprite, global_position, 12)


func _spawn_effect(sprite: StringName, point: Vector2, fps: float) -> void:
	var spark := AnimatedSprite2D.new()
	spark.z_index = GameConstants.Layers.Z_DEAD
	spark.z_as_relative = false
	spark.sprite_frames = SpriteLibrary.get_animations({"spark": [sprite, fps, false]})
	spark.position = _player.sub_area.get_foreground().to_local(point)
	spark.animation_finished.connect(spark.queue_free)
	_player.sub_area.add_deferred(spark)
	spark.play("spark")


func _play_sound(sound: String) -> void:
	var stream := SoundLibrary.stream(sound)
	if stream != null:
		_sound.stream = stream
		_sound.play()
