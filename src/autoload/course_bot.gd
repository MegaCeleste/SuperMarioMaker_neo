extends Node
## CourseBot — 本地关卡仓储（M0 空壳占位，REQ-ARC-012）
## 目录布局：user://courses/<uuid>/level.json + thumb.png（backlog-draft §5.2）

const COURSES_DIR := "user://courses/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(COURSES_DIR)
