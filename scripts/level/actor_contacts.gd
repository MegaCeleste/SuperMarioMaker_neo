# SPDX-License-Identifier: AGPL-3.0-or-later
class_name ActorContacts
extends Node
## One fixed-tick snapshot keeps neighbour turns independent of body order.
## Contacts use source bboxes, rather than making every actor a rigid solid.

## Spatial-bucket width and height in world pixels; this is not a collision margin.
const CELL := 32.0
## Owning playable area, assigned before this controller enters the scene tree.
var sub_area: SubArea
var _buckets: Dictionary = {}
var _bounds: Dictionary = {}


## Finds the contact controller in the actor's containing area; returns null outside one.
static func for_actor(body: Node) -> ActorContacts:
	var ancestor := body.get_parent()
	while ancestor != null:
		if ancestor is SubArea:
			return ancestor.actor_contacts
		ancestor = ancestor.get_parent()
	return null


func _ready() -> void:
	process_physics_priority = -40


## Drops all cached bounds and neighbours before a new tick or area lifecycle change.
func reset() -> void:
	_buckets.clear()
	_bounds.clear()


func _physics_process(_delta: float) -> void:
	reset()
	if sub_area.level.status != Level.Status.PLAYING or sub_area.level.is_player_dying():
		return
	for body in sub_area.get_foreground().find_children("*", "CharacterBody2D", true, false):
		if not body is CharacterBodyExt or body is Player or not _active(body):
			continue
		var bounds := Utility.get_bounding_box(body)
		if not bounds.has_area():
			continue
		_bounds[body.get_instance_id()] = bounds
		for cell in _cells(bounds):
			if not _buckets.has(cell):
				_buckets[cell] = []
			_buckets[cell].append(body)


func _active(body: Node2D) -> bool:
	return (
		is_instance_valid(body)
		and not body.is_queued_for_deletion()
		and body.is_visible_in_tree()
		and body.can_process()
	)


func _cells(bounds: Rect2) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(floori(bounds.position.y / CELL), floori((bounds.end.y - 0.001) / CELL) + 1):
		for x in range(floori(bounds.position.x / CELL), floori((bounds.end.x - 0.001) / CELL) + 1):
			cells.append(Vector2i(x, y))
	return cells


## Returns other active actors intersecting world-space bounds in stable instance order.
func overlaps(body: Node2D, bounds: Rect2) -> Array[CharacterBodyExt]:
	var result: Array[CharacterBodyExt] = []
	var seen := {}
	for cell in _cells(bounds):
		for other: CharacterBodyExt in _buckets.get(cell, []):
			if not _active(other) or other == body or seen.has(other.get_instance_id()):
				continue
			seen[other.get_instance_id()] = true
			if bounds.intersects(_bounds[other.get_instance_id()]):
				result.append(other)
	result.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	return result


func _held_obstacle(other: Node2D) -> bool:
	if other is Spring:
		return other.pickup.get_holder() == null and not other.active
	if other is KoopaShell:
		return other.motion == KoopaShell.Motion.STATIONARY and other._grace <= 0
	if other is StompedGaloomba:
		var pickup: PickupComponent = other.get_node("PickupComponent")
		return pickup.get_holder() == null and pickup.pickup_immunity_left <= 0
	return false


func _away(body: Node2D, other: Node2D) -> int:
	var center: float = (
		_bounds.get(body.get_instance_id(), Utility.get_bounding_box(body)).get_center().x
	)
	var target: float = _bounds[other.get_instance_id()].get_center().x
	return (
		1
		if (
			center > target
			or (center == target and body.get_instance_id() > other.get_instance_id())
		)
		else -1
	)


## obj_enemyparent/Other_12: ordinary overlap first, then held-parent overlap.
func turn_enemy(enemy: Enemy) -> bool:
	if enemy.velocity.x == 0 or enemy.source_death_stopped():
		return false
	var eligible: bool = (
		enemy is Galoomba
		or enemy is Koopa
		or enemy is BuzzyBeetle
		or enemy is Spiny
		or enemy is Monty
		or (enemy is BeachKoopa and enemy.is_walking())
	)
	if not eligible:
		return false
	var flight := enemy.get_node_or_null("FlightComponent") as EnemyFlightComponent
	if (enemy is Spiny or enemy is BuzzyBeetle) and flight != null and flight.wings:
		return false
	var bounds: Rect2 = _bounds.get(enemy.get_instance_id(), Utility.get_bounding_box(enemy))
	bounds.size.y = maxf(0.1, bounds.size.y - 4)
	var normal: CharacterBodyExt
	var held: CharacterBodyExt
	for other in overlaps(enemy, bounds):
		if _held_obstacle(other):
			if held == null:
				held = other
		elif (
			other is Enemy
			and not other is KoopaShell
			and not (other is BeachKoopa and not other.is_walking())
		):
			if normal == null:
				normal = other
	var target := held if held != null else normal
	if target == null:
		return false
	var direction := _away(enemy, target)
	var changed := enemy.velocity.x * direction < 0
	enemy.velocity.x = absf(enemy.velocity.x) * direction
	var slide := enemy.get_node_or_null("SlideComponent") as SlideComponent
	if slide != null and not enemy is Monty:
		slide.direction = direction
		if changed:
			slide.turned.emit(Vector2(direction, 0))
	# Monty's Step restores its facing toward Mario after inherited motion.
	if enemy is BeachKoopa:
		enemy.direction = direction
	return changed


## Powerup/physics-parent side contacts include resting held-family objects.
## Ordinary enemies and other powerups are intentionally not solid barriers.
func turn_item(item: CharacterBodyExt, delta: float) -> void:
	if item.velocity.x == 0 or item.source_death_stopped():
		return
	var bounds := Utility.get_bounding_box(item)
	var reach := 1 + absf(item.velocity.x) * delta
	var side := Rect2(
		Vector2(bounds.end.x, bounds.position.y + 1), Vector2(reach, maxf(0.1, bounds.size.y - 5))
	)
	if item.velocity.x < 0:
		side.position.x = bounds.position.x - reach
	for other in overlaps(item, side):
		if not _held_obstacle(other):
			continue
		var direction := _away(item, other)
		if item is FireFlower:
			item.velocity.x = 0
		else:
			item.velocity.x = absf(item.velocity.x) * direction
		if item is OneUp or item is SuperStar:
			item._direction = direction
		var slide := item.get_node_or_null("SlideComponent") as SlideComponent
		if slide != null:
			slide.direction = direction
		return


## obj_enemyparent_held contacts: rising/thrown bodies and held shields.
func hit_from_galoomba(item: StompedGaloomba) -> void:
	if item.source_death_stopped() or item.is_queued_for_deletion():
		return
	var pickup: PickupComponent = item.get_node("PickupComponent")
	var holder := pickup.get_holder()
	var bounds := Utility.get_bounding_box(item)
	for other in overlaps(item, bounds):
		if other is KoopaShell:
			# The shell's existing sensor owns this pair, including its combo.
			continue
		if other is StompedGaloomba:
			var other_holder: Player = other.get_node("PickupComponent").get_holder()
			if holder != null or other_holder != null or item.velocity.x != 0:
				other.kill(signf(item.velocity.x))
				if holder != null or other_holder != null:
					item.kill()
				EnemyEffect.sound_once(sub_area, "uid://c345xnns7om3m")
			return
		if (
			not other is Enemy
			or other.hardness >= 99
			or (other is BeachKoopa and not other.is_walking())
		):
			continue
		var can_hit: bool = (
			(item.velocity.y < 0 or (item.velocity.x != 0 and item.velocity.y <= 0))
			if holder == null
			else bounds.end.y > _bounds[other.get_instance_id()].position.y + 4
		)
		if (
			can_hit
			and other.hit_by_actor(
				&"held_item", item, holder.direction if holder != null else signf(item.velocity.x)
			)
		):
			EnemyEffect.sound_once(sub_area, "uid://c345xnns7om3m")
			if holder != null:
				item.kill(-holder.direction)
				return
