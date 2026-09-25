# AGENTS.md — SMMneo 执行者守则

> 本文件是所有 AI agent（与人类协作者）进入本仓库的**必读守则**。
> 项目采用 SDD（规格驱动开发）：**spec 是宪法，代码是执行**。冲突时以 spec 为准。

## 0. 进场必读顺序

1. 本文件（守则与禁令）
2. `specs/README.md`（spec 库规则、REQ-ID 前缀表、铁律）
3. 任务单中列出的具体 spec 文件（只读与任务相关的章节）

## 1. 项目速览

- SMMneo：Godot 4.6+ 复刻 Super Mario Maker 2，目标平台 Win/macOS/Linux/Android。
- 物理架构：**统一物理基线 + 风格能力开关**（SMM2 真实架构，不是三风格三套参数）。
- 复刻基准：以 SMM2 实测为准，原作反汇编仅作对照（REQ-PHYS-100）。

## 2. 铁律（违反即打回）

1. **Foundation 严格最小集**：共享契约只进 `specs/00-foundation.md`。
2. **引用不重复**：功能实现引用 spec 的 REQ-ID，禁止在代码注释里复制 spec 定义。
3. **REQ-ID 终身制**：不复用、不改义；废弃标 `DEPRECATED`。
4. **变更受控**：`approved` 状态的 spec 不许改；`draft` 可改但要升版本号 + changelog。
5. **TBD 禁令**：spec 中标注 `TBD` 的参数/数值**禁止编造填充**。遇到 TBD 阻塞时停下，在回报中明确列出"被哪些 TBD 阻塞"，由架构师裁决。

## 3. 编码标准速查（详见 REQ-STD-001~005）

- GDScript 强制静态类型；函数/变量蛇形，类大驼峰，常量全大写蛇形。
- 跨系统通信用信号；gameplay 实体禁止引用 Autoload 以外的单例。
- 禁止 magic number：物理数值只能来自 `PlayerPhysicsProfile`；其余配置进 `res://data/`。
- 源码只放 `res://src/`（拓扑见 REQ-ARC-010）；测试放 `res://test/`（GUT）。
- 输入只消费逻辑 Action（REQ-INP-001），禁止直接判断物理按键。

## 4. 验证命令

```bash
# Godot 可执行路径（本机）：C:\!application\tools\Godot\Godot_v4.7.2-stable_win64.exe

# 导入并检查项目错误（应零错误零警告关键项）
godot --headless --import

# 运行 GUT 测试
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit

# 主场景冒烟运行（120 帧后自动退出）
godot --headless --quit-after 120
```

每个任务完成后必须执行适用命令并在回报中粘贴结果摘要。

## 5. 任务单流程

- 任务以 `tasks/` 下的任务单下达（模板见 `tasks/TEMPLATE.md`）。
- 只执行任务单范围内的修改；发现范围外问题，记入回报"范围外发现"栏，禁止顺手修改。
- 回报必须包含：完成项核对、验证命令输出摘要、TBD 阻塞清单、范围外发现。

## 6. 资产红线

- 仓库内**不存在**任何游戏媒体文件；`textures/`、`audio/` 不入库（REQ-AST-001）。
- 占位素材由 `tools/gen_placeholders.gd` 生成；真实素材走本地资产管线，禁止提交。
