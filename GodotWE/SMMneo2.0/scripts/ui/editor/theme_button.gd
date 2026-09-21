extends TextureButton

var _effect: ButtonHoverEffect

const THEME_MAP := {
	"Overworld": 0,
	"Underground": 1,
	"Underwater": 2,
	"Castle": 3,
	"Sky": 4,
	"Airship": 5,
	"Desert": 6,
	"Snow": 7,
	"Mansion": 8,
	"Forest": 9,
	"Fall": 10,
	"Beach": 11,
	"Mountain": 12,
}

func _ready():
	_effect = ButtonHoverEffect.new(self)
	mouse_entered.connect(_effect.start)
	mouse_exited.connect(_effect.stop)
	pressed.connect(_on_pressed)

func _process(_delta):
	_effect.check_redraw()

func _draw():
	_effect.draw()

func _on_pressed():
	# 从按钮向上找到 Editor 节点
	var node = get_parent()
	while node != null and not node.has_signal("loaded"):
		node = node.get_parent()
	if node == null:
		return
	var level = node.level
	if level == null or level.sub_areas.size() == 0:
		return
	var sub_area = level.sub_areas[0]
	sub_area.level_theme = THEME_MAP.get(name, 0)
	sub_area._load_background()
	# 刷新所有 GroundPart 的地面贴图
	for child in sub_area.get_parts().get_children():
		if child is GroundPart:
			child._update_theme_texture()
	# 刷新 StartingGround 预览
	for child in sub_area.get_parts().get_children():
		if child is StartingGround:
			child._rebuild_editor_preview()
	# 刷新编辑器上方预览卡片
	for card in node.get_node("TopPanel/Cards").get_children():
		if card.has_method("refresh_icon"):
			card.refresh_icon()
	# 刷新所有 ThemeSprite
	for ts in get_tree().get_nodes_in_group("主题预览"):
		ts._update()
