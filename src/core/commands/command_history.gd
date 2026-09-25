class_name CommandHistory
extends RefCounted
## 撤销/重做命令栈：容量 ≥100，满栈淘汰最旧（backlog-draft §6）

signal changed

const MAX_DEPTH := 100

var _undo_stack: Array[IEditorCommand] = []
var _redo_stack: Array[IEditorCommand] = []

func push(command: IEditorCommand) -> void:
	command.execute()
	_undo_stack.append(command)
	if _undo_stack.size() > MAX_DEPTH:
		_undo_stack.pop_front()
	_redo_stack.clear()
	changed.emit()

func undo() -> void:
	if _undo_stack.is_empty():
		return
	var command: IEditorCommand = _undo_stack.pop_back()
	command.undo()
	_redo_stack.append(command)
	changed.emit()

func redo() -> void:
	if _redo_stack.is_empty():
		return
	var command: IEditorCommand = _redo_stack.pop_back()
	command.execute()
	_undo_stack.append(command)
	changed.emit()

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	changed.emit()

func depth() -> int:
	return _undo_stack.size()
