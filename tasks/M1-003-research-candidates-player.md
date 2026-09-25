# 任务单：M1-003-接入手感研究候选值

> **状态**: in_progress
> **下达日期**: 2026-09-24
> **执行者**: Codex
> **关联里程碑**: M1

## 目标

把 `../../TBDtoVERIFIED/smm2_feel_and_animation_verified.md` 的可试玩候选值接入 Player 控制器、Profile 和仪表盘，保留证据不足的校准标记。

## REQ-ID 引用清单

| REQ-ID | 所在 spec | 要点摘要 |
|---|---|---|
| REQ-PHYS-001/005/006/008 | `specs/01-physics-profiles.md` | 校准状态、风格门控、碰撞盒、统一基线 |
| REQ-PHYS-106/107/108/110/112 | `specs/10-player-physics.md` | 刹车、P-Meter、仪表盘、动画和跑姿 |

## 涉及文件

- 修改：`specs/01-physics-profiles.md`、`specs/10-player-physics.md`、`data/physics/base_physics.tres`、`src/gameplay/player/player_physics_profile.gd`、`src/gameplay/player/player_controller.gd`、`src/gameplay/debug/physics_dashboard.gd`、`data/i18n/strings.csv`。`data/physics/style_abilities.json` 已有正确门控，无须改动。
- 暂不处理：P-Run 专用贴图/帧条映射、投掷物系统、完整 PowerUpManager 与战斗受击盒。

## 实施要点

1. 800 px/s² 刹车仅为 NSMBU 对照值，不进入 SMM2 Profile；动画 fps 与 P-Meter 112/+2/-1 可作为待试玩候选值。
2. P-Meter 按风格能力门控，满格解锁 P-Speed 和大跳；刹车、下蹲、撞墙及死亡清零。
3. 走/跑动画帧率依据候选采样点插值；跑姿继续按工程预览在 `run_max` 切换，P-Run 逻辑复用现有 run 帧条，独立姿态待证据。
4. SMB1/SMB3/SMW 小型下蹲均保留；地形与受击盒待后续 SMM2 实测。
5. 仪表盘显示 P-Meter、当前帧率及姿态，供项目负责人试玩签认。

## 禁止事项

- 不将站点首页、旧作反汇编或数学推导冒充 SMM2 可复查实测证据。
- 未获得原始逐帧录像/表格前不把本任务候选值标为 TUNED。
- 不新增媒体到仓库。

## 验收标准

- [x] Profile、spec 与控制器中的候选参数一致。
- [ ] 逐帧检查现有刹车、动画 fps 样本、跑姿门槛和 P-Meter 时序。
- [ ] SMB1/SMB3/SMW 小型下蹲均可用。
- [ ] Godot 导入、仪表盘、主场景和已有 GUT 用例运行。

## 当前进展与待签认项

- 已接入候选 P-Meter、P-Speed、大跳、随速度变化的动画 fps；仪表盘显示 P-Meter、帧率、动画并加长了直线跑道。
- 800 px/s² 仍只作 NSMBU 对照；当前 400 px/s² 从 VERIFIED 降为 CANDIDATE，等待 SMM2 原始逐帧证据与项目负责人试玩。
- 本地确认 SMB1/SMB3/SMW 的小型下蹲帧均存在（16×32 单帧）。当前场景仅加载 SMW 帧，跨风格资产接入另行处理。
- `mario_small_run_Strip2.png` 为项目当前 run 帧条，不标作 P-Run 专用；P-Run 暂复用 run 动画。
- Godot 导入、仪表盘场景和主场景均以退出码 0 启动。导入期间 Godot MCP 插件监听失败；运行场景时日志目录与系统证书有环境错误。GUT 与交互式逐帧试玩尚未执行。
- 待补：SMM2 原始刹车速度表、P-Meter 帧表、动画切换帧表、小型下蹲地形/受击盒测试，以及项目负责人在仪表盘的 TUNED 签认。
