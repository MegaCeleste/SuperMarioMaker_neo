# 01 - 统一物理基线与风格能力开关 (Unified Physics & Style Abilities)

> **状态**: draft
> **版本**: 0.3.2
> **日期**: 2026-09-24
> **Changelog**: 0.1.0 初版（三风格参数矩阵）→ 0.2.0 统一基线与能力开关 → 0.2.1 导入第一版研究基线 → 0.2.2 记录试玩待复测项 → 0.3.0 增加 CANDIDATE 校准状态与研究审计 → 0.3.1 纠正跨游戏推断：800 仅作 NSMBU 对照，小型下蹲适用 SMB1/SMB3/SMW → 0.3.2 刹车基线降级为 CANDIDATE
> **引用**: REQ-ARC-003（60Hz 物理帧）、REQ-STD-003（数值唯一来源）、REQ-INP-002（旋转跳降级）

## 1. 架构原则

**REQ-PHYS-008 统一基线原则**: 全部游戏风格共用**一套**物理基线参数（`data/physics/base_physics.tres` 对应的 `PlayerPhysicsProfile` 资源）。风格之间不存在跑速、跳跃、重力数值差异；风格差异一律通过能力开关（§4）表达。仅当未来实测证实某个参数存在风格差异时，允许以"基线 + 风格覆盖项"形式追加单条覆盖，**禁止恢复整表复制**。

## 2. 校准状态与数据源

**REQ-PHYS-001**: 每个参数携带校准状态：`TBD`（缺少可用数值）→ `CANDIDATE`（研究报告给出可试玩数值，但没有足够的 SMM2 原始录像/逐帧表可独立复核）→ `VERIFIED`（已对照可复查的 SMM2 原始实测数据并标注具体出处；旧作反汇编仅作对照）→ `TUNED`（经本项目仪表盘实测和项目负责人试玩确认）。已有 VERIFIED 基线记录保留其历史来源，但如出现测算矛盾，应重新审计，不能直接升 TUNED。`CANDIDATE` 可以进入调试 Profile 供试玩，不得通过 M1 正式验收。

**REQ-PHYS-002**: M1 验收前，统一基线的全部参数必须达到 `TUNED`。禁止任何参数以 `TBD` 或 `CANDIDATE` 状态进入 M1 验收。

**REQ-PHYS-003**: 引用外部数据时必须记录出处与原始值。涉及原作对照数据时按 60fps 帧-子像素（1/256 px）换算：`px/s = subpixels_per_frame × 60 / 256`。

**REQ-PHYS-004**: 一切定性描述（如"空中机动性好"）在定稿前必须量化为数值系数，禁止以文字描述进入实现。

## 3. 统一基线参数表

单位：速度 px/s，加速度 px/s²，负 Y 为向上。下表采用 ../../TBDtoVERIFIED/smm2_physics_baseline.md 的 SMM2 统一基线；VERIFIED 表示已对照该研究清单，工程内仪表盘校准仍未完成，因此尚未达到 TUNED。

| 参数 | 字段名 | 基线值 | 状态 | 出处 |
|---|---|---|---|---|
| 行走最大速度 | `walk_max` | 84.0 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md baseline §3.1; 1.40 px/f |
| 跑步最大速度 | `run_max` | 180.0 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md baseline §3.1; 3.00 px/f |
| P-Meter 冲刺速度 | `p_speed` | 216.0 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md baseline §3.1; 3.60 px/f |
| 地面加速度 | `ground_accel` | 225.0 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md baseline §3.1; 16 subpixels/frame² conversion |
| 滑行刹车阻尼 | `skid_decel` | 400.0 | CANDIDATE | ../../TBDtoVERIFIED/smm2_physics_baseline.md baseline §3.1；用户试玩反馈偏弱，SMM2 原始逐帧速度表待补 |
| 地面自然摩擦 | `friction_normal` | 225.0 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md §3.1; natural ground deceleration |
| 滑行触发速度阈值 | `skid_threshold` | 100.0 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md §3.1; reverse-input skid threshold |
| 基础跳跃初速度 | `jump_initial` | -360.0 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md baseline §3.2; -6.0 px/f |
| 极速大跳初速度 | `super_jump_initial` | -430.0 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md baseline §3.2; -7.167 px/f |
| 旋转跳初速度 | `spin_jump_initial` | -280.0 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md baseline §3.2; -4.667 px/f |
| 上升重力（按住跳跃键） | `gravity_rise` | 900.0 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md baseline §3.2; 15.0 px/s/frame |
| 下落重力（松开/下落） | `gravity_fall` | 1800.0 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md baseline §3.2; 30.0 px/s/frame |
| 最大下落速度 | `max_fall` | 270.0 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md baseline §3.2; 4.50 px/f |
| 空中加速度系数 | `air_accel_factor` | 0.65 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md baseline §3.2; 0.65 × ground acceleration |
| 跳跃截断相关 | — | — | — | 已由双重力机制取代（REQ-PHYS-101） |

研究清单字段名映射：air_control 对应项目字段 air_accel_factor，buffer_frames 对应 jump_buffer_frames，anti_stick_velocity 对应 head_bump_speed。
出处追溯备注：该整理文件没有附外部原始 URL；REQ-PHYS-003 的直接链接仍待补入。此处 VERIFIED 是按 Gemini 研究清单导入，尚不代表本项目已独立复测。

数据核对备注：研究清单中的 ground_accel=225 px/s² 意味着从静止到 run_max=180 px/s 约需 48 个 60Hz 物理帧，而原文写约 24 帧；列出的跳跃初速度/上升重力与同文档的跳高描述也需要仪表盘逐帧核对。因此本表保留研究清单的 VERIFIED 参数值，M1 的 TUNED 验收以实测曲线为准，不把这些推导描述直接当作验收值。

试玩复核备注（2026-09-24）：`skid_decel=400` 的反向制动力被试玩判定偏弱，且缺少可复查的 SMM2 原始帧表，故降为 CANDIDATE；`skid_threshold` 与动画姿势切换也需逐帧验证。这些参数复测前不得升为 TUNED。动画 fps 曲线与跑步姿势切换阈值尚无已核实数值，见 REQ-PHYS-110/112。

新研究审计备注（2026-09-24）：`smm2_feel_and_animation_verified.md` 的部分链接只到站点首页，没有对应 SMM2 录像、时间码或原始帧表。该文件的动画公式把 px/s 再乘 60，单位不成立；“104 帧 / 240px 精确零误差”与 60Hz 离散积分的 241.5px 推导不完全一致。其 `800 px/s²` 来源于 NSMBU/NSMBW 的 `decel_skid`，不能当成 SMM2 实测；仅记录为旧作/相邻作品对照，不能直接覆盖本项目基线。以下其他新增值仅作 `CANDIDATE` 试玩参数，工程结果不能反向证明它们为 SMM2 VERIFIED。

### 3.1 新增手感与动画候选参数

| 参数 | Profile 字段 | 候选值 | 状态 | 研究来源 |
|---|---|---:|---|---|
| P-Meter 容量 | `p_meter_max` | 112 点 | CANDIDATE | `smm2_feel_and_animation_verified.md` §1.7 |
| 地面满速蓄积 | `p_meter_charge_per_frame` | 2 点/帧 | CANDIDATE | 同上 |
| 衰减 | `p_meter_decay_per_frame` | 1 点/帧 | CANDIDATE | 同上 |
| 低速采样速度 | `anim_low_speed` | 30 px/s | CANDIDATE | 同文 §1.1 |
| 低速动画帧率 | `anim_low_fps` | 3.3 fps | CANDIDATE | 同上 |
| `walk_max` 处动画帧率 | `anim_walk_fps` | 7.5 fps | CANDIDATE | 同上 |
| `run_max` 处动画帧率 | `anim_run_fps` | 15.0 fps | CANDIDATE | 同上 |
| `p_speed` 处动画帧率 | `anim_p_fps` | 18.0 fps | CANDIDATE | 同上 |
| 小型形态下蹲受击盒 | — | TBD | TBD | 报告的 8 px 未附 SMM2 原始受击测试，战斗受击盒系统尚未实现 |

## 4. 风格能力开关矩阵 (StyleAbilityMatrix)

**REQ-PHYS-005**: 风格专属能力通过 `data/physics/style_abilities.json` 门控。运行时读取到能力为 `false` 时必须禁用对应行为；`spin_jump` 在不支持的风格中按 REQ-INP-002 降级为普通跳跃。

| 能力 | 字段名 | SMB1 | SMB3 | SMW | 说明 |
|---|---|---|---|---|---|
| 旋转跳 | `spin_jump` | ✗ | ✗ | ✓ | 不支持时 ↓ 键降级为普通跳跃 |
| 搬举/投掷 | `carry` | ✗ | ✓ | ✓ | SMB1 不能举起龟壳等物品 |
| P-Meter 冲刺 | `p_meter` | ✗ | ✓ | ✓ | 满格后切换 `p_speed` 上限（见 REQ-PHYS-107） |
| 踢墙跳 | `wall_kick` | ✗ | ✗ | ✗ | 三风格均不支持（NSMBU 预留） |
| 耀西 | `yoshi` | ✗ | ✗ | ✓ | 骑乘系统（M3+ 范围） |
| 小型形态下蹲姿态 | — | ✓ | ✓ | ✓ | 项目负责人 SMM2 实际观察确认；不以旧作控制规则覆盖 |

**REQ-PHYS-009**: 能力矩阵的扩充（新风格 NSMBU/SM3DW、新能力）只需在本表与 `style_abilities.json` 追加行列，不得改动统一基线参数表结构。

## 5. 玩家碰撞尺寸

| 形态 | 宽 × 高（px） | 校准状态 | 出处 |
|---|---|---|---|
| 小型马里奥（站立） | 12 × 14 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md §3.4 |
| 小型马里奥（下蹲，全三风格） | 地形盒 TBD；受击盒 TBD | TBD | 项目负责人确认姿态存在；工程预览暂沿用 12 × 14 站立地形盒，未实现独立受击盒 |
| 大马里奥（站立） | 12 × 28 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md §3.4 |
| 大马里奥（下蹲） | 12 × 14 | VERIFIED | ../../TBDtoVERIFIED/smm2_physics_baseline.md §3.4 |

**REQ-PHYS-006**: 碰撞盒以 16px 格为参照定义，变身切换形态时碰撞盒原地切换，若新碰撞盒与地形重叠则按 REQ-PWR-005（下蹲保护）规则处理。

## 6. 验证方法

**REQ-PHYS-007**: 参数验证通过 `10-player-physics.md` 定义的数值仪表盘调试场景执行：场景实时绘制速度/位置曲线，验收时对照基准表逐项核对并录屏存档。M1 验收 = 数值达标（REQ-PHYS-002）+ 项目负责人试玩签认。
