extends Node
## CourseBot — 本地关卡目录基座；完整仓储/界面待实现，见 docs/roadmap.md。

const COURSES_DIR := "user://courses/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(COURSES_DIR)
