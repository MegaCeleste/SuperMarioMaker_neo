# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BillBlaster
extends StaticBodyExt
## SMW Bill Blaster (source obj_bullebill_base): a solid column whose head
## fires Bullet Bills at Mario. The first check comes after 90 ticks; it fires
## toward Mario when he is within 256px on that side, not more than 160px
## above the head, and the cell beside the head is clear. After a shot it
## waits 192 ticks; with its last bullet on that side still alive it retries
## after 15, and with nothing to shoot at after 60.

const FIRST_TICKS := 90
const RELOAD_TICKS := 192
const BUSY_TICKS := 15
const IDLE_TICKS := 60
const RANGE := 256.0
const BULLET = preload("res://scenes/level/entities/bullet_bill.tscn")

## Column height in 16px cells; source size_y, at least 2.
var height := 2
var _clock := FIRST_TICKS
var _last := {-1: null, 1: null}
var _level: Level
var _area: SubArea


func setup(area: SubArea, cells: int) -> void:
	_area = area
	_level = area.level
	height = cells


func _ready() -> void:
	z_as_relative = false
	z_index = GameConstants.Layers.Z_SOLIDS
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(16, height * 16)
	shape.position = Vector2(8, height * 8)
	add_child(shape)
	var frames := SpriteLibrary.get_frames(&"spr_bullebill_base")
	for cell in height:
		var piece := Sprite2D.new()
		piece.centered = false
		# Source Draw: head, neck, then body frames down the column.
		piece.texture = frames.get_frame_texture(&"default", mini(cell, 2))
		piece.position = Vector2(0, cell * 16)
		add_child(piece)


func _physics_process(_delta: float) -> void:
	if _level.status != Level.Status.PLAYING:
		return
	_clock -= 1
	if _clock > 0:
		return
	var player := _level.get_living_player()
	_clock = IDLE_TICKS
	if player == null:
		_clock = 1
		return
	var side := 0
	if player.global_position.x - 2 <= global_position.x and player.global_position.x > global_position.x - RANGE:
		side = -1
	elif player.global_position.x + 2 >= global_position.x + 16 and player.global_position.x < global_position.x + 16 + RANGE:
		side = 1
	if side == 0 or global_position.y < player.global_position.y - 32 - 160 or not _clear(side):
		return
	if is_instance_valid(_last[side]) and not _last[side].is_queued_for_deletion():
		_clock = BUSY_TICKS
		return
	fire(side)


## Source Alarm_0/Other_11-12: snd_explode, smoke and a Bullet Bill at the head.
func fire(side: int) -> void:
	var bullet: BulletBill = BULLET.instantiate()
	bullet.direction = side
	bullet.position = _area.get_foreground().to_local(global_position + Vector2(8 + side * 16, 16))
	_area.add_deferred(bullet)
	_last[side] = bullet
	EnemyEffect.sound_once(_area, SoundLibrary.path("snd_explode"))
	EnemyEffect.play_once(_area, &"spr_smokespin", global_position + Vector2(8 + side * 12, 8), 24, false)
	_clock = RELOAD_TICKS


# The cell beside the head must be free of solids and of Mario himself.
func _clear(side: int) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position + Vector2(8 + side * 16, 8)
	query.collision_mask = 1 | 4
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
