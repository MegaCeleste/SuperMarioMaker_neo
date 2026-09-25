# 任务单：M0-001-基座构建与目录迁移（回填示例）

> **状态**: done
> **下达日期**: 2026-09-23
> **执行者**: Kimi（架构师代理）
> **关联里程碑**: M0

## 目标

建立 M0 基座：工作流脚手架、资产合规、目录迁移（REQ-ARC-011）、输入对齐（REQ-INP-004）、Autoload 骨架、对象注册表、组件库、命令栈、统一物理资源、GUT 测试框架。

## REQ-ID 引用清单

| REQ-ID | 所在 spec | 要点摘要 |
|---|---|---|
| REQ-ARC-010/011/012 | `specs/00-foundation.md` | src/ 拓扑、目录迁移、Autoload 清单 |
| REQ-INP-001~004 | `specs/00-foundation.md` | 逻辑 Action、SMMWE 键位、重绑、命名对齐 |
| REQ-AST-001~006 | `specs/05-asset-pipeline.md` | 仓库零媒体、切片清单、导入向导 |
| REQ-PHYS-001/005/008 | `specs/01-physics-profiles.md` | TBD 制度、能力开关、统一基线 |
| REQ-REG-001/002/005 | `specs/02-object-registry.md` | 注册表加载校验、Schema、组件清单 |
| REQ-LVL-005 | `specs/03-level-format.md` | RLE 编解码 |

## 涉及文件

- 新建：`AGENTS.md`、`tasks/TEMPLATE.md`、`specs/05-asset-pipeline.md`、`tools/gen_placeholders.gd`、`src/autoload/*`（7）、`src/core/components/*`（7）、`src/core/commands/*`（2）、`src/gameplay/player/player_physics_profile.gd`、`data/registry/objects.json`、`data/physics/{base_physics.tres,style_abilities.json}`、`test/unit/*`（3）、`addons/gut/`（v9.6.1）
- 修改：`.gitignore`（排除 textures/ audio/）、`project.godot`（autoload、输入、Mobile 渲染器）、`specs/{README,00,01,10,backlog-draft}.md`、迁移 `scripts/`+`scenes/` → `src/`（44 个 rename）
- git rm --cached：`textures/`、`audio/` 共 601 个媒体文件（保留磁盘文件，未 commit）

## 完成回报

- 完成项核对：见上"涉及文件"，全部落地
- 验证输出（2026-09-24，Godot v4.7.2-stable）：
  - `godot --headless --import`：通过（仅 godot_mcp 插件在 headless 下的固有警告，与项目代码无关）
  - GUT CLI：**13/13 通过**（22 断言，0.456s）
  - 主场景 headless 运行 120 帧：零报错，Registry 正常加载 5 个注册对象
  - JSON 合法性、旧路径/旧 action 名 grep：通过
- TBD 阻塞：物理基线全部参数按 spec 保持 TBD（REQ-PHYS-001），未填任何编造值；M1 前需安排 SMM2 实测数据收集
- 范围外发现：
  1. `project.godot` 中 `config/features` 曾被子任务误改为 "4.7"，已修正回 "4.6"+"Mobile"
  2. `scripts/.clineignore` 迁移至根目录 `.clineignore`
  3. 玩家控制器现有 `max_run_speed` 等常量是硬编码，接入 `PlayerPhysicsProfile` 属 M1 任务
  4. spec 01 §3 曾缺 `p_speed` 行（被 REQ-PHYS-107 引用），已补
