class_name QuestionBlock
extends InteractableBlock
## REQ-PHYS-122, REQ-PWR-014/016.

@export var contained_item: String = "smm.item.coin"
@onready var container: ContainerComponent = $Container
var _released_item: Node2D
var _hit_player: Player


func _ready() -> void:
	super._ready()
	container.pop_height = float(_config["item_rise"])
	container.pop_duration = float(_config["item_rise_seconds"])
	container.item_released.connect(_on_item_released)


func _trigger_effect(player: Player) -> void:
	if container.is_used():
		return
	var item: Node2D = Registry.instantiate_object(contained_item)
	if item == null:
		return
	if not item.get_node_or_null("BlockContent") is BlockContent:
		item.free()
		push_error("Unsupported question block content: " + contained_item)
		return
	_released_item = item
	_hit_player = player
	_state = State.EMPTY
	sprite.animation = &"empty"
	_frame_phase = 0.0
	container.contained_item = contained_item
	container.release_item()


func _on_item_released(_object_id: String, target: Vector2) -> void:
	var item: Node2D = _released_item
	get_parent().add_child(item)
	item.global_position = global_position
	var content: BlockContent = item.get_node_or_null("BlockContent") as BlockContent
	if content == null:
		push_error("Question-block content lacks release contract")
		item.queue_free()
	else:
		content.release_from_block(_hit_player, global_position, target, roundi(container.pop_duration * float(Engine.physics_ticks_per_second)))
	_released_item = null
	_hit_player = null
