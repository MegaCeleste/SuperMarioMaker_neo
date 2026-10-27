# SPDX-License-Identifier: AGPL-3.0-or-later
class_name Grrrol
extends Enemy
## Three source objects share rolling AI. Drawing angle never rotates masks.

@export var variant: GrrrolVariant = preload("res://resources/content/smw_grrrol_small.tres")
@export_enum("Left:2", "Right:3") var attack_direction := 2
var swimming := false
var lava_mode := false
var bouncy := true
var angle := 0.0 # Original GameMaker drawing angle, counterclockwise.
var _wake_left := 2.0 / 60
var _land_speed := 0.0
var _before := Rect2()
var _sprite: AnimatedSprite2D


func _ready() -> void:
	hardness = 99
	fireproof = true
	stomp_behavior = Stompability.RECOIL
	for path in ["CollShape", "PlayerArea/CollShape", "EnemyArea/CollShape"]:
		get_node(path).shape = SpriteCollision.ellipse(variant.runtime_mask.size, variant.runtime_mask.get_center())
	_sprite = $Sprite
	_sprite.material = SpriteLibrary.ROTATION_MATERIAL
	SpriteLibrary.configure_sprite(_sprite, variant.body_sprite, &"roll", 0)
	_sprite.pause()
	_sprite.frame = 2
	$EnemyArea.body_entered.connect(_hit_enemy)
	_update_visuals()
	super()


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	_before = Utility.get_bounding_box(self)
	# Source alarms precede Step's new swimming sample, including startup.
	_wake_left -= delta
	if _wake_left <= 0:
		_wake_left = INF
		velocity.x = (variant.water_walk_speed if swimming else variant.walk_speed) * (-1 if attack_direction == 2 else 1)
	swimming = _in_water()
	_handle_sides()
	var supported := _has_support()
	if not source_death_stopped():
		if supported:
			var incoming := maxf(velocity.y, _land_speed)
			if incoming > 0:
				if bouncy and incoming > 30:
					velocity.y = -minf(incoming, 240) / 2
				else:
					velocity.y = 0
					bouncy = false
		else:
			velocity.y = minf(variant.water_fall_speed if swimming else variant.fall_speed, velocity.y) \
					+ (variant.water_gravity if swimming else variant.gravity) * delta
	_land_speed = 0
	if _is_below_world() or (not variant.legacy and _below_molten_limit()):
		queue_free()
		return
	_turn_from_legacy(supported)
	if sub_area.night_mode:
		var player := level.get_living_player()
		var cap := variant.water_walk_speed if swimming else variant.walk_speed
		if not is_instance_valid(player) or player.global_position.x < global_position.x:
			velocity.x = maxf(-cap, velocity.x - variant.left_acceleration * delta)
		else:
			velocity.x = minf(cap, velocity.x + variant.right_acceleration * delta)
	angle -= variant.rotation_speed * signf(velocity.x) * delta
	if swimming and absf(velocity.x) > variant.water_walk_speed:
		velocity.x = move_toward(velocity.x, variant.water_walk_speed * signf(velocity.x), variant.drag * delta)
	elif not swimming and velocity.x > variant.right_drag_threshold:
		velocity.x = maxf(variant.walk_speed, velocity.x - variant.drag * delta)
	elif not swimming and velocity.x < -variant.walk_speed:
		velocity.x = minf(-variant.walk_speed, velocity.x + variant.drag * delta)
	_liquid_contact()
	var incoming := velocity
	move_source_and_slide()
	if not source_death_stopped():
		if is_on_wall() and incoming.x != 0:
			velocity.x = -incoming.x
			if incoming.y == 0:
				velocity.y = -variant.wall_hop
			EnemyEffect.sound_once(sub_area, SoundLibrary.path("snd_bump"))
		if is_on_floor() and incoming.y > 0:
			_land_speed = incoming.y
	for enemy in $EnemyArea.get_overlapping_bodies():
		_hit_enemy(enemy)
	for player in hitbox.get_overlapping_bodies():
		_body_handling(true, player)
	_update_visuals()


func _update_visuals() -> void:
	_sprite.position = Vector2(roundf(global_position.x) - global_position.x,
			SpriteLibrary.contact_draw_y(variant.body_sprite, 0, false, false, 2))
	_sprite.rotation_degrees = -angle


func _query(bounds: Rect2, mask: int) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = bounds.size
	query.shape = shape
	query.transform.origin = bounds.get_center()
	query.collision_mask = mask
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 32)


func _has_support() -> bool:
	var feet := global_position + Vector2(variant.runtime_mask.get_center().x, 0)
	return not _query(Rect2(feet - Vector2(variant.runtime_mask.size.x / 2, 0.125), Vector2(variant.runtime_mask.size.x, 0.25)), 1).is_empty() \
			and _query(Rect2(feet - Vector2(variant.runtime_mask.size.x / 2, 5.125), Vector2(variant.runtime_mask.size.x, 0.25)), 1).is_empty()


func _handle_sides() -> void:
	if velocity.x == 0:
		return
	var bounds := Utility.get_bounding_box(self)
	var side := signf(velocity.x)
	var reach := variant.block_probe + absf(velocity.x) / 60
	var strip := Rect2(Vector2(bounds.end.x, bounds.position.y + variant.side_inset),
			Vector2(reach, bounds.size.y - 2 * variant.side_inset))
	if side < 0:
		strip.position.x = bounds.position.x - reach
	for hit in _query(strip, 1):
		var body := hit.collider as PhysicsBody2D
		if body is HardBlock:
			body.break_from_impact()
			continue
		if body != null and not body.is_queued_for_deletion() and Utility.find_child_by_class(body, BlockComponent) != null:
			BlockBreakRequest.arm(sub_area, body, variant.break_sprite, variant.empty_break_sprite)
	strip.size.x = 1.2
	strip.position.x = bounds.end.x - 1 if side > 0 else bounds.position.x - 0.2
	for hit in _query(strip, 1):
		var body: CollisionObject2D = hit.collider
		if body.is_queued_for_deletion():
			continue
		var owner_node := body.shape_owner_get_owner(body.shape_find_owner(hit.shape))
		if owner_node is CollisionShape2D and owner_node.one_way_collision:
			continue
		velocity.x *= -1
		if velocity.y == 0:
			velocity.y = -variant.wall_hop
		EnemyEffect.sound_once(sub_area, SoundLibrary.path("snd_bump"))
		break


func _turn_from_legacy(supported: bool) -> void:
	# All three source Other_12 events query obj_grrrol, not the new objects.
	var bounds := Utility.get_bounding_box(self)
	bounds.size.y -= 4
	for other in sub_area.get_foreground().find_children("*", "CharacterBody2D", true, false):
		if other == self or not other is Grrrol or not other.variant.legacy \
				or other.is_queued_for_deletion() or not other.is_visible_in_tree():
			continue
		var theirs := Utility.get_bounding_box(other)
		if not bounds.intersects(theirs):
			continue
		var center := Utility.get_bounding_box(self).get_center().x
		if center > theirs.get_center().x or (center == theirs.get_center().x and get_instance_id() > other.get_instance_id()):
			velocity.x = absf(velocity.x)
		else:
			velocity.x = -absf(velocity.x)
			if supported:
				velocity.y = -variant.wall_hop
		break


func _in_water() -> bool:
	return sub_area.level_theme == Level.LevelTheme.UNDERWATER \
			or (sub_area.night_mode and sub_area.level_theme in [Level.LevelTheme.SKY, Level.LevelTheme.AIRSHIP]) \
			or (is_instance_valid(sub_area.liquid) and variant.source_position(global_position).y + 8 >= sub_area.liquid.global_position.y - 12)


func _below_molten_limit() -> bool:
	return is_instance_valid(sub_area.liquid) and variant.source_position(global_position).y > sub_area.liquid.global_position.y + 32 \
			and (sub_area.level_theme == Level.LevelTheme.CASTLE or (sub_area.level_theme == Level.LevelTheme.FOREST and sub_area.night_mode))


func _liquid_contact() -> void:
	var liquid := sub_area.liquid
	if not is_instance_valid(liquid):
		return
	var edge := Utility.get_bounding_box(self).end.y - 9
	if not lava_mode and edge >= liquid.global_position.y - 12 \
			and (sub_area.level_theme == Level.LevelTheme.CASTLE or (sub_area.level_theme == Level.LevelTheme.FOREST and sub_area.night_mode)):
		lava_mode = true
		EnemyEffect.play_once(sub_area, liquid.rules.poison_splash_sprite if sub_area.level_theme == Level.LevelTheme.FOREST \
				else liquid.rules.lava_splash_sprite, Vector2(global_position.x, liquid.global_position.y - 26), liquid.rules.splash_fps, false)
	if edge <= liquid.global_position.y - 12 and liquid.velocity > 0 and (lava_mode or swimming):
		global_position.y = liquid.global_position.y - 20 + variant.source_to_feet.y


func _hit_enemy(body: Node2D) -> void:
	if body == self or is_queued_for_deletion() or body.is_queued_for_deletion():
		return
	if body is Enemy and body.hardness < 99:
		if body.hit_by_actor(&"crush", self, signf(velocity.x)):
			EnemyEffect.sound_once(sub_area, SoundLibrary.path("snd_klock"))
	elif body is StompedGaloomba:
		body.kill(signf(velocity.x))
		EnemyEffect.sound_once(sub_area, SoundLibrary.path("snd_klock"))


func _body_handling(entering: bool, body: Node2D) -> void:
	if body is Player and body.has_star():
		body.star_hit(self)
		return
	if not entering or is_queued_for_deletion() or not body is Player or body.is_dead() or body.is_frozen():
		return
	var bottom := _before.end.y if _before.has_area() else INF
	if body.helmet_deflects(self, bottom) or body.helmet_shields(self, bottom):
		return
	var previous := Utility.get_bounding_box(body)
	previous.position += body.previous_position - body.global_position
	if previous.end.y < Utility.get_bounding_box(self).position.y - velocity.y / 60 + 5:
		stomped.emit(body)
	else:
		body.damage()


func get_helmet_hit_margin(spiny: bool) -> float:
	return 10 + level.hud.player.velocity.y / 60 if spiny else 5.0


func hit_by_actor(kind: StringName, impact: CollisionObject2D, _fallback_direction := 0.0) -> bool:
	if kind == &"shell":
		if impact is KoopaShell and not impact.is_queued_for_deletion():
			impact.kill(signf(velocity.x))
		return false
	return hit_by_projectile(kind, source_hit_direction(impact))


func hit_by_projectile(kind: StringName, launch_direction := 0.0) -> bool:
	if is_queued_for_deletion() or kind not in [&"helmet", &"block", &"held_pow"]:
		return false
	kill(launch_direction)
	return true


func bumped_by_block(block: PhysicsBody2D, _activator: PhysicsBody2D) -> void:
	source_block_defeat(block)


func kill(launch_direction := 0.0) -> void:
	var style := EnemyDefeatStyle.new()
	style.dead_sprite = variant.body_sprite
	style.dead_frame = 2
	style.dead_offset = -variant.source_to_feet
	style.dead_mask_rect = variant.source_mask()
	# Source Other_10 does not copy direct or the body's drawing angle.
	spawn_source_defeat(style, 1, launch_direction)


func _is_below_world() -> bool:
	return Utility.get_bounding_box(self).position.y - 16 > 0
