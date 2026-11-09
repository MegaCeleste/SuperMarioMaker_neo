# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BobOmb
extends Enemy
## SMW Bob-omb (source obj_bobomb, obj_explosion). It walks like a Galoomba.
## A stomp turns it into a [HeldBobOmb] facing the same way (obj_bobomb
## Other_11); a spin jump also kicks that bomb away (obj_enemyparent
## Collision_obj_mario, hitpoint 1). The blast hurts Mario, defeats enemies
## and breaks blocks in its 38px area.

## Source spr_explosion is 38x38 around the bomb.
const BLAST_SIZE := Vector2(38, 38)


func _ready() -> void:
	super()
	stomp_behavior = Stompability.CUSTOM
	SpriteLibrary.configure_sprite(%Sprite, &"spr_bobomb", &"walk", 9,
			Vector2(0, SpriteLibrary.contact_draw_y(&"spr_bobomb")))
	# Source direct starts at -1: face the walking direction before any turn.
	_turned(Vector2.RIGHT if $SlideComponent.direction > 0 else Vector2.LEFT)


func _physics_process(delta: float) -> void:
	super(delta)
	# Source Step_0: falling into lava sets it off.
	var liquid := sub_area.liquid
	if not is_queued_for_deletion() and is_instance_valid(liquid) and not liquid.is_water() \
			and global_position.y > liquid.global_position.y:
		blast(self, global_position + Vector2(0, -8))
		queue_free()


func _stomped(player: Player) -> void:
	if is_queued_for_deletion() or player.is_dead():
		return
	var spin := player.state_machine.current_state is PlayerSpinJumpingState
	player.bounce()
	player.sounds.stream = preload("uid://c345xnns7om3m")
	player.sounds.play()
	player.spawn_spin_thump()
	var held: HeldBobOmb = load("res://scenes/level/entities/held_bob_omb.tscn").instantiate()
	held.direct = 1 if $SlideComponent.direction > 0 else -1
	held.position = sub_area.get_foreground().to_local(global_position)
	if spin:
		held.kick_away(player)
	sub_area.add_deferred(held)
	queue_free()


## Source obj_explosion: snd_explode, the blast sprite, then everything in it.
static func blast(source: Node2D, center: Vector2) -> void:
	var area: SubArea = source.sub_area
	EnemyEffect.sound_once(area, SoundLibrary.path("snd_explode"))
	EnemyEffect.play_once(area, &"spr_explosion", center, 24, false)
	var box := Rect2(center - BLAST_SIZE / 2, BLAST_SIZE)
	var player := area.level.get_living_player()
	if player != null and box.intersects(Utility.get_bounding_box(player)):
		player.damage()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = BLAST_SIZE
	query.transform.origin = center
	query.collision_mask = 1 | 2
	if source is CollisionObject2D:
		query.exclude = [source.get_rid()]
	for hit in source.get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body: Object = hit.collider
		if body is Enemy and not body.is_queued_for_deletion():
			body.hit_by_projectile(&"explosion", signf(body.global_position.x - center.x))
		elif body is StompedGaloomba and not body.is_queued_for_deletion():
			# obj_enemyparent_held/Collision_obj_explosion: Other_10, no chain.
			body.kill(signf(body.global_position.x - center.x))
		elif body is TurnBlockTile or body is HardBlock:
			BlockBreakRequest.break_now(area, body, &"spr_shard_g", &"spr_shard_g")


func _turned(direction: Vector2) -> void:
	%Sprite.flip_h = direction == Vector2.LEFT


func get_defeat_sprite() -> StringName:
	return &"spr_bobomb_deads"
