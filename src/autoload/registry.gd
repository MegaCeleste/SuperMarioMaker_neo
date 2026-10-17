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


func instantiate_object(object_id: String, properties: Dictionary = {}) -> Node2D:
	if not has_object(object_id):
		push_error("Registry: unknown object " + object_id)
		return null
	var definition: Dictionary = get_object(object_id)
	var schema: Dictionary = definition.get("properties_schema", {}) as Dictionary
	for field: String in properties:
		if not schema.has(field):
			push_error("Registry: unknown property " + object_id + "." + field)
			return null
	var values: Dictionary = {}
	for field: String in schema:
		var rule: Dictionary = schema[field] as Dictionary
		var value: Variant = properties.get(field, rule.get("default"))
		if not _valid_runtime_property(value, rule):
			push_error("Registry: invalid property " + object_id + "." + field)
			return null
		values[field] = int(value) if String(rule["type"]) == "int" else value
	var scenes: Dictionary = definition["scenes"] as Dictionary
	var path: String = String(scenes.get("play", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("Registry: missing play scene for " + object_id)
		return null
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_error("Registry: play scene must be a PackedScene: " + object_id)
		return null
	var instance: Node = scene.instantiate()
	if not instance is Node2D:
		instance.free()
		push_error("Registry: play root must be Node2D: " + object_id)
		return null
	var available: PackedStringArray = PackedStringArray()
	for property: Dictionary in instance.get_property_list():
		available.append(String(property["name"]))
	for field: String in values:
		if not available.has(field):
			instance.free()
			push_error("Registry: scene lacks property " + object_id + "." + field)
			return null
		instance.set(field, values[field])
	return instance as Node2D


func _valid_runtime_property(value: Variant, rule: Dictionary) -> bool:
	var valid: bool = false
	match String(rule.get("type", "")):
		"bool": valid = value is bool
		"int": valid = value is int or (value is float and is_finite(float(value)) and floorf(float(value)) == float(value))
		"float": valid = value is int or value is float
		"string": valid = value is String
		"object_id": valid = value is String and has_object(String(value))
	if valid and rule.has("enum"):
		if String(rule["type"]) == "int":
			valid = false
			for choice: Variant in rule["enum"]:
				if (choice is int or choice is float) and float(choice) == float(value):
					valid = true
					break
		else:
			valid = (rule["enum"] as Array).has(value)
	return valid
