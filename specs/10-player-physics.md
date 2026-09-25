# 10 - 玩家手感核心算法 (Player Feel)

> **状态**: draft
> **版本**: 0.6.2
> **日期**: 2026-09-24
> **Changelog**: 0.1.0 初版 → 0.2.0 双重力与现代辅助 → 0.3.0 统一基线 → 0.3.1 摩擦/刹车分离 → 0.4.0 移动状态与帧顺序 → 0.5.0 试玩反馈及待调研项 → 0.6.0 研究候选值审计 → 0.6.1 纠正 NSMBU 刹车值及旧作下蹲规则误用，核对现有 run 帧条 → 0.6.2 核对三风格小型下蹲素材和 P 跳姿态
> **引用**: `01-physics-profiles.md`（全部数值常数）、REQ-ARC-003（物理帧）、REQ-COL-001（碰撞层）

玩家控制器为 `CharacterBody2D`，全部运动学常数来自**统一基线** `PlayerPhysicsProfile`（REQ-PHYS-008），风格差异通过能力开关门控（REQ-PHYS-005）。本文件只定义算法行为，不定义数值。

## 0. 校准原则

**REQ-PHYS-100**: 本项目复刻对象为 **SMM2**。凡 SMM2 与原原作（SMB1/SMB3/SMW）行为不一致处（如 SMM2 内置的拐角纠偏），**以 SMM2 实测数据为准**，原作反汇编数据仅作对照参考。每项机制标注其来源：`SMM2 原生` / `现代辅助（本项目内置）`。

**REQ-PHYS-100a**: 三项手感辅助（土狼时间、跳跃缓冲、拐角纠偏）为**常开内置行为，不提供配置开关**。

## 1. 核心手感算法

**REQ-PHYS-101 变高跳跃（双重力机制）** `SMM2 原生`
跳跃高度通过双重力实现：上升阶段且按住 `jump` 时应用较小的上升重力 `gravity_rise`；松开 `jump` 或进入下落（`velocity.y >= 0`）后应用较大的下落重力 `gravity_fall`。两值见 01-physics-profiles.md，当前 VERIFIED；工程验收后升为 TUNED。禁止使用"松开按键乘系数"的简化实现。

**REQ-PHYS-102 土狼时间 (Coyote Time)** `现代辅助`
离开平台边缘后的 N 物理帧内仍允许起跳（N=6 物理帧，Profile 字段 coyote_frames，当前 VERIFIED）。土狼窗口自离地当帧计时，起跳或超时即失效；窗口内起跳与平地起跳行为完全一致。

**REQ-PHYS-103 跳跃输入缓冲 (Jump Buffering)** `现代辅助`
落地前 M 物理帧内按下 `jump`（M=5 物理帧，Profile 字段 jump_buffer_frames，当前 VERIFIED），着地第一物理帧自动触发跳跃。缓冲在起跳或超时后清除，不可叠加多次按压。

**REQ-PHYS-104 拐角纠偏 (Corner Correction)** `SMM2 原生`
头顶碰撞上方实心方块且水平偏差在 1~3px 内时，检测左右空隙，向最近可通过方向自动平移滑过棱角；两侧均不可通过时按正常顶头处理。纠偏不消耗水平速度。最大纠偏距离为 3.0px，Profile 字段 corner_correction_max，当前 VERIFIED。

**REQ-PHYS-105 顶块交互与防黏连** `SMM2 原生`
头部撞击且碰撞法线 `normal.y > 0.5` 时：对被撞击方块触发 `hit_by_player()`（携带玩家状态与撞击方向），随后将玩家垂直速度重置为+10px/s，Profile 字段 head_bump_speed，当前 VERIFIED，防止与方块底面黏连。一帧内撞击多方块时只对水平重叠最大的一个触发交互。

## 2. 地面与滑行

**REQ-PHYS-106**: 松开方向键时的地面自然减速使用 Profile 的 `friction_normal`；反向输入时使用 `skid_decel`。当前水平速度达到 `skid_threshold` 且方向相反时进入滑行状态（播放滑行动画与音效）。进入后，即使速度降至触发阈值以下，也持续使用刹车阻尼和滑行动画，直到松开反向输入、离地、速度归零或反向完成。参数值及校准状态统一定义于 `01-physics-profiles.md`；现有 `skid_decel` 经试玩反馈力度不足，需重新测量，禁止标记 TUNED。

**REQ-PHYS-107**: 达到 `run_max` 后维持按住 `run` 可保持极速；当前风格能力开关 `p_meter` 开启时（REQ-PHYS-005），地面满速持续奔跑每帧蓄积 `p_meter_charge_per_frame`，满 `p_meter_max` 后速度上限切换为 `p_speed`，普通跳跃改用 `super_jump_initial`，并在当前 SpriteFrames 含 `p_jump` 时使用该上升姿态。地面未满足蓄积条件时每帧扣除 `p_meter_decay_per_frame`；空中保持原方向输入且未撞墙时冻结，否则按该值衰减。刹车、下蹲、撞墙、受伤、进门/管道时清零。`p_meter` 关闭的风格保持 0。112/+2/-1 是 `CANDIDATE`，不是 TUNED；进门/管道事件的连接归相应交互系统任务。

**REQ-PHYS-109 移动状态与逐帧顺序**: Player 显式暴露互斥的 `IDLE`、`RUN`、`AIR`、`CROUCH`、`SKID`、`DEAD` 移动状态，并在状态转换时发信号；旋转跳是 `AIR` 中的跳跃类型，不复用变身状态机。每物理帧按“读取逻辑 Action 与缓冲 → 更新碰撞盒及水平速度 → 消费合法跳跃 → 应用双重力 → 拐角纠偏 → `move_and_slide()` 一次 → 处理顶块及落地缓冲 → 发布状态与动画”的顺序运行。`PowerUpManager` 的形态状态独立于移动状态，遵循 `11-player-statemachine.md`。

**REQ-PHYS-110 速度驱动移动动画**: 行走/跑步动画的帧切换速度随水平速度绝对值增加。工程预览以 Profile 的 `(30,3.3)`、`(walk_max,7.5)`、`(run_max,15)`、`(p_speed,18)`（速度 px/s、动画 fps）候选采样点分段线性插值，再按 SpriteFrames 原始 fps 算出 `speed_scale`；低于 30 px/s 时从静止线性插值。采样点及插值形状均为 CANDIDATE，须依据 SMM2 原始逐帧表校准。

**REQ-PHYS-111 下蹲跳姿态**: SMB1、SMB3、SMW 的小型形态均可下蹲，遵循项目负责人对 SMM2 的直接试玩观察；Gemini 报告中“小型 SMB1/SMB3 不可下蹲”混入旧作规则，已驳回。本地拆包目录 `TBDtoVERIFIED/textures/styles/{smb1,smb3,smw}/player/` 均有 `mario_small_duck_Strip1.png`，各为 16×32 单帧；工程 SMW `small/duck.png` 与 SMW 拆包帧像素一致。下蹲时起跳后保持下蹲姿态至落地，即使空中松开下方向也不立即切回普通跳跃姿态。移动状态仍为 `AIR`。小型下蹲地形盒/受击盒尚无 SMM2 可复查数值；工程预览暂保留站立地形盒，不声称其为已验证的下蹲尺寸。SMB1/SMB3 风格贴图尚未接入游戏场景。

**REQ-PHYS-112 走路到跑步姿势切换**: 按住 `run` 并加速后从走姿切到跑姿；当前工程预览仍以 `run_max` 为切换点。报告提出的 `abs(vx)>walk_max`/第 23 帧与项目负责人“切换过早”的试玩反馈冲突，缺少 SMM2 原始帧表，暂不采用。`mario_small_run_Strip2.png` 与工程 `textures/player/mario/small/run.png` 像素完全相同，均为 2 帧 16×32 正常跑步条，不能称为已确认的“P-Run 专用贴图”。当前 P-Run 逻辑暂时复用 run 动画；独立 P-Run 姿态是否存在及素材映射继续待核对。

### 待调研数据（不得直接标记 TUNED）

| 项目 | 需要研究员提供的证据 | 当前工程预览 |
|---|---|---|
| 走/跑动画速度曲线 | 提供 SMM2 录像 ID/时间码、每档速度与帧率原始计数 | 按 3.3/7.5/15/18 fps 候选样本插值 |
| 跑步姿势切换条件 | 从静止按住 `run` 的 SMM2 原始录像/帧表，确认身体前倾与 P-Run 的各自切换帧 | 工程预览保持达到 `run_max` 时切换 |
| 反向刹车力度和时长 | SMM2 在 `run_max` 反向输入的逐帧速度与归零帧数，不能以 NSMBU 参数代替 | 基线暂保留 `skid_decel=400 px/s²`，待手感重测 |
| 小型形态下蹲碰撞盒 | SMM2 三风格地形/受击盒分别测量 | 三风格可下蹲；工程预览沿用站立地形盒 |
| P-Meter 蓄衰与清零 | 逐帧计数与跑道距离原始记录，区分 SMM2 与旧作 | 112/+2/-1 候选，可在仪表盘试玩 |

## 3. 验收标准（M1）

**REQ-PHYS-108 数值仪表盘调试场景**
M1 验收前必须交付 `res://src/gameplay/debug/physics_dashboard.tscn`：可自由跑跳的测试场景，HUD 实时显示 `velocity`、`position`、P-Meter、当前状态机状态，并可绘制最近 5 秒速度曲线。

验收清单：
1. 仪表盘实测：走/跑/P-Speed 极速与 Profile 一致（REQ-PHYS-002 达标后对照基准表）；
2. 短按/长按跳跃高度比与双重力参数的理论曲线吻合；
3. 土狼窗口边界逐帧验证：窗口内可跳、窗口外第一帧不可跳；
4. 缓冲窗口边界逐帧验证：窗口内落地自动起跳、窗口外失败；
5. 纠偏阈值边界验证：阈值内擦角通过不卡头、阈值外正常顶头；
6. 顶问号块触发弹出动画且玩家不黏连；
7. 项目负责人试玩签认手感。
