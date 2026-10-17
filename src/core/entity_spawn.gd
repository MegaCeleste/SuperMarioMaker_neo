class_name EntitySpawn
extends RefCounted

static func enemy(path: String, parent: Node, feet: Vector2, properties: Dictionary = {}) -> Enemy:
	var actor: Enemy = (load(path) as PackedScene).instantiate() as Enemy
	for key: String in properties:
		actor.set(key, properties[key])
	actor.position = feet - Vector2(0.0, 8.0)
	parent.add_child(actor)
	actor.global_position += feet - actor.feet_position()
	return actor

static func fits(actor: Enemy, height: float) -> bool:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(11.8, height - 0.2)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, actor.feet_position() - Vector2(0.0, height / 2.0))
	query.collision_mask = CollisionConfig.layer("solids")
	query.exclude = [actor.get_rid()]
	return actor.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

static func swept_enemies(actor: Enemy, previous: Vector2) -> Array[Enemy]:
	var shape: CapsuleShape2D = CapsuleShape2D.new()
	shape.radius = 6.0
	shape.height = previous.distance_to(actor.global_position) + 12.0
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D((actor.global_position - previous).angle() + PI / 2.0, (previous + actor.global_position) / 2.0)
	query.collision_mask = CollisionConfig.mask(["enemies", "projectiles"])
	query.exclude = [actor.get_rid()]
	var result: Array[Enemy] = []
	for record: Dictionary in actor.get_world_2d().direct_space_state.intersect_shape(query, 64):
		var target: Enemy = record["collider"] as Enemy
		if target != null and not target.is_dead and not target.is_queued_for_deletion():
			result.append(target)
	return result
