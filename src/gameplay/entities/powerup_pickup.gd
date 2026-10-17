class_name PowerUpPickup
extends CharacterBody2D
## REQ-PWR-014, REQ-PHYS-123.

@export_enum("Left:-1", "Right:1") var start_direction: int = -1
@onready var pickup_area: Area2D = $PickupArea
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var dir: float = -1.0
var _config: Dictionary = {}
var _collected: bool = false
var interaction: PickupInteraction
var _frame_phase: float = 0.0
var _emergence_left: int = 0
var _emergence_total: int = 0
var _emergence_start: Vector2
var _emergence_target: Vector2
var _profile: PlayerPhysicsProfile = preload("res://data/physics/base_physics.tres")


func _config_section() -> String:
	return "mushroom"


func _visual_group() -> String:
	return ""


func _request_pickup(_player: Player) -> bool:
	return false


func _ready() -> void:
	_config = PrototypeEntityConfig.section(_config_section())
	var dimensions: Dictionary = PrototypeEntityConfig.section("pickup")
	dir = float(start_direction)
	_set_shape(body_shape, dimensions["body_size"] as Array)
	body_shape.position.y = float(dimensions["feet_y"]) - (body_shape.shape as RectangleShape2D).size.y / 2.0
	_set_shape(pickup_area.get_node("CollisionShape2D") as CollisionShape2D, dimensions["sensor_size"] as Array)
	collision_layer = CollisionConfig.layer("pickups")
	collision_mask = CollisionConfig.mask(["solids", "semisolids"])
	pickup_area.collision_layer = CollisionConfig.layer("sensors")
	pickup_area.collision_mask = CollisionConfig.layer("player")
	interaction = PickupInteraction.new()
	add_child(interaction)
	interaction.configure(pickup_area, _request_pickup)
	var content: BlockContent = get_node("BlockContent") as BlockContent
	content.configure(_release_from_block)
	if not _visual_group().is_empty():
		BasicSpriteLibrary.apply(sprite, _visual_group())
	sprite.animation = &"idle"
	sprite.pause()
	add_child(GameplayFreezeGate.new())


func _set_shape(node: CollisionShape2D, dimensions: Array) -> void:
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(float(dimensions[0]), float(dimensions[1]))
	node.shape = rectangle


func _release_from_block(player: Player, start: Vector2, target: Vector2, frames: int) -> void:
	dir = player.motion.facing if is_instance_valid(player) else 1.0
	begin_emergence(start, target, frames)


func begin_emergence(from: Vector2, target: Vector2, frames: int) -> void:
	_emergence_start = from
	_emergence_target = target
	_emergence_total = maxi(1, frames)
	_emergence_left = _emergence_total
	global_position = from
	velocity = Vector2.ZERO
	collision_layer = 0
	body_shape.disabled = true
	pickup_area.monitoring = false
	interaction.contacts.clear()


func _finish_emergence() -> void:
	global_position = _emergence_target
	collision_layer = CollisionConfig.layer("pickups")
	body_shape.disabled = false
	pickup_area.monitoring = true


func _on_contact(body: Node2D) -> void:
	interaction._entered(body)


func _on_contact_exit(body: Node2D) -> void:
	interaction._exited(body)


func _physics_process(delta: float) -> void:
	_frame_phase += sprite.sprite_frames.get_animation_speed(&"idle") * delta
	var count: int = sprite.sprite_frames.get_frame_count(&"idle")
	if count > 0:
		sprite.frame = floori(_frame_phase) % count
	if _emergence_left > 0:
		_emergence_left -= 1
		global_position = _emergence_start.lerp(_emergence_target, 1.0 - float(_emergence_left) / float(_emergence_total))
		if _emergence_left == 0:
			_finish_emergence()
		return
	if interaction.try_collect():
		_collected = true
		pickup_area.set_deferred("monitoring", false)
		collision_layer = 0
		queue_free()
		return
	_move_pickup(delta)
	if global_position.y > float(_config["cleanup_y"]):
		queue_free()


func _move_pickup(delta: float) -> void:
	velocity.y = minf(velocity.y, float(_config.get("max_fall", 240.0))) + float(_config["gravity"]) * delta
	velocity.x = dir * float(_config["speed"])
	move_and_slide()
	if is_on_wall():
		dir *= -1.0


func bumped() -> void:
	if not _collected and _emergence_left == 0:
		velocity.y = float(_config.get("bump_initial", _profile.spin_bounce_initial))
