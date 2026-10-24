# SPDX-License-Identifier: AGPL-3.0-or-later
class_name ActorActivity
extends Node
## Native suspension of the source obj_deactivation descendants. Actors retain
## their state while processing, animation, drawing and collision are disabled.

var rules: ActorActivityRules = preload("res://resources/content/source_actor_activity.tres")
var sub_area: SubArea
var enabled := true
var _clock := 0
var _actors: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	# The source manager updates its activation set in end-step, after motion.
	process_physics_priority = 100
	for actor in sub_area.get_foreground().find_children("*", "CharacterBody2D", true, false):
		if actor is CharacterBodyExt:
			register(actor)


func register(actor: CharacterBodyExt) -> void:
	if actor.uses_source_deactivation() and not _actors.has(actor.get_instance_id()):
		_actors[actor.get_instance_id()] = {"actor": weakref(actor), "asleep": false}


func reset() -> void:
	_actors.clear()
	_clock = 0


func region() -> Rect2:
	var view := Utility.get_visible_rect()
	var height := Level.LEVEL_HEIGHT * Level.GRID_SIZE.y
	return Rect2(Vector2(view.position.x - rules.horizontal_margin, -height - rules.vertical_margin),
			Vector2(view.size.x + 2 * rules.horizontal_margin, height + 2 * rules.vertical_margin))


func _physics_process(_delta: float) -> void:
	if sub_area.level.status not in [Level.Status.PLAYING, Level.Status.COMPLETED]:
		return
	if enabled and _clock > 0:
		_clock -= 1
		return
	_clock = rules.interval_ticks - 1 if enabled else 0
	var bounds := region()
	for id in _actors.keys():
		var entry: Dictionary = _actors[id]
		var actor: CharacterBodyExt = entry.actor.get_ref()
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not sub_area.is_ancestor_of(actor):
			_actors.erase(id)
			continue
		var active := not enabled or bounds.intersects(Utility.get_bounding_box(actor))
		if active == not entry.asleep:
			continue
		# Respect a separate caller's disabled node; only restore modes we own.
		if not active and actor.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		_apply.call_deferred(id, active, sub_area._runtime_revision)


func _apply(id: int, active: bool, revision: int) -> void:
	if not _actors.has(id) or revision != sub_area._runtime_revision:
		return
	var entry: Dictionary = _actors[id]
	var actor: CharacterBodyExt = entry.actor.get_ref()
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not sub_area.is_ancestor_of(actor):
		_actors.erase(id)
		return
	if active and entry.asleep:
		actor.process_mode = entry.mode
		actor.visible = entry.visible
		entry.asleep = false
	elif not active and not entry.asleep and actor.process_mode != Node.PROCESS_MODE_DISABLED:
		entry.mode = actor.process_mode
		entry.visible = actor.visible
		entry.asleep = true
		actor.hide()
		actor.process_mode = Node.PROCESS_MODE_DISABLED


func _exit_tree() -> void:
	reset()
