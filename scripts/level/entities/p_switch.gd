# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PSwitch
extends CarryBlock
## SMW P-switch (source obj_pswitch, obj_pswitch_press). Mario landing on it
## presses it: the SMW press thud (scr_snd_pwarning is snd_door_close), the
## flattened switch for 8 ticks, and the level-wide [PSwitchTimer].

## Source image_index = global.apariencia; SMW is frame 2.
const SMW_FRAME := 2
## Source obj_pswitch_press alarm[1]: the flattened switch stays 8 ticks.
const FLAT_TICKS := 8


func _ready() -> void:
	super()
	_sprite = SpriteLibrary.make_sprite(&"spr_pswitch")
	_sprite.name = "Sprite"
	_sprite.stop()
	_sprite.frame = SMW_FRAME
	_sprite.position = Vector2(-8, -15)
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	super(delta)
	if is_queued_for_deletion() or is_held():
		return
	var player := level.get_living_player()
	if player != null and player_landing(player):
		press()


func press() -> void:
	if is_queued_for_deletion():
		return
	EnemyEffect.sound_once(sub_area, SoundLibrary.path("snd_door_close"))
	var flat := SpriteLibrary.make_sprite(&"spr_pswitch_press")
	flat.name = "PressedPSwitch"
	flat.stop()
	flat.frame = SMW_FRAME
	flat.position = sub_area.get_foreground().to_local(global_position + Vector2(-8, -15))
	flat.z_index = z_index
	sub_area.add_deferred(flat)
	get_tree().create_timer(FLAT_TICKS / 60.0, false, true).timeout.connect(flat.queue_free)
	PSwitchTimer.activate(level)
	queue_free()
