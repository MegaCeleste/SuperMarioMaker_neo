# 任务单：M1-001-Player 控制器与物理仪表盘

> **状态**: done
> **下达日期**: 2026-09-24
> **执行者**: Codex
> **关联里程碑**: M1

## 目标

把现有 Player 的运动接入统一物理 Profile，并交付可独立运行的试玩仪表盘。

## REQ-ID 引用清单

| REQ-ID | 所在 spec | 要点摘要 |
|---|---|---|
| REQ-PHYS-006/008 | `specs/01-physics-profiles.md` | 碰撞尺寸与唯一物理基线 |
| REQ-PHYS-101~106/108/109 | `specs/10-player-physics.md` | 跳跃、纠偏、滑行、仪表盘和移动状态 |
| REQ-PHYS-005/107 | `specs/01-physics-profiles.md` / `specs/10-player-physics.md` | 能力门控；P-Meter 曲线仍 TBD |
| REQ-ARC-003、REQ-STD-001~005 | `specs/00-foundation.md` | 60Hz、类型、配置、测试与 UI 翻译 |

## 涉及文件

- 新建：`src/gameplay/player/player_controller.gd`、`src/gameplay/debug/*`、`src/core/collision_config.gd`、`data/physics/collision_layers.json`、`data/i18n/strings.csv`
- 修改：`src/gameplay/player/state/player.gd`、`src/gameplay/player/player_physics_profile.gd`、`data/physics/base_physics.tres`、`src/gameplay/enemies/goomba.gd`、`src/gameplay/entities/mushroom.gd`、`specs/10-player-physics.md`
- 暂不处理：完整 `PowerUpManager`、搬运投掷与 P-Meter 数值曲线。

## 实施要点

1. Player 移动只由一个 `_physics_process` 控制，旧状态节点不再更新运动。
2. 保留 `die()`、`bounce()`、`collect_mushroom()` 供现有关卡调用。
3. 独立仪表盘显示速度、位置、移动状态、跳高及五秒横向速度曲线。
4. P-Meter 的曲线维持 TBD，在仪表盘显式标记，勿用研究候选值冒充已定规范。

## 禁止事项

- 禁止编造 TBD 参数。
- 禁止把媒体文件加入仓库。
- 禁止把工程内未试玩的数据标记为 TUNED。

## 验收标准

- [x] 玩家从 `base_physics.tres` 获取全部运动数值。
- [x] 现有关卡仍可通过原 Player 接口交互。
- [x] 仪表盘可运行，并显示五秒速度曲线及 P-Meter 待定状态。
- [x] Godot 导入、仪表盘与主场景冒烟检查通过。

## 验证命令

```bash
godot --headless --import
godot --headless --scene res://src/gameplay/debug/physics_dashboard.tscn --quit-after 120
godot --headless --quit-after 120
```

## 完成回报

- 完成项核对：四项任务验收项均已实现；试玩手感仍需项目负责人在 Godot 中确认。
- 验证输出：导入、仪表盘 120 帧、主场景 120 帧均退出码 0，未报 Player 脚本错误。受控输入探针确认落地、向右跑 40 帧达到 150 px/s、起跳后进入 AIR（第 5 帧 `velocity.y=-300 px/s`）。GUT 当前未发现可运行用例（`Nothing was run`）。
- TBD 阻塞：P-Meter 蓄衰曲线和受击/变身完整流程仍未写入本任务实现；投掷动力学与搬运也不在本任务范围，均不得据此标记 TUNED。
- 范围外发现：本机无头导入会输出 Godot MCP 插件 `listen` 空对象、根证书及编辑器设置写入错误；主场景与试玩场景启动时还会输出 `user://logs` 写入失败，但均未导致 Player 场景加载失败。
