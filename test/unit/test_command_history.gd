extends GutTest
## 命令栈用例（backlog-draft §6：≥100 步，满栈淘汰最旧）

const CommandHistory := preload("res://src/core/commands/command_history.gd")
const IEditorCommand := preload("res://src/core/commands/i_editor_command.gd")

class CounterCommand:
	extends IEditorCommand
	var counter: Array

	func _init(target: Array) -> void:
		counter = target

	func execute() -> void:
		counter[0] += 1

	func undo() -> void:
		counter[0] -= 1

func test_push_executes_and_undo_reverts() -> void:
	var history := CommandHistory.new()
	var counter := [0]
	history.push(CounterCommand.new(counter))
	assert_eq(counter[0], 1)
	history.undo()
	assert_eq(counter[0], 0)
	assert_true(history.can_redo())

func test_push_clears_redo_stack() -> void:
	var history := CommandHistory.new()
	var counter := [0]
	history.push(CounterCommand.new(counter))
	history.undo()
	history.push(CounterCommand.new(counter))
	assert_false(history.can_redo())

func test_max_depth_evicts_oldest() -> void:
	var history := CommandHistory.new()
	var counter := [0]
	for i: int in 150:
		history.push(CounterCommand.new(counter))
	assert_eq(history.depth(), 100, "栈深必须封顶 100")
	assert_eq(counter[0], 150)

func test_empty_undo_is_safe() -> void:
	var history := CommandHistory.new()
	history.undo()
	history.redo()
	assert_false(history.can_undo())
