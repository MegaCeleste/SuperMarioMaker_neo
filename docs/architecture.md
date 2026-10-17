# 架构

更新：2026-10-17。以下以当前代码为依据；预留能力不代表完整功能已实现。

## 工程结构与运行基础

工程根目录为 `SuperMarioMaker_neo/`，F5 入口为 `src/main/game.tscn`。使用 Godot 4.7、Godot Physics 2D、Nearest 纹理过滤，以及 60 Hz 物理步。features 标记包含 Mobile，但没有显式设置 rendering_method；2026-10-09 本机默认渲染检查日志实际为 D3D12 / Forward+，不以 features 推断运行渲染器。目标平台为 Windows、macOS、Linux、Android；目前开发环境为 Windows，跨平台导出尚未验证。

```text
AGENTS.md                 Codex 工作入口
docs/                     当前设计、路线图、决策与计划
src/
  autoload/               全局服务
  core/                   数据辅助、组件、命令栈
  gameplay/               玩家、敌人、方块、道具、投射物、试玩场景
  editor/                 制作界面、局部 UI 状态、静态画布与圆环菜单
  ui/                     当前界面/背景
  main/                   主场景
data/                     物理、行为、注册表、帧映射、翻译与场地配置
fonts/                    本地字体（编辑器 Theme 与 UI 使用）
tools/                    素材安装、清单生成、研究与校验脚本
test/                     现有 GUT 用例
textures/、audio/          本地媒体，Git 忽略
local_debug_output/       本地编译/启动日志，Git 忽略
```

仓库统一按 LF 入库（`.gitattributes`），Godot 的 `*.import` 作为文本参与 diff；`.DS_Store`、日志与临时文件由 `.gitignore` 排除。约定见[决策 0002](decisions/0002-repository-normalization.md)。

编辑器第一轮位于 `src/editor/`，已有界面与交互骨架，尚无实际物件编辑或创作/试玩闭环。本地参考旧工程 `GodotWE/` 已移出本工程目录，位于工作区级的 `../references/GodotWE/`，不再参与 Godot 导入扫描，也不作为当前实现来源直接运行或迁移。

## 编辑器界面与状态

打开 `src/editor/editor.tscn` 后 F6 运行。负责人提供的1920×1080 SMM2截图是当前视觉基准：SubViewportContainer铺满窗口，内部是独立World2D的SubViewport → MakerWorld/Camera2D；ReferenceUI覆盖在画布上。顶部十二卡片、左侧设置托盘、右侧工具、左下试玩板和右下主区域均保存为场景节点，工具区使用半透明Theme，卡片行/设置列仍用HBox/VBox。ReferenceUI按`min(窗口宽/1920, 窗口高/1080)`缩放，边缘工具按锚点定位；最小960×540，退出恢复此前窗口缩放/最小尺寸。

`editor.gd` 拥有局部 RefCounted `EditorState`（工具、物件 ID、打开的面板、网格开关、相机中心、缩放）。按钮发信号，控制器调用状态方法，组件按 changed/view_changed 刷新；不新增 Autoload，也不写 LevelManager.level_data。工具用 ButtonGroup 保持互斥，程序同步滑条范围和值时阻断信号，避免缩放反向触发平移。

`palette_wheel.gd`以相同的中心、半径与十等分角度绘制/命中圆环。负责人后续提供的图6覆盖首轮八槽方案：全屏淡色遮罩、隐藏工具栏、四个分类图标与选中长条、十槽浅粉圆环/虚线分隔、彩色中心/白色物件卡、黑色关闭按钮及循环翻页。地形分类包含Registry的terrain/block，道具/enemy/gizmo分别独立。`editor_catalog.gd`维护只读视觉顺序与Registry ID映射；未注册物件展示已有原图、点击不选中，空槽/中心也不选择。原图缓存在Catalog中，避免临时Texture2D释放后绘制RID失效。Goomba仍为SMB1静态占位，不实例化gameplay。

顶部十二卡片沿用截图顺序；只有已注册的硬块/火焰花/地面/金币可切换，其余禁用。`MakerArtButton`是`@tool Button`；图标由场景中的`ArtView: TextureRect`绘制，顶部色条由`CapView: TextureRect`绘制。脚本仅同步ArtView的texture，保留负责人调整的偏移、尺寸与材质；旧cap/cap_color/art_inset父级属性已迁移到子节点。所有ArtView/CapView设置mouse_filter=IGNORE，按钮继续接收点击。`Feedback`独立层绘制固定标记与工具栏四角，避免被子节点遮盖；B/E徽标绘制与V的KeyBadge节点已删除，逻辑快捷键保留。`PaletteCategoryButton`负责选中长条宽度，分类图也由ArtView绘制；分类与翻页按钮不显示四角。

圆盘与中心使用真正的`draw_circle(..., antialiased=true)`，已移除圆周点5px吸附产生的不规则多边形。`PaletteWheel._draw_sector()`按相同槽位角度绘制悬停扇区，用分类色与中心连成整块；此时隐藏该扇区两侧虚线，不绘制物品四角。其他分隔线使用淡化分类色。缺失图标留空。所有通用tooltip、设置/Coursebot说明弹窗、擦除气泡已移除；设置/Coursebot入口禁用，菜单仅保留真实网格/位置/缩放控件。

编辑器暂用英文，不做中文本地化（负责人最新决定）；场景中已有静态文案直接保存英文，避免Godot编辑器预览显示MAKER_*键；动态文案仍按CSV加载英文。Theme统一使用`fonts/MARIOMAKER.otf`，按钮/普通Label/计时数字/Play及调色盘同字体，禁用系统字体回退并使用MSDF导入。此前Button指定Mario Maker而Label/计时器采用MPLUS，造成字体不一致，已统一到共享LocalUIFont。12个CapView高度以保存的火焰花为准，当前9.636364px，保留各自颜色。本地字体的简体字覆盖不完整，不能沿用字体预览图中的“全覆盖”声明。

`maker_viewport.gd` 使用相机中心和实际`view_scale`将局部屏幕位置转换为世界像素，再除以16并取floor得到格坐标。逻辑缩放仍为1～4、初始2；实际相机缩放=`逻辑缩放×2.5×窗口参考比例`，1920×1080下初始每格80px，三种16:9尺寸显示相同世界范围。`MakerWorld`复用完整SMW地面背景并按参考图调整背景水平相位；只绘制背景/网格/预览。SubViewport默认过滤及World节点均显式设为最近邻；CanvasItem的过滤继承不会穿过子视口边界，不能只设外层容器。滚轮保持鼠标世界位置，边界以相机钳制为准。全屏画布需额外检查`gui_get_hovered_control()`，工具区覆盖处停止预览/拖动；弹窗阻断画布鼠标，菜单内位置滑条通过明确的UI请求调整相机。网格按钮、滑条、缩放比例与状态文字位于菜单中。

SVG按钮底板、SVG ArtView与CapView单独使用线性采样，PNG ArtView显式最近邻。编辑器仍按实际窗口分辨率绘制；因为关闭了Window内容缩放，`editor.gd::_resize_reference_ui()`主动设置窗口`oversampling_override=max(1, 2×参考比例)`，让DPITexture按窗口大小重栅格化，而非放大固定小图。仅UI窗口启用4×MSAA处理圆盘悬停扇区/箭头等几何边缘，世界SubViewport保持独立最近邻设置。入场保存原窗口MSAA与oversampling，退出还原。字体继续使用本地MARIOMAKER/MSDF，不改像素图细节；12个CapView.position.y均为−8。

InputManager 在内存注册新的编辑器逻辑 Action，然后加载用户绑定，不改 project.godot 的 F5 入口。B/E/V 切工具、Tab 开关圆环、G 网格、Esc 关闭、中键拖动、滚轮缩放。编辑器只在自身场景处理这些动作；文字输入焦点内保留文字操作。存读、撤销、重置、实际编辑、试玩、副区域仍禁用。

教学观察步骤、检查命令和证据见 [编辑器框架记录](plans/2026-10-09-editor-framework.md)。

## 玩家模块

| 入口 | 职责 |
|---|---|
| `src/gameplay/player/player.gd` | Godot 生命周期、事件队列、物理步编排、一次运动求解及能力请求 |
| `player_input_frame.gd` | 逻辑输入快照与按下/释放边沿 |
| `player_motion.gd` | 水平动量、跳跃、重力、缓冲和速度 |
| `player_movement_state_machine.gd` | 只读移动状态和转换信号 |
| `power_up_manager.gd` | 形态、演出阶段、合法转换与无敌计时 |
| `player_collision.gd` | 地形盒/受击盒、净空、擦角、顶块/落块选择 |
| `player_animator.gd` | 形态贴图、走跑位移相位、空中姿态及发射表现 |
| `player_carry.gd` | 抓取候选、携带、投掷/掉落和碰撞恢复 |
| `player_status_effects.gd` | 独立星星600活动帧、颜色循环和临时30px/s走/跑门槛加成 |
| `player_physics_profile.gd` | 可复制、可校验的玩家参数 Resource |

移动状态为 `IDLE / RUN / AIR / CROUCH / SKID / DEAD`。旋转跳、满速跳、蹲跳属于 AIR 的跳跃类型/姿态；形态 `SMALL / SUPER / FIRE / DEAD` 与阶段 `ACTIVE / TRANSFORMING / DEAD` 分开建模。状态转换入口拥有状态，外部读取和消费信号，不直接赋值。

Profile 的 `motion_model` 选择 LEGACY 或 SMMWE；默认 Resource 使用 SMMWE，类缺省和旧备份保持 LEGACY。参考路径先按进帧水平速度起跳，再更新横向速度和重力；反向步可越零，近顶点锁存大重力，落速先限后加重力。缓冲起跳在落地求解后赋初速，下一移动帧正常积分一次；反弹接受完整 PlayerInputFrame，由 Motion 维护保持键来源。Godot 地形求解仍由 PlayerCollision 和一次 move_and_slide 负责，不复制 SMMWE 的预测落地/像素掩码。

存活物理步依次捕获输入边沿，处理强制死亡/形态事件及敌人接触，更新碰撞和运动，处理搬运，进行一次 `move_and_slide()`，处理顶块/旋转击破/落地，发布动画与快照，推进无敌计时。演出定格时保留动量和输入，只推进演出；死亡走独立路径。具体顺序以 `Player._physics_process()` 为准。

Area 回调缓存接触或请求，安全物理步统一处理；踩踏优先于侧面伤害。变大/站起查询新增头顶空间。复位清空窗口、事件、无敌、动画、搬运与本次火球，避免上一轮状态污染。

## 输入、碰撞与冻结

输入设备映射在 `project.godot` 与 InputManager，玩法消费逻辑 Action；默认操作见 game-design。重绑配置写 `user://settings.cfg`，完整重绑 UI 尚未实现。

碰撞编号由 `data/physics/collision_layers.json` 提供，CollisionConfig 将名称转换为位掩码：

| 层 | 名称 | 当前用途 |
|---|---|---|
| 1 | solids | 地面、实心方块 |
| 2 | player | 玩家地形主体 |
| 3 | enemies | 活动敌人 |
| 4 | pickups | 道具主体 |
| 5 | projectiles | 火球、被抛出的板栗仔、滑动龟壳 |
| 6 | semisolids | 单向地形预留 |
| 7 | sensors | 踩踏、伤害、拾取、搬运及其他触发 |

玩家主体求解地形，敌人交互由独立传感器处理。场景金币本身是传感器，不能从类别名直接推断实际碰撞层。

GameManager 发布 gameplay 冻结开始/结束，GameplayFreezeGate 保存实体处理模式；冻结期间保留物理接触，停止实体的自主积分和计时。搬运另行挂起实体处理及碰撞，释放时恢复；遇到演出冻结须正确恢复保存的模式。HUD 与 BGM 独立于 gameplay 定格；场景暂停则按节点处理模式执行。

## 全局服务现状

| Autoload | 已有能力 / 限制 |
|---|---|
| GameManager | 模式/风格信号、单人冻结、会话金币/获得额外生命计数；完整关卡生命周期尚未形成 |
| InputManager | 逻辑输入、用户绑定加载和保存 |
| Registry | 对象索引、类别/风格查询、场景工厂与属性类型/枚举校验 |
| LevelManager | 内存关卡、新关卡、JSON 存读、RLE 辅助；深度校验与运行场景构建未接通 |
| GizmoEventBus | 机关通知接口；完整机关玩法尚未接入 |
| AudioManager | 总线名称占位；完整动态音乐状态机未实现 |
| CourseBot | 建立本地 courses 目录；完整仓储/界面未实现 |

Registry 的 `styles` 表示对象兼容声明，不能证明该风格贴图已经完成。`components` 是描述，当前工厂不按字符串自动装配组件。场景包含实际节点；调用者负责挂入树、位置与生命周期。地面条目 play 路径为空，由 TileMap 承担，不能用工厂直接实例化。

## 基础实体

2026-10-10表现修正：`Enemy.spin_defeat()`区分旋跳秒杀与普通死亡，仅生成四颗星光并立即移除目标；`spin_defeat_effect.gd`归所属世界管理。`player_skid_dust.gd`是Player的SkidDust子节点，读取SKID与形态状态，拥有脚底烟尘发射与逐帧计时；其Sprite采用top_level保持发射位置，生命周期仍随Player，死亡/复位显式清空。两类表现均接入GameplayFreezeGate，不改变普通玩家运动Profile。

Enemy提供`WALKING / STUNNED / HELD / THROWN / SQUASHED / DEAD`及共用运动/传感器。Goomba普通踩踏变踩扁；Galoomba翻倒后可搬运/踢出并计时恢复。新增红绿龟、钢盔龟、刺刺、炸弹兵、四向食人花，共享分类基类和组件，保留自己的专属状态。

`EntityHit`/`EntityHitResult`统一踩踏、旋跳、火球、壳、投掷物、顶块、星星、爆炸请求与响应。玩家、火球、投掷物不直接调用其他怪物die；类型决定受击生效、攻击物消耗与玩家反弹。`EntitySpawn`为转换对象保持脚底、检查恢复净空和扫描高速壳越过的敌人。

PowerUpPickup共用蘑菇/花/星星/1UP的运动生命周期，PickupInteraction统一接触候选及一次性消费。Coin继续用Area2D，一份实现支持1/10/30/50面额。BlockContent提供出块入口；QuestionBlock通过Registry生成并检查释放组件，支持原有内容、星星与1UP。三种大金币只支持场景放置。

KoopaShell共享颜色/钢盔/内部翻倒刺壳行为，拥有占用者、恢复、滑动、保护及扫掠去重；NakedKoopa拥有脱壳滑行/恢复/跳入阶段。BombFuse作为明确pausable的子节点在搬运时继续引信，GameManager冻结和场景暂停时停止；Galoomba恢复计时随搬运挂起。EntityExplosion按目标ID去重，查询传感器/身体并包含手持目标；硬块/翻转块可破坏、问号块一次释放。PiranhaPlant保持管口锚点，裁剪露出长度并同步碰撞，完全隐藏时无伤害。

InteractableBlock保持网格碰撞，Bumpable只移动视觉；TurnBlock暂时关闭碰撞并在净空后恢复。

状态、制作入口与扩展规则见[实体制作规范](entity-production.md)，数值、事件和适配见[实体研究](research/2026-10-09-smmwe-entities.md)。技术检查与负责人手感认可分别记录，几何仍包含工程候选。

## 配置、素材与来源

| 文件 | 内容 |
|---|---|
| `data/physics/base_physics.tres` | 玩家运行基线；每个实例深复制 |
| `data/physics/pre_smmwe_physics.tres` | 2026-10-08 同步前配置，配合 LEGACY 算法在仪表盘对比 |
| `data/physics/style_abilities.json` | 风格能力开关；不等于已实现全部列出的系统 |
| `data/physics/player_parameter_evidence.json` | 参数出处、候选/测量等级与用户观察 |
| `data/physics/player_presentation.json` | 玩家表现配置 |
| `data/gameplay/prototype_entities.json` | 基础实体运动、碰撞和表现候选 |
| `data/gameplay/pre_smmwe_entities.json` | 本轮实体同步前配置 |
| `data/gameplay/entity_parameter_evidence.json` | 51项实体数值出处/换算/适配及20条继承链 |
| `data/registry/objects.json` | 当前22个语义对象条目及可设置属性；派生实体由所属对象创建 |
| `data/assets/basic_smw.json` | 当前试玩预设的逐图元数据及逻辑动画映射 |
| `data/visuals/basic_smw_*.tres` | 由安装脚本生成、用于 Godot 场景预览的 SpriteFrames |
| `data/debug/*.json` | 两个试玩场景的场地/入口/调参布局 |
| `data/i18n/strings.csv` | 中英文 UI 文案 |

`tools/asset_pipeline/install_basic_assets.py`从外层`TBDtoVERIFIED/textures/styles/`原样复制选定PNG，检查尺寸、哈希、帧范围及风格/用途，生成清单与SpriteFrames。爆炸按已保存SMMWE ZIP的YY顺序无重采样拼接14张原帧。当前活动素材51张；runtime的BasicSpriteLibrary从同一目录构造帧，拒绝尺寸错误、风格不一致或非行走图冒充walk的映射。

尺寸合法不能证明动画语义正确。2026-10-08 修正了把多外观 `goomba_res_Strip4` 当作走路帧的错误。负责人澄清 Goomba 与 Galoomba 是两种敌人后，决定默认 SMW 中的 Goomba 先用 SMB1 行走双帧与专用踩扁单帧占位，之后提供独立贴图；Galoomba 继续使用 SMW 圆栗子的行走/翻倒双帧。两类行为仍分别为踩扁消失与翻倒搬运。短暂使用的圆栗子缩放踩扁方案已移除，现有踩扁使用原生帧并由 `Enemy._render()` 保持脚底对齐。清单中的 `usage_state: placeholder` 与用途说明标明占位性质，不把源图核对通过当成最终美术认可。

本次涉及的本地敌人贴图按“风格_外观实体_用途_帧尺寸_帧数”命名：`smb1_goomba_walk_16x16_2f.png`、`smb1_goomba_squashed_16x16_1f.png`、`smw_galoomba_walk_16x16_2f.png`、`smw_galoomba_stunned_16x16_2f.png`，资产键使用对应的风格/实体/用途名称。逻辑动画组 `goomba` / `galoomba` 仍表示行为实体；原始文件名保留于 `source_original`。旧本地副本不删除，活动清单和预览资源使用明确命名的新副本。其他素材尚未批量改名；后续多风格加载应将表现集显式分开。

错误源图记入清单的 `rejected_sources`；安装脚本拒绝重新用于活动资产，并将旧本地副本的 JSON 状态改为 `rejected`、清空动画映射。原始 PNG 保留，方便追溯。

核对时查看每帧画面，确认整帧尺寸、语义、索引、风格和锚点；不根据透明边界推算物理碰撞，也不自动裁切/缩放原图。未确认的帧先保留草稿。动画速度的候选标签独立于美术映射核对状态。

完整资产导入向导、用户目录覆盖加载、缺失全部媒体时的自动兜底尚未实现。新克隆需配置本地媒体；当前工具不能单独补齐 Player、音频和 UI 的全部依赖。

## 编译与可观察入口

在工程根目录执行 PowerShell；本机路径可按安装位置替换。

```powershell
& 'C:\!application\tools\Godot\Godot_v4.7.2-stable_win64.exe' --headless --path . --import --quit
```

这检查导入/编译，不代表玩法已通过。需要运行检查时可用主场景 `--quit-after 120 --fixed-fps 60`；显式场景路径为：

- `res://src/gameplay/debug/physics_dashboard.tscn`：速度、状态、曲线、实例调参、CSV/Profile 导出。
- `res://src/gameplay/debug/basic_entities_playground.tscn`：十个分区入口，现有对象及龟/壳/刺顶/爆炸/花/星星与奖励；HUD可滚动，复位清空会话奖励。

实体批次原生检查入口`res://tools/verification/entity_batch_probe.tscn`，窗口截帧入口`entity_batch_capture.tscn`。结果、复现命令和分阶段阅读/试玩步骤见[本轮计划](plans/2026-10-09-entity-batch.md)。

Godot 编辑器中选中试玩场景后 F6 运行；运行中的逻辑 F6 是暂停，F7 是单帧，R 是复位。

物理仪表盘提供参考/调整前两套预设，切换时复制全部 Profile 字段到同一实例并复位玩家/测量；各模块仍共享原 Profile 引用。导出元数据保存 `physics_preset` 及完整参数快照，参考专属调参在旧模式禁用。数值和真实合成地面碰撞检查入口在 [本次数值同步计划](plans/2026-10-08-smmwe-physics-sync.md)。

`test/unit/` 有注册表、RLE、命令栈的历史 GUT 用例，尚无充分的 Player/实体覆盖。只有当次任务需要并授权测试时才新增或运行，执行结果必须实际记录。

已有环境问题包括 Windows 证书存储读取失败、godot_mcp 导入插件的 null.listen、编辑器设置保存权限和插件退出资源残留。应与 gameplay 解析错误区分，不把退出码 0 当作没有任何错误。
