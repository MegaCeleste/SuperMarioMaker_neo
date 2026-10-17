class_name BlockContent
extends Node
## Composed release contract: rewards and emerging bodies keep their own motion.
var _handler: Callable

func configure(handler: Callable) -> void:
	_handler = handler

func release_from_block(player: Player, start: Vector2, target: Vector2, frames: int) -> void:
	_handler.call(player, start, target, frames)
