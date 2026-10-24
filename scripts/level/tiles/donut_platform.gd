# SPDX-License-Identifier: AGPL-3.0-or-later
class_name DonutPlatform
extends AnimatableBody2D
## Ordinary obj_donut:30 loaded ticks, source shake/fall,180-tick return.

enum Phase { IDLE, WARNING, FALLING, WAITING, REGROWING }
var sub_area: SubArea
var phase := Phase.IDLE
var phase_ticks := 0
var fall_speed := 0.0
var _home: Vector2
var _sprite: Sprite2D
var _shape: CollisionShape2D
var _size := 1.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	process_physics_priority = -10
	z_index = 20
	_home = position
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	_shape.shape.size = Vector2(16, 5)
	_shape.position = Vector2(8, 2.5)
	_shape.one_way_collision = true
	_shape.one_way_collision_margin = 0.5
	add_child(_shape)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.position.x = 8
	_sprite.offset.x = -8
	add_child(_sprite)
	_show_art(false)
	_apply_size()


func _physics_process(delta: float) -> void:
	if phase == Phase.WAITING:
		phase_ticks -= 1
		if phase_ticks <= 0:
			# Source Alarm1 replaces the off-room body. A new native body also
			# prevents the return teleport from becoming a huge rider velocity.
			var replacement := DonutPlatform.new()
			replacement.sub_area = sub_area
			replacement.position = _home
			replacement.phase = Phase.REGROWING
			replacement._size = 0.2
			sub_area.add_deferred(replacement)
			queue_free()
		return
	if _size < 1:
		_size = minf(1, _size + 0.05)
		_apply_size()
		if phase == Phase.REGROWING and _size >= 0.99999:
			phase = Phase.IDLE
	if phase in [Phase.IDLE, Phase.WARNING, Phase.REGROWING]:
		if not _loaded():
			phase = Phase.IDLE
			phase_ticks = 0
			position = _home
			_shake(0)
			_show_art(false)
			return
		if phase != Phase.WARNING:
			phase = Phase.WARNING
			phase_ticks = 0
		phase_ticks += 1
		_show_art(true)
		_shake(-2 if int((phase_ticks - 1) / 4.0) % 2 == 0 else 0)
		if phase_ticks < 30:
			return
		phase = Phase.FALLING
		_shake(0)
	if phase == Phase.FALLING:
		fall_speed = minf(fall_speed, 150) + 360 * delta
		position.y += fall_speed * delta
		if global_position.y > 64:
			phase = Phase.WAITING
			phase_ticks = 180
			fall_speed = 0
			collision_layer = 0
			hide()


func _loaded() -> bool:
	var player := sub_area.level.hud.player
	if not is_instance_valid(player) or player.is_dead() or player.is_frozen() \
			or not player.is_on_floor() or player.velocity.y < 0:
		return false
	var bounds := Utility.get_bounding_box(player)
	var surface := Utility.get_bounding_box(self)
	return bounds.end.x > surface.position.x - 1 and bounds.position.x < surface.end.x + 1 \
			and absf(bounds.end.y - surface.position.y) < 5


func _shake(offset: float) -> void:
	# Source x alarms move the mask/art, not the inherited platform hspeed.
	# Keep the body transform fixed so native carrying cannot shake Mario too.
	_sprite.position.x = 8 + offset
	_shape.position.x = 8 + offset


func _show_art(falling: bool) -> void:
	_sprite.texture = SpriteLibrary.get_frames(&"spr_donut_fall" if falling else &"spr_donut").get_frame_texture(&"default", 0)


func _apply_size() -> void:
	_sprite.scale = Vector2.ONE * _size
	_shape.scale = Vector2.ONE * _size
	_shape.position = Vector2(8, 2.5 * _size)
