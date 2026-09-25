class_name IEditorCommand
extends RefCounted
## 编辑器命令接口（M0 命令栈，见 specs/backlog-draft.md §6 与 REQ-STD-001）

func execute() -> void:
	pass

func undo() -> void:
	pass
