class_name EditorWindow
extends PanelContainer

## 当用户在变体窗口中选择了一个变体时触发。
## id 是被选中变体的场景路径（如 "res://scenes/parts/red_koopa_part.tscn"）。
signal selected(id: StringName)

## 创建此窗口的 Part 引用（用于定位和上下文）。
var part: Part
## 窗口的目标位置（世界坐标，即 Part 所在的网格位置中心）。
var target_position: Vector2

var _mouse_in := false


func _ready() -> void:
	# 播放窗口弹出音效
	%SoundPlayer.play()
	# 将窗口定位到 Part 所在位置
	# target_position 是 Part 世界坐标，*3 转为编辑器视口坐标，- pivot_offset 居中
	# - Vector2(48, 48) 是修正偏移（3×3 格）
	position = (target_position - Vector2(48, 48)) * 3 - pivot_offset
	# 鼠标进入/离开窗口区域的标记，用于判断点击窗口外时关闭
	mouse_entered.connect(func(): _mouse_in = true)
	mouse_exited.connect(func(): _mouse_in = false)
	# 弹出动画：从 (0,0) 缩放到 (1,1)，0.1 秒，QUAD 缓出
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1).from(Vector2(0, 0))


func _input(event: InputEvent) -> void:
	# 点击窗口外部任意位置 → 关闭窗口（不选择变体）
	if event is InputEventMouseButton and not _mouse_in:
		if event.pressed:
			close()


## 选择变体后调用：发射 selected 信号告知 Part 替换自己，同时关闭窗口。
func select(id: StringName) -> void:
	selected.emit(id)
	close()


## 关闭窗口：播放缩小动画后销毁自身。
func close() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0, 0), 0.1)
	tween.tween_callback(queue_free)
