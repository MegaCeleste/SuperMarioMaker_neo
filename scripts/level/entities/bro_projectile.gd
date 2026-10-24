# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BroProjectile
extends Entity
## Native obj_brohammer, obj_fireball_bro, obj_snowball_bro (inherits
## obj_snowball) and obj_boomerang policies. Positions use source origins.

enum Kind { HAMMER, FIRE, ICE, BOOMERANG }

@export var kind: Kind = Kind.HAMMER
@export var direction := 1
@export var rules: BroProjectilePhysics = preload("res://resources/content/smw_bro_projectile_physics.tres")
var home: Node2D
var _sprite: AnimatedSprite2D
var _age := 0.0
var _returning := false
var _back_at_speed := false
var _caught := false
var _ice_bounces := 0
var _blink := 0.0
var _shapes: Array[ConvexPolygonShape2D]
var _before: Rect2
var _molten := false


func uses_source_deactivation() -> bool:
	return kind in [Kind.FIRE, Kind.ICE]


func uses_source_death_stop() -> bool:
	return kind != Kind.BOOMERANG


func _ready() -> void:
	collision_layer = 0 if kind == Kind.BOOMERANG else 2
	collision_mask = 1 if kind in [Kind.FIRE, Kind.ICE] else 0
	_sprite = AnimatedSprite2D.new()
	if kind in [Kind.HAMMER, Kind.BOOMERANG]:
		_sprite.material = SpriteLibrary.ROTATION_MATERIAL
	add_child(_sprite)
	SpriteLibrary.configure_sprite(_sprite, _sprite_name(), &"default",
			9.0 if kind in [Kind.FIRE, Kind.ICE] else 0.0)
	if kind == Kind.HAMMER:
		_sprite.flip_h = direction < 0
	if kind == Kind.HAMMER:
		_shapes.append(SpriteCollision.ellipse(Vector2(12, 10), Vector2.ZERO))
	elif kind == Kind.ICE:
		_shapes.append(SpriteCollision.rectangle(Vector2(8, 8), Vector2(0, 8)))
	else:
		_shapes = SpriteCollision.precise(_sprite_name())
	SpriteCollision.add_shapes(self, _shapes)
	var area := Area2D.new()
	area.name = "PlayerArea"
	area.collision_layer = 0
	area.collision_mask = 4 | (PlayerFrozenState.ICE_CONTACT_LAYER if kind == Kind.ICE else 0)
	SpriteCollision.add_shapes(area, _shapes)
	area.body_entered.connect(_hit_player)
	add_child(area)
	velocity = Vector2(rules.horizontal_speeds[kind] * direction, rules.launch_speeds[kind])
	# Create_0 omits beach water from its launch test; Step_0 includes it.
	if kind == Kind.HAMMER and sub_area.level_theme != Level.LevelTheme.BEACH and _in_water(14):
		velocity.y = rules.water_hammer_launch
	if kind == Kind.FIRE:
		EnemyEffect.sound_once(sub_area, "res://assets/openwe/sounds/snd_fireball.ogg")
	if collision_mask != 0:
		var query := PhysicsShapeQueryParameters2D.new()
		query.collision_mask = 1
		query.transform = global_transform
		for shape in _shapes:
			query.shape = shape
			if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
				_burst()
				break


func _sprite_name() -> StringName:
	return [&"spr_hammer", &"spr_fireball", &"spr_snowball", &"spr_boomerang"][kind]


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	_before = Utility.get_bounding_box(self)
	_age += delta
	if source_death_stopped():
		velocity = Vector2.ZERO
		_sprite.position.x = roundf(global_position.x) - global_position.x
		if _outside_view():
			queue_free()
		elif kind == Kind.ICE:
			# Snowball's final bounce/count branch is outside its living-Mario
			# guard. The central death pass clears its automatic launch again.
			if _ice_bounces > 0:
				_burst()
			else:
				_ice_bounces += 1
				position.y -= 1
		else:
			_liquid_contact()
		return
	match kind:
		Kind.HAMMER:
			var swimming := _in_water(14)
			velocity.y = minf(velocity.y, rules.molten_hammer_cap if _molten else rules.fall_cap) \
					+ (rules.water_hammer_gravity if swimming or _molten else rules.hammer_gravity) * delta
			_sprite.rotation_degrees += (rules.water_hammer_spin if swimming else rules.hammer_spin) * direction * delta
			_sprite.flip_h = direction < 0
			# image_angle rotates the hammer mask too; boomerang's draw-only
			# rotacion intentionally leaves its collision mask unchanged.
			for owner_id in get_shape_owners():
				var shape_owner: CollisionShape2D = shape_owner_get_owner(owner_id)
				shape_owner.rotation = _sprite.rotation
			for shape_owner in $PlayerArea.get_children():
				shape_owner.rotation = _sprite.rotation
			_liquid_contact()
			if _outside_view():
				queue_free()
				return
			position += velocity * delta
		Kind.FIRE, Kind.ICE:
			if _liquid_contact():
				return
			if _outside_view():
				queue_free()
				return
			_bouncing_shot(delta)
		Kind.BOOMERANG:
			_tick_boomerang_lifetime(delta)
			if is_queued_for_deletion():
				return
			_boomerang(delta)
			if is_queued_for_deletion():
				return
			if _outside_view():
				queue_free()
				return
			if _back_at_speed and is_instance_valid(home) and not home.is_queued_for_deletion() and not _caught \
					and Utility.get_bounding_box(self).intersects(Utility.get_bounding_box(home)):
				_caught = true
			position += velocity * delta
	# Draw_0 snaps x; the boomerang also snaps y, without moving physics.
	_sprite.position.x = roundf(global_position.x) - global_position.x
	if kind == Kind.BOOMERANG:
		_sprite.position.y = roundf(global_position.y) - global_position.y


func _outside_view() -> bool:
	# Source Step sees the origin before automatic movement, not a sprite's
	# bounds or its rounded drawing position. Hammer deliberately has no top.
	var view := Utility.get_visible_rect()
	var outside := global_position.x < view.position.x - 32 or global_position.x > view.end.x + 32 \
			or global_position.y > view.end.y + 32
	if kind != Kind.HAMMER:
		outside = outside or global_position.y < view.position.y - 32
	return outside


func _tick_boomerang_lifetime(delta: float) -> void:
	if _age >= rules.boomerang_expiry - 0.00001:
		queue_free()
		return
	if _age >= rules.boomerang_blink_time - 0.00001:
		_blink -= delta
		if _blink <= 0.00001:
			_blink = rules.boomerang_blink_interval
			_sprite.visible = not _sprite.visible


func _bouncing_shot(delta: float) -> void:
	# Ice's inherited Other_14 caps at 3px/frame, fire uses the parent's 4.
	var swimming := kind == Kind.FIRE and _in_water(16)
	var cap := rules.ice_fall_cap if kind == Kind.ICE else rules.water_fire_cap if swimming else rules.fall_cap
	velocity.y = minf(velocity.y, cap) + (rules.water_fire_gravity if swimming else rules.shot_gravity) * delta
	var collision := move_and_collide(velocity * delta)
	if collision == null:
		return
	var normal := collision.get_normal()
	if absf(normal.x) > 0.5:
		_burst()
	elif normal.y < -0.5:
		if kind == Kind.ICE and _ice_bounces > 0:
			_burst()
		else:
			_ice_bounces += 1
			velocity.y = rules.ice_bounce if kind == Kind.ICE else rules.fire_bounce
			position.y -= 1
	else:
		velocity.y = 0


func _boomerang(delta: float) -> void:
	_sprite.rotation_degrees += rules.boomerang_spin * delta
	if _caught:
		if _sprite.scale.x <= 0.2:
			queue_free()
		else:
			_sprite.scale -= Vector2.ONE * 12.0 * delta
		return
	# Source alarms: 32 ticks upward, 15 flattening, 8 downward, then
	# 0.075px/frame² horizontal reversal. No homing toward a moving owner.
	if _age >= (rules.boomerang_alarms[0] + rules.boomerang_alarms[1] + rules.boomerang_alarms[2]) / 60.0 - 0.00001 and not _back_at_speed:
		_returning = true
		if velocity.x * direction > -rules.horizontal_speeds[Kind.BOOMERANG]:
			velocity.x -= rules.boomerang_turn * direction * delta
		else:
			velocity.x = -rules.horizontal_speeds[Kind.BOOMERANG] * direction
			velocity.y = 0
			_back_at_speed = true
	if _back_at_speed:
		velocity.y = move_toward(velocity.y, 0, rules.boomerang_vertical_acceleration * delta)
	elif _age >= (rules.boomerang_alarms[0] + rules.boomerang_alarms[1]) / 60.0 - 0.00001:
		velocity.y = minf(velocity.y + rules.boomerang_vertical_acceleration * delta, -rules.launch_speeds[Kind.BOOMERANG])
	elif _age >= rules.boomerang_alarms[0] / 60.0 - 0.00001:
		velocity.y = move_toward(velocity.y, 0, rules.boomerang_vertical_acceleration * delta)


func _in_water(depth: float) -> bool:
	if sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (sub_area.night_mode and sub_area.level_theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP]):
		return true
	return is_instance_valid(sub_area.liquid) and sub_area.liquid.is_water() \
			and global_position.y > sub_area.liquid.global_position.y + depth


func _hit_player(body: Node2D) -> void:
	if kind == Kind.ICE and body.has_meta(&"frozen_player") and not is_queued_for_deletion():
		var frozen: WeakRef = body.get_meta(&"frozen_player")
		var player: Player = frozen.get_ref()
		if not body.is_queued_for_deletion() and is_instance_valid(player) and player.is_frozen():
			_burst()
		return
	if not body is Player or is_queued_for_deletion():
		return
	if body.helmet_deflects(self):
		return
	if kind in [Kind.FIRE, Kind.ICE] and body.helmet_shields(self, _before.end.y if _before.size.y > 0 else INF):
		return
	if kind == Kind.ICE:
		if body.freeze_in_ice():
			queue_free()
	else:
		body.damage()


## obj_helmet has a dedicated hammer collision and generic physical-shot
## bounces. Neither projectile response awards enemy-defeat points.
func deflect_from_helmet(player: Player, head_top: float, data: HelmetRules) -> int:
	if kind == Kind.HAMMER:
		var effect := SwimmingEnemyDefeat.new()
		var style := EnemyDefeatStyle.new()
		style.dead_sprite = _sprite_name()
		style.dead_frame = 0
		style.dead_mask_rect = Rect2(-6, -5, 12, 10)
		effect.variant = style
		effect.sub_area = sub_area
		effect.position = sub_area.get_foreground().to_local(global_position)
		effect.rotation = _sprite.rotation
		effect.direction = 1
		effect.velocity.x = 60 * signf(player.velocity.x if player.velocity.x != 0 else global_position.x - player.global_position.x)
		sub_area.add_deferred(effect)
		queue_free()
	elif kind in [Kind.FIRE, Kind.ICE]:
		var bottom := minf(Utility.get_bounding_box(self).end.y, _before.end.y if _before.size.y > 0 else INF)
		if velocity.y < 0 or bottom - 1 >= head_top - player.velocity.y / 60 + (5 if data.defeat_on_head else 8):
			return PlayerHelmet.ContactFeedback.NONE
		velocity.y = -data.head_bounce_speed if player.velocity.y >= 0 else player.velocity.y - data.physical_rising_bounce_extra
	else:
		return PlayerHelmet.ContactFeedback.NONE
	return PlayerHelmet.ContactFeedback.SOUND if data.defeat_on_head else PlayerHelmet.ContactFeedback.SPARK


func _liquid_contact() -> bool:
	var liquid := sub_area.liquid
	if not is_instance_valid(liquid):
		return false
	var bottom := Utility.get_bounding_box(self).end.y - 9
	if kind == Kind.ICE:
		# Other_14 checks its supporting floor before the liquid branch.
		if _ice_supported():
			return false
		if sub_area.level_theme in [Level.LevelTheme.FOREST, Level.LevelTheme.BEACH] \
				and bottom > liquid.global_position.y - 12 and bottom < liquid.global_position.y - 10:
			EnemyEffect.play_once(sub_area, liquid.rules.water_splash_sprite,
					Vector2(global_position.x, liquid.global_position.y - 24), liquid.rules.splash_fps, false)
		if not liquid.is_water() and bottom > liquid.global_position.y - 12:
			_splash(liquid, -24)
			_burst()
			return true
	elif kind == Kind.HAMMER and not _molten and not liquid.is_water() \
			and sub_area.level_theme in [Level.LevelTheme.CASTLE, Level.LevelTheme.FOREST] \
			and bottom > liquid.global_position.y - 12:
		_splash(liquid, -26)
		_molten = true
	elif kind == Kind.FIRE and not liquid.is_water() \
			and sub_area.level_theme in [Level.LevelTheme.CASTLE, Level.LevelTheme.FOREST] \
			and global_position.y > liquid.global_position.y + 32:
		queue_free()
		return true
	return false


func _ice_supported() -> bool:
	var bounds := Utility.get_bounding_box(self)
	var query := PhysicsShapeQueryParameters2D.new()
	var line := RectangleShape2D.new()
	line.size = Vector2(bounds.size.x, 0.2)
	query.shape = line
	query.collision_mask = 1
	query.transform.origin = Vector2(bounds.get_center().x, bounds.end.y)
	if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	query.transform.origin.y -= 5
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _splash(liquid: LiquidSurface, y_offset: float) -> void:
	EnemyEffect.play_once(sub_area, liquid.rules.poison_splash_sprite if sub_area.level_theme == Level.LevelTheme.FOREST \
			else liquid.rules.lava_splash_sprite, Vector2(global_position.x, liquid.global_position.y + y_offset), liquid.rules.splash_fps, false)


func _burst() -> void:
	if is_queued_for_deletion():
		return
	var nsmb_ice := kind == Kind.ICE and level.game_style == Level.GameStyle.NSMBU
	var art: StringName = &"spr_NSMBU_snowball_destroy" if nsmb_ice else &"spr_smoke"
	EnemyEffect.play_once(sub_area, art, global_position + Vector2(-8, 0), 18)
	if nsmb_ice:
		EnemyEffect.sound_once(sub_area, "res://assets/openwe/sounds/snd_NSMBU_snowball_break.ogg")
	queue_free()
