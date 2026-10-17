# 01 - 统一物理基线与风格能力开关 (Unified Physics & Style Abilities)

> **状态**: draft
> **版本**: 0.4.0
> **日期**: 2026-09-29
> **Changelog**: 0.1.0 初版（三风格参数矩阵）→ 0.2.0 统一基线与能力开关 → 0.2.1 导入第一版研究基线 → 0.2.2 记录试玩待复测项 → 0.3.0 增加 CANDIDATE 校准状态与研究审计 → 0.3.1 纠正跨游戏推断：800 仅作 NSMBU 对照，小型下蹲适用 SMB1/SMB3/SMW → 0.3.2 刹车基线降级为 CANDIDATE
> **引用**: REQ-ARC-003（60Hz 物理帧）、REQ-STD-003（数值唯一来源）、REQ-INP-002（旋转跳降级）

> **本次变更**: 0.4.0 独立审计 SMM2 一手来源；撤销无证据的 VERIFIED 与 216 P-Speed；新增运动/碰撞/形态候选配置和可导出仪表盘。旧研究导入记录见 Git 历史。

## 1. 架构原则

**REQ-PHYS-008 统一基线原则**: 全部游戏风格默认共用**一套**物理基线参数（`data/physics/base_physics.tres` 对应的 `PlayerPhysicsProfile` 资源）；风格能力通过 §4 表达。实测证实参数存在风格差异时，以“基线 + 风格覆盖项”追加单条覆盖，**禁止恢复整表复制**。这是本项目的工程架构；相同最高跑速不能证明 SMM2 所有风格的内部算法完全一致。

## 2. 校准状态与数据源

**REQ-PHYS-001**: 每个参数携带校准状态：`TBD`（缺少可用数值）→ `CANDIDATE`（有明确来源或工程设计依据的试玩值）→ `VERIFIED`（可独立复查的 SMM2 原始证据）→ `TUNED`（本项目仪表盘测量 + 负责人试玩签认）。工程设计的辅助参数由负责人签认可直接达到 TUNED，但不得先冒充 SMM2 VERIFIED。可撤销错误的等级；研究报告命名不构成证据。证据、状态及用途记录在 `data/physics/player_parameter_evidence.json`，数值的运行时唯一来源为 Profile。

**REQ-PHYS-002**: M1 验收前，统一基线的全部参数必须达到 `TUNED`。禁止任何参数以 `TBD` 或 `CANDIDATE` 状态进入 M1 验收。

**REQ-PHYS-003**: 引用外部数据时必须记录出处与原始值。涉及原作对照数据时按 60fps 帧-子像素（1/256 px）换算：`px/s = subpixels_per_frame × 60 / 256`。

**REQ-PHYS-004**: 一切定性描述（如"空中机动性好"）在定稿前必须量化为数值系数，禁止以文字描述进入实现。

## 3. 统一基线参数表

单位：px/s、px/s²、60Hz 物理帧；负 Y 为向上。本次独立研究见 `../../TBDtoVERIFIED/smm2_player_physics_codex_research.md`。完整字段及候选依据见参数证据 JSON。以下候选为本次重构的**工程默认值**，不是 SMM2 精确参数；未知的 SMM2 对应原值仍为 TBD。

| 参数/字段 | 默认值 | 状态 | 依据 |
|---|---:|---|---|
| `run_max` | 180 | VERIFIED | [SMM2 跑者平地实测](https://w.atwiki.jp/smm2l_documents/pages/167.html)：11.25 格/s × 16px/格 |
| `walk_max` | 84 | CANDIDATE | 保留旧工程预览；SMM2 步行逐帧表 TBD |
| `ground_accel` / `friction_normal` | 225 / 225 | CANDIDATE | 保留当前工程默认；到 180 需 48 帧，不能称为 24 帧 |
| `skid_decel` / `skid_threshold` | 540 / 100 | CANDIDATE | 负责人反馈 400 偏弱；默认工程刹停目标 20 帧。800 是 NSMBU 对照，不是 SMM2 数据 |
| `air_accel_factor` | 0.65 | CANDIDATE | 一手实验支持空中惯性、不同加速；系数待测 |
| `jump_initial` / `run_jump_initial` / `spin_jump_initial` | -360 / -430 / -280 | CANDIDATE | 保留可试玩模型；跑跳按起跳速度插值，不依赖 P-Meter |
| `gravity_rise` / `gravity_fall` / `max_fall` | 900 / 1800 / 270 | CANDIDATE | 双重力工程近似；公开轨迹不能证明这就是 SMM2 常数 |
| `coyote_frames` / `jump_buffer_frames` | 6 / 5 | CANDIDATE | 本项目常开辅助设计 |
| `corner_correction_max` / `head_bump_speed` | 3 / 10 | CANDIDATE | 本项目工程默认；原生阈值 TBD |
| `hitbox_width` / `small_height` / `super_height` / `crouch_height` | 12 / 14 / 28 / 14 | CANDIDATE | 工程碰撞尺寸；没有独立 SMM2 命中/地形实验 |
| `small_crouch_height` | 14 | CANDIDATE | 精确 SMM2 地形盒 TBD，工程沿用站立盒 |
| `small_hurt_height` / `small_crouch_hurt_height` / `super_hurt_height` / `crouch_hurt_height` | 14 / 14 / 28 / 14 | CANDIDATE | 受击盒与地形盒分离，预览同尺寸；不采用未核实的 8px |
| `feet_y` | 16 | CANDIDATE | 当前 SMW 场景的明确锚点约定；不是从透明边界推测 |
| `collision_margin` / `clearance_epsilon` / `floor_snap` / `floor_angle_degrees` | 0.01 / 0.02 / 2 / 46 | CANDIDATE | Godot 接触/净空工程配置 |
| `p_meter_max` / `p_meter_charge_per_frame` / `p_meter_decay_per_frame` | 112 / 2 / 1 | CANDIDATE | 旧作来源的独立候选计数，仅供未来飞行系统对照；不影响跑速、跑姿或跳高 |
| `animation_stride` / `spin_animation_fps` / `death_animation_fps` | 12 / 18 / 4 | CANDIDATE | 地面每移动 12px 推进一帧；空中多帧动画按物理时间推进 |
| `bounce_initial` / `bounce_held_initial` / `spin_bounce_initial` / `stomp_tolerance` | -180 / -360 / -120 / 4 | CANDIDATE | 工程敌人交互默认，待 SMM2 踩踏轨迹 |
| `death_initial` / `death_gravity` / `death_delay_frames` / `death_duration_frames` | -240 / 900 / 30 / 120 | CANDIDATE | 工程死亡演出与完成事件 |
| `powerup_freeze_frames` / `damage_freeze_frames` / `invulnerability_frames` / `flash_interval_frames` | 44 / 36 / 120 / 4 | CANDIDATE | 工程单人演出默认；定格现象有实证，精确时长无实证 |
| `hold_offset_small` / `hold_offset_super` / `throw_speed` / `throw_lift` / `throw_up_speed` | (12,8) / (14,0) / 180 / -80 / -360 | CANDIDATE | M1 搬运接口的工程默认，SMM2 原值 TBD |
| `fireball_speed` / `fireball_gravity` / `fireball_bounce` / `fireball_radius` / `fireball_lifetime_frames` / `fireball_cooldown_frames` / `fireball_limit` | 240 / 900 / -120 / 3 / 180 / 12 / 2 | CANDIDATE | Fire 能力试玩模型，非完整 SMM2 投射物系统 |

废弃字段：`p_speed=216`、`super_jump_initial`（原 P-Meter 门控含义）、`anim_low_speed`、`anim_low_fps`、`anim_walk_fps`、`anim_run_fps`、`anim_p_fps`。旧数值及含义保留在 Git 历史，不再进入运行时。

## 4. 风格能力开关矩阵 (StyleAbilityMatrix)

**REQ-PHYS-005**: 风格专属能力通过 `data/physics/style_abilities.json` 门控。运行时读取到能力为 `false` 时必须禁用对应行为；`spin_jump` 在不支持的风格中按 REQ-INP-002 降级为普通跳跃。

| 能力 | 字段名 | SMB1 | SMB3 | SMW | 说明 |
|---|---|---|---|---|---|
| 旋转跳 | `spin_jump` | ✗ | ✗ | ✓ | 不支持时 ↓ 键降级为普通跳跃 |
| 搬举/投掷 | `carry` | ✗ | ✓ | ✓ | SMB1 不能举起龟壳等物品 |
| P-Meter 候选计数 | `p_meter` | ✗ | ✓ | ✓ | 独立计数，不改跑速、跑姿或跳高（REQ-PHYS-113） |
| 踢墙跳 | `wall_kick` | ✗ | ✗ | ✗ | 三风格均不支持（NSMBU 预留） |
| 耀西 | `yoshi` | ✗ | ✗ | ✓ | 骑乘系统（M3+ 范围） |
| 小型形态下蹲姿态 | — | ✓ | ✓ | ✓ | 项目负责人 SMM2 实际观察确认；不以旧作控制规则覆盖 |

**REQ-PHYS-009**: 能力矩阵的扩充（新风格 NSMBU/SM3DW、新能力）只需在本表与 `style_abilities.json` 追加行列，不得改动统一基线参数表结构。

## 5. 玩家碰撞尺寸

| 形态 | 宽 × 高（px） | 校准状态 | 出处 |
|---|---|---|---|
| 小型马里奥（站立） | 12 × 14 | CANDIDATE | 工程预览 |
| 小型马里奥（下蹲，全三风格） | 地形/受击预览均 12 × 14；SMM2 原值 TBD | CANDIDATE | 项目负责人确认姿态存在；两盒独立可调 |
| 大马里奥（站立） | 12 × 28 | CANDIDATE | 工程预览 |
| 大马里奥（下蹲） | 12 × 14 | CANDIDATE | 工程预览 |

**REQ-PHYS-006**: 碰撞盒以 16px 格为参照定义，变身切换形态时碰撞盒原地切换，若新碰撞盒与地形重叠则按 REQ-PWR-005（下蹲保护）规则处理。

## 6. 验证方法

**REQ-PHYS-007**: 参数验证通过 `10-player-physics.md` 定义的数值仪表盘调试场景执行：场景实时绘制速度/位置曲线，验收时对照基准表逐项核对并录屏存档。M1 验收 = 数值达标（REQ-PHYS-002）+ 项目负责人试玩签认。
