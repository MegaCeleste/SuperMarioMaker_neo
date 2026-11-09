# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BobOmb
extends Enemy
## SMW Bob-omb (source obj_bobomb, obj_bobomb_ready, obj_explosion). It walks
## like a Galoomba; stomping it lights the fuse: it stops, flashes on the
## ready sprite and explodes 300 ticks later (source alarm[1]). The blast
## hurts Mario, defeats enemies and breaks blocks in its 38px area.

## Source obj_bobomb_ready alarm[1].
const FUSE_TICKS := 300
## Source spr_explosion is 38x38 around the bomb.
const BLAST_SIZE := Vector2(38, 38)

## Ticks until the explosion; negative while walking.
var fuse := -1


func _ready() -> void:
	super()
	SpriteLibrary.configure_sprite(%Sprite, &"spr_bobomb", &"walk", 9, Vector2(0, -16))


func _physics_process(delta: float) -> void:
	if fuse < 0:
		super(delta)
		return
	if source_death_stopped():
		return
	velocity.x = 0
	$GravityComponent._physics_process(delta)
	move_source_and_slide()
	fuse -= 1
	if fuse == 0:
		explode()


func _stomped(player: Player) -> void:
	if is_queued_for_deletion() or player.is_dead():
		return
	player.bounce()
	player.sounds.stream = preload("uid://c345xnns7om3m")
	player.sounds.play()
	if fuse < 0:
		light()


## Source obj_bobomb -> obj_bobomb_ready: stop walking and start the fuse.
func light() -> void:
	fuse = FUSE_TICKS
	$SlideComponent.process_mode = Node.PROCESS_MODE_DISABLED
	velocity.x = 0
	SpriteLibrary.configure_sprite(%Sprite, &"spr_bobomb_ready", &"ready", 12, Vector2(0, -16))


## Source obj_explosion: snd_explode, the blast sprite, then everything in it.
func explode() -> void:
	if is_queued_for_deletion():
		return
	var center := global_position + Vector2(0, -8)
	EnemyEffect.sound_once(sub_area, SoundLibrary.path("snd_explode"))
	EnemyEffect.play_once(sub_area, &"spr_explosion", center, 24, false)
	var blast := Rect2(center - BLAST_SIZE / 2, BLAST_SIZE)
	var player := level.get_living_player()
	if player != null and blast.intersects(Utility.get_bounding_box(player)):
		player.damage()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = BLAST_SIZE
	query.transform.origin = center
	query.collision_mask = 1 | 2
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var body: Object = hit.collider
		if body is Enemy and not body.is_queued_for_deletion():
			body.hit_by_projectile(&"explosion", signf(body.global_position.x - center.x))
		elif body is TurnBlockTile or body is HardBlock:
			BlockBreakRequest.break_now(sub_area, body, &"spr_shard_g", &"spr_shard_g")
	queue_free()


func _turned(direction: Vector2) -> void:
	%Sprite.flip_h = direction == Vector2.RIGHT


func get_defeat_sprite() -> StringName:
	return &"spr_bobomb_deads"
