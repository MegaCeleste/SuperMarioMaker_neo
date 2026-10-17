class_name PlayerMovementStateMachine
extends RefCounted
## REQ-PHYS-109/115/117. State ownership only; motion supplies solved facts.

signal state_exited(state: State, next: State)
signal state_entered(state: State, previous: State)
signal state_changed(previous: State, current: State)

enum State { IDLE, RUN, AIR, CROUCH, SKID, DEAD }

var current: State:
	get: return _current
	set(_value): push_error("Movement state is read only; use resolve(), take_off(), die(), or reset().")

var _current: State = State.AIR


func resolve(grounded: bool, crouched: bool, skidding: bool, velocity: Vector2, speed_epsilon: float) -> void:
	if _current == State.DEAD:
		return
	var target: State = State.IDLE
	if not grounded or velocity.y < 0.0:
		target = State.AIR
	elif crouched:
		target = State.CROUCH
	elif skidding:
		target = State.SKID
	elif absf(velocity.x) > speed_epsilon:
		target = State.RUN
	_transition(target)


func take_off() -> void:
	_transition(State.AIR)


func die() -> void:
	_transition(State.DEAD)


func reset() -> void:
	_transition(State.AIR, true)


func _transition(target: State, respawning: bool = false) -> void:
	if target == _current or (_current == State.DEAD and not respawning):
		return
	var previous: State = _current
	_current = target
	state_exited.emit(previous, target)
	state_entered.emit(target, previous)
	state_changed.emit(previous, target)
