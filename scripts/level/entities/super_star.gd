# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SuperStar
extends Entity

var _age := 0
var _collected := false
var _direction := 1


func uses_source_deactivation() -> bool:
	return true


func uses_source_death_stop() -> bool:
	return true


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	z_index = GameConstants.Layers.Z_ENTITIES
	# spr_estrella_mask: ellipse, inclusive bbox(2,2)..(13,15), origin(0,0).
	var shapes: Array[ConvexPolygonShape2D] = [SpriteCollision.ellipse(Vector2(12, 14), Vector2(0, -7))]
	SpriteCollision.add_shapes(self, shapes)
	var sprite := SpriteLibrary.make_sprite(&"spr_star")
	sprite.position = Vector2(-8, -16)
	sprite.sprite_frames = SpriteLibrary.get_animations({"star": ["spr_star", 18, true]})
	sprite.play(&"star")
	add_child(sprite)
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 4
	SpriteCollision.add_shapes(sensor, shapes)
	sensor.body_entered.connect(_collect)
	add_child(sensor)


func _physics_process(delta: float) -> void:
	if _collected:
		return
	if source_death_stopped():
		velocity = Vector2.ZERO
		return
	_age += 1
	var liquid := sub_area.liquid
	var swimming := sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (is_instance_valid(liquid) and liquid.is_water() and position.y - 16 > liquid.position.y + 16)
	if _age == 2:
		velocity.x = 30 if swimming else 60
	var limit := 30.0 if swimming else 60.0
	if absf(velocity.x) > limit:
		velocity.x = move_toward(velocity.x, _direction * limit, 288 * delta)
	if is_instance_valid(liquid) and not liquid.is_water() and position.y - 16 > liquid.position.y:
		EnemyEffect.play_once(sub_area, &"spr_smoke", global_position + Vector2(-8, -16), 18)
		queue_free()
		return
	velocity.y = minf(velocity.y, 60 if swimming else 240) + 450 * delta
	sub_area.actor_contacts.turn_item(self, delta)
	move_source_and_slide()
	if is_on_wall():
		_direction *= -1
		velocity.x = limit * _direction
	if is_on_floor():
		velocity.y = -240
	if global_position.y - 32 > Player.VOID_LEVEL:
		queue_free()


func _collect(body: Node2D) -> void:
	if not body is Player or _collected or body.is_dead() or body.is_frozen() \
			or body.level.status != Level.Status.PLAYING or get_tree().paused:
		return
	_collected = true
	body.score += 1000
	body.collect_star()
	body.sounds.stream = preload("uid://b20440v3vqlik")
	body.sounds.play()
	queue_free()
