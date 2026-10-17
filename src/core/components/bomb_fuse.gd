class_name BombFuse
extends Node
## Explicit PAUSABLE mode keeps the fuse alive when carrying disables the body.
signal expired
signal ticked(remaining: int)
var remaining: int = 0

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func ignite(frames: int) -> void:
	if remaining == 0:
		remaining = frames

func _physics_process(_delta: float) -> void:
	if remaining <= 0 or GameManager.is_gameplay_frozen:
		return
	remaining -= 1
	ticked.emit(remaining)
	if remaining == 0:
		expired.emit()
