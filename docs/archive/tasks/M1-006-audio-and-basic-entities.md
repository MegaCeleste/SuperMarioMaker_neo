# 任务单：M1-006-状态音效与基础实体

> **状态**: paused（负责人要求关机，2026-09-30 保存现场）
> **下达日期**: 2026-09-30
> **执行者**: Codex

## 目标与范围

按负责人纠正，将刹车声绑定整个 SKID 状态并去除玩家音效/主场景 BGM 的距离衰减。接入火焰花与 Fire 贴图、栗子仔和板栗仔，以及问号块、用过的方块、硬块、翻转块和用于方块内容的金币。

- 参考 REQ-PHYS-105/115/120~123、REQ-PWR-002/006~013/014~017、REQ-REG-001~006、REQ-AST-001~003/007~009。
- 当前主要试玩视觉为 SMW；两个敌人各有独立场景及状态，其他风格不自动冒充完成。
- 真实媒体只复制到忽略的 textures/，原始素材保留；可复现映射和清单留在 data/ 与 tools/。
- 注册所有可放置场景，提供实体试玩场景和仪表盘入口，并保留用户主场景 tile_map_data。
- 数值沿用现有工程候选及 Profile；新增计时/表现配置明确为工程候选，不升级 VERIFIED/TUNED。
- 仅执行导入/编译和场景启动检查，不新增或运行测试用例。

## 实现核对

- [x] SKID 内循环，退出/演出/死亡/复位停止；恢复刹车时可重新播放，玩家声音与 BGM 不衰减。
- [x] 火焰花实体、问号块弹出、拾取 Fire、Fire 专用贴图和火球链路已实现。
- [x] 栗子仔巡逻/转向/踩扁/火球击败；板栗仔翻倒/搬运/投掷/踢出/恢复/击中敌人已实现。
- [x] 基础方块、金币和含物注册表配置已实现，接入演出/暂停/复位生命周期。
- [x] 可启动的基础实体试玩场景及仪表盘入口完成。
- [x] 编译/启动摘要、TBD 与范围外问题记录已保存。

以上为代码实现核对；启动检查没有模拟操作、试听或签认交互正确性。仍需下述继续事项。

## 完成回报

## 关机前进度存档（2026-09-30）

负责人最新要求：栗子仔 Goomba 与板栗仔 Galoomba **两种都实装**；之后要求先保存进度，关机后再继续。工作已按此暂停。代码/配置/spec/场景均写入本地文件，未提交或推送 Git，保留此前 Player 重构及负责人已有工作区改动。

### 已保存的实现

- Player 声音节点与主场景 BGM 改为 AudioStreamPlayer。SoundEffectStream 复制实例流：SkidSound 正向循环，其他声音单次播放；循环与 SKID/ACTIVE/演出/死亡/复位绑定。
- 25 张本地 PNG 保留原文件，复制到忽略的 textures/basic/smw；data/assets/basic_smw.json 明确尺寸/帧索引/锚点，工具生成 SpriteFrames 文本与哈希清单。火球帧条的完整画布实际为 **16×16/帧**，不能按可见图案大小切片。
- Fire 专用帧条、火球贴图、地面发射姿态已接入。发射姿态不会覆盖空中的满速跳锁定、下蹲或刹车姿态。
- 敌人共用 Enemy 生命周期，两类行为独立；Galoomba 只有翻倒后可搬运，被搬运时不参与踩踏。Goomba 踩扁表现沿地形脚线对齐；当前使用本地 SMW 项目变体素材及缩放踩扁表现，并非已核实的 SMM2 原生 SMW Goomba 美术规则。
- 问号块可选金币/蘑菇/火焰花；已用块、硬块、翻转块独立场景。翻转块暂时通行，净空后恢复，大型 SMW 旋转跳可击破。金币会话计数、非重复领取、出块演出、全局冻结已接入。
- Registry 工厂校验属性并应用默认值，注册表现有 10 项（其中 ground 保留 TileMap 路径占位）。
- 新增 src/gameplay/debug/basic_entities_playground.tscn 和 data/debug/basic_entities_playground.json。可从 physics_dashboard 的“基础实体试玩”进入，也可直接 F6 运行该场景；支持入口/形态选择、R 全部复位、F6 暂停、F7 单帧、金币/状态显示和返回仪表盘。
- 主场景加入火焰花、板栗仔、火焰花问号块、已用块、硬块和翻转块。负责人原有 tile_map_data 未修改；本轮场景放置前后该行 UTF-8 SHA-256 均为 `0ABFDFAC25AA6CD5240309535C0AFF166D74B5C78F2FF9BB82F7AC12E850294B`。
- 草案版本：10-player-physics 0.7.3；02-object-registry 0.1.1；新增 12-basic-entities 0.1.1。旧音效需求已保留并标 DEPRECATED。未修改 approved 的 specs/README.md。

### 已执行命令摘要

运行目录：C:/Working/SMMneo/SuperMarioMaker_neo。Godot 路径为 AGENTS.md 中的 v4.7.2-stable。

| 操作 | 结果 / 本地日志 |
|---|---|
| install_basic_assets.py --source C:/Working/SMMneo/TBDtoVERIFIED/textures/styles | 退出 0，25 张原样复制及清单；原始图保留 |
| Godot --headless --import --quit | 退出 0；basic-entities-fourth-import.log，新素材导入完成；仍有下列环境/插件错误 |
| 主场景 --headless --quit-after 120 --fixed-fps 60 | 退出 0；basic-entities-main-startup.log，无 gameplay 脚本或场景加载错误 |
| physics_dashboard.tscn --headless --quit-after 180 --fixed-fps 60 | 退出 0；basic-entities-dashboard-startup.log，无 gameplay 脚本或场景加载错误 |
| basic_entities_playground.tscn --headless --quit-after 180 --fixed-fps 60 | 退出 0；basic-entities-room-startup.log，注册 10 项，无 gameplay 脚本或场景加载错误 |
| git diff --check | 退出 0；只有既有场景 CRLF→LF 提示 |
| git check-ignore 媒体与日志 | textures/basic/smw、audio 和 local_debug_output 均被忽略 |

日志均位于忽略目录 local_debug_output。前期生成的 .tres 首行 `#` 导致解析错误，已去除并重新生成；最后三次场景启动无此错误。本次未新增/运行 GUT 或交互测试，未通过耳朵确认音效。

### 继续时的顺序

1. 先阅读本任务单并检查工作区差异；继续使用当前本地文件，不回退或重新重构已完成部分。
2. 复核实体试玩 HUD 在实际窗口下的高度；长操作说明可能需要滚动容器，以免底部操作被遮挡。这项在负责人要求暂停时尚未处理。
3. 继续人工复核实体状态边界，重点为 Galoomba 翻倒后接触/搬运/投掷/恢复、受击掉落，以及问号块出物与冻结的时序；随后进行负责人试玩反馈。需要自动交互测试时先等负责人明确要求。
4. 人工试听刹车：整个 SKID 持续，离开状态立即停，远距离音量保持，暂停/变身/死亡/复位后无残留。
5. 在试玩中确认两种踩踏区别、火球命中、问号块只出一次、翻转块净空恢复与旋转跳击破；确认主场景新增放置符合负责人地图意图。
6. 根据真实试玩反馈修复，再决定下一阶段；数值签认必须走 VERIFIED/TUNED 证据流程。

### TBD / 候选及范围外发现

- 无阻塞本轮工程实现的 TBD；精确 SMM2 敌人恢复/踩扁、出块/翻转/发射表现计时、动画速率与碰撞几何仍待实测。新增配置与原型运动保留 CANDIDATE，不自动升为 VERIFIED/TUNED。
- 当前预览素材为 SMW；其他风格换皮及原生 Goomba 美术差异尚未实装。
- 所有启动都有 Windows root certificate store 读取失败；编辑器导入另有 godot_mcp 的 null.listen、编辑器设置保存权限和插件退出资源残留。属于原有环境/插件问题，本轮未修改。
- 独立试玩场景用调试地形，不作为 SMM2 的测量数据。
