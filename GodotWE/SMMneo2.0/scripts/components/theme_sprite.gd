extends Sprite2D
## 挂载到 Sprite2D 上后，贴图会随编辑器主题自动切换。
## 在 Inspector 里给对应主题的 Texture 属性赋值即可。

@export var overworld: Texture2D
@export var underground: Texture2D
@export var underwater: Texture2D
@export var castle: Texture2D
@export var sky: Texture2D
@export var airship: Texture2D
@export var desert: Texture2D
@export var snow: Texture2D
@export var mansion: Texture2D
@export var forest: Texture2D
@export var fall: Texture2D
@export var beach: Texture2D
@export var mountain: Texture2D


func _ready() -> void:
	add_to_group("ThemeSprite")
	update_tex()


func update_tex() -> void:
	var editor = get_tree().current_scene
	if editor == null or not editor.has_signal("loaded"):
		return
	var level = editor.level
	if level == null or level.sub_areas.size() == 0:
		return
	var theme = level.sub_areas[0].level_theme
	var tex = _get_tex(theme)
	if tex != null:
		texture = tex


func _get_tex(theme: int) -> Texture2D:
	match theme:
		Level.LevelTheme.OVERWORLD: return overworld
		Level.LevelTheme.UNDERGROUND: return underground
		Level.LevelTheme.UNDERWATER: return underwater
		Level.LevelTheme.CASTLE: return castle
		Level.LevelTheme.SKY: return sky
		Level.LevelTheme.AIRSHIP: return airship
		Level.LevelTheme.DESERT: return desert
		Level.LevelTheme.SNOW: return snow
		Level.LevelTheme.MANSION: return mansion
		Level.LevelTheme.FOREST: return forest
		Level.LevelTheme.FALL: return fall
		Level.LevelTheme.BEACH: return beach
		Level.LevelTheme.MOUNTAIN: return mountain
	return null
