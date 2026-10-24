# SPDX-License-Identifier: AGPL-3.0-or-later
class_name OneUp
extends Entity
## Ordinary SMW 1UP; night poison/attachments are outside the SMM1 batch.

var _collected := false
var _age := 0
var _direction := 1
var _moving := false


func uses_source_deactivation() -> bool:
	return true


func uses_source_death_stop() -> bool:
	return true


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	z_index = GameConstants.Layers.Z_ENTITIES
	var shapes := SpriteCollision.precise(&"spr_1up", Vector2(-8, -16))
	SpriteCollision.add_shapes(self, shapes)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = SpriteLibrary.get_frames(&"spr_1up").get_frame_texture(&"default", 1)
	sprite.position = Vector2(0, -7)
	add_child(sprite)
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 4
	SpriteCollision.add_shapes(sensor, shapes)
	sensor.body_entered.connect(_collect)
	add_child(sensor)


func _physics_process(delta: float) -> void:
	if _collected or source_death_stopped():
		velocity = Vector2.ZERO
		return
	_age += 1
	var liquid := sub_area.liquid
	var swimming := sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (is_instance_valid(liquid) and liquid.is_water() and position.y - 16 > liquid.position.y + 16)
	if is_instance_valid(liquid) and not liquid.is_water() and position.y - 16 > liquid.position.y:
		EnemyEffect.play_once(sub_area, &"spr_smoke", global_position + Vector2(-8, -16), 18)
		queue_free()
		return
	if _age >= 2 and (is_on_floor() or velocity.y < 0):
		_moving = true
	if _moving:
		velocity.x = _direction * (30 if swimming else 60)
	velocity.y = minf(velocity.y, 60 if swimming else 240) + (72 if swimming else 720) * delta
	sub_area.actor_contacts.turn_item(self, delta)
	move_source_and_slide()
	if is_on_wall():
		_direction *= -1
	if global_position.y - 32 > Player.VOID_LEVEL:
		queue_free()


func bumped_from_below(activator: PhysicsBody2D) -> void:
	if _collected:
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.collision_mask = 1
	query.exclude = [get_rid()]
	query.transform = global_transform.translated(Vector2.UP)
	for owner_id in get_shape_owners():
		query.shape = shape_owner_get_shape(owner_id, 0)
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			EnemyEffect.play_once(sub_area, &"spr_smoke", global_position + Vector2(-8, -16), 18)
			queue_free()
			return
	velocity.y = -108 if sub_area.level_theme == Level.LevelTheme.UNDERWATER else -180
	_direction = 1 if velocity.x == 0 or global_position.x > activator.global_position.x else -1
	_moving = true


func _collect(body: Node2D) -> void:
	if not body is Player or _collected or body.is_dead() or body.is_frozen() \
			or body.level.status != Level.Status.PLAYING or get_tree().paused:
		return
	_collected = true
	body.extra_lives += 1
	EnemyEffect.sound_once(sub_area, "res://assets/openwe/sounds/snd_1up.ogg")
	var popup := LifePopup.new()
	popup.texture = SpriteLibrary.get_frames(&"spr_points").get_frame_texture(&"default", 8)
	popup.position = position + Vector2(0, -24)
	popup.z_index = GameConstants.Layers.Z_PARTICLES
	sub_area.add_deferred(popup)
	queue_free()


class LifePopup extends Sprite2D:
	var rise_speed := -60.0

	func _physics_process(delta: float) -> void:
		position.y += rise_speed * delta
		rise_speed = move_toward(rise_speed, 0, 63 * delta)
		if rise_speed == 0:
			modulate.a -= 3 * delta
			if modulate.a <= 0:
				queue_free()
