class_name Coin
extends Area2D
## REQ-PWR-016. Block rewards are counted once, before their popup presentation.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var _config: Dictionary = {}
@export_enum("1:1", "10:10", "30:30", "50:50") var value: int = 1
var interaction: PickupInteraction
var _collected: bool = false
var _popup_left: int = 0
var _popup_start: Vector2
var _popup_velocity: float = 0.0
var _frame_phase: float = 0.0


func _ready() -> void:
	_config = PrototypeEntityConfig.section("coin" if value == 1 else "big_coin")
	collision_layer = CollisionConfig.layer("sensors")
	collision_mask = CollisionConfig.layer("player")
	var shape: RectangleShape2D = RectangleShape2D.new()
	var dimensions: Array = _config["sensor_size"] as Array
	shape.size = Vector2(float(dimensions[0]), float(dimensions[1]))
	($CollisionShape2D as CollisionShape2D).shape = shape
	BasicSpriteLibrary.apply(sprite, "coin" if value == 1 else "coin_%d" % value)
	interaction = PickupInteraction.new()
	add_child(interaction)
	interaction.configure(self, _request_pickup)
	if value == 1:
		var content: BlockContent = get_node("BlockContent") as BlockContent
		content.configure(_release_from_block)
	add_child(GameplayFreezeGate.new())


func _on_contact(body: Node2D) -> void:
	interaction._entered(body)


func _on_contact_exit(body: Node2D) -> void:
	interaction._exited(body)


func _request_pickup(player: Player) -> bool:
	return player.collect_reward(value)


func _release_from_block(player: Player, _start: Vector2, target: Vector2, _frames: int) -> void:
	pop_from_block(player, target)


func pop_from_block(player: Player, start: Vector2) -> void:
	if _collected or (is_instance_valid(player) and not _request_pickup(player)):
		queue_free()
		return
	if not is_instance_valid(player):
		GameManager.add_coins(value)
	_collected = true
	interaction.collected = true
	monitoring = false
	_popup_start = start
	global_position = start
	_popup_left = int(_config["popup_frames"])
	_popup_velocity = float(_config["popup_initial"])


func _physics_process(delta: float) -> void:
	_frame_phase += sprite.sprite_frames.get_animation_speed(&"idle") * delta
	sprite.animation = &"idle"
	sprite.pause()
	var count: int = sprite.sprite_frames.get_frame_count(&"idle")
	if count > 0:
		sprite.frame = floori(_frame_phase) % count
	if _popup_left > 0:
		_popup_left -= 1
		global_position.y += _popup_velocity * delta
		_popup_velocity += float(_config["popup_gravity"]) * delta
		if _popup_left == 0 or (_popup_velocity > 0.0 and global_position.y > _popup_start.y + float(_config["popup_end_offset"])):
			queue_free()
		return
	if _collected:
		return
	if interaction.try_collect():
		_collected = true
		monitoring = false
		queue_free()
