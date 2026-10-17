class_name PowerUpManager
extends RefCounted
## REQ-PWR-001~005/009~011/013. Form and presentation phase have one owner.

signal powerup_changed(previous: Form, current: Form)
signal phase_changed(previous: Phase, current: Phase)
signal transition_started(previous: Form, current: Form, frames: int, damage: bool)
signal transition_finished
signal transition_cancelled(reason: StringName)

enum Form { SMALL, SUPER, FIRE, DEAD }
enum Phase { ACTIVE, TRANSFORMING, DEAD }
enum Event { MUSHROOM, FIRE_FLOWER, DAMAGE, KILL }

const TRANSITIONS: Dictionary = {
	Form.SMALL: {Event.MUSHROOM: Form.SUPER, Event.FIRE_FLOWER: Form.FIRE, Event.DAMAGE: Form.DEAD},
	Form.SUPER: {Event.FIRE_FLOWER: Form.FIRE, Event.DAMAGE: Form.SMALL},
	Form.FIRE: {Event.DAMAGE: Form.SUPER},
}

var profile: PlayerPhysicsProfile
var form: Form:
	get: return _form
	set(_value): push_error("Power-up form is read only; use request() or reset().")
var phase: Phase:
	get: return _phase
	set(_value): push_error("Power-up phase is read only; use request(), advance_transition(), or reset().")
var transition_from: Form:
	get: return _transition_from
	set(_value): push_error("The power-up manager owns the source form of a transition.")
var transition_left: int:
	get: return _transition_left
	set(_value): push_error("The power-up manager owns transition timing.")
var invulnerability_left: int:
	get: return _invulnerability_left
	set(_value): push_error("The power-up manager owns invulnerability timing.")

var _form: Form = Form.SMALL
var _phase: Phase = Phase.ACTIVE
var _transition_from: Form = Form.SMALL
var _transition_left: int = 0
var _invulnerability_left: int = 0
var _damage_transition: bool = false


func _init(physics: PlayerPhysicsProfile) -> void:
	profile = physics


func request(event: Event) -> bool:
	if _phase == Phase.DEAD:
		return false
	if event == Event.KILL:
		_enter_dead()
		return true
	if _phase != Phase.ACTIVE or (event == Event.DAMAGE and _invulnerability_left > 0):
		return false
	var allowed: Dictionary = TRANSITIONS.get(_form, {}) as Dictionary
	if not allowed.has(event):
		return false
	var target: Form = allowed[event]
	if target == Form.DEAD:
		_enter_dead()
	else:
		_start_transition(target, event == Event.DAMAGE)
	return true


func collect_mushroom() -> bool:
	return request(Event.MUSHROOM)


func collect_fire_flower() -> bool:
	return request(Event.FIRE_FLOWER)


func take_damage() -> bool:
	return request(Event.DAMAGE)


func kill() -> void:
	request(Event.KILL)


func _start_transition(target: Form, damage: bool) -> void:
	var previous: Form = _form
	var previous_phase: Phase = _phase
	_transition_from = previous
	_form = target
	_damage_transition = damage
	_transition_left = profile.damage_freeze_frames if damage else profile.powerup_freeze_frames
	_phase = Phase.TRANSFORMING if _transition_left > 0 else Phase.ACTIVE
	powerup_changed.emit(previous, _form)
	if previous_phase != _phase:
		phase_changed.emit(previous_phase, _phase)
	transition_started.emit(previous, _form, _transition_left, damage)
	if _transition_left == 0:
		_finish_transition()


func advance_transition() -> void:
	if _phase != Phase.TRANSFORMING:
		return
	_transition_left = maxi(0, _transition_left - 1)
	if _transition_left == 0:
		_finish_transition()


func _finish_transition() -> void:
	if _damage_transition:
		_invulnerability_left = profile.invulnerability_frames
	_damage_transition = false
	var previous_phase: Phase = _phase
	_phase = Phase.ACTIVE
	if previous_phase != _phase:
		phase_changed.emit(previous_phase, _phase)
	transition_finished.emit()


func finish_active_tick() -> void:
	if _phase == Phase.ACTIVE:
		_invulnerability_left = maxi(0, _invulnerability_left - 1)


func is_transforming() -> bool:
	return _phase == Phase.TRANSFORMING


func is_invulnerable() -> bool:
	return _phase != Phase.ACTIVE or _invulnerability_left > 0


func is_large() -> bool:
	return _form == Form.SUPER or _form == Form.FIRE


func _enter_dead() -> void:
	var previous: Form = _form
	var previous_phase: Phase = _phase
	_form = Form.DEAD
	_phase = Phase.DEAD
	_transition_from = previous
	_transition_left = 0
	_invulnerability_left = 0
	_damage_transition = false
	powerup_changed.emit(previous, _form)
	phase_changed.emit(previous_phase, _phase)
	if previous_phase == Phase.TRANSFORMING:
		transition_cancelled.emit(&"death")


func reset(target: Form = Form.SMALL) -> bool:
	if target not in [Form.SMALL, Form.SUPER, Form.FIRE]:
		push_error("Respawn requires a living power-up form.")
		return false
	var previous: Form = _form
	var previous_phase: Phase = _phase
	_form = target
	_phase = Phase.ACTIVE
	_transition_from = target
	_transition_left = 0
	_invulnerability_left = 0
	_damage_transition = false
	if previous != target:
		powerup_changed.emit(previous, target)
	if previous_phase != _phase:
		phase_changed.emit(previous_phase, _phase)
	if previous_phase == Phase.TRANSFORMING:
		transition_cancelled.emit(&"reset")
	return true
