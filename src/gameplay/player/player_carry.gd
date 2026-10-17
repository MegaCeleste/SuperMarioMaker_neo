class_name PlayerCarry
extends RefCounted
## REQ-PWR-006~008. Area events maintain candidates; no overlap polling.

signal carrying_changed(carried: Node2D)

var profile: PlayerPhysicsProfile
var _owner: Node2D
var _candidates: Array[Node2D] = []
var _held: Node2D
var _contract: ICarryable
var _saved_mode: Node.ProcessMode
var _saved_collisions: Array[Dictionary] = []


func _init(owner: Node2D, physics: PlayerPhysicsProfile) -> void:
	_owner = owner
	profile = physics


func add_candidate(body: Node2D) -> void:
	if body.get_node_or_null("Carryable") is ICarryable and not _candidates.has(body):
		_candidates.append(body)


func remove_candidate(body: Node2D) -> void:
	_candidates.erase(body)


func tick(input: PlayerInputFrame, enabled: bool, facing: float, large: bool, allow_up_throw: bool) -> void:
	if not enabled:
		drop(Vector2.ZERO)
		return
	if is_carrying():
		if input.run_released or not input.run:
			var launch: Vector2 = Vector2(facing * profile.throw_speed, profile.throw_lift)
			if input.up and allow_up_throw:
				launch = Vector2(0.0, profile.throw_up_speed)
			_release(launch, true)
		else:
			follow(facing, large)
		return
	if not input.run:
		return
	for body: Node2D in _candidates.duplicate():
		if not is_instance_valid(body):
			_candidates.erase(body)
			continue
		var contract: ICarryable = body.get_node_or_null("Carryable") as ICarryable
		if contract != null and contract.can_pick_up():
			_pick_up(body, contract)
			follow(facing, large)
			break


func _pick_up(body: Node2D, contract: ICarryable) -> void:
	_held = body
	_contract = contract
	_saved_mode = body.process_mode
	_saved_collisions.clear()
	_suspend_collisions(body)
	body.process_mode = Node.PROCESS_MODE_DISABLED
	contract.pick_up(_owner)
	carrying_changed.emit(_held)


func _suspend_collisions(node: Node) -> void:
	if node is CollisionObject2D:
		var object: CollisionObject2D = node as CollisionObject2D
		_saved_collisions.append({"node": object, "layer": object.collision_layer, "mask": object.collision_mask})
		object.collision_layer = 0
		object.collision_mask = 0
	for child: Node in node.get_children():
		_suspend_collisions(child)


func follow(facing: float, large: bool) -> void:
	if not is_carrying():
		return
	var offset: Vector2 = profile.hold_offset_super if large else profile.hold_offset_small
	offset.x *= facing
	_held.global_position = _owner.global_position + offset


func drop(inherited_velocity: Vector2) -> void:
	if is_carrying():
		_release(inherited_velocity, false)


func _release(launch: Vector2, thrown: bool) -> void:
	if not is_carrying():
		return
	var freeze_gate: GameplayFreezeGate = null
	for child: Node in _held.get_children():
		if child is GameplayFreezeGate:
			freeze_gate = child as GameplayFreezeGate
			break
	if freeze_gate != null:
		freeze_gate.restore_process_mode(_saved_mode)
	else:
		_held.process_mode = _saved_mode
	for entry: Dictionary in _saved_collisions:
		var object: CollisionObject2D = entry["node"] as CollisionObject2D
		if is_instance_valid(object):
			object.collision_layer = int(entry["layer"])
			object.collision_mask = int(entry["mask"])
	if _held is CharacterBody2D:
		(_held as CharacterBody2D).velocity = launch
	elif _held is RigidBody2D:
		(_held as RigidBody2D).linear_velocity = launch
	if is_instance_valid(_contract):
		if thrown:
			_contract.throw(launch)
		else:
			_contract.drop()
	_held = null
	_contract = null
	_saved_collisions.clear()
	carrying_changed.emit(null)


func is_carrying() -> bool:
	return is_instance_valid(_held)


func clear() -> void:
	drop(Vector2.ZERO)
	_candidates.clear()
