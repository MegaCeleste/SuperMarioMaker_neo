class_name PlayerFireball
extends CharacterBody2D
## REQ-PWR-012/014. Profile motion with reviewed local sprite geometry.

signal finished(projectile: PlayerFireball)

const COLOR: Color = Color(1.0, 0.55, 0.1)

var _profile: PlayerPhysicsProfile
var _direction: float
var _frames_left: int
var _done: bool = false
var _hit_queue: Array[Enemy] = []
var _sprite: AnimatedSprite2D
var _frame_phase: float = 0.0


func _init(profile: PlayerPhysicsProfile, direction: float) -> void:
	_profile = profile
	_direction = direction
	_frames_left = profile.fireball_lifetime_frames


func _ready() -> void:
	collision_layer = CollisionConfig.layer("projectiles")
	collision_mask = CollisionConfig.mask(["solids", "semisolids"])
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = _profile.fireball_radius
	shape.shape = circle
	add_child(shape)
	var sensor: Area2D = Area2D.new()
	sensor.collision_layer = CollisionConfig.layer("sensors")
	sensor.collision_mask = CollisionConfig.mask(["enemies", "projectiles"])
	var sensor_shape: CollisionShape2D = CollisionShape2D.new()
	sensor_shape.shape = circle.duplicate()
	sensor.add_child(sensor_shape)
	add_child(sensor)
	sensor.body_entered.connect(_on_enemy_entered)
	velocity = Vector2(_direction * _profile.fireball_speed, 0.0)
	_sprite = AnimatedSprite2D.new()
	add_child(_sprite)
	BasicSpriteLibrary.apply(_sprite, "fireball")
	_sprite.animation = &"idle"
	_sprite.pause()
	_sprite.flip_h = _direction < 0.0
	add_child(GameplayFreezeGate.new())


func _physics_process(delta: float) -> void:
	_frame_phase += _sprite.sprite_frames.get_animation_speed(&"idle") * delta
	var count: int = _sprite.sprite_frames.get_frame_count(&"idle")
	if count > 0:
		_sprite.frame = floori(_frame_phase) % count
	for enemy: Enemy in _hit_queue:
		if is_instance_valid(enemy) and not enemy.is_dead:
			var response: EntityHitResult = enemy.receive_hit(EntityHit.new(EntityHit.Kind.FIREBALL, self, null, _direction))
			if response.consume_attack:
				_finish()
				return
	_hit_queue.clear()
	_frames_left -= 1
	if _frames_left <= 0:
		_finish()
		return
	velocity.y += _profile.fireball_gravity * delta
	move_and_slide()
	if is_on_wall() or is_on_ceiling():
		_finish()
	elif is_on_floor():
		velocity.y = _profile.fireball_bounce


func _on_enemy_entered(body: Node2D) -> void:
	if body is Enemy:
		_hit_queue.append(body as Enemy)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit(self)
	queue_free()


func _draw() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		draw_circle(Vector2.ZERO, _profile.fireball_radius, COLOR)
