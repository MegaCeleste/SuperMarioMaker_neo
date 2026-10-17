extends Node
## InputManager — 跨端输入语义统一入口（REQ-INP-001）
## gameplay/编辑器只准消费逻辑 Action；物理设备映射只发生在这里。

const SETTINGS_PATH := "user://settings.cfg"

## spec 登记的逻辑 Action（00-foundation.md §4）
const ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"jump", &"run", &"spin_jump",
	&"editor_undo", &"editor_redo", &"toggle_maker_play",
	&"editor_draw", &"editor_erase", &"editor_select", &"editor_palette",
	&"editor_toggle_grid", &"editor_close_panel", &"editor_pan",
	&"editor_zoom_in", &"editor_zoom_out",
	&"debug_reset", &"debug_pause", &"debug_step",
]

func _ready() -> void:
	_install_editor_defaults()
	_load_custom_bindings()

## 新编辑器动作按需注册；不覆盖项目或用户已配置的动作。
func _install_editor_defaults() -> void:
	var keys: Dictionary[StringName, int] = {
		&"editor_draw": KEY_B, &"editor_erase": KEY_E, &"editor_select": KEY_V,
		&"editor_palette": KEY_TAB, &"editor_toggle_grid": KEY_G,
		&"editor_close_panel": KEY_ESCAPE,
	}
	for action: StringName in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)
	var mouse_buttons: Dictionary[StringName, int] = {
		&"editor_pan": MOUSE_BUTTON_MIDDLE,
		&"editor_zoom_in": MOUSE_BUTTON_WHEEL_UP,
		&"editor_zoom_out": MOUSE_BUTTON_WHEEL_DOWN,
	}
	for action: StringName in mouse_buttons:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = mouse_buttons[action]
		InputMap.action_add_event(action, event)

func pressed(action: StringName) -> bool:
	return Input.is_action_pressed(action)

func just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action)

func just_released(action: StringName) -> bool:
	return Input.is_action_just_released(action)

func axis(negative: StringName, positive: StringName) -> float:
	return Input.get_axis(negative, positive)

## 键位重绑（REQ-INP-003）：从 user://settings.cfg 加载自定义绑定覆盖默认表
func _load_custom_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for action: StringName in ACTIONS:
		if not cfg.has_section_key("input", action):
			continue
		var events: Array = cfg.get_value("input", action, [])
		InputMap.action_erase_events(action)
		for event: InputEvent in events:
			InputMap.action_add_event(action, event)

## 重绑单个 action；与现有绑定冲突时返回冲突的 action 名，无冲突返回 &""
func rebind(action: StringName, new_event: InputEvent) -> StringName:
	for other: StringName in ACTIONS:
		if other == action:
			continue
		for event: InputEvent in InputMap.action_get_events(other):
			if event.is_match(new_event):
				return other
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, new_event)
	_save_custom_bindings()
	return &""

func reset_bindings() -> void:
	DirAccess.remove_absolute(SETTINGS_PATH)
	# 恢复 project.godot 默认绑定需要重启或重载 InputMap，M0 留接口

func _save_custom_bindings() -> void:
	var cfg := ConfigFile.new()
	for action: StringName in ACTIONS:
		var custom: Array = InputMap.action_get_events(action).filter(
			func(e: InputEvent) -> bool: return e is InputEventKey
		)
		if not custom.is_empty():
			cfg.set_value("input", action, custom)
	cfg.save(SETTINGS_PATH)
