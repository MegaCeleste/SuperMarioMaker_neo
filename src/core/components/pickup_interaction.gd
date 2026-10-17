class_name PickupInteraction
extends Node
## Shared contact bookkeeping; collection commits only after the handler accepts.
var collected: bool = false
var contacts: Array[Player] = []
var _handler: Callable

func configure(area: Area2D, handler: Callable) -> void:
	_handler = handler
	area.body_entered.connect(_entered)
	area.body_exited.connect(_exited)

func _entered(body: Node2D) -> void:
	if body is Player and not contacts.has(body):
		contacts.append(body as Player)

func _exited(body: Node2D) -> void:
	if body is Player:
		contacts.erase(body as Player)

func try_collect() -> bool:
	if collected:
		return false
	for player: Player in contacts.duplicate():
		if not is_instance_valid(player):
			contacts.erase(player)
		elif bool(_handler.call(player)):
			collected = true
			contacts.clear()
			return true
	return false
