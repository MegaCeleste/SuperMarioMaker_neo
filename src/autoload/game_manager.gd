extends Node
## GameManager — 全局生命周期与模式调度（REQ-ARC-012）

signal mode_changed(new_mode: Mode)
signal style_changed(new_style: StringName)
signal gameplay_freeze_started
signal gameplay_freeze_ended
signal coins_changed(total: int)
signal extra_lives_changed(total: int)
var extra_lives: int = 0

enum Mode { BOOT, MAKER, PLAY }

var is_gameplay_frozen: bool = false
var _freeze_frames_left: int = 0
var coins: int:
	get: return _coins
var _coins: int = 0

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
	process_physics_priority = -100
	mode = Mode.MAKER


func _physics_process(_delta: float) -> void:
	if is_gameplay_frozen:
		if _freeze_frames_left == 0:
			clear_gameplay_freeze()
		else:
			_freeze_frames_left -= 1


func freeze_gameplay(frames: int) -> void:
	if frames <= 0:
		return
	_freeze_frames_left = maxi(_freeze_frames_left, frames - 1)
	if not is_gameplay_frozen:
		is_gameplay_frozen = true
		gameplay_freeze_started.emit()


func clear_gameplay_freeze() -> void:
	_freeze_frames_left = 0
	if is_gameplay_frozen:
		is_gameplay_frozen = false
		gameplay_freeze_ended.emit()


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	_coins += amount
	coins_changed.emit(_coins)


func add_extra_life() -> void:
	extra_lives += 1
	extra_lives_changed.emit(extra_lives)


func reset_coins() -> void:
	extra_lives = 0
	extra_lives_changed.emit(extra_lives)
	_coins = 0
	coins_changed.emit(_coins)
