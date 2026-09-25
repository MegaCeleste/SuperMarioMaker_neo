# 占位素材生成脚本（REQ-AST-001）
# 用法: godot --headless -s tools/gen_placeholders.gd
# 全新克隆的仓库不含任何媒体文件；本脚本生成 16px 纯色占位图，
# 已存在的真实素材文件一律跳过，不会覆盖。
extends SceneTree

const PLACEHOLDERS := {
	# 路径: [宽, 高, 颜色]
	"res://textures/tiles/ground.png": [16, 16, Color.SADDLE_BROWN],
	"res://textures/tiles/coin.png": [16, 16, Color.GOLD],
	"res://textures/tiles/empty_block.png": [16, 16, Color.DIM_GRAY],
	"res://textures/player/mario/small/idle.png": [12, 14, Color.RED],
	"res://textures/player/mario/small/walk.png": [36, 14, Color.RED],
	"res://textures/player/mario/small/run.png": [36, 14, Color.RED],
	"res://textures/player/mario/small/jump.png": [12, 14, Color.RED],
	"res://textures/player/mario/small/fall.png": [12, 14, Color.RED],
	"res://textures/player/mario/small/skid.png": [12, 14, Color.RED],
	"res://textures/player/mario/small/duck.png": [12, 14, Color.RED],
	"res://textures/player/mario/small/p_jump.png": [12, 14, Color.RED],
	"res://textures/player/mario/small/spin_jump.png": [12, 14, Color.RED],
	"res://textures/player/mario/dead.png": [12, 14, Color.DARK_RED],
	"res://textures/smw/entities/galoomba.png": [16, 16, Color.PURPLE],
	"res://textures/smw/entities/mushroom.png": [16, 16, Color.ORANGE_RED],
	"res://textures/skid_smoke.png": [16, 16, Color.LIGHT_GRAY],
	"res://textures/sparkle.png": [8, 8, Color.WHITE],
	"res://textures/spin_thump.png": [16, 16, Color.GRAY],
	"res://textures/smw/background/background.png": [256, 224, Color.SKY_BLUE],
}

func _init() -> void:
	var created := 0
	var skipped := 0
	for path: String in PLACEHOLDERS:
		if FileAccess.file_exists(path):
			skipped += 1
			continue
		var spec: Array = PLACEHOLDERS[path]
		var img := Image.create(spec[0], spec[1], false, Image.FORMAT_RGBA8)
		img.fill(spec[2])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var err := img.save_png(path)
		if err == OK:
			created += 1
		else:
			push_error("生成失败 %s: %s" % [path, error_string(err)])
	print("占位素材生成完成: 新建 %d, 跳过已存在 %d" % [created, skipped])
	quit()
