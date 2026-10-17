class_name EntityHit
extends RefCounted
## Explicit attack context; callbacks enqueue contacts, actors resolve in physics.
enum Kind { STOMP, SPIN, FIREBALL, SHELL, THROWN, BUMP, STAR, EXPLOSION }
var kind: Kind
var source: Node2D
var player: Player
var direction: float

func _init(type: Kind, attacker: Node2D = null, owner_player: Player = null, facing: float = 1.0) -> void:
	kind = type
	source = attacker
	player = owner_player
	direction = facing
