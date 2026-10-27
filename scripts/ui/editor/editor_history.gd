class_name EditorHistory
extends Node
## Native UndoRedo actions retain detached Parts, including their SWE fields.

signal changed

var editor: Editor
var _undo := UndoRedo.new()
var _stroke := false
var _action_open := false
var _stroke_name := ""
var _terrain_dirty := false


func begin_stroke(action_name: String) -> void:
	if _stroke:
		return
	_stroke = true
	_stroke_name = action_name


func end_stroke() -> void:
	if _action_open:
		_record_environment_updates()
		_undo.commit_action(false)
		_action_open = false
		changed.emit()
	_stroke = false


func record_place(part: Part) -> void:
	_begin("Place")
	_undo.add_do_method(_set_present.bind(part, true))
	_undo.add_undo_method(_set_present.bind(part, false))
	_undo.add_do_reference(part)
	if part is GroundPart or part is SlopePart:
		_schedule_terrain_refresh()
	_commit()


func erase(part: Part) -> void:
	if not part.can_erase():
		return
	_begin("Erase")
	_undo.add_do_method(_set_present.bind(part, false))
	_undo.add_undo_method(_set_present.bind(part, true))
	_undo.add_undo_reference(part)
	_set_present(part, false)
	_commit()


## Erases several Parts as one undo step (both doors of a pair).
func erase_together(parts: Array) -> void:
	var own := not _stroke
	begin_stroke("Erase")
	for part: Part in parts:
		erase(part)
	if own:
		end_stroke()


func record_move(part: Part, before: Vector2, after: Vector2) -> void:
	if before == after:
		return
	_begin("Move")
	_undo.add_do_method(_move_to.bind(part, after))
	_undo.add_undo_method(_move_to.bind(part, before))
	_commit()


func record_geometry(part: Part, before: Dictionary, after: Dictionary) -> void:
	if before != after:
		_record_part_state(part, before, after, "Resize")


func set_theme(area: SubArea, theme: Level.LevelTheme) -> void:
	if area.level_theme == theme:
		return
	end_stroke()
	_begin("Change course theme")
	var before := area.theme_state()
	area.set_theme(theme)
	_undo.add_do_method(area.restore_theme_state.bind(area.theme_state()))
	_undo.add_undo_method(area.restore_theme_state.bind(before))
	_commit()


func set_night_mode(area: SubArea, night: bool) -> void:
	if area.night_mode == night:
		return
	end_stroke()
	_begin("Change day/night")
	var before := area.theme_state()
	area.set_night_mode(night)
	_undo.add_do_method(area.restore_theme_state.bind(area.theme_state()))
	_undo.add_undo_method(area.restore_theme_state.bind(before))
	_commit()


## Insertion consumes the loose Part and changes contents as one undo action.
func store_content(block: ContainerBlockPart, item: Part, original: Vector2) -> void:
	var before := block.get_variant_state()
	_begin("Put item in block")
	block.set_variant(ContainerBlockPart.content_for(item, block))
	_undo.add_do_method(block.restore_variant_state.bind(block.get_variant_state()))
	_undo.add_undo_method(block.restore_variant_state.bind(before))
	_undo.add_do_method(_set_present.bind(item, false))
	_undo.add_undo_method(_set_present.bind(item, true))
	_undo.add_undo_reference(item)
	_move_to(item, original)
	_set_present(item, false)
	_commit()


func set_variant(part: Part, variant: StringName) -> void:
	var before := part.get_variant_state()
	if before.id == variant:
		return
	part.set_variant(variant)
	var after := part.get_variant_state()
	_record_part_state(part, before, after, "Change variant")


## Direction buttons and size toggles may change dependent state together.
func set_part_state(part: Part, state: Dictionary, action_name := "Change option") -> void:
	var before := part.get_variant_state()
	if before == state:
		return
	part.restore_variant_state(state)
	_record_part_state(part, before, part.get_variant_state(), action_name)


func _record_part_state(part: Part, before: Dictionary, after: Dictionary, action_name: String) -> void:
	_begin(action_name)
	_undo.add_do_method(part.restore_variant_state.bind(after))
	_undo.add_undo_method(part.restore_variant_state.bind(before))
	_commit()


func undo() -> void:
	end_stroke()
	if _undo.has_undo():
		_undo.undo()
		_refresh_terrain()
		changed.emit()


func set_modifier(part: Part, id: StringName, enabled: bool) -> void:
	if part.has_modifier(id) == enabled:
		return
	var before := part.get_variant_state()
	part.set_modifier(id, enabled)
	_record_part_state(part, before, part.get_variant_state(), "Change option")


func redo() -> void:
	end_stroke()
	if _undo.has_redo():
		_undo.redo()
		_refresh_terrain()
		changed.emit()


func can_undo() -> bool:
	return _undo.has_undo() or _action_open


func can_redo() -> bool:
	return _undo.has_redo() and not _action_open


func clear() -> void:
	end_stroke()
	_undo.clear_history()
	changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		end_stroke()
		_undo.clear_history()
		_undo.free()


func _begin(action_name: String) -> void:
	if not _action_open:
		_undo.create_action(_stroke_name if _stroke else action_name, UndoRedo.MERGE_DISABLE, true)
		_action_open = true


func _commit() -> void:
	if not _stroke:
		end_stroke()


## Capture source-driven attachment removal after the complete edit gesture.
## Undo runs these restores before restoring terrain; no new action is created.
func _record_environment_updates() -> void:
	if not is_instance_valid(editor) or not is_instance_valid(editor.level) \
			or not is_instance_valid(editor.level.current_sub_area):
		return
	for part: Part in editor.level.current_sub_area.get_parts().get_children():
		var before := part.get_environment_state()
		if before.is_empty():
			continue
		part.refresh_environment()
		var after := part.get_environment_state()
		if before != after:
			_undo.add_do_method(part.restore_environment_state.bind(after))
			_undo.add_undo_method(part.restore_environment_state.bind(before))


func _set_present(part: Part, present: bool) -> void:
	var area := editor.level.current_sub_area
	if present:
		area.add_part(part)
		part._grid_pos = Level.to_grid(part.global_position)
	else:
		part._stop_window_timer()
		if is_instance_valid(part._window):
			part._window.close()
		if editor.hovered_part == part:
			editor.hovered_part = null
		area.get_parts().remove_child(part)
	if part is GroundPart or part is SlopePart:
		_schedule_terrain_refresh()


func _move_to(part: Part, target: Vector2) -> void:
	part.position = target
	part._grid_pos = Level.to_grid(part.global_position)
	if part is StartingGround:
		part.update_size()
	if part is GroundPart or part is StartingGround or part is SlopePart:
		_schedule_terrain_refresh()


func _schedule_terrain_refresh() -> void:
	if not _terrain_dirty:
		_terrain_dirty = true
		_refresh_terrain.call_deferred()


func _refresh_terrain() -> void:
	if not _terrain_dirty:
		return
	_terrain_dirty = false
	if is_instance_valid(editor) and is_instance_valid(editor.level) \
			and is_instance_valid(editor.level.current_sub_area):
		GroundPart.refresh_all(editor.level.current_sub_area.get_parts())
