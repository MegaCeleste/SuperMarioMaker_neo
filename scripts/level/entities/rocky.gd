# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Rocky
extends Enemy
## obj_rocky: pops out of its cell, rises in two steps, throws a wrench, sinks
## back and repeats. Removing its support while settled defeats it.

enum Phase { FALLING, POP, WAIT, RISE, HIGH_WAIT, WINDUP, THROW, IDLE, SINK }

@export var variant: RockyVariant = preload("res://resources/content/smw_rocky.tres")
var direction := -1
var swimming := false
var phase := Phase.FALLING
var _home := 0.0
var _timer := 0.0
var _target := 0.0
var _rise_next := Phase.HIGH_WAIT
var _art: StringName
var _sprite: AnimatedSprite2D


func _ready() -> void:
	super()
	_home = global_position.y
	_sprite = $Graphics/Sprite
	$GravityComponent.set_physics_process(false)
	_set_art(variant.idle_sprite)


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	var player := level.get_living_player()
	direction = -1 if player == null or player.global_position.x < global_position.x else 1
	_sprite.flip_h = direction < 0
	if phase not in [Phase.FALLING, Phase.POP] and not _has_support():
		kill(0)
		return
	var before_motion := global_position
	var sample_before_motion := false
	match phase:
		Phase.FALLING:
			_fall(delta)
			super(delta)
			sample_before_motion = not is_on_floor()
			if is_on_floor():
				phase = Phase.POP
				velocity.y = -pop_speed()
				position.y -= 1
		Phase.POP:
			sample_before_motion = true
			_fall(delta)
			if source_death_stopped():
				velocity = Vector2.ZERO
			elif velocity.y < 0:
				if move_and_collide(velocity * delta) != null:
					velocity.y = 0
			else:
				# Source lands its origin on the surface, leaving the body buried.
				# A normal full-height move_and_slide would stop one cell too high.
				if _try_settle(delta):
					sample_before_motion = false
				else:
					position += velocity * delta
		Phase.WAIT:
			_timer -= delta
			if _timer <= 0.00001:
				if _blocked_above():
					_timer = variant.retry_ticks / 60.0
				else:
					_begin_rise(_home - 2.0, Phase.HIGH_WAIT)
		Phase.RISE:
			global_position.y -= variant.rise_speed * delta
			if global_position.y < _target - 0.00001:
				global_position.y = _target
				phase = _rise_next
				_timer = (variant.high_wait_ticks if _rise_next == Phase.HIGH_WAIT \
						else variant.windup_ticks) / 60.0
		Phase.HIGH_WAIT:
			_timer -= delta
			if _timer <= 0.00001:
				_begin_rise(_home - 9.0, Phase.WINDUP)
		Phase.WINDUP:
			_timer -= delta
			if _timer <= 0.00001:
				phase = Phase.THROW
				_timer = variant.throw_ticks / 60.0
				_set_art(variant.throw_sprite)
		Phase.THROW:
			_timer -= delta
			if _timer <= 0.00001:
				_throw_wrench()
				phase = Phase.IDLE
				_timer = variant.idle_ticks / 60.0
				_set_art(variant.idle_sprite)
		Phase.IDLE:
			_timer -= delta
			if _timer <= 0.00001:
				phase = Phase.SINK
				_set_art(variant.idle2_sprite)
		Phase.SINK:
			global_position.y = move_toward(global_position.y, _home, variant.rise_speed * delta)
			if is_equal_approx(global_position.y, _home):
				phase = Phase.WAIT
				_timer = variant.wait_ticks / 60.0
				_set_art(variant.idle2_sprite)
	if _is_below_world():
		queue_free()
		return
	# The source samples swimming at Step end, before its automatic free
	# flight integrates. Manual rise/sink/settlement has already moved it.
	swimming = _in_water(before_motion if sample_before_motion else global_position)
	if _touches_damaging_liquid():
		_sink()


func _fall(delta: float) -> void:
	velocity.y = minf(velocity.y, variant.water_fall_speed if swimming else variant.fall_speed) \
			+ (variant.water_gravity if swimming else variant.gravity) * delta


func _try_settle(delta: float) -> bool:
	var distance := velocity.y * delta
	var query := PhysicsShapeQueryParameters2D.new()
	var strip := RectangleShape2D.new()
	strip.size = Vector2(variant.mask_size.x, distance + 1)
	query.shape = strip
	query.transform.origin = global_position - Vector2(0, 15 - (distance + 1) / 2)
	query.collision_mask = 1
	var supports: Array[Dictionary] = []
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		if not hit.collider is Muncher and _solid_probe_body(hit.collider):
			supports.append({"body": hit.collider, "top": Utility.get_bounding_box(hit.collider).position.y})
	supports.sort_custom(func(a: Dictionary, b: Dictionary): return a.top < b.top)
	if supports.is_empty():
		return false
	_settle(supports[0].top, supports[0].body)
	return true


func _settle(surface_y: float, support: Node2D) -> void:
	velocity = Vector2.ZERO
	_home = surface_y + 16
	global_position.y = _home
	collision_mask = 0
	z_index = support.z_index - 1
	z_as_relative = false
	phase = Phase.WAIT
	_timer = variant.wait_ticks / 60.0
	_set_art(variant.idle2_sprite)
	EnemyEffect.play_once(sub_area, &"spr_smoke", global_position + Vector2(-8, -24), 18)


func _has_support() -> bool:
	return _terrain_at(12)


func _blocked_above() -> bool:
	return _terrain_at(-16)


func _terrain_at(y_offset: float) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = $CollShape.shape
	query.transform = $CollShape.global_transform
	query.transform.origin.y += y_offset
	query.collision_mask = 1
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		if _solid_probe_body(hit.collider):
			return true
	return false


func _solid_probe_body(body: CollisionObject2D) -> bool:
	if body is AnimatableBody2D:
		return true
	for shape_owner in body.get_shape_owners():
		if body.is_shape_owner_disabled(shape_owner):
			continue
		var collider := body.shape_owner_get_owner(shape_owner)
		if not collider is CollisionShape2D or not collider.one_way_collision:
			return true
	return false


func _begin_rise(target: float, next_phase: Phase) -> void:
	_target = target
	_rise_next = next_phase
	phase = Phase.RISE


func _set_art(name: StringName) -> void:
	if _art == name:
		return
	_art = name
	SpriteLibrary.configure_sprite(_sprite, name, &"default", 0, Vector2.ZERO)
	_sprite.pause()
	_sprite.frame = 2 # obj_rocky uses image_index = global.apariencia.
	# idle2 shortens the source mask by four pixels; its origin does not move.
	var height := 12.0 if name == variant.idle2_sprite else 16.0
	for path in ["CollShape", "PlayerArea/CollShape"]:
		var collider: CollisionShape2D = get_node(path)
		collider.shape = SpriteCollision.ellipse(Vector2(variant.mask_size.x, height), Vector2.ZERO)
		collider.position.y = -16 + height / 2


func _throw_wrench() -> void:
	var wrench := Wrench.new()
	wrench.direction = direction
	wrench.swimming = swimming
	wrench.rules = variant.wrench_rules
	wrench.position = global_position + Vector2(0, -16)
	sub_area.add_deferred(wrench)


func pop_speed() -> float:
	return variant.water_pop_speed if swimming else variant.pop_speed


func _in_water(at: Vector2) -> bool:
	if sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (sub_area.night_mode and sub_area.level_theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP]):
		return true
	var liquid := sub_area.liquid
	return is_instance_valid(liquid) and at.y - 8 >= liquid.global_position.y - 12


func _touches_damaging_liquid() -> bool:
	var liquid := sub_area.liquid
	return is_instance_valid(liquid) and (sub_area.level_theme == Level.LevelTheme.CASTLE \
			or (sub_area.level_theme == Level.LevelTheme.FOREST and sub_area.night_mode)) \
			and Utility.get_bounding_box(self).position.y > liquid.global_position.y - 10


func _sink() -> void:
	var liquid := sub_area.liquid
	EnemyEffect.play_once(sub_area, liquid.rules.poison_splash_sprite if sub_area.level_theme == Level.LevelTheme.FOREST \
			else liquid.rules.lava_splash_sprite, Vector2(global_position.x, liquid.global_position.y - 26), liquid.rules.splash_fps, false)
	var sink := SinkingEnemy.new()
	sink.sub_area = sub_area
	sink.sprite_name = _art
	sink.initial_frame = _sprite.frame
	sink.animate = false
	sink.mask_size = Vector2(variant.mask_size.x, 12 if _art == variant.idle2_sprite else variant.mask_size.y)
	sink.mask_center = Vector2(0, sink.mask_size.y / 2)
	sink.direction = direction
	sink.position = sub_area.get_foreground().to_local(global_position - Vector2(0, 16))
	sub_area.add_deferred(sink)
	queue_free()


func kill(_launch_direction := 0.0) -> void:
	if is_queued_for_deletion():
		return
	var effect := SwimmingEnemyDefeat.new()
	effect.variant = variant
	effect.sub_area = sub_area
	effect.direction = direction
	# SMW Other_10 never gives Rocky's corpse horizontal speed or spin.
	effect.velocity.x = 0
	effect.position = sub_area.get_foreground().to_local(global_position + variant.dead_offset)
	sub_area.add_deferred(effect)
	queue_free()


func _is_below_world() -> bool:
	return Utility.get_bounding_box(self).position.y - 16 > 0


func _stomped(player: Player) -> void:
	if is_queued_for_deletion():
		return
	player.bounce()
	player.sounds.stream = preload("uid://c345xnns7om3m")
	player.sounds.play()
	player.spawn_spin_thump()
	player.score += 200
	kill(player.direction)


func get_defeat_sprite() -> StringName:
	return variant.dead_sprite


func get_defeat_frame() -> int:
	return 2
