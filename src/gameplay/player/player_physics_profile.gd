class_name PlayerPhysicsProfile
extends Resource
## 统一物理基线（REQ-PHYS-008）：全部风格共用一套参数。
## 统一基线数值见 specs/01-physics-profiles.md §3；VERIFIED 不代表已完成工程内 TUNED 验收。

@export var walk_max := 84.0
@export var run_max := 180.0
@export var p_speed := 216.0
@export var ground_accel := 225.0
@export var skid_decel := 400.0
@export var friction_normal := 225.0
@export var skid_threshold := 100.0
@export var jump_initial := -360.0
@export var super_jump_initial := -430.0
@export var spin_jump_initial := -280.0
@export var gravity_rise := 900.0
@export var gravity_fall := 1800.0
@export var max_fall := 270.0
@export var air_accel_factor := 0.65

## 土狼窗口（物理帧，REQ-PHYS-102）
@export var coyote_frames := 6
## 跳跃缓冲窗口（物理帧，REQ-PHYS-103）
@export var jump_buffer_frames := 5
## 拐角纠偏最大距离（px，REQ-PHYS-104）
@export var corner_correction_max := 3.0
## 顶块后垂直速度重置值（px/s，REQ-PHYS-105）
@export var head_bump_speed := 10.0

## REQ-PHYS-006: all hitboxes share one foot line.
@export var hitbox_width := 12.0
@export var small_height := 14.0
@export var super_height := 28.0
@export var crouch_height := 14.0
@export var feet_y := 16.0

## 试玩候选值，来源和证据等级见 REQ-PHYS-001/107/110。
@export var p_meter_max := 112
@export var p_meter_charge_per_frame := 2
@export var p_meter_decay_per_frame := 1
@export var anim_low_speed := 30.0
@export var anim_low_fps := 3.3
@export var anim_walk_fps := 7.5
@export var anim_run_fps := 15.0
@export var anim_p_fps := 18.0
