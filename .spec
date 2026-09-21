# ==============================================================================
# Super Mario Maker Neo (SMMneo) - 工业级软件设计规格说明书 (SDD Specification)
# 规范版本: 1.1.0-FINAL-APPROVED
# 制定日期: 2026-09-21
# 规范方法: SDD (Spec-Driven Development) / IEEE 1016 体系标准
# 目标平台: Windows (x86_64), macOS (Universal), Linux (x86_64), Android (ARM64)
# 核心基座: Godot Engine 4.6+ (Mobile 渲染器, Forward+ 兼容, 2D Jolt Physics)
# ==============================================================================

================================================================================
目录 (Table of Contents)
================================================================================
1. 项目愿景与设计总则 (Vision & Guiding Principles)
2. 全局架构与子系统拓扑 (Architecture & Subsystems)
3. 2D 物理碰撞分层与手感动力学规范 (Physics Layers & Multi-Style Dynamics)
4. 核心对象模型与组件系统 (Data-Driven Entity-Component Model)
5. 关卡数据契约与存储架构 (Level Data Contract & CourseBot Repository)
6. 关卡编辑器规格说明 (Course Maker Specification)
7. 核心游戏玩法子系统 (Gameplay Subsystems & Rules)
8. 全平台跨端输入与触控交互 (Cross-Platform Input & Touch UX)
9. 动态摄像机与卷轴控制系统 (Dynamic Camera & Autoscroll)
10. 全局机关与事件总线系统 (Gizmo Event Bus & Interactive Blocks)
11. 动态音频系统规格 (Dynamic Audio Engine & Music State Machine)
12. 智能 Tile 与场景主题管理 (Smart Tile & Themes)
13. 资产隔离与本地解包管道 (Asset Pipeline & Legal Separation)
14. 国际化与本地化规范 (i18n & Localization)
15. 工程目录拓扑与编码标准 (Project Structure & Coding Standards)
16. 实施路线图与里程碑 (Roadmap & Milestones)

================================================================================
1. 项目愿景与设计总则 (Vision & Guiding Principles)
================================================================================
1.1 项目定位
SMMneo 是一个基于 Godot 4 引擎、面向全平台打造的《Super Mario Maker 2》(SMM2) 完美像素级工业复刻。
本项目以极高质量复现：
  - 核心风格：优先完整实现 SMB1、SMB3、SMW 三种核心风格的手感、视觉、实体与专属机制，架构预留 NSMBU 与 SM3DW。
  - 双模核心：自由度极高的关卡创作编辑器 (Course Maker) 与 100% 物理确定性的关卡游玩引擎 (Course Play)。
  - 全端通达：在桌面 PC (Windows, macOS, Linux) 与 移动设备 (Android) 均具备一流的原生级操作体验。
  - 架构优雅：采用数据驱动 (Data-Driven) 与轻量组件化 (ECS-Lite)，编辑器与引擎共享统一对象注册表。
  - 合法合规：核心仓库与任何任天堂受版权保护的美术/音频资产彻底物理隔离，提供本地资产导入解包向导。

1.2 核心设计总则
  - 确定性物理与手感至上 (Handfeel Precision): 必须精准还原马里奥的惯性曲线、滑行制动、变高跳截断、土狼时间与拐角微调纠偏。
  - 数据与运行时表现彻底解耦: 关卡文件仅描述语义 ID、网格坐标与参数，不直接存储场景实例或二进制脏数据。
  - 零污染热测试 (Zero-Pollution Playtesting): 采用“独立运行树克隆 (Isolated Runtime Clone)”，编辑态与游玩态物理与内存完全隔离。
  - 平台原生交互范式 (Platform-Native UX): 触屏端提供符合人机工程学的手势操作与自适应半透明虚拟触控按键。

================================================================================
2. 全局架构与子系统拓扑 (Architecture & Subsystems)
================================================================================
2.1 分层架构
系统划分为五大清晰层级：
  [ 5. 表现与交互层 (Presentation & UI) ]
      - 编辑器 HUD, 调色板轮盘/抽屉, 触屏虚拟按键, 游玩 HUD, 结算仪式 UI, CourseBot 界面
  [ 4. 模式运行层 (Runtime Modes) ]
      - CourseMakerController (编辑模式控制器)
      - CoursePlayController (游玩模式控制器)
      - HotSwapManager (独立运行树克隆与生命周期重置)
  [ 3. 领域子系统层 (Domain Subsystems) ]
      - PlayerController & PowerUpManager (马里奥状态机与变身降级管理器)
      - MultiStylePhysicsEngine (基于配置表的 SMB1/SMB3/SMW 物理动力学)
      - CameraController (平滑跟随, 封闭实心墙锁屏 Scroll Stop, 垂直爬塔, 自动卷轴与挤压)
      - GizmoEventBus (ON/OFF 翻转, P开关, POW 震地, 钥匙集中事件)
      - PipeTraversalManager (传送门与生成器双模管道)
      - ClearConditionEvaluator (关卡通关条件校验器)
      - SoundStateMachine (动态多音轨与覆盖 BGM 状态机)
  [ 2. 核心服务与注册表层 (Core Services & Registries) ]
      - GameObjectRegistry (全对象语义注册表 objects.json)
      - CommandHistory (撤销重做命令栈, 支持 >100 步历史)
      - CourseBotRepository (关卡本地目录、缩略图快照与跨端导入导出)
      - InputAbstractionService (统一 PC 键鼠、手柄、移动触控语义)
  [ 1. 引擎与平台层 (Godot 4 Core) ]
      - Mobile 渲染通道 (低开销、全平台像素完美输出)
      - 2D 物理引擎 (CharacterBody2D, TileMapLayer, Raycast2D)
      - OS 沙盒文件 I/O 与 AudioBus 总线

2.2 核心单例服务 (Autoloads)
  - `GameManager`: 全局生命周期、游戏模式调度。
  - `Registry`: 加载并对外提供 `res://data/registry/objects.json` 查询。
  - `LevelManager`: 当前编辑/游玩的 `LevelData` 内存持有者，负责 JSON 读写与快照生成。
  - `InputManager`: 汇总 PC、手柄与移动触屏事件，对外派发统一逻辑动作。
  - `GizmoEventBus`: 集中式机关事件总线。
  - `AudioManager`: AudioBus 路由与动态音乐状态机。
  - `CourseBot`: 本地关卡库管理器，处理 `user://courses/` 读写与分享。

================================================================================
3. 2D 物理碰撞分层与手感动力学规范 (Physics Layers & Multi-Style Dynamics)
================================================================================
3.1 严格 7 层 2D 物理碰撞分层 (Collision Layers)
  - Layer 1: `Solids` (地形实心方块、地面、坚固硬块、管道外壁、闭合开关块)
  - Layer 2: `Player` (马里奥主体角色)
  - Layer 3: `Enemies` (栗子球、慢慢龟、吞食花、刺顶敌人等活动敌对实体)
  - Layer 4: `Pickups` (静止或移动中的道具：金币、超级蘑菇、火花、无敌星)
  - Layer 5: `Projectiles` (被踢出的龟壳、玩家火球、敌人炮弹、飞锤)
  - Layer 6: `Semisolids` (单向板：木质平台、蘑菇顶、云朵块，可自下而上跳穿、顶部站立)
  - Layer 7: `Sensors` (区域触发器：触碰终点检测、钥匙门感应、管道入口检测、深渊销毁线)

3.2 多风格物理参数矩阵 (PlayerPhysicsProfile)
三款风格采用独立的 `PlayerPhysicsProfile` 资源文件驱动，在 60Hz 固定物理帧率下严格匹配：

| 物理参数项                   | SMB1 风格          | SMB3 风格          | SMW 风格 (优先打磨) |
|------------------------------|--------------------|--------------------|--------------------|
| 行走最大速度 (Walk Max)      | 78.0 px/s          | 84.0 px/s          | 78.0 px/s          |
| 跑步最大速度 (Run Max)       | 156.0 px/s         | 168.0 px/s         | 180.0 px/s         |
| P-Meter 冲刺速度 (P-Speed)   | 不支持             | 204.0 px/s         | 216.0 px/s         |
| 地面加速度 (Ground Accel)    | 220.0 px/s²        | 240.0 px/s²        | 200.0 px/s²        |
| 地面滑动阻尼 (Skid Decel)    | 380.0 px/s²        | 420.0 px/s²        | 400.0 px/s²        |
| 普通跳跃初速度 (Jump Initial)| -340.0 px/s        | -350.0 px/s        | -360.0 px/s        |
| 冲刺大跳初速度 (Super Jump)  | -380.0 px/s        | -410.0 px/s        | -430.0 px/s        |
| 旋转跳初速度 (Spin Jump)     | 不支持             | 不支持             | -280.0 px/s        |
| 重力加速度 (Gravity)         | 880.0 px/s²        | 920.0 px/s²        | 900.0 px/s²        |
| 终端下落极速 (Max Fall)      | 260.0 px/s         | 270.0 px/s         | 258.0 px/s         |
| 空中转向机动性 (Air Control) | 极小(近纯惯性锁死) | 良好               | 优秀(高自由度微调) |

3.3 跳跃手感核心算法
  1. 变高跳跃截断 (Variable Jump Cut):
     马里奥在上升阶段（`velocity.y < 0`）一旦松开跳跃键，立即执行 `velocity.y *= 0.55`。
  2. 土狼时间 (Coyote Time):
     离开平台边缘后的 6 物理帧（约 0.1s）内，依然允许起跳。
  3. 输入缓冲 (Jump Buffering):
     落地前 5 物理帧内按下跳跃键，着地第一物理帧自动触发跳跃。
  4. 拐角微调纠偏 (Corner Correction / Slip):
     在马里奥头顶边缘碰撞上方方块 1~3 像素内时，检测左右空隙，自动平移 1~3px 滑过棱角，杜绝卡头顿挫。
  5. 头部撞块吸附与下推:
     顶部撞击方块法线 Y > 0.5 时，对被撞击方块触发 `hit_by_player()`，马里奥垂直速度重置为 +10px/s 避免黏连。

================================================================================
4. 核心对象模型与组件系统 (Data-Driven Entity-Component Model)
================================================================================
4.1 对象注册表规范 (`data/registry/objects.json`)
全量对象必须在 `objects.json` 中以语义 ID 注册，涵盖：
  - 分类 (Category): `terrain`, `block`, `item`, `enemy`, `gizmo`
  - 调色板归类 (Palette Category)
  - 属性 Schema: 包含内藏物、是否带翅膀、降落伞、颜色、方向等
  - 场景绑定: 游玩实体场景与编辑器预览场景

4.2 通用实体可复用组件库
  - `HitboxComponent (Area2D)`: 提供精准的头部受击、足底踩踏与侧面碰撞事件。
  - `BumpableComponent (Node)`: 赋予方块被顶起时的弹性缓动与对上方实体的动量推离。
  - `ContainerComponent (Node)`: 管理方块内藏物品（金币、蘑菇）的弹出缓动与激活。
  - `GravityMovementComponent (Node)`: 赋予敌人巡逻走动、撞墙调头与悬崖检测。
  - `WingedComponent (Node)`: 为任意实体附加翅膀正弦波振翅悬浮与跳跃动力学。
  - `ParachuteComponent (Node)`: 赋予实体降落伞低速降落并在触地时自动脱落。
  - `ICarryable (接口)`: 声明被抓取、手持、踢出与高抛的行为契约。

================================================================================
5. 关卡数据契约与存储架构 (Level Data Contract & CourseBot Repository)
================================================================================
5.1 关卡 JSON 契约格式
文件后缀为 `.smmlevel` 或 `.json`：
```json
{
  "format_version": 1,
  "metadata": {
    "title": "Course Title",
    "author": "Creator",
    "description": "Level description",
    "game_style": "smw",
    "creation_timestamp": 1726920000,
    "timer": 300,
    "clear_condition": {
      "type": "none",
      "target_id": "",
      "count_required": 0
    }
  },
  "main_area": {
    "theme": "ground",
    "is_night": false,
    "autoscroll_speed": "none",
    "bounds": { "left": 0, "top": 0, "right": 240, "bottom": 27 },
    "tilemap_layers": [
      { "layer_id": "terrain", "tiles_rle": "0x0:15,1x3:4,0x0:20" }
    ],
    "entities": [
      {
        "instance_id": "ent_001",
        "object_id": "smm.block.question",
        "grid_pos": [12, 18],
        "properties": {
          "contained_item": "smm.item.super_mushroom",
          "is_winged": false
        }
      }
    ]
  },
  "sub_area": {
    "theme": "underground",
    "is_night": false,
    "autoscroll_speed": "none",
    "bounds": { "left": 0, "top": 0, "right": 120, "bottom": 27 },
    "tilemap_layers": [],
    "entities": []
  },
  "pipe_connections": [
    {
      "source_area": "main_area",
      "source_pipe_id": "pipe_01",
      "target_area": "sub_area",
      "target_pipe_id": "pipe_02"
    }
  ]
}
```

5.2 CourseBot 本地仓储体系
  - 目录布局：`user://courses/<uuid>/`
    ├── `level.json`: 完整关卡数据
    └── `thumb.png`: 960x540 缩略图（保存时自动截屏压缩）
  - PC 端支持通过原生文件对话框导入/导出单个关卡文件。
  - Android 端利用 Godot 文件分享通道导出至外部目录或社交应用。

================================================================================
6. 关卡编辑器规格说明 (Course Maker Specification)
================================================================================
6.1 核心操作模式
  - `DRAW (绘制)`: 16×16 像素网格吸附，支持点按放置与连续拖动笔刷涂抹。
  - `ERASE (擦除)`: 连续划过快速清除实体与图块。
  - `SELECT (选择)`: 矩形套索多选，支持批量拖动平移、复制、删除与镜像。
  - `INSPECT (属性抽屉)`: 长按实体或右键呼出属性环（设置带翅膀、降落伞、内藏物品等）。
  - `VIEW (漫游)`: 双指/中键平移，滚轮/捏合缩放 (0.5x ~ 3.0x)。

6.2 撤销/重做命令历史 (Command Pattern)
所有编辑动作包装为 `IEditorCommand` 实例并推入 `CommandHistory`：
  - `PlaceEntityCommand`, `EraseEntityCommand`, `ModifyPropertyCommand`, `PaintTilesCommand`
  - 维护至少 100 步深度的操作栈。

6.3 独立运行树克隆 (Isolated Runtime Clone)
  - 进入游玩测试时：将编辑器当前关卡序列化，并在独立的游玩容器树中完整实例化纯净节点。
  - 退出游玩测试时：彻底销毁游玩节点树，恢复编辑器视口与镜头，绝不污染编辑态实体。

================================================================================
7. 核心游戏玩法子系统 (Gameplay Subsystems & Rules)
================================================================================
7.1 角色变身与受击降级机制 (SMM2 严格规则)
  - 变身层级：
    Any Advanced Power-Up (Fire, Leaf, Cape) -> Super (大马里奥) -> Small (小型马里奥) -> Dead (阵亡)。
  - 受击降级：高级状态单次受击降级为 Super，并触发 120 物理帧 (2.0s) 的无敌闪烁期 (i-frames)。
  - 1格高狭缝下蹲保护：
    大马里奥在 1 格高的狭小空间松开下蹲键时，强制保持下蹲判定框与滑行状态，直到完全离开天花板，防止直接穿模卡死。

7.2 实体搬运与投掷规范 (ICarryable)
  - 按住跑动/拾取键接触龟壳、POW 块、弹簧、P开关时，触发拾取。
  - 拾取后实体挂载至玩家手部锚点 (Hold Anchor)，禁用自身碰撞；松开键投掷（前抛或 SMW 专属按上高抛）。

7.3 敌人体系与外壳交互
  - 敌人基类 `EnemyBase` 提供基础步行动力学与受击虚方法。
  - 慢慢龟受踩后缩入龟壳，静止龟壳可被踢飞（横扫消灭沿途杂兵、撞砖反弹）。
  - 刺顶敌人（如刺壳龟 Spiny）普通踩踏导致伤害，仅在 SMW 旋转跳下可弹起。

7.4 策略模式风格专属结算器 (StyleGoalStrategy)
  - SMB1: 终点旗杆，高度计分，滑杆入堡，城堡升旗与烟花。
  - SMB3: 轮盘卡片方块，撞击随机定格卡片，过关跑出屏幕。
  - SMW: 巨型闸门，撞击上下浮动横杆按高度奖励 1~50 颗过关星。
  - 通关条件未达成时，终点处于灰色虚影封印状态，拒绝触发通关。

7.5 双模管道系统 (Dual-Mode Pipe)
  - 传送门功能：进入后平滑补间缩入管口，黑屏/圆形遮罩过渡，在目标管口滑出。
  - 生成器功能：管道内藏敌人/道具时，按颜色周期（红管快、绿管常速）定时向外吐出物品。

================================================================================
8. 全平台跨端输入与触控交互 (Cross-Platform Input & Touch UX)
================================================================================
8.1 跨平台输入语义映射
引擎内部一律监听抽象 Action:
  - `move_left`, `move_right`, `move_up`, `move_down`
  - `jump`, `run`, `spin_jump` (SMW专属)
  - `editor_pan`, `editor_zoom`, `editor_undo`, `editor_redo`, `toggle_maker_play`

8.2 Android 触屏状态自适应触控
  - 【游玩模式】: 屏幕左下角动态半透明十字键/虚拟摇杆；右下角 A(旋转跳)、B(跳跃)、Y(冲刺/吐舌/抓取) 动作按键。
  - 【编辑模式】: 单指绘制/擦除；双指平移视口；双指捏合缩放 (Pinch-to-zoom)；长按实体 0.4s 触发触觉震动并弹出属性菜单。UI 自动避让手机安全区 (Safe Area)。

================================================================================
9. 动态摄像机与卷轴控制系统 (Dynamic Camera & Autoscroll)
================================================================================
9.1 核心功能规范
  - 平滑跟随与死区缓冲 (Smooth Follow & Deadzone)。
  - 实心墙自动锁屏 (Scroll Stop Detection): 关卡内从顶到底连续闭合的实心方块列（或从左到右闭合的行）被识别为房间边界，相机禁止透视越界。
  - 垂直子区域 (Vertical Area): 强制锁定水平宽度为单屏 (约 27 格)，沿 Y 轴向上爬升高塔。
  - 自动卷轴 (Autoscroll) 与防挤压 (Crush Detection): 支持慢/中/快卷轴速度；玩家被卷轴视口边缘与实心方块挤压时触发挤压阵亡。

================================================================================
10. 全局机关与事件总线系统 (Gizmo Event Bus & Interactive Blocks)
================================================================================
10.1 集中式事件总线 (`GizmoEventBus`)
  - `on_off_state_changed(is_on: bool)`: 红蓝实虚方块翻转、履带换向。
  - `p_switch_activated(duration: float)`: 全图砖块金币互换、P门显现、倒计时音效。
  - `p_switch_expired()`: 砖块金币还原。
  - `pow_triggered(epicenter: Vector2)`: 全屏震颤波，消灭地面杂兵、掉落硬币。
  - `key_collected(key_id: String)`: 钥匙跟随玩家浮动。

================================================================================
11. 动态音频系统规格 (Dynamic Audio Engine & Music State Machine)
================================================================================
11.1 AudioBus 分层路由
  - `Master`: 主输出
    ├── `Music`: 挂载 Low-Pass Filter (水下主题动态激活)
    ├── `SFX`: 实体与环境音效 (对象池化)
    ├── `UI`: 交互反馈音
    └── `Jingle`: 胜利/阵亡短乐句 (暂时静音 Music)

11.2 音乐状态机 (MusicStateMachine)
  - 场景主题 BGM (地上/地下/水下/城堡等独立旋律)。
  - 动态叠加与覆盖：
    - 无敌星拾取：插播快节奏无敌旋律，超时平滑淡入主曲。
    - 倒计时 <100s：播放急促警示音，BGM 加速至 1.25x。
    - P 开关激活：覆盖急促节拍音轨。
    - 耀西骑乘：解除打击乐通道 (Bongo Track) 静音。

================================================================================
12. 智能 Tile 与场景主题管理 (Smart Tile & Themes)
================================================================================
12.1 地形分层与斜坡物理
  - 使用 Godot 4 `TileMapLayer` 多图层架构：背景层、单向板层、主地形层、液体动画层。
  - 45° 陡坡与 22.5° 缓坡通过 TileSet 精准多边形碰撞定义，配合 `CharacterBody2D` 的 `floor_snap` 算法，完美支持下蹲斜坡滑行冲撞击杀敌人。
  - 支持 10 种环境主题与月夜模式（颠倒重力、低重力、视野迷雾等）。

================================================================================
13. 资产隔离与本地解包管道 (Asset Pipeline & Legal Separation)
================================================================================
13.1 版权合规与提取向导
  - 源码仓库仅维护通用开源占位图与纯逻辑。
  - 内置 `AssetImportWizard` 工具：引导用户从个人合法 Dump 压缩包中自动解包、切片并放置到 `user://assets/` 覆盖加载。

================================================================================
14. 国际化与本地化规范 (i18n & Localization)
================================================================================
  - 基于 Godot `TranslationServer` 与 CSV 翻译表 (`res://data/i18n/strings.csv`)。
  - 首批完整支持 `zh_CN` (简体中文) 与 `en_US` (英语)，所有 UI 标签动态绑定 `tr("KEY")`。

================================================================================
15. 工程目录拓扑与编码标准 (Project Structure & Coding Standards)
================================================================================
```
res://
├── assets/                  # 游戏媒体资源 (解包挂载)
├── data/                    # 数据驱动 JSON 与配置表
│   ├── i18n/strings.csv    # 多语言表
│   ├── physics/            # 三风格物理配置 (.tres)
│   └── registry/objects.json # 对象注册表
├── src/                     # 源代码实现
│   ├── autoload/           # 单例服务 (GameManager, LevelManager, etc.)
│   ├── core/               # 核心命令栈、ECS组件、数据模型
│   ├── editor/             # 关卡编辑器、视口、调色盘
│   ├── gameplay/           # 实体实现 (Player, Blocks, Enemies, Mounts)
│   └── ui/                 # HUD、触屏按键、CourseBot 界面
└── test/                    # 单元与集成测试 (GUT)
```
- GDScript 编码规范：强制静态类型注解，蛇形命名函数与变量，大驼峰命名类，信号优先解耦。

================================================================================
16. 实施路线图与里程碑 (Roadmap & Milestones)
================================================================================
- M0 (基座与注册表): 建立组件化基座、对象注册表、命令模式栈、三风格物理资源。
- M1 (物理与状态机精调): 落地变高跳、土狼时间、拐角纠偏、逐级受击降级变身状态机。
- M2 (编辑器与基础实体): 16px 网格放置/擦除/框选、JSON 存读、独立运行树热切、问号块与栗子球。
- M3 (多区域与复杂机制): 主副区域、双模管道跨区穿越、实心墙锁屏相机、ON/OFF 与 P开关总线。
- M4 (跨端适配与音频): Android 虚拟按键与手势、AudioBus 动态音乐状态机、中英文本地化。
- M5 (CourseBot 与交付): 机器鸽仓储体系、全平台导出预设验证与资产导入向导。
================================================================================
