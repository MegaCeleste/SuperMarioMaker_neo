# 00 - Foundation 共享契约（宪法）

> **状态**: draft
> **版本**: 0.2.0
> **日期**: 2026-09-23
> **Changelog**: 0.1.0 初版（自 `.spec` v1.1.0 §1/2/3.1/8.1/15 拆分；修正 "2D Jolt Physics" 错误）→ 0.2.0 默认键位改为 SMMWE 布局；新增 REQ-INP-002 旋转跳降级规则、REQ-INP-003 键位重绑、REQ-INP-004 命名对齐
> **收录标准**: 只收录被 ≥2 个功能 spec 共享的契约。单一功能内部的设计决定不属于本文件。

---

## 1. 引擎与平台基线 (ARC)

- **REQ-ARC-001**: 引擎基线为 Godot Engine **4.6+**。渲染通道使用 **Mobile Renderer**（低开销、全平台像素完美 2D 输出），禁止依赖 Forward+ 独占特性。
- **REQ-ARC-002**: 2D 物理使用 **Godot 内置 Godot Physics 2D**。禁止引入 3D 物理扩展（如 Godot Jolt，仅支持 3D）用于 2D  gameplay。
- **REQ-ARC-003**: 游戏逻辑一律运行在 **60Hz 固定物理帧**（`_physics_process`）。任何手感、计时、动画帧数相关的常数均以"物理帧"为单位定义，禁止依赖渲染帧率。
- **REQ-ARC-004**: 目标平台：Windows (x86_64)、macOS (Universal)、Linux (x86_64)、Android (ARM64)。所有功能设计必须可在四平台运行；平台差异只允许出现在输入与 UI 层。
- **REQ-ARC-005**: 游戏内坐标与尺寸以 **16×16 像素网格**为基本单位；1 格 = 16px。关卡边界、实体坐标均以格为单位存储。

## 2. 目录拓扑与迁移 (ARC)

```
res://
├── assets/                  # 游戏媒体资源（本地解包挂载，不入库的商业素材）
├── data/                    # 数据驱动配置
│   ├── i18n/strings.csv     # 多语言表
│   ├── physics/             # 统一物理基线 (.tres) 与风格能力配置 (.json)
│   └── registry/objects.json # 对象注册表（见 02-object-registry.md）
├── src/                     # 全部源代码
│   ├── autoload/            # 单例服务
│   ├── core/                # 命令栈、组件库、数据模型
│   ├── editor/              # 关卡编辑器
│   ├── gameplay/            # 游玩实体（Player, Blocks, Enemies, Mounts）
│   └── ui/                  # HUD、触屏按键、CourseBot 界面
└── test/                    # GUT 单元与集成测试
```

- **REQ-ARC-010**: 全部 GDScript 源码必须位于 `res://src/`，场景文件就近放在所属系统目录。禁止新增顶层 `scripts/`、`scenes/` 目录。
- **REQ-ARC-011**: M0 第一个任务为**目录迁移**：将现有 `scripts/`、`scenes/` 内容迁入上述拓扑并修复全部引用。迁移完成前禁止开发新功能。
- **REQ-ARC-012**: 核心单例（Autoload）限定为：`GameManager`、`Registry`、`LevelManager`、`InputManager`、`GizmoEventBus`、`AudioManager`、`CourseBot`。新增 Autoload 必须修改本条约并升版本号。

## 3. 2D 物理碰撞分层 (COL)

严格 7 层，Godot 碰撞层编号即语义编号：

| 层 | 名称 | 内容 |
|---|---|---|
| 1 | `Solids` | 地形实心方块、地面、硬块、管道外壁、激活态开关块 |
| 2 | `Player` | 马里奥主体 |
| 3 | `Enemies` | 活动敌对实体（栗子球、慢慢龟、吞食花、刺顶类） |
| 4 | `Pickups` | 道具（金币、蘑菇、火花、无敌星） |
| 5 | `Projectiles` | 被踢出的龟壳、玩家火球、敌人炮弹、飞锤 |
| 6 | `Semisolids` | 单向板（自下而上跳穿、顶部站立） |
| 7 | `Sensors` | 区域触发器（终点、钥匙门、管道入口、深渊销毁线） |

- **REQ-COL-001**: 所有实体必须且只能使用上表 7 层；新增层必须修改本文件并升版本号。
- **REQ-COL-002**: 每层的 `collision_layer` 与 `collision_mask` 配置必须集中在 `res://data/` 的配置文件中定义，实体场景不得私自硬编码掩码组合。
- **REQ-COL-003**: 实体间交互（踩踏、受击、拾取）优先通过 Layer 7 的 `Area2D` 传感器 + 信号实现，禁止用轮询位置重叠代替碰撞事件。

## 4. 跨端输入语义 (INP)

引擎内部一律监听抽象 Action，禁止在 gameplay 代码中直接判断物理按键。

默认键位遵循 SMMWE 规范：WASD 负责移动意图，方向键负责动作。

| 逻辑 Action | PC 键盘（默认） | 手柄 | Android 触控 | 说明 |
|---|---|---|---|---|
| `move_left` / `move_right` | A / D | 左摇杆 / 十字键 | 虚拟摇杆 / 十字键 | 水平移动 |
| `move_up` | W | 左摇杆上 / 十字键上 | 虚拟摇杆上 | 抬头、进上方管道、攀爬 |
| `move_down` | S | 左摇杆下 / 十字键下 | 虚拟摇杆下 | 下蹲、进下方管道 |
| `jump` | ↑ | A / B | 右侧 `B` 触控键 | 跳跃 |
| `run` | ← | X / Y | 右侧 `Y` 触控键 | 冲刺 / 发射火球 / 抓取（动作键） |
| `spin_jump` | ↓ | R | 右侧 `A` 触控键 | 旋转跳（见 REQ-INP-002 降级规则） |
| `editor_undo` / `editor_redo` | Ctrl+Z / Ctrl+Y | — | 编辑器 HUD 按钮 | |
| `toggle_maker_play` | Tab | Select | 顶部 HUD 图标 | |

- **REQ-INP-001**: 所有 gameplay 与编辑器逻辑只消费上表逻辑 Action；物理按键/手柄按钮/触控事件的映射只发生在 `InputManager` 单例内。
- **REQ-INP-002**: 新增逻辑 Action 必须先登记本表。`spin_jump` 在不支持旋转跳的风格（SMB1/SMB3）中必须**降级表现为普通跳跃**，而非静默无效或报错。
- **REQ-INP-003**: 全部键盘绑定允许玩家自由重绑。自定义绑定持久化到 `user://` 配置文件，`InputManager` 启动时加载覆盖默认表；重绑必须检测并阻止按键冲突；重绑 UI 归属后续设置界面 spec（见 `backlog-draft.md`）。
- **REQ-INP-004**: 本表逻辑 Action 命名为权威命名。现有工程中 `player_*` 旧命名在 M0 目录迁移（REQ-ARC-011）时统一更名对齐。

## 5. 编码与工程标准 (STD)

- **REQ-STD-001**: GDScript 强制静态类型注解（变量、参数、返回值）。函数与变量蛇形命名，类名大驼峰，常量全大写蛇形。
- **REQ-STD-002**: 跨系统通信优先使用信号（Signal）解耦；禁止 gameplay 实体直接引用 Autoload 以外的其他实体单例。
- **REQ-STD-003**: 一切 magic number 必须来自配置文件（`res://data/`）或具名常量；物理相关数值只允许来自 `PlayerPhysicsProfile` 资源（见 `01-physics-profiles.md`）。
- **REQ-STD-004**: 测试使用 GUT 框架，置于 `res://test/`。新增核心系统（组件库、注册表、命令栈、关卡序列化）必须附带 GUT 用例。
- **REQ-STD-005**: 所有 UI 文本必须经 `tr("KEY")` 绑定，翻译表为 `res://data/i18n/strings.csv`，首发语言 `zh_CN` 与 `en_US`。
