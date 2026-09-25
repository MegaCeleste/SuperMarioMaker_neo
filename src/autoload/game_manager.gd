extends Node
## GameManager — 全局生命周期与模式调度（REQ-ARC-012）

signal mode_changed(new_mode: Mode)
signal style_changed(new_style: StringName)

enum Mode { BOOT, MAKER, PLAY }

var mode: Mode = Mode.BOOT:
	set(value):
		if mode == value:
			return
		mode = value
		mode_changed.emit(mode)

## 当前关卡风格（smb1 / smb3 / smw），见 01-physics-profiles.md §4
var game_style: StringName = &"smw":
	set(value):
		if game_style == value:
			return
		game_style = value
		style_changed.emit(game_style)

func _ready() -> void:
	mode = Mode.MAKER
