class_name EntityExplosion
extends Node2D
## One lifetime, one hit per target. Geometry is explicit, independent of art.
var attacker: Player
var held_player: Player
var remaining: int = 0
var _hit: Dictionary = {}
var _config: Dictionary
var _sprite: AnimatedSprite2D
var _age: int = 0

func _ready() -> void:
	_config = PrototypeEntityConfig.section("explosion")
	remaining = int(_config["frames"])
	_sprite = AnimatedSprite2D.new()
	add_child(_sprite)
	BasicSpriteLibrary.apply(_sprite, "explosion")
	_sprite.scale = Vector2.ONE * 0.5
	_sprite.animation = &"idle"
	_sprite.pause()
	add_child(GameplayFreezeGate.new())

func _physics_process(_delta: float) -> void:
	# Carry offsets belong to the existing player profile and can exceed this radius.
	# A bomb exploding in the player's hands always applies ordinary explosion damage.
	_hit_target(held_player)
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = float(_config["radius"])
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = CollisionConfig.mask(["enemies", "projectiles", "player", "solids", "sensors"])
	query.collide_with_areas = true
	for record: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 128):
		var target: Node = record["collider"] as Node
		if target is Area2D and (target.get_parent() is Enemy or target.get_parent() is Player or target.get_parent() is InteractableBlock):
			target = target.get_parent()
		_hit_target(target)
	_age += 1
	var count: int = _sprite.sprite_frames.get_frame_count(&"idle")
	_sprite.frame = mini(count - 1, floori(float(_age) * float(count) / float(_config["frames"])))
	remaining -= 1
	if remaining <= 0:
		queue_free()

func _hit_target(target: Node) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or _hit.has(target.get_instance_id()):
		return
	_hit[target.get_instance_id()] = true
	var request: EntityHit = EntityHit.new(EntityHit.Kind.EXPLOSION, self, attacker)
	if target is Enemy:
		(target as Enemy).receive_hit(request)
	elif target is Player:
		(target as Player).take_damage()
	elif target is InteractableBlock:
		(target as InteractableBlock).hit_by_attack(request)
