# SPDX-License-Identifier: AGPL-3.0-or-later
class_name CharacterBodyExt
extends CharacterBody2D
## A modified version of [CharacterBody2D] that adds useful collision signals.

## Fired when a collision occurs. Can be fired back-to-back for equal
## collisions.
signal collided(collision: KinematicCollision2D)

## Fired when a collision occurs. Does not fire on back-to-back equal
## collisions.
signal just_collided(collision: KinematicCollision2D)

## Array of all bodies this body has collided within the last [method
## move_and_slide] call.
var last_collided: Array[Node2D] = []


## Only source obj_deactivation descendants participate in the room strip.
func uses_source_deactivation() -> bool:
	return false


func uses_source_death_stop() -> bool:
	return false


func source_death_stopped() -> bool:
	return uses_source_death_stop() and WorldDeath.active_for(self)


func apply_source_death() -> void:
	if uses_source_death_stop():
		velocity = Vector2.ZERO
		for gravity in find_children("*", "Node", true, false):
			if gravity is GravityComponent:
				gravity.gravity = Vector2.ZERO
		WorldDeath.pause_sprites(self)


## Source automatic motion runs after all Step events, including the death
## object's final zeroing pass. Keep native AI/alarms running without that move.
func move_source_and_slide() -> void:
	if source_death_stopped():
		velocity = Vector2.ZERO
	else:
		move_and_slide()


func _enter_tree() -> void:
	# Covers ordinary Parts, deferred replacements and the existing block
	# sprout factory, including objects reparented into a player's hands.
	var activity_parent := get_parent()
	while activity_parent != null:
		if activity_parent is SubArea and activity_parent.actor_activity != null:
			activity_parent.actor_activity.register(self)
			return
		activity_parent = activity_parent.get_parent()


func _physics_process(_delta: float) -> void:
	var collisions = {}
	# Turn blocks and other solids can disappear while they are in this list.
	last_collided = last_collided.filter(func(body): return is_instance_valid(body))

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		collisions[collision.get_collider()] = collision

	for collider in Utility.array_merge(
				last_collided.duplicate(), collisions.keys()):
		# already collided
		if collider in last_collided:
			if collider in collisions:
				collided.emit(collisions[collider])
				if collider is StaticBodyExt:
					collider.collided.emit(collisions[collider])
			else:
				last_collided.erase(collider)
		# just collided
		elif collider in collisions:
			last_collided.append(collider)
			just_collided.emit(collisions[collider])
			collided.emit(collisions[collider])
			if collider is StaticBodyExt:
				collider.just_collided.emit(collisions[collider])
				collider.collided.emit(collisions[collider])
