# SMMneo 规格说明书库 (Specs)

> **状态**: approved
> **版本**: 1.2.0
> **日期**: 2026-09-23
> **Changelog**: 1.0.0 初版（自 `.spec` / `SPEC.md` v1.1.0 拆分重组）→ 1.1.0 新增 `04-lighting.md` 与 `LGT` 前缀 → 1.2.0 新增 `05-asset-pipeline.md` 与 `AST` 前缀；`01-physics-profiles.md` 重构为统一基线+能力开关

本目录是 SMMneo 项目的**唯一规格事实来源**（Single Source of Truth）。旧版 `.spec` 与 `SPEC.md` 已废弃，内容按本目录结构拆分归档。任何设计决定以本目录内文件为准；代码与本目录冲突时，改代码或走变更流程改 spec，不允许两者长期不一致。

## 索引

| 文件 | 内容 | 状态 |
|---|---|---|
| `00-foundation.md` | 宪法级共享契约：引擎基线、碰撞分层、输入语义、目录拓扑、编码标准 | draft |
| `01-physics-profiles.md` | 统一物理基线参数与风格能力开关矩阵 | draft |
| `02-object-registry.md` | `objects.json` 对象注册表 Schema 契约 | draft |
| `03-level-format.md` | 关卡 JSON 数据契约（`.smmlevel`） | draft |
| `04-lighting.md` | 法线贴图光影系统（SMM2 差异化增强，默认关闭） | draft |
| `05-asset-pipeline.md` | 资产管线：仓库零媒体、帧条切片清单、导入向导 | draft |
| `10-player-physics.md` | 玩家手感五大核心算法 | draft |
| `11-player-statemachine.md` | 变身/受击降级状态机 | draft |
| `backlog-draft.md` | M2~M5 内容（编辑器、音频、CourseBot 等），待逐个定稿拆分 | draft |

编号约定：`0x` 为 foundation（共享契约），`1x` 为 M1 玩家系统，后续 `2x` 编辑器、`3x` 关卡机制、`4x` 跨端与音频、`5x` 仓储与交付。

## 铁律

1. **Foundation 严格最小集**：`00-foundation.md` 只收录跨功能共享契约（碰撞层、物理参数基准、输入语义、注册表 Schema 引用、关卡格式引用、目录拓扑、编码标准、引擎基线）。任何"只属于单一功能"的内容禁止进入。
2. **引用不重复**：功能 spec 涉及共享契约时，只准引用 foundation 的 REQ-ID，禁止复制/重述其定义。发现重复定义必须立即回流 foundation。
3. **REQ-ID 终身制**：REQ-ID 一经分配，永不复用、永不更改含义。废弃的需求标记 `DEPRECATED` 并保留原文，不删除。
4. **变更受控**：spec 进入 `approved` 状态后，任何修改必须升版本号并在 Changelog 记录原因。`draft` 状态可自由修改。
5. **状态生命周期**：`draft`（可改）→ `approved`（定稿，变更受控）→ `deprecated`（废弃，保留存档）。

## REQ-ID 前缀表

| 前缀 | 领域 | 定义位置 |
|---|---|---|
| `ARC` | 架构、目录拓扑、引擎基线 | `00-foundation.md` |
| `COL` | 2D 物理碰撞分层 | `00-foundation.md` |
| `INP` | 跨端输入语义 | `00-foundation.md` |
| `STD` | 编码与工程标准 | `00-foundation.md` |
| `PHYS` | 物理参数矩阵与手感算法 | `01-physics-profiles.md` / `10-player-physics.md` |
| `REG` | 对象注册表 | `02-object-registry.md` |
| `LVL` | 关卡数据契约 | `03-level-format.md` |
| `PWR` | 变身与受击降级 | `11-player-statemachine.md` |
| `LGT` | 法线贴图光影 | `04-lighting.md` |
| `AST` | 资产管线与合规 | `05-asset-pipeline.md` |

新功能 spec 立项时，先在本表登记新前缀，再分配 REQ-ID。
