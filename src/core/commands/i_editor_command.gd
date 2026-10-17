class_name IEditorCommand
extends RefCounted
## 编辑器命令接口；当前架构与开发进度见 docs/architecture.md、docs/roadmap.md。

func execute() -> void:
	pass

func undo() -> void:
	pass
