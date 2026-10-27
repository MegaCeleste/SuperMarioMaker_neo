# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerFireball
extends Entity
## obj_fireball, distinct from the enemy Bro's lower bounce/water policies.

const GRAVITY := 720.0
const FALL_CAP := 240.0
const BOUNCE_SPEED := -120.0
var _shapes: Array[ConvexPolygonShape2D]
var _sprite: AnimatedSprite2D


func uses_source_deactivation() -> bool:
	return true


func uses_source_death_stop() -> bool:
	return true


func _ready() -> void:
	z_index = GameConstants.Layers.Z_ENTITIES
	collision_layer = 0
	collision_mask = 1
	_sprite = SpriteLibrary.make_sprite(&"spr_fireball")
	_sprite.sprite_frames = SpriteLibrary.get_animations({"fire": ["spr_fireball", 9, true]})
	_sprite.play(&"fire")
	add_child(_sprite)
	_shapes = SpriteCollision.precise(&"spr_fireball")
	SpriteCollision.add_shapes(self, _shapes)
	var area := Area2D.new()
	area.name = "EnemyArea"
	area.collision_layer = 0
	area.collision_mask = 2
	SpriteCollision.add_shapes(area, _shapes)
	area.body_entered.connect(_hit_enemy)
	add_child(area)
	EnemyEffect.sound_once(sub_area, SoundLibrary.path("snd_fireball"))
	var query := PhysicsShapeQueryParameters2D.new()
	query.collision_mask = 1
	query.transform = global_transform
	for shape in _shapes:
		query.shape = shape
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			_burst()
			break


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	var view := Utility.get_visible_rect()
	if global_position.x < view.position.x - 32 or global_position.x > view.end.x + 32 \
			or global_position.y < view.position.y - 32 or global_position.y > view.end.y + 32:
		queue_free()
		return
	if source_death_stopped():
		velocity = Vector2.ZERO
		return
	if _liquid_contact():
		return
	velocity.y = minf(velocity.y, FALL_CAP) + GRAVITY * delta
	var horizontal := velocity.x
	move_and_slide()
	for index in get_slide_collision_count():
		var normal := get_slide_collision(index).get_normal()
		if absf(normal.x) > 0.5:
			_burst()
			return
		if normal.y < -0.5:
			velocity.y = BOUNCE_SPEED
			position.y -= 1
	velocity.x = horizontal


func _hit_enemy(body: Node2D) -> void:
	if not body is Enemy or is_queued_for_deletion() or body.is_queued_for_deletion() \
			or not body.is_visible_in_tree():
		return
	if body.hit_by_actor(&"fire", self, signf(velocity.x)):
		if is_instance_valid(level.hud.player) and not level.hud.player.is_dead():
			level.hud.player.score += 200
		EnemyEffect.sound_once(sub_area, "uid://c345xnns7om3m")
	_burst()


func _liquid_contact() -> bool:
	var liquid := sub_area.liquid
	# Source Other14 gives a supporting platform precedence over liquid.
	if liquid == null or _supported():
		return false
	var source_y := global_position.y
	var bottom_sample := source_y + 3 # Inclusive bbox_bottom11 minus8.
	if liquid.is_water() and bottom_sample > liquid.global_position.y - 12 \
			and bottom_sample < liquid.global_position.y - 10:
		EnemyEffect.play_once(sub_area, liquid.rules.water_splash_sprite,
				Vector2(global_position.x, liquid.global_position.y - 24), liquid.rules.splash_fps, false)
	if sub_area.level_theme == Level.LevelTheme.CASTLE and bottom_sample >= liquid.global_position.y - 12:
		EnemyEffect.play_once(sub_area, liquid.rules.lava_splash_sprite,
				Vector2(global_position.x, liquid.global_position.y - 26), liquid.rules.splash_fps, false)
		queue_free()
		return true
	if sub_area.level_theme == Level.LevelTheme.FOREST and sub_area.night_mode \
			and source_y + 8 >= liquid.global_position.y:
		EnemyEffect.play_once(sub_area, liquid.rules.poison_splash_sprite,
				Vector2(global_position.x, liquid.global_position.y - 26), liquid.rules.splash_fps, false)
		queue_free()
		return true
	return false


func _supported() -> bool:
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


func _burst() -> void:
	if is_queued_for_deletion():
		return
	EnemyEffect.play_once(sub_area, &"spr_smoke", global_position + Vector2(-8, 0), 18)
	EnemyEffect.sound_once(sub_area, SoundLibrary.path("snd_bump"))
	queue_free()
