# SPDX-License-Identifier: AGPL-3.0-or-later
class_name NoteBlock
extends StaticBodyExt
## obj_noteblock: a moving solid with an8px,2px/tick compression cycle.

var sub_area: SubArea
var content_id: StringName = &"none"
var active := false
var age := 0
var compression := 1
var _home: Vector2
var _rider: WeakRef
var _sprite: AnimatedSprite2D


func _ready() -> void:
	collision_layer = 1
	process_physics_priority = -10
	z_index = 20
	_home = position
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(16, 16)
	shape.position = Vector2(8, 8)
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = false
	_sprite.sprite_frames = SpriteLibrary.get_frames(&"spr_noteblock")
	add_child(_sprite)
	collided.connect(_contact)


func _physics_process(_delta: float) -> void:
	_sprite.frame = int(floor(sub_area.level.animation_time * 9 + 0.00001)) % _sprite.sprite_frames.get_frame_count(&"default")
	if active:
		age += 1
		var offset := mini(age, 8 - age) * 2 if age <= 8 else 0
		position.y = _home.y + offset * compression
		if age == 10:
			_release_content(Vector2.DOWN if compression > 0 else Vector2.UP)
		if age >= 12:
			active = false
		return
	var player := sub_area.level.hud.player
	if is_instance_valid(player) and not player.is_dead() and not player.is_frozen() \
			and not player.state_machine.current_state is PlayerStunnedState and player.velocity.y >= 0:
		var box := Utility.get_bounding_box(player)
		if box.end.x > global_position.x and box.position.x < global_position.x + 16 \
				and box.end.y >= global_position.y - 3 and box.end.y < global_position.y + 0.5:
			_begin(1)
			_rider = weakref(player)
			var state := Utility.find_child_by_class(player.state_machine, PlayerNoteState) as PlayerNoteState
			state.block = self
			player.state_machine.switch(PlayerNoteState)
			return
	_bounce_actor()


func _begin(direction: int) -> void:
	active = true
	age = 0
	compression = direction


func _contact(hit: KinematicCollision2D) -> void:
	if active:
		return
	var actor: Node = hit.get_local_shape().get_parent()
	if actor is Player and hit.get_normal().y > 0.5 and not actor.is_dead() and not actor.is_frozen():
		_begin(-1)


func _bounce_actor() -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	var strip := RectangleShape2D.new()
	strip.size = Vector2(16, 3)
	query.shape = strip
	query.transform.origin = global_position + Vector2(8, -1)
	query.collision_mask = 2 | 8
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var body := hit.collider as CharacterBodyExt
		if body == null or body.velocity.y < 0 or body.is_queued_for_deletion() \
				or body is Thwomp or body is Rocky or body is CheepCheep \
				or body is BroProjectile or body is PlayerFireball:
			continue
		if body.get_parent() is Player or ((body is BuzzyBeetle or body is Spiny) and body.ceiling):
			continue
		var bounds := Utility.get_bounding_box(body)
		if bounds.end.y > global_position.y + 5:
			continue
		var speed := 30.0 if body.test_move(body.global_transform, Vector2.UP) else 313.5
		var liquid := sub_area.liquid
		if sub_area.level_theme == Level.LevelTheme.UNDERWATER or (is_instance_valid(liquid) \
				and liquid.is_water() and body.global_position.y > liquid.global_position.y + 16):
			speed /= 2
		body.velocity.y = -speed
		_begin(1)
		EnemyEffect.sound_once(sub_area, "res://assets/openwe/sounds/snd_spring.ogg")
		return


func detach_rider(player: Player) -> void:
	if _rider != null and _rider.get_ref() == player:
		_rider = null


func _release_content(direction: Vector2) -> void:
	if content_id == &"none":
		return
	var release := NoteContentRelease.new()
	release.sub_area = sub_area
	release.content_id = content_id
	release.direction = direction
	release.position = _home
	add_child(release)
	content_id = &"none"
