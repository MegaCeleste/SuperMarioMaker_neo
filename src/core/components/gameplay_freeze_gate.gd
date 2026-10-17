class_name GameplayFreezeGate
extends Node
## REQ-PWR-010. Opt-in actor gate; audio/HUD/autoloads remain independent.

var _actor: Node
var _previous_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
var _frozen: bool = false


func _ready() -> void:
	_actor = get_parent()
	_keep_collisions_active(_actor)
	GameManager.gameplay_freeze_started.connect(_on_freeze)
	GameManager.gameplay_freeze_ended.connect(_on_resume)
	if GameManager.is_gameplay_frozen:
		_on_freeze()


func _keep_collisions_active(node: Node) -> void:
	if node is CollisionObject2D:
		(node as CollisionObject2D).disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	for child: Node in node.get_children():
		_keep_collisions_active(child)


func _on_freeze() -> void:
	if _frozen:
		return
	_previous_mode = _actor.process_mode
	_actor.process_mode = Node.PROCESS_MODE_DISABLED
	_frozen = true


func _on_resume() -> void:
	if not _frozen:
		return
	_actor.process_mode = _previous_mode
	_frozen = false


func restore_process_mode(mode: Node.ProcessMode) -> void:
	if _frozen:
		_previous_mode = mode
	else:
		_actor.process_mode = mode
