# SPDX-License-Identifier: AGPL-3.0-or-later
class_name HammerBro
extends Enemy
## SMW Bro alarms, independent throwing/recovery clocks, platform jumps and
## Sledge's windup/hover/landing. Resources select the type's art and cadence.

@export var variant: HammerBroVariant = preload("res://resources/content/smw_hammerbro_hammer.tres")
var direction := 1
var wings := false
var parachute := false
var through_solid := 0
var _home_x := 0.0
var _home_y := 0.0
var _jump_timer := 6.0
var _jump_windup := 0.0
var _jump_floor := 0.0
var _small_jump := false
var _pass_delay := 0.0
var _throw_timer := 17.0 / 60
var _windup := 0.0
var _recover := 0.0
var _throw_pose := 0
var _throws_left := 1
var _wake_left := 2.0 / 60
var _previous_walk := 24.0
var _hover_left := 0.0
var _hover_used := false
var _sprite: AnimatedSprite2D
var _wing_sprite: AnimatedSprite2D
var _parachute_sprite: AnimatedSprite2D
var _art: StringName
var _airborne := false
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	super()
	_home_x = global_position.x
	_home_y = global_position.y
	_sprite = $Graphics/Sprite
	$Graphics.position.y = SpriteLibrary.contact_draw_y(variant.idle_sprite)
	for path in ["CollShape", "PlayerArea/CollShape"]:
		var collider: CollisionShape2D = get_node(path)
		collider.shape = SpriteCollision.ellipse(variant.mask_size, Vector2.ZERO)
		collider.position = Vector2(0, -variant.mask_size.y / 2)
	$GravityComponent.set_physics_process(false)
	_jump_timer = variant.jump_interval
	_throw_timer = variant.throw_interval / 60.0
	_random.randomize()
	_throws_left = _random.randi_range(2, 4) if variant.id == &"hammer" else _random.randi_range(variant.min_throws, variant.max_throws)
	_previous_walk = variant.water_initial_walk_speed if _full_water() else variant.walk_speed
	_set_art(variant.idle_sprite, 7.5)
	_wing_sprite = SpriteLibrary.make_sprite(&"spr_wings")
	_wing_sprite.name = "Wings"
	$Graphics.add_child(_wing_sprite)
	SpriteLibrary.configure_sprite(_wing_sprite, &"spr_wings", &"wings", 7.2)
	_parachute_sprite = SpriteLibrary.make_sprite(&"spr_paracaidas")
	_parachute_sprite.name = "Parachute"
	_parachute_sprite.pause()
	_parachute_sprite.frame = 2
	_parachute_sprite.z_index = -1
	$Graphics.add_child(_parachute_sprite)
	if parachute:
		velocity.x = -30
	_update_visuals()


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if _touches_damaging_liquid():
		_sink()
		return
	var player := level.get_living_player()
	direction = -1 if not is_instance_valid(player) or player.global_position.x < global_position.x else 1
	_tick_throwing(delta)
	_tick_jumping(delta)
	_wake_left = maxf(0, _wake_left - delta)
	if parachute:
		if global_position.x > _home_x + 16:
			velocity.x = maxf(velocity.x - 54.0 * delta, -30)
		elif global_position.x < _home_x - 16:
			velocity.x = minf(velocity.x + 54.0 * delta, 30)
		velocity.y = minf(velocity.y, 24) + 360.0 * delta
		direction = -1
	elif _hover_left > 0:
		_hover_left = maxf(0, _hover_left - delta)
		if global_position.y > _home_y + 8:
			velocity.y = maxf(velocity.y - 306.0 * delta, -12)
		elif global_position.y < _home_y - 8:
			velocity.y = minf(velocity.y + 306.0 * delta, 12)
		if _hover_left == 0:
			velocity.y = 120
	else:
		var swimming := _in_water()
		if through_solid > 0:
			var cap := variant.water_fall_speed if swimming else variant.fall_speed
			velocity.y = cap if velocity.y > cap else velocity.y \
					+ (variant.water_pass_gravity if swimming else variant.pass_gravity) * delta
		else:
			velocity.y = minf(velocity.y, variant.water_fall_speed if swimming else variant.fall_speed) \
					+ (variant.water_gravity if swimming else variant.gravity) * delta
		if variant.sledge and wings and _airborne and not _hover_used and velocity.y > 0:
			_hover_left = 1.0
			_hover_used = true
			velocity.y = 0
	if not parachute:
		if _throw_pose > 0 or _jump_windup > 0 or through_solid > 0:
			velocity.x = 0
		elif _wake_left == 0:
			_patrol()
	if through_solid == 1 and velocity.y > 0:
		through_solid = 2
	if not source_death_stopped() and through_solid == 2 and velocity.y > 0 \
			and (not _small_jump or global_position.y > _jump_floor + variant.source_to_feet):
		_try_platform_landing(delta)
	if through_solid > 0:
		if not source_death_stopped():
			position += velocity * delta
	else:
		super(delta)
	if parachute and is_on_floor():
		parachute = false
		velocity.x = 0
		_wake_left = 10.0 / 60
		_drop_parachute()
	if variant.sledge and _airborne and is_on_floor() and _hover_left == 0:
		_airborne = false
		_recover = 15.0 / 60
		_sledge_landing()
	if _is_below_world():
		queue_free()
	_update_visuals()


func apply_source_death() -> void:
	super()
	# Regular alarm2 and Sledge alarm3 start throws; their pending windup
	# alarms3/4 and recovery alarms6/5 deliberately keep running.
	_throw_timer = INF
	_jump_timer = INF


func _tick_throwing(delta: float) -> void:
	if _recover > 0:
		_recover = maxf(0, _recover - delta)
		if _recover <= 0.00001:
			_recover = 0
			_throw_pose = 0
			velocity.x = _previous_walk
	if _windup > 0:
		_windup = maxf(0, _windup - delta)
		if _windup <= 0.00001:
			_windup = 0
			_spawn_projectile()
			_throw_pose = 2
			_recover = 5.0 / 60
	_throw_timer -= delta
	if _throw_timer <= 0.00001:
		if variant.sledge:
			if not is_on_floor() or _hover_left > 0 or _jump_windup > 0:
				_throw_timer = 1.0 / 60
				return
		elif _throws_left <= 0:
			_throws_left = _random.randi_range(variant.min_throws, variant.max_throws)
			_throw_timer = variant.burst_cooldown / 60.0
			_throw_pose = 0
			velocity.x = _previous_walk
			return
		_throws_left -= 1
		if not is_zero_approx(velocity.x):
			_previous_walk = velocity.x
		_throw_pose = 1
		_windup = 10.0 / 60
		_throw_timer = (80.0 if variant.sledge else variant.throw_delay) / 60
		velocity.x = 0


func _tick_jumping(delta: float) -> void:
	if _pass_delay > 0:
		_pass_delay = maxf(0, _pass_delay - delta)
		if _pass_delay <= 0.00001:
			_pass_delay = 0
			through_solid = 1
			collision_mask = 0
	if _jump_windup > 0:
		_jump_windup = maxf(0, _jump_windup - delta)
		if _jump_windup <= 0.00001:
			_jump_windup = 0
			velocity.y = -180 if _in_water() else variant.jump_speed
			_jump_timer = 490.0 / 60
			_airborne = true
			_hover_used = false
		return
	_jump_timer -= delta
	if _jump_timer > 0.00001:
		return
	if not is_on_floor() or (variant.sledge and _throw_pose > 0):
		# Regular Alarm_1's airborne branch writes the unused alarm[0].
		# No ancestor handles it, so it does not schedule another jump.
		_jump_timer = 1.0 / 60 if variant.sledge else INF
		return
	if variant.sledge:
		_jump_windup = 30.0 / 60
		_throw_timer = 80.0 / 60
		_previous_walk = velocity.x if not is_zero_approx(velocity.x) else _previous_walk
		velocity.x = 0
	else:
		_small_jump = _choose_small_jump()
		var swimming := _in_water()
		velocity.y = (variant.water_wing_jump_small if swimming else variant.wing_jump_small) if wings and _small_jump \
				else (variant.water_wing_jump_big if swimming else variant.wing_jump_big) if wings \
				else (variant.water_jump_small if swimming else variant.jump_small) if _small_jump \
				else (variant.water_jump_big if swimming else variant.jump_big)
		_jump_floor = global_position.y
		_pass_delay = 1.0 / 60
		_jump_timer = variant.jump_interval


func _patrol() -> void:
	var cap := variant.water_walk_speed if _in_water() else variant.walk_speed
	if velocity.x <= 0 and global_position.x <= _home_x - 16:
		velocity.x = cap
	elif velocity.x >= 0 and global_position.x >= _home_x + 16:
		velocity.x = -cap
	elif is_zero_approx(velocity.x):
		velocity.x = _previous_walk * direction if _previous_walk > 0 else _previous_walk
	if is_on_wall():
		velocity.x = -velocity.x
	if not is_zero_approx(velocity.x):
		_previous_walk = velocity.x


func _block_at(y: float) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(variant.mask_size.x, 0.2)
	query.shape = shape
	query.transform.origin = Vector2(global_position.x, y)
	query.collision_mask = 1
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		if Utility.find_child_by_class(hit.collider, BlockComponent) != null:
			return true
	return false


## Alarm_1's probes are native shape overlaps, corresponding to place_meeting
## with the whole source mask. Its largest room-depth test subsumes the rest.
func _choose_small_jump() -> bool:
	var bounds := Utility.get_bounding_box(self)
	var above := _block_at(bounds.position.y - variant.upper_block_probe)
	var below := _block_at(bounds.end.y - 1 + variant.lower_block_probe)
	if not below or global_position.y - variant.source_to_feet + variant.jump_room_below >= 0:
		return false
	if not above:
		return true
	for offset in variant.lower_support_probes:
		if _terrain_at_feet(global_position + Vector2(0, offset)):
			return _random.randf() >= 0.5
	return false


func _terrain_at_feet(at: Vector2, ignore_one_way := false) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	# Physics overlap queries include touching edges. Remove that solver-only
	# contact so the lower probe does not mistake its current block for a floor.
	query.shape = SpriteCollision.ellipse(variant.mask_size - Vector2(0.2, 0.2), Vector2.ZERO)
	query.transform.origin = at - Vector2(0, variant.mask_size.y / 2)
	query.collision_mask = 1
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		if not ignore_one_way or not _one_way_only(hit.collider):
			return true
	return false


func _one_way_only(body: CollisionObject2D) -> bool:
	for owner_id in body.get_shape_owners():
		if body.is_shape_owner_disabled(owner_id):
			continue
		var shape_owner := body.shape_owner_get_owner(owner_id)
		if not shape_owner is CollisionShape2D or not shape_owner.one_way_collision:
			return false
	return true


func _try_platform_landing(delta: float) -> void:
	var distance := velocity.y * delta
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(variant.mask_size.x, distance + 2)
	query.shape = shape
	query.transform.origin = global_position + Vector2(0, distance / 2)
	query.collision_mask = 1
	var floors: Array[Dictionary] = []
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var bounds := Utility.get_bounding_box(hit.collider)
		if bounds.position.y >= global_position.y - 1 and bounds.position.y <= global_position.y + distance + 1:
			floors.append({"top": bounds.position.y, "center": bounds.get_center().x})
	floors.sort_custom(func(a: Dictionary, b: Dictionary): return a.top < b.top)
	for floor_hit in floors:
		# The source tests room at the candidate support, ignoring semisolid
		# undersides. Native solids/physical platforms still block that room.
		if _terrain_at_feet(Vector2(floor_hit.center, floor_hit.top), true):
			continue
		global_position.y = floor_hit.top
		velocity.y = 1
		through_solid = 0
		collision_mask = 1
		velocity.x = _previous_walk if _throw_pose == 0 else 0.0
		return


func _spawn_projectile() -> void:
	var player := level.get_living_player()
	if is_instance_valid(player) and is_equal_approx(player.global_position.x, global_position.x):
		return
	var projectile := BroProjectile.new()
	projectile.kind = variant.projectile as BroProjectile.Kind
	projectile.direction = direction
	projectile.home = self
	projectile.position = global_position + Vector2(variant.hammer_offset.x * direction, variant.hammer_offset.y)
	sub_area.add_deferred(projectile)


func _set_art(art: StringName, fps: float) -> void:
	if _art != art:
		_art = art
		SpriteLibrary.configure_sprite(_sprite, art, &"default", maxf(1, fps))
	if fps <= 0:
		_sprite.pause()
	else:
		_sprite.play()
	_sprite.flip_h = direction < 0


func _update_visuals() -> void:
	if source_death_stopped():
		pass # The source SMW end-step art selector is guarded by !obj_deadmario.
	elif _throw_pose > 0 and (is_on_floor() or _throw_pose == 1):
		_set_art(variant.throw_sprite, 0)
		_sprite.frame = _throw_pose - 1
	elif not is_on_floor() and not variant.sledge:
		_set_art(variant.jump_sprite, 0)
		_sprite.frame = 0
	elif variant.sledge and not is_on_floor() and _hover_left == 0:
		_set_art(variant.idle_sprite, 0)
		_sprite.frame = int(velocity.y > 0)
	else:
		_set_art(variant.idle_sprite, 7.5)
	_sprite.position.x = roundf(global_position.x) - global_position.x
	_sprite.flip_h = direction < 0
	_wing_sprite.visible = wings
	_wing_sprite.position = Vector2((-14 if variant.sledge else -12) * direction, -26 if variant.sledge else -22)
	_wing_sprite.flip_h = direction < 0
	_wing_sprite.speed_scale = (10.8 if variant.sledge else 12.0) / 7.2 if not is_on_floor() else 1.0
	_parachute_sprite.visible = parachute
	_parachute_sprite.position = Vector2(-6 * direction, -4)


func _sledge_landing() -> void:
	EnemyEffect.sound_once(sub_area, SoundLibrary.path("snd_thwomp_original"))
	level.shake_camera(1)
	if is_instance_valid(level.hud.player):
		level.hud.player.stun_from_landing()
	var bounds := Utility.get_bounding_box(self)
	for x in [bounds.position.x - 8, bounds.end.x - 9]:
		EnemyEffect.play_once(sub_area, &"spr_smoke", Vector2(x, global_position.y - 9), 18)


func _drop_parachute() -> void:
	var sprite := SpriteLibrary.make_sprite(&"spr_paracaidas_go")
	sprite.pause()
	sprite.frame = 2
	sprite.position = global_position + Vector2(6, -20)
	sub_area.add_deferred(sprite)
	sprite.ready.connect(func():
		var tween := sprite.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 8.0 / 60)
		tween.tween_callback(sprite.queue_free))


func _full_water() -> bool:
	return sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (sub_area.night_mode and sub_area.level_theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP])


func _in_water() -> bool:
	return _full_water() or (is_instance_valid(sub_area.liquid) and sub_area.liquid.is_water() \
			and global_position.y - 8 > sub_area.liquid.global_position.y)


func _touches_damaging_liquid() -> bool:
	var liquid := sub_area.liquid
	if not is_instance_valid(liquid) or liquid.is_water():
		return false
	# Source bbox_bottom is inclusive; the native Rect2 end is exclusive.
	var bottom := Utility.get_bounding_box(self).end.y - 9
	return bottom >= liquid.global_position.y - 12 if sub_area.level_theme == Level.LevelTheme.CASTLE \
			else bottom > liquid.global_position.y - 12 if sub_area.level_theme == Level.LevelTheme.FOREST and sub_area.night_mode \
			else false


func _sink() -> void:
	var liquid := sub_area.liquid
	EnemyEffect.play_once(sub_area, liquid.rules.poison_splash_sprite if sub_area.level_theme == Level.LevelTheme.FOREST \
			else liquid.rules.lava_splash_sprite, Vector2(global_position.x, liquid.global_position.y - 26), liquid.rules.splash_fps, false)
	var sink := SinkingEnemy.new()
	sink.sub_area = sub_area
	sink.sprite_name = _art
	sink.mask_size = variant.mask_size
	sink.mask_center = Vector2(0, variant.source_to_feet - variant.mask_size.y / 2)
	sink.ellipse_mask = true
	sink.direction = direction
	sink.position = sub_area.get_foreground().to_local(global_position - Vector2(0, variant.source_to_feet))
	sub_area.add_deferred(sink)
	queue_free()


func _stomped(player: Player) -> void:
	if is_queued_for_deletion():
		return
	if player.state_machine.current_state is PlayerSpinJumpingState:
		player.bounce()
		_spin_stomp()
		return
	player.bounce()
	player.sounds.stream = preload("uid://c345xnns7om3m")
	player.sounds.play()
	player.spawn_spin_thump()
	if wings:
		wings = false
		_wake_left = 2.0 / 60
		var dead := DetachedEnemyAttachment.new()
		dead.position = sub_area.get_foreground().to_local(global_position + Vector2(9 * direction, -7))
		dead.turn_direction = direction
		var sprite := SpriteLibrary.make_sprite(&"spr_wings_deads")
		sprite.pause()
		sprite.frame = 2
		dead.add_child(sprite)
		sub_area.add_deferred(dead)
		_update_visuals()
		return
	player.score += 200
	hit_by_actor(&"stomp", player)


func hit_by_actor(kind: StringName, impact: CollisionObject2D, _fallback_direction := 0.0) -> bool:
	return hit_by_projectile(kind, source_hit_direction(impact))


func hit_by_projectile(kind: StringName, launch_direction := 0.0) -> bool:
	if kind == &"pow":
		if is_queued_for_deletion() or velocity.y != 0:
			return false
		spawn_source_defeat(variant, direction, 0, true)
		return true
	return super(kind, launch_direction)


func bumped_by_block(block: PhysicsBody2D, _activator: PhysicsBody2D) -> void:
	source_block_defeat(block)


func kill(launch_direction := 0.0) -> void:
	spawn_source_defeat(variant, direction, launch_direction)


func get_defeat_sprite() -> StringName:
	return variant.dead_sprite


func get_defeat_frame() -> int:
	return variant.dead_frame
