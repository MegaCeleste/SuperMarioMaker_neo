class_name GameStyleBtn
extends PopoutBtn

const STYLE_CARDS = {
	Level.GameStyle.SMB: preload("uid://ct7nsivikgx8h"),
	Level.GameStyle.SMB3: preload("uid://ce4hyhrbcmjlt"),
	Level.GameStyle.SMW: preload("uid://b548gpt5xh0v2"),
	Level.GameStyle.NSMBU: preload("uid://upsn5uu41qe6"),
}
const POPOUT_CLOSE = preload("uid://dy8hcmykup336")


func _draw() -> void:
	super()
	if %Editor.level != null:
		draw_texture(STYLE_CARDS[%Editor.level.game_style], Vector2(0, 0))
	effect.draw()


func _toggled(toggled_on: bool) -> void:
	popout.close_sound = POPOUT_CLOSE
	super(toggled_on)


func _game_style_changed(_old: Level.GameStyle) -> void:
	queue_redraw()
