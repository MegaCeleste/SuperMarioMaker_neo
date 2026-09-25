extends Node
## Registry — 对象注册表（REQ-REG-001）
## 加载 objects.json 并建立 id → 定义索引；重复 ID 或非法条目报错中止。

const REGISTRY_PATH := "res://data/registry/objects.json"
const VALID_CATEGORIES: Array[String] = ["terrain", "block", "item", "enemy", "gizmo"]
const REQUIRED_FIELDS: Array[String] = [
	"id", "category", "palette_category", "display_name_key", "styles", "scenes"
]

var _by_id: Dictionary = {}

func _ready() -> void:
	_load_registry()

func _load_registry() -> void:
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		push_error("Registry: 无法打开 " + REGISTRY_PATH)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Array:
		push_error("Registry: objects.json 顶层必须是数组")
		return
	for entry: Variant in data:
		if not _validate_entry(entry):
			continue
		_by_id[entry["id"]] = entry
	print("Registry: 已注册 %d 个对象" % _by_id.size())

func _validate_entry(entry: Variant) -> bool:
	if not entry is Dictionary:
		push_error("Registry: 条目必须是 Dictionary")
		return false
	for field: String in REQUIRED_FIELDS:
		if not entry.has(field):
			push_error("Registry: 条目缺少必填字段 %s: %s" % [field, entry])
			return false
	if not VALID_CATEGORIES.has(entry["category"]):
		push_error("Registry: 非法 category %s" % entry["category"])
		return false
	if _by_id.has(entry["id"]):
		push_error("Registry: 重复 ID %s" % entry["id"])
		return false
	return true

func has_object(object_id: String) -> bool:
	return _by_id.has(object_id)

func get_object(object_id: String) -> Dictionary:
	return _by_id.get(object_id, {})

func get_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _by_id.values():
		if entry["category"] == category:
			result.append(entry)
	return result

func get_by_style(style: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _by_id.values():
		if entry["styles"].has(style):
			result.append(entry)
	return result
