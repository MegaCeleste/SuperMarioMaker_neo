class_name CarryableProbe
extends CharacterBody2D
## Debug-only ICarryable implementation for REQ-PWR-006~008.

const COLOR: Color = Color(0.4, 0.85, 0.95)
var _profile: PlayerPhysicsProfile


func _init(profile: PlayerPhysicsProfile) -> void:
	_profile = profile


func _ready() -> void:
	collision_layer = CollisionConfig.layer("pickups")
	collision_mask = CollisionConfig.mask(["solids", "semisolids"])
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2.ONE * _profile.hitbox_width
	shape.shape = rectangle
	add_child(shape)
	var contract: ICarryable = ICarryable.new()
	contract.name = "Carryable"
	add_child(contract)
	add_child(GameplayFreezeGate.new())


func _physics_process(delta: float) -> void:
	velocity.y += _profile.gravity_fall * delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, _profile.friction_normal * delta)
	move_and_slide()


func _draw() -> void:
	var dimensions: Vector2 = Vector2.ONE * _profile.hitbox_width
	draw_rect(Rect2(-dimensions / 2.0, dimensions), COLOR)
