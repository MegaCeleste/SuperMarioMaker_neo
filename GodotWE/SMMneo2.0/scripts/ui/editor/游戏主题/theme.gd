extends Sprite2D


func _ready():
	add_to_group("主题预览")
	# 找到 Editor 节点
	var editor = %Editor
	# 等编辑器加载完成
	await editor.loaded
	# 根据当前主题换贴图
	_update()

func _update():
	var editor = %Editor
	var theme = editor.level.sub_areas[0].level_theme
	match theme:
		Level.LevelTheme.OVERWORLD:
			texture = preload("res://textures/backgrounds/smw/overworld/overworld_theme.png")
		Level.LevelTheme.AIRSHIP:
			texture = preload("res://textures/backgrounds/smw/airship/airship_theme.png")
		# ...其他主题
