# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PowBlock
extends CarryBlock
## SMW POW block (source obj_block_pow_hold, obj_block_pow_active). It goes
## off when Mario bumps it from below or when a thrown POW first lands or hits
## a wall: the screen shakes, snd_pow plays, enemies standing on the ground
## on screen are defeated, and on-screen coins drop as loose coins.

## Source image_speed 0.15: the four frames cycle the POW colours at 9fps.
const ANIMATION_FPS := 9.0
## Source view margins: 20px around the 384x216 view.
const MARGIN := 20.0


func _ready() -> void:
	super()
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	add_child(_sprite)
	SpriteLibrary.configure_sprite(_sprite, &"spr_block_pow", &"default", ANIMATION_FPS, Vector2(-8, -15))


func _physics_process(delta: float) -> void:
	super(delta)
	if is_queued_for_deletion() or is_held():
		return
	var player := level.get_living_player()
	if player != null and player_bump(player):
		player.velocity.y = 0
		explode()


func _thrown_impact() -> void:
	explode()


## Source obj_block_pow_active Create/Alarm_0.
func explode() -> void:
	if is_queued_for_deletion():
		return
	level.shake_camera(1)
	EnemyEffect.sound_once(sub_area, SoundLibrary.path("snd_pow"))
	EnemyEffect.play_once(sub_area, &"spr_pow_explode", global_position + Vector2(0, -8), 30, false)
	var view := Utility.get_visible_rect().grow(MARGIN)
	for node in sub_area.get_foreground().get_children():
		if node.is_queued_for_deletion() or not (node is Node2D) or not view.has_point(node.global_position):
			continue
		if node is Enemy and node.hardness < 99 and not node is Thwomp and node.is_on_floor():
			node.hit_by_projectile(&"pow")
		elif node is Coin:
			var coin := PowCoin.new()
			coin.position = node.position
			coin.velocity.x = randf_range(-60, 60)
			node.queue_free()
			sub_area.add_deferred(coin)
	queue_free()
