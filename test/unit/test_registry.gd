extends GutTest
## REQ-REG-001/002 注册表用例

const RegistryScript := preload("res://src/autoload/registry.gd")

var _registry: Node

func before_each() -> void:
	_registry = RegistryScript.new()
	add_child_autofree(_registry)

func test_seed_entries_loaded() -> void:
	assert_eq(_registry._by_id.size(), 5, "五个种子条目全部加载")

func test_get_object() -> void:
	var entry: Dictionary = _registry.get_object("smm.block.question")
	assert_eq(entry.get("category"), "block")
	assert_eq(entry.get("components"), ["BumpableComponent", "ContainerComponent"])

func test_unknown_id_returns_empty() -> void:
	assert_false(_registry.has_object("smm.enemy.lakitu"))
	assert_eq(_registry.get_object("smm.enemy.lakitu"), {})

func test_get_by_style() -> void:
	var smw_entries: Array = _registry.get_by_style(&"smw")
	assert_eq(smw_entries.size(), 5)

func test_get_by_category() -> void:
	assert_eq(_registry.get_by_category("enemy").size(), 1)
	assert_eq(_registry.get_by_category("item").size(), 2)
