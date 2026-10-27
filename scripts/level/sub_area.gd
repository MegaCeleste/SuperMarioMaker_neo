# SPDX-License-Identifier: AGPL-3.0-or-later
@icon("uid://df4s8fh7js7tm")
class_name SubArea
extends Node2D
## Represents a separated world in a level.

signal theme_changed(old: Level.LevelTheme)

## The level theme this sub-area uses.
@export var level_theme := Level.LevelTheme.OVERWORLD
## Whether this sub-area is in night mode.
@export var night_mode := false
## The water speed of this sub-area. Only applies if this level theme supports
## water.
@export var water_speed := Level.WaterSpeed.SLOW
@export var min_water_height := 1
@export var max_water_height := 1
## SWE water positions in native coordinates; source y minus the432px room.
@export var water_start_y := -16.0
@export var water_limit_y := -16.0
@export var meteorites := false
@export var autoscroll := Level.Autoscroll.NONE

## The background node.
var background: Node
var liquid: LiquidSurface

var editor_foreground: Node
## The sub-area's parent [Level].
var level: Level
## Whether this sub-area has been loaded (see [method load]).
var is_loaded := false
var _runtime_revision := 0
var _pending_spawns: Dictionary[int, Dictionary] = {}
var actor_activity: ActorActivity
var actor_contacts: ActorContacts
var pixel_shadows: PixelShadows
var presentation: WorldPresentation


## Called by the [Level] to make sure this [SubArea] is ready to enter (i.e.,
## creating the background).
func load() -> void:
	if is_loaded:
		return
	is_loaded = true
	level.playing.connect(_play)
	level.editing.connect(_edit)
	actor_activity = ActorActivity.new()
	actor_activity.sub_area = self
	add_child(actor_activity)
	actor_contacts = ActorContacts.new()
	actor_contacts.sub_area = self
	add_child(actor_contacts)
	_refresh_environment()
	for i: Part in %Parts.get_children():
		if i is not Part:
			var cls: Script = i.get_script()
			push_warning("Found non-Part in Parts (class name '%s')" %
					cls.get_global_name())
			continue
		i.sub_area = self
		i.level = level
		i.load()
	GroundPart.refresh_all(%Parts)
	presentation = WorldPresentation.new()
	presentation.sub_area = self
	add_child(presentation)
	pixel_shadows = PixelShadows.new()
	pixel_shadows.sub_area = self
	add_child(pixel_shadows)
	match level.status:
		Level.Status.PLAYING:
			_play()
		Level.Status.EDITING:
			_edit()


## Edit-time theme replacement preserves authored objects and their history.
func set_theme(next: Level.LevelTheme, reset_water := true) -> void:
	if next == level_theme or not is_instance_valid(level) or level.status != Level.Status.EDITING:
		return
	var old := level_theme
	level_theme = next
	if reset_water and LiquidSurface.supports(next, night_mode):
		# obj_bg1/Mouse_4 creates a new surface at room_height-4. An old
		# non-liquid SWE's unused0 value must not flood a newly chosen castle.
		water_start_y = -16
		water_limit_y = -16
		water_speed = Level.WaterSpeed.SLOW
	if is_loaded:
		_refresh_environment()
		for part: Part in get_parts().get_children():
			if not part is EditorPlayer and not part is GoalPolePart and not part is GroundPart and not part is SlopePart:
				part.load()
		GroundPart.refresh_all(get_parts())
	theme_changed.emit(old)
	if is_instance_valid(level.editor):
		level.editor.refresh_theme()


func theme_state() -> Dictionary:
	return {"theme": level_theme, "start": water_start_y, "limit": water_limit_y, "speed": water_speed}


func restore_theme_state(state: Dictionary) -> void:
	water_start_y = state.start
	water_limit_y = state.limit
	water_speed = state.speed
	set_theme(state.theme, false)


func _refresh_environment() -> void:
	if is_instance_valid(background):
		remove_child(background)
		background.queue_free()
	if is_instance_valid(liquid):
		remove_child(liquid)
		liquid.queue_free()
	liquid = null
	background = SMWTheme.create_background(self)
	if background == null:
		var path: String = GameConstants.BACKGROUNDS[level.game_style][level_theme][night_mode]
		background = Node2D.new() if path.is_empty() else load(path).instantiate()
	add_child(background)
	if LiquidSurface.supports(level_theme, night_mode):
		liquid = LiquidSurface.new()
		liquid.name = "LiquidSurface"
		liquid.sub_area = self
		add_child(liquid)


func get_background() -> Node2D:
	return %Background


## Returns the foreground node, which stores all tiles and entities. Note that
## you shouldn't fill this out yourself, as [Part]s automatically generate
## content to put here (see [method get_parts]).
func get_foreground() -> Node2D:
	return %Foreground


## Returns the node which contains all [Part]s, which generate the tiles and
## entities in the foreground node (see [method get_foreground]).
func get_parts() -> Node2D:
	return %Parts


## Freezes this sub-area. All entities will stop processing and the sub-area
## will be invisible.
func freeze() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()


func unfreeze() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	show()


## Adds a node to this sub-area's foreground. If the node is an [Entity],
## [member Entity.sub_area] is set to this sub-area and [member Entity.level] is
## set to this sub-area's associated [member level]. Note that this mustn't be
## used for [Part]s, as they have their own [member parts] container node.
func add(node: Node) -> void:
	if node is CharacterBody2D:
		for part in get_parts().get_children():
			if part is SlopePart:
				SlopeBody.configure(node)
				break
	if "level" in node:
		node.level = level
	if "sub_area" in node:
		node.sub_area = self
	%Foreground.add_child(node)
	if node is CharacterBodyExt and actor_activity != null:
		actor_activity.register(node)


## Collision callbacks defer new bodies; discard them if play restarts first.
## Pending unparented nodes remain owned here until insertion or teardown.
func add_deferred(node: Node) -> void:
	var id := node.get_instance_id()
	_pending_spawns[id] = {"node": node, "revision": _runtime_revision}
	_finish_spawn.call_deferred(id)


func _finish_spawn(id: int) -> void:
	if not _pending_spawns.has(id):
		return
	var pending: Dictionary = _pending_spawns[id]
	_pending_spawns.erase(id)
	var node: Variant = pending.node
	if not is_instance_valid(node):
		return
	if pending.revision != _runtime_revision or not is_inside_tree() \
			or level.status == Level.Status.EDITING:
		node.free()
	else:
		add(node)


func _exit_tree() -> void:
	for pending in _pending_spawns.values():
		if is_instance_valid(pending.node):
			pending.node.free()
	_pending_spawns.clear()


func add_part(part: Part) -> void:
	part.sub_area = self
	part.level = level
	%Parts.add_child(part)


func _play() -> void:
	_runtime_revision += 1
	if is_instance_valid(liquid):
		liquid.reset()
	%Foreground.process_mode = Node.PROCESS_MODE_INHERIT
	for i: Part in %Parts.get_children():
		if i is not Part:
			continue
		i.build()
	reset_physics_interpolation.call_deferred()
	%Parts.hide()
	%Parts.process_mode = Node.PROCESS_MODE_DISABLED


func _edit() -> void:
	_runtime_revision += 1
	if actor_contacts != null:
		actor_contacts.reset()
	if actor_activity != null:
		actor_activity.reset()
	if is_instance_valid(liquid):
		liquid.reset()
	for i in %Foreground.get_children():
		%Foreground.remove_child(i)
		i.queue_free()
	%Parts.process_mode = Node.PROCESS_MODE_INHERIT
	%Parts.show()
