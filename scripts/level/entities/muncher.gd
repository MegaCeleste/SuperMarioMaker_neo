# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Muncher
extends Entity
## A falling solid hazard, not an Enemy: shells rebound and spin jumps hurt.

@export var variant: MuncherVariant = preload("res://resources/content/smw_muncher_small.tres")
var swimming := false
var support: Muncher
var _gravity := 0.0
var _sprite: AnimatedSprite2D
var _contact_shape: RectangleShape2D


func uses_source_deactivation() -> bool:
	return true


func uses_source_death_stop() -> bool:
	return true


func _ready() -> void:
	collision_layer = 3 # Native solid movement plus block/helmet queries.
	collision_mask = 1
	SpriteCollision.add_shapes(self, [SpriteCollision.ellipse(variant.mask_size, Vector2(0, -variant.mask_size.y / 2))])
	_contact_shape = RectangleShape2D.new()
	_contact_shape.size = variant.mask_size + Vector2(2, 2)
	_sprite = SpriteLibrary.make_sprite(variant.body_sprite)
	_sprite.position.y = SpriteLibrary.contact_draw_y(variant.body_sprite)
	_sprite.pause()
	add_child(_sprite)


func _process(_delta: float) -> void:
	# All Munchers use the level's banim2 clock, including later spawns.
	_sprite.frame = floori(level.animation_time * 6 + 0.00001) % _sprite.sprite_frames.get_frame_count(&"default")
	_sprite.position.x = roundf(global_position.x) - global_position.x


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	var before := Utility.get_bounding_box(self)
	var was_grounded := is_on_floor()
	var before_velocity_y := velocity.y
	if not is_instance_valid(support) or support.is_queued_for_deletion():
		support = _find_support()
		if is_instance_valid(support):
			velocity.y = 0
			_gravity = 0
	var incoming_y := velocity.y
	if is_instance_valid(support):
		# Step_0 follows the source instance origin before built-in motion.
		global_position = support.global_position + Vector2(0,
				variant.mask_size.y - variant.canvas_size.y - support.variant.mask_size.y)
		if not source_death_stopped():
			global_position += velocity * delta
	else:
		var drag := variant.ground_drag if is_zero_approx(_gravity) else variant.air_drag
		velocity.x = move_toward(velocity.x, 0, drag * delta)
		swimming = _in_water()
		_gravity = variant.water_gravity if swimming else variant.gravity
		var cap := variant.water_fall_speed if swimming else variant.fall_speed
		velocity.y = minf(cap, velocity.y) + _gravity * delta
		incoming_y = velocity.y
		move_source_and_slide()
		if is_on_floor():
			_gravity = 0
			if not was_grounded and before_velocity_y > 0 and not variant.landing_sound.is_empty():
				EnemyEffect.sound_once(sub_area, SoundLibrary.path(variant.landing_sound))
				level.shake_camera(2)
	_interact(before, incoming_y if global_position.y > before.end.y + 0.0001 else 0.0, delta)
	super(delta)
	# Muncher overrides the generic lava-deletion branch. Only void culls it.
	if Utility.get_bounding_box(self).position.y > 16:
		queue_free()


func _in_water() -> bool:
	if _full_water():
		return true
	var liquid := sub_area.liquid
	return is_instance_valid(liquid) and liquid.is_water() \
			and global_position.y - variant.mask_size.y > liquid.global_position.y + 16


func _full_water() -> bool:
	return sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (sub_area.night_mode and sub_area.level_theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP])


func _find_support() -> Muncher:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position + Vector2(0, 7)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_point(query, 32):
		var below := hit.collider as Muncher
		if below != null and not below.is_queued_for_deletion() \
				and below.global_position.y - below.variant.mask_size.y > global_position.y - variant.mask_size.y:
			return below
	return null


func _interact(before: Rect2, incoming_y: float, delta: float) -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _contact_shape
	query.transform = global_transform.translated_local(Vector2(0, -variant.mask_size.y / 2))
	query.collision_mask = 14
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body := hit.collider as CharacterBody2D
		if body == null or body is Muncher or body.is_queued_for_deletion():
			continue
		var bounds := Utility.get_bounding_box(body)
		var crushing := incoming_y > 0 and before.end.y < bounds.position.y + 2
		if body is Player:
			if body.is_dead() or level.status != Level.Status.PLAYING:
				continue
			if body.helmet_deflects(self):
				continue
			if crushing and (body.is_on_floor() or body.test_move(body.global_transform, Vector2(0, incoming_y * delta + 1))):
				body.kill()
			else:
				if crushing:
					body.global_position.y += incoming_y * delta
				if not body.has_helmet() or bounds.position.y < Utility.get_bounding_box(self).end.y - 1:
					body.damage()
		elif crushing and not body is Blooper and not body is CheepCheep:
			if body.is_on_floor() or body.test_move(body.global_transform, Vector2(0, incoming_y * delta + 1)):
				if body.has_method("kill"):
					var direction := signf(velocity.x)
					if direction == 0:
						direction = signf(bounds.position.x - Utility.get_bounding_box(self).position.x)
					EnemyEffect.sound_once(sub_area, SoundLibrary.path(variant.crush_sound))
					if body is Enemy:
						body.hit_by_actor(&"crush", self, direction)
					else:
						body.kill(direction)
				elif body is Mushroom:
					EnemyEffect.play_once(sub_area, &"spr_smoke", body.global_position - Vector2(0, 8), 18)
					body.queue_free()
			else:
				body.global_position.y += incoming_y * delta


## obj_physicsparent/Collision_obj_blockparent: bounce only with free headroom.
func bumped_from_below(_activator: PhysicsBody2D) -> void:
	if not test_move(global_transform, Vector2(0, -1)):
		velocity.y = -variant.water_bump_speed if _full_water() else -variant.bump_speed


## Source Buzzy physical-solid and Spiny Muncher handlers use different clearances.
func get_helmet_hit_margin(spiny: bool) -> float:
	return variant.spiny_helmet_margin if spiny else variant.buzzy_helmet_margin


## Dedicated helmet hits exclude ascending actors; ordinary fire/shell hits fail.
func hit_by_projectile(kind: StringName, launch_direction := 0.0) -> bool:
	if is_queued_for_deletion():
		return false
	if kind == &"helmet" and velocity.y >= 0:
		kill(launch_direction)
		return true
	if kind == &"pow" and is_zero_approx(velocity.y):
		kill(0, true)
		return true
	return false


func kill(launch_direction := 0.0, stationary := false) -> void:
	if is_queued_for_deletion():
		return
	var dead := SwimmingEnemyDefeat.new()
	dead.variant = variant
	dead.sub_area = sub_area
	dead.position = sub_area.get_foreground().to_local(global_position + variant.dead_offset)
	dead.direction = signf(launch_direction) if launch_direction != 0 else -1
	dead.velocity.x = 0 if stationary else dead.direction * 60
	sub_area.add_deferred(dead)
	if stationary:
		EnemyEffect.play_once(sub_area, variant.pow_smoke_sprite, global_position + variant.dead_offset - Vector2(0, 5), 18)
	queue_free()
