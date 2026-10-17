class_name InteractableBlock
extends StaticBody2D
## REQ-PHYS-105/122/123. Bump the visual while grid collision stays stable.

signal hit(player: Player)
enum State { ACTIVE, EMPTY, TURNING, BROKEN }

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var bumpable: BumpableComponent = $Bumpable
@onready var top_sensor: Area2D = $TopSensor
@onready var bump: AudioStreamPlayer = $Bump

var current_state: State:
	get: return _state
	set(_value): push_error("Block state is owned by interaction methods.")
var _state: State = State.ACTIVE
var _config: Dictionary = {}
var _top_contacts: Array[Node2D] = []
var _frame_phase: float = 0.0


func _ready() -> void:
	_config = PrototypeEntityConfig.section("block")
	collision_layer = CollisionConfig.layer("solids")
	collision_mask = CollisionConfig.mask(["player", "enemies", "pickups", "projectiles"])
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	var dimensions: Array = _config["size"] as Array
	rectangle.size = Vector2(float(dimensions[0]), float(dimensions[1]))
	body_shape.shape = rectangle
	var sensor_shape: RectangleShape2D = RectangleShape2D.new()
	var sensor_size: Array = _config["top_sensor_size"] as Array
	sensor_shape.size = Vector2(float(sensor_size[0]), float(sensor_size[1]))
	(top_sensor.get_node("CollisionShape2D") as CollisionShape2D).shape = sensor_shape
	top_sensor.position.y = -(rectangle.size.y + sensor_shape.size.y) / 2.0
	top_sensor.collision_layer = CollisionConfig.layer("sensors")
	top_sensor.collision_mask = CollisionConfig.mask(["enemies", "pickups"])
	top_sensor.body_entered.connect(_on_top_entered)
	top_sensor.body_exited.connect(_on_top_exited)
	bumpable.visual_target = sprite
	bumpable.configure(float(_config["bounce_height"]), float(_config["bounce_seconds"]))
	bump.stream = SoundEffectStream.copy(bump.stream)
	sprite.pause()
	sprite.animation = &"idle"
	add_child(GameplayFreezeGate.new())


func _physics_process(delta: float) -> void:
	_frame_phase += sprite.sprite_frames.get_animation_speed(sprite.animation) * delta
	var count: int = sprite.sprite_frames.get_frame_count(sprite.animation)
	if count > 0:
		sprite.frame = floori(_frame_phase) % count


func hit_by_player(player: Player) -> void:
	if current_state == State.EMPTY:
		_play_bump()
		return
	if current_state != State.ACTIVE or bumpable.is_running():
		return
	hit.emit(player)
	_trigger_effect(player)
	bumpable.bump(player)
	_play_bump()
	for actor: Node2D in _top_contacts.duplicate():
		if not is_instance_valid(actor):
			_top_contacts.erase(actor)
		elif actor is Enemy:
			(actor as Enemy).receive_hit(EntityHit.new(EntityHit.Kind.BUMP, self, player, player.motion.facing if is_instance_valid(player) else 1.0))
		elif actor is PowerUpPickup:
			(actor as PowerUpPickup).bumped()


func hit_by_attack(request: EntityHit) -> void:
	if current_state == State.BROKEN or (current_state == State.TURNING and request.kind != EntityHit.Kind.EXPLOSION):
		return
	if request.kind == EntityHit.Kind.EXPLOSION and not self is QuestionBlock:
		_state = State.BROKEN
		body_shape.disabled = true
		collision_layer = 0
		queue_free()
		return
	hit_by_player(request.player)


func _play_bump() -> void:
	if bump.stream != null:
		bump.play()


func _on_top_entered(body: Node2D) -> void:
	if not _top_contacts.has(body):
		_top_contacts.append(body)


func _on_top_exited(body: Node2D) -> void:
	_top_contacts.erase(body)


func _trigger_effect(_player: Player) -> void:
	pass


func hit_from_above(_player: Player) -> bool:
	return false
