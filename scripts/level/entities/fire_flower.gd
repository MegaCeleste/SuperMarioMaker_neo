# SPDX-License-Identifier: AGPL-3.0-or-later
class_name FireFlower
extends Entity
## Ordinary and progressive SMW flowers share the native powerup lifecycle.

var progressive := false
var _collected := false


func uses_source_deactivation() -> bool:
	return true


func uses_source_death_stop() -> bool:
	return true


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	z_index = 30
	var shapes := SpriteCollision.precise(&"spr_fireflower", Vector2(-8, -16))
	SpriteCollision.add_shapes(self, shapes)
	var sprite := SpriteLibrary.make_sprite(&"spr_fireflower")
	sprite.name = "Sprite"
	sprite.position = Vector2(-8, -16)
	sprite.sprite_frames = SpriteLibrary.get_animations({"flower": ["spr_fireflower", 9, true]})
	sprite.play(&"flower")
	add_child(sprite)
	var area := Area2D.new()
	area.name = "PlayerArea"
	area.collision_layer = 0
	area.collision_mask = 4
	SpriteCollision.add_shapes(area, shapes)
	area.body_entered.connect(_body_entered)
	add_child(area)


func _physics_process(delta: float) -> void:
	if _collected or is_queued_for_deletion():
		return
	var player := level.hud.player
	if progressive and is_instance_valid(player) and player.get_powerup() is SmallPowerup \
			and Utility.get_visible_rect().grow(32).has_point(global_position + Vector2(-8, -16)):
		_replace_with_mushroom()
		return
	if source_death_stopped():
		velocity = Vector2.ZERO
		return
	var liquid := sub_area.liquid
	if liquid != null and not liquid.is_water() and position.y - 16 > liquid.position.y:
		EnemyEffect.play_once(sub_area, &"spr_smoke", global_position + Vector2(-8, -16), 18)
		queue_free()
		return
	var swimming := sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (liquid != null and liquid.is_water() and position.y - 16 > liquid.position.y + 16)
	velocity.y = minf(velocity.y, 60 if swimming else 240) + (72 if swimming else 720) * delta
	sub_area.actor_contacts.turn_item(self, delta)
	move_source_and_slide()
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, 720 * delta)
	if global_position.y - 32 > Player.VOID_LEVEL:
		queue_free()


func bumped_from_below(_activator: PhysicsBody2D) -> void:
	if velocity.y < 0 or _collected:
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.collision_mask = 1
	query.transform = global_transform.translated(Vector2(0, -1))
	query.exclude = [get_rid()]
	for owner_id in get_shape_owners():
		query.shape = shape_owner_get_shape(owner_id, 0)
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			EnemyEffect.play_once(sub_area, &"spr_smoke", global_position + Vector2(-8, -16), 18)
			queue_free()
			return
	velocity.y = -108 if sub_area.level_theme == Level.LevelTheme.UNDERWATER else -180


func _replace_with_mushroom() -> void:
	if _collected:
		return
	_collected = true
	# ActorContacts references both powerup controllers. Resolve the replacement
	# at runtime so that dependency does not preload an unfinished PackedScene.
	var mushroom: Mushroom = load("res://scenes/entities/mushroom.tscn").instantiate()
	mushroom.position = position
	sub_area.add_deferred(mushroom)
	queue_free()


func _body_entered(body: Node2D) -> void:
	if not body is Player or _collected or body.is_dead() or body.is_frozen() \
			or body.level.status != Level.Status.PLAYING or get_tree().paused:
		return
	if progressive and body.get_powerup() is SmallPowerup:
		_replace_with_mushroom()
		return
	_collected = true
	body.score += 1000
	if not body.get_powerup() is FirePowerup:
		body.set_powerup(FirePowerup.new(), true)
	else:
		body.sounds.stream = preload("uid://b20440v3vqlik")
		body.sounds.play()
	queue_free()
