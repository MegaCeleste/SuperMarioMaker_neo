# 路线图与交接

更新：2026-10-17。这里记录可以观察到的进度和下一步，替代旧任务单作为日常入口。

## 当前现状

| 系统 | 已实现 | 尚未确认 / 未完成 |
|---|---|---|
| Player | 模块拆分、移动/形态状态、跳跃辅助、蹲跳/满速跳、碰撞和死亡复位 | 物理大多是工程候选，手感尚未由负责人完整认可 |
| 试玩仪表盘 | 入口选择、暂停/单帧、调参、曲线与导出 | 缺少充分的数值与交互回归证据 |
| 基础实体 | 原有对象+红绿龟/壳/无壳龟、钢盔龟、刺刺、炸弹/爆炸、四向食人花；星星/1UP/10/30/50金币；类型命中与共用组件 | 428项批次检查与52项反馈回归通过；视觉与手感等待负责人试玩认可 |
| 音效 | SKID 循环、退出状态停止、玩家与 BGM 无距离衰减 | 仍需人工试听暂停/演出/死亡后的边界 |
| 美术映射 | Goomba 使用 SMB1 占位；Galoomba 翻倒复用原行走图上下翻转；旋跳秒杀仅星光；刹车使用SMW专用五帧烟尘 | Goomba 独立贴图等待负责人提供；完整多风格表现集未完成，不能从注册表 styles 推断美术齐全 |
| 关卡数据 | 新建/JSON 存读/RLE/对象工厂 | 深度校验、TileMap 转换、运行加载器未接通 |
| 编辑器 | 命令栈基座；SMM2风格独立界面、十槽圆环、工具状态、静态画布、平移/缩放；新批次目录预览/选择 | 实际放置/擦除/对象选择/属性/存读/试玩返回闭环未实现；本轮保持用户布局 |
| 文档工作流 | docs 与新 AGENTS、旧文档归档 | 以后按真实变化持续维护 |

“已实现”不等于“已经交互验收”。2026-09-30 的主场景/仪表盘/实体场景启动检查仅证明当时无 gameplay 加载错误；本轮检查见下方交接。

## 近期顺序

### 1. 稳定可试玩原型

- 修正用户报告的素材/行为问题，建立明确的风格表现映射。
- 实体试玩HUD已增加滚动和奖励统计；收集不同窗口尺寸下的操作反馈。
- 先按[本批试玩步骤](plans/2026-10-09-entity-batch.md)收集龟/壳/刺顶/爆炸/食人花/奖励反馈，再调明确的几何和表现候选。
- 试听刹车整个状态内持续，退出/变身/死亡/复位后无残留；远离世界原点音量保持。
- 使用仪表盘调加速、刹车、跳跃和速度驱动动画；留下输入/曲线/参数与负责人认可记录。

### 2. 做通创作与试玩

- 深度关卡校验、可靠存读、稳定图块 ID 与实体锚点转换。
- 编辑器先完成放置/擦除/属性修改及撤销，再接通独立试玩实例与返回编辑。
- 加入起点、终点和一次完整过关/重新开始流程。

### 3. 扩展关卡机制

多区域、传送管道、相机/卷轴、更多敌人变体、ON/OFF/P/POW/钥匙。当前地面常用怪物和壳已完成；扩展按独立试玩功能拆分。

### 4. 完善长期制作体验

多风格美术、手柄/Android 触控、设置与音频分轨、CourseBot 仓储、资产导入向导和平台导出。法线光影作为可选视觉方向，在核心体验稳定后评估。

## 当前交接：2026-10-17 仓库规范化与首次完整提交

本轮目标：把长期只存在于本地工作区的改动整理成可维护、可推送的仓库，不改游戏行为、不调参数。

已整理：删除被跟踪的根目录 `.DS_Store` 与残留空目录；移除无引用、已被 `player_skid_dust.gd` 取代的 `src/vfx/skid_smoke.*`（备份在本地 `local_debug_output/normalize-backup-2026-10-17/`）；`.gitignore` 按 Godot 缓存 / Mono / 本地媒体 / 日志 / 参考工程 / 代理目录 / 系统临时文件分层；`.gitattributes` 把 `*.import` 由二进制改为文本，补 `*.smmlevel` 与 `*.py`，全仓库文本按 LF 入库。约定记入[决策 0002](decisions/0002-repository-normalization.md)。

未改动：玩家参数与代码、实体逻辑、编辑器界面与关卡数据格式。`src/main/game.tscn` 保持负责人 2026-10-17 16:19 手动保存的内容（地形重画，新增火之花、火焰花问号块、已用块、硬块与板栗仔，玩家出生点移到 (30,-72)，BGM 由 `AudioStreamPlayer2D` 改为普通 `AudioStreamPlayer`），本轮只提交、不修改。

检查：Godot 4.7.2 `--headless --import --quit` 退出码 0，无新增 gameplay 脚本/资源解析错误；日志中只有既有的 MCP 插件 `listen` 空调用、退出时 3 个 ObjectDB 实例与 1 个资源未释放，以及 `GodotWE/` 嵌套 `project.godot` 被忽略的提示。`git diff --check` 通过，跟踪文件按 LF 重新入库。未进行交互试玩。

遗留：`project.godot` 中新增的 `debug_reset/debug_pause/debug_step` 三个输入动作带 `device=16`，在键盘上可能不触发，待负责人试玩 R/F6/F7 时确认。编辑器真实放置/擦除仍未开始。

## 历史交接：2026-10-10 试玩反馈修复

移除实体试玩旧右边界墙（x1528），补齐x1536–1616的连接地面，保留后方悬崖测试。Galoomba翻倒/携带/投掷复用原SMW行走帧并上下翻转，恢复时转正，原翻倒素材保留但退出活动映射。旋跳秒杀经Enemy.spin_defeat立即隐藏并移除怪物，仅生成四颗星光、没有烟雾；刺刺/食人花安全反弹和炸弹点燃分支保持。

刹车原来使用无贴图GPU粒子，现由Player的SkidDust子节点播放专用`skidsmoke_Strip5.png`五帧。按公开源码每8活动帧发射、18fps、17活动帧结束，尺寸减半并贴脚底；离开SKID停止新发射，已有烟尘播完；暂停/变身冻结停止计时，死亡/复位立即清理。旋跳星光按公开源码速度减半，持续16活动帧；用户明确要求去掉源码中的烟雾。

核验：Godot导入退出0，无新增玩法解析错误；52项反馈检查在原生窗口运行全部通过、退出0，428项批次回归通过。已查看通道、原图/翻倒对照、纯星光及刹车烟尘四张实际D3D12窗口截图。负责人尚未认可最终视觉/手感。Headless默认音频首次在52项检查完成后发生退出异常；Dummy音频复核退出0但有资源残留告警，实际窗口检查与截图均正常退出，无残留告警；原有Windows证书/screen=-1与编辑器插件/设置权限诊断仍在。

阅读入口：`data/debug/basic_entities_playground.json` → `galoomba.gd`与`Enemy.spin_defeat` → `src/gameplay/effects/`。试玩：实体场景F6，从原区域走到乌龟区；踩翻板栗仔并搬运/投掷；旋跳击败可秒杀对象；跑动时按反方向观察脚边五帧烟尘。检查工具为`tools/verification/entity_feedback_probe.tscn`与`entity_feedback_capture.tscn`，证据位于`local_debug_output/entity-feedback-*`。

已重新读取antigravity-delegate。Gemini通过官方CLI以`gemini-3.8-flash-medium`分析公开源码摘录，SUCCESS且无工具拒绝；Codex核验继承、帧数与事件后采用星光参数，翻倒图和去烟雾以用户选择为准。结果及验收：`local_debug_output/delegations/2026-10-10-spin-fix/run-01/`。主场景、编辑器场景、project.godot及普通物理Profile与本次起始哈希一致；未提交/推送。

## 历史交接：2026-10-09 怪物与物品批次

负责人授权的六类怪物、五类物品全部实现：红绿龟共享代码，壳按颜色/钢盔/内部翻倒刺壳共享代码，无壳龟与爆炸由所属对象生成；钢盔龟巡逻/缩壳/火球免疫，刺刺普通踩伤与旋跳安全反弹，炸弹保留引信并可手持爆炸，食人花四向锚点/周期/抑制/露出碰撞；星星600活动帧刷新/免伤/接触击敌/临时加速，1UP会话生命计数和10/30/50金币单次奖励。

公共框架保持Enemy/PowerUpPickup/InteractableBlock与Coin Area2D分类。EntityHit/EntityHitResult取代跨类型直接die路径；PickupInteraction统一接触消费，BlockContent统一出块；复用搬运与冻结，BombFuse独立pausable计时。Registry现22对象，编辑器对应圆盘槽位、静态预览和选择已接入，实际放置功能和用户场景布局保持。

SMMWE 4.0.0公开源码为参考：51项原值/换算/适配与20条继承链记入`data/gameplay/entity_parameter_evidence.json`，同步前配置保留于`pre_smmwe_entities.json`。现有敌人走30、重力720、Galoomba恢复600等已同步；金币出块改为参考抛物运动，火焰花/金币9fps；普通玩家永久Profile不变。Goomba继续SMB1占位、Galoomba保持SMW美术身份。51活动素材经现有工具安装，食人花采用源码指定嘴帧，爆炸14帧从既有ZIP提取拼接，原素材保留。

检查：Godot4.7.2导入退出0，无新增解析错误；原生probe **428检查/0失败**，覆盖迁移回归、矩阵、真实火球/壳碰撞、入壳/净空恢复、手持引信/爆炸、四向花、星星/奖励与全部类型暂停/冻结。实际1280×720 D3D12窗口十区截图及星星状态已查看，最近窗口退出无资源残留。Headless快速退出偶有音频播放资源告警，Windows证书/screen=-1、MCP导入插件/编辑器权限问题单独记录。主场景和editor30帧启动通过。

学习与后续：先读[制作规范](entity-production.md)理解状态所有权及接口，再读[数值/交互矩阵](research/2026-10-09-smmwe-entities.md)，按[分阶段计划](plans/2026-10-09-entity-batch.md)在`basic_entities_playground.tscn` F6试玩。十个入口支持复位/暂停/单帧，R清空金币、获得生命与星星。负责人尚未给本批手感/视觉认可；技术实现已完成，后续按分区反馈调整候选。管口为静态地形，不接传送；P/POW/钥匙/其他形态/音乐/TileMap运行破坏等另行推进。

Gemini：仅公开SMMWE源码，经官方CLI实际使用`gemini-3.8-flash-medium`。命令读取被拒绝的run-02空结果不通过；run-03公开摘录无工具整理成功，Codex补继承/计时事件并修正换算与遗漏后采用。结果`local_debug_output/delegations/2026-10-09-entity-batch/run-03/`，本批验收`codex-acceptance.md`；未外发私有工程源码。

default Profile/project.godot/editor.tscn与本轮开始前哈希一致。主场景在任务期间另有保存并增加新怪物实例，整文件哈希已变化；Codex未写入/回退该场景，保留当前保存内容，不声称已证明地形哈希相同。全部改动仍在现有本地工作区，未提交/推送。最终边界、链接与差异检查见`local_debug_output/entity-batch-final-audit.json`。

## 历史交接：2026-10-08

本次目标：修正敌人走路贴图；按负责人要求废弃原 spec/SDD，采用持续维护的 docs 与 Codex 项目指南。

已修改：原来 goomba_res 多外观帧不再加载；Goomba 显式使用 SMB1 16×16 走路双帧与踩扁单帧，Galoomba 使用 SMW 双帧。补源图用途/风格记录与安装/runtime 的声明校验，重新生成 26 张本地素材的清单与 SpriteFrames。错误源列入 rejected_sources，旧本地副本 JSON 已标为 rejected，原 PNG 保留。

文档与数据：旧 20 份文本原样归档，有迁移哈希清单。旧编号不再约束当前工作。玩家物理证据仍保留在 data，历史任务引用已改为归档路径；没有把关卡格式版本或数值校准等级一起重置。

检查：源图已经直接查看，安装工具执行成功。Godot 4.7.2 导入/编译退出码 0，未观察到新增 gameplay 或资源解析错误；已有证书、MCP 插件、编辑器权限与退出残留错误仍在。git diff --check 退出码 0，20 份归档哈希全部匹配，活动文档相对链接有效，主场景地形哈希保持。未新增/运行自动测试，尚未进行交互试玩或试听。

委派：已将负责人要求的 Gemini 自动委派规则写入 AGENTS。官方 CLI 使用 gemini-3.8-flash-medium 做只读复核，但命令权限被拒绝、最终回答为空；Codex 判定未通过验收并接手收尾，没有将 CLI SUCCESS 当作有效审查。结果保留于 local_debug_output/delegations/2026-10-08-docs-review-02/result.json 与 codex-acceptance.md。

继续从本页的“稳定可试玩原型”推进，不重复 Player 重构，不清空工作区。主场景 tile_map_data 保持负责人原有内容；目前所有改动仍在本地工作区，未提交或推送。

详细本轮步骤见 [计划](plans/2026-10-08-docs-and-enemy-sprites.md)。2026-09-30 的原始暂停记录在 archive/tasks/M1-006-audio-and-basic-entities.md，后续现状以本页为准。

补充交接：负责人要求在项目推进中同步学习 Godot，已将改前的模块/状态/入口文件/验收说明与改后的对应核验写入 AGENTS.md。此项仅修改协作说明，未改游戏行为。

后续贴图修复（同日）：负责人明确选择棕色圆头、绿色脚的 SMW 圆栗子造型；Goomba 不再用上方早先交接的 SMB1 图。默认两个敌人共享 SMW 行走图，保留各自行为；Goomba 踩扁使用首帧纵向 0.5 缩放候选并保持脚底对齐。两个本地敌人 PNG 与资产键已改为明确的风格/外观/用途名称，原始图和旧本地副本保留；安装清单与预览 SpriteFrames 重新生成（24 张源图）。Godot 控制台导入退出码 0；通过普通场景启动的节点检查验证所有敌人动画的 runtime/预览路径、帧区域一致，踩扁脚底对齐、死亡翻转、Galoomba 翻倒及拾取开启均通过，无脚本错误。未进行人工交互试玩，踩扁自然度待负责人判断。主场景文件哈希保持不变。

本次 Gemini 复核：模型 gemini-3.8-flash-medium，SUCCESS 且回答非空；源码与配置外发先被自动审批拒绝，负责人明确授权后执行。Codex 核对缩放与行为结论通过；Gemini 报告的资产键不匹配来自审查摘录使用 walk/stunned 展示别名，实际清单键和运行加载一致，判为误报；基类默认视觉组是既有设计，留待需要时调整。结果在 local_debug_output/delegations/2026-10-08-smw-enemy-review/run-01/。

最新决定（同日，覆盖上述共享外观方案）：负责人澄清两类敌人的区别，要求 SMW 中的 Goomba 暂用 SMB1 贴图，之后提供独立贴图。已恢复 SMB1 原生行走/踩扁帧并标记 placeholder，保留明确命名；移除圆栗子缩放踩扁逻辑，Galoomba 的 SMW 图和翻倒/搬运行为不变。重新安装 26 张原样源图并生成 SpriteFrames。Godot 导入与普通场景节点验证退出码均为 0，无节点验证脚本错误；runtime/预览贴图路径与帧一致，Goomba 原生踩扁脚底对齐，Galoomba 翻倒与拾取状态保持。未进行人工试玩。本次小范围修复由 Codex 直接完成，没有再次调用 Gemini。检查日志：local_debug_output/goomba-placeholder-import.log、local_debug_output/goomba-placeholder-verification.log。

## SMMWE 物理研究交接：2026-10-08

负责人报告当前物理手感仍不自然，并提供 arichornlover/SMMWE-SourceCode，要求与Gemini联合调研。已从其README下载最新列出的4.0.0 ZIP，只提取文本源码，保留完整ZIP/文本CRC/哈希清单。包内为SMM_WE-HD工程，60Hz、32px网格；换算到本工程16px尺度后比较。

结果见 [研究报告](research/2026-10-08-smmwe-physics.md) 与 [计划/复现入口](plans/2026-10-08-smmwe-physics-research.md)。已保存JSON、逐帧CSV和四张对照曲线，并用Godot真实PlayerMotion跑合成平地数值探针。核心差异：空中反向过零当前74帧，对照模型24帧；原地长跳高度接近但到顶点24/36帧；满速长跳当前6.65格，对照模型5.61格；当前点按短跳更高。地面跑速/加速本身相近，调校应优先空中反向和整体跳跃曲线。

SMMWE普通Mario、游泳、冰雪/低重力、P槽/动画、掩码/碰撞入口已整理；特殊能力只给定位和部分常量。NSMBU独立对象多数数值约半尺度，未证明运行补偿，未混入SMW表。SMMWE数字是同人源码参考，尚未运行GameMaker/发布版或进行人工A/B试玩，不认作SMM2实测或负责人认可。

Gemini：官方Antigravity CLI，实际gemini-3.8-flash-medium，SUCCESS、非空报告，无工具拒绝。Codex验收核心提取通过，修正P槽固定充满时间、终端限速时序和土狼窗口边界；不采纳未经运行的抖动/缺陷推测。原始结果与验收放 local_debug_output/delegations/2026-10-08-smmwe-physics/run-01/。

本轮没有改玩家运行参数、玩家源码、project.godot或主场景，哈希保持；只新增研究与数值工具及文档入口。未提交/推送。下一轮用可切换实验配置比较216/468空中同向/反向力与360/1080重力、三档起跳和顶点前阈值；保留负责人已确认的跑姿、满速跳和蹲跳锁存规则。

## SMMWE 默认数值同步交接：2026-10-08

负责人要求同步数值供试玩，已完成默认 SMMWE 白天 SMW 参考配置与算法：走78/跑180、同向216/反向468、摩擦180/超速90；三档起跳−237/−243/−258、旋−198，重力360/1080、vy>−30锁存，落速积分前240；顶头0、踩踏−253.5。旧配置完整保存在 pre_smmwe_physics.tres，仪表盘提供两套预设。已确认的姿态、来源键、辅助和P槽规则保留；旋跳键降级普通跳后的踩踏来源边界在参考模式修复。碰撞盒/动画步频/特殊能力未同步，不宣称完整SMMWE移植。

详见 [实现/试玩/复现记录](plans/2026-10-08-smmwe-physics-sync.md) 和 [新测量JSON](research/smmwe-sync-2026-10-08.json)。Godot原生新旧参数数值对照139项和实际Player合成地面边界断言160次通过，主场景及仪表盘可启动；原地/满速长跳约4.71/5.61格、顶点36/40帧，空中反向24帧。验证辅助场景早期销毁/退出访问异常已通过等待帧清理修正，最终退出0；已有证书/MCP/编辑器权限问题仍区分记录。尚未负责人试玩认可，不认作官方SMM2实测。

Gemini实际 gemini-3.8-flash-medium，SUCCESS、非空只读审查，无工具拒绝；Codex部分采纳来源键疑点，核验后排除反向分段/终端后钳/缓冲重复重力/切换残留的误报。结果与验收在 local_debug_output/delegations/2026-10-08-smmwe-sync/run-01/。

主场景地形、PlayerCollision/PlayerAnimator/project.godot哈希保持，未提交/推送。重新F5运行主场景即可试玩；仪表盘可切调整前版本。接下来由负责人比较换向、长短跳和满速跳手感，再决定后续微调。

## 轻飘反馈复核交接：2026-10-09

负责人试玩默认SMMWE参考后报告“轻飘飘，像在月球上”，该配置尚未获认可。复核未发现delta/单位重复换算；原地长按上升重力900→360、顶点24→36帧、腾空46→61帧，确有明显更慢的节奏。

新增公开3.4.2F普通16px分支对照：初速和360/1080重力归一后与HD一致，不能据此将重力改720当纠错；大重力阈值是−60而HD归一为−30，移动跳门槛60而HD为30。临时阈值探针将原地顶点/腾空改为33/57、满速36/65，只解释部分差别。默认参数和游戏代码保持，反馈已入证据；后续配对调初速/重力必须标为手感候选，或先通过实际SMMWE录像校准。

详见 [复核报告](research/2026-10-09-smmwe-float-audit.md) 与 [测量/来源哈希](research/smmwe-float-audit-2026-10-09.json)。本轮只读真实PlayerMotion跑两组配置，未运行GameMaker或做人工A/B。上轮通过的含义是实现与源码模型一致，不代表发布版手感还原。

Gemini实际gemini-3.8-flash-medium，SUCCESS、非空只读审查。Codex采纳单位换算与跨版本主数值对照；收窄完整还原、作者遗漏与关卡损坏推断，以离散实测取代连续高度估算。结果与验收在 local_debug_output/delegations/2026-10-09-float-audit/run-01/。

## 编辑器界面框架交接：2026-10-09

负责人确认了首轮范围与学习方式：Codex 实现、负责人分阶段观察；原版布局加电脑操作、原版圆环、独立 F6 场景。已完成 `src/editor/editor.tscn`、Theme、局部 EditorState、Registry 分类的八槽圆环、静态首帧预览、独立 SubViewport/Camera2D、16px 网格、鼠标格高亮、中键平移、1～4倍鼠标锚点缩放和同步位置滑条。界面中文；工具/面板/网格快捷键通过 InputManager 内存注册，未修改项目入口。

Godot 原生 GUI/输入与真实 D3D12 渲染检查204项通过，960×540、1280×720、1920×1080界面与圆环截图已直接查看。覆盖全部10个有效物件槽位、中心/空槽、关闭/外侧点击、文字焦点、失焦取消拖动、相机实际变换、缺图名称占位、面板阻断及关卡数据保持。修正了工具重复点击取消选中、滑条范围更新触发反馈、静态标签翻译键未刷新及退出时悬停回调访问已销毁节点的问题。没有物件运行实例或数据写入；技术检查不代表人工操作或负责人认可。

委派：官方 Antigravity CLI 初次模型查询因沙盒网络失败；授权执行重试被自动审批拒绝，理由是没有明确授权将四个私有编辑器源码摘录发送至外部 Gemini。未选择/调用到实际模型、无 Gemini 报告。Codex 接手复核，保留失败/拒绝与验收记录于 `local_debug_output/delegations/2026-10-09-editor-framework/`；若负责人明确授权这些摘录外发，可继续补独立复核，不绕过拒绝。

主场景、默认物理和 project.godot SHA256 保持。默认渲染日志实际为 D3D12/Forward+，已修正文档对 features=Mobile 的推断。已知证书/插件/设置写权限错误仍独立记录；原生窗口启动还报告 screen=-1 的环境问题，但截图和检查完成。未提交/推送。

下一步：负责人在 Godot 打开 editor.tscn，F6 检查布局/圆环/平移缩放，按 [教学与复现记录](plans/2026-10-09-editor-framework.md) 追踪节点和信号，再基于反馈接真实放置/擦除/撤销。F5 继续原试玩。

## 已知工程问题

- Godot 编辑器导入仍可能报 MCP 插件 null.listen、编辑器设置保存权限、退出资源残留；启动有 Windows root certificate store 错误。
- 缺少完整媒体时，新克隆不能直接运行所有场景；现有安装工具只覆盖选定基础素材。
- LevelManager 当前加载只做浅校验，RLE 的非法整数/计数与实体 schema 仍需加强。
- 没有将 NSMBU 逆向参数认作 SMM2 数值；小型下蹲和满速跳姿态以负责人直接反馈为依据，精确碰撞盒仍待复测。

## 编辑器视觉返工：2026-10-09

负责人否定首版布局，指定提供的1920×1080 SMM2截图为基准，缺失图标先留空。已重做全屏画布、半透明顶栏/侧托盘、十二原图卡片、菜单/Coursebot/橡皮擦/狗/火箭、左下试玩板、右下主区域。卡片及布局保存为Godot可调整的场景节点。UI与相机密度同比例缩放，1920×1080初始每格80px，逻辑缩放仍为2（1～4）。电脑快捷键/中键/滚轮保持；网格、位置滑条和缩放状态移入菜单。选擦除后保留当前物件卡片标记。

原生GUI/输入/D3D12渲染334项通过，三种尺寸及擦除/菜单/圆环截图已直接查看。覆盖参考位置/尺寸、Registry边界、遮挡输入、坐标/鼠标锚点缩放、菜单滑条、缺图留空及数据保持。无新增脚本/资源错误；现有证书/screen=-1、导入插件/设置权限问题独立记录。主场景、默认物理、project.godot的SHA256保持，未提交/推送。

证据在`local_debug_output/editor-reference-verification.json`、`reference-editor-*.png`、`reference-wheel-*.png`、`editor-reference-assets.json`、`editor-reference-import.log`和`editor-reference-capture.log`。素材清单/安装与Godot观察步骤见[更新后的计划](plans/2026-10-09-editor-framework.md)。本次视觉及关联输入修正由Codex完成，无新Gemini调用，未绕过上次外发审批拒绝。

下一步：负责人F6判断图标大小/阴影、浮层比例/透明度和电脑操作。缺失专用图标留空是当前明确要求；参考图关卡内容尚未接入编辑数据。视觉认可待反馈，再接真实编辑与命令栈。


## 编辑器后续视觉与字体修正：2026-10-09

负责人再次否定通用提示/说明预览，指定图4物件留白、图5悬停四角和图6调色盘，并要求本地fonts字体，随后确认先统一英文。已移除通用tooltip、设置/Coursebot说明弹窗与擦除气泡；设置/Coursebot禁用，真实视图菜单保留。卡片图缩进白色范围，悬停显示原素材橙红四角。调色盘改为全屏十槽浅粉圆环/虚线分隔/白卡/分类色中心、选中分类长条、关闭黑叉和循环翻页；未注册图只展示、空槽不选择。

子视口默认线性过滤造成背景糊，已将子视口与World显式改为最近邻；实际1920×1080背景4029点与原图匹配，最大RGB差0。普通文字/数字使用本地MPLUSRounded1c-Bold、标题使用MARIOMAKER；系统回退禁用，英文界面，无新增中文版。

Godot4.7.2原生GUI/输入/D3D12渲染386项通过，三种窗口截图已查看。包括每槽实际图像、容器选中宽度、十个注册物件/未注册与空槽、翻页/关闭、坐标/缩放/遮挡/快捷键和数据保持。技术通过不代表负责人已认可。报告local_debug_output/editor-polish-verification.json，截图polish-*.png，日志editor-polish-import.log、editor-polish-capture.log与editor-polish-start.log。主场景/默认物理/project.godot哈希保持。

本轮由Codex完成，无新Gemini调用，未重试此前自动审批拒绝的源码外发。下一步负责人F6检查英文字体、卡片留白、三角与图6布局，再接真实编辑。教学/复现见[计划](plans/2026-10-09-editor-framework.md)。未提交/推送。

## ArtView/CapView及圆盘修正：2026-10-09

负责人已改ThemeButton/ArtView并注释Art父级绘制；本次保留其偏移、尺寸与rounded_art_mask Shader，其他按钮补齐ArtView，12个Cap改为CapView子节点。脚本仅同步贴图，不覆盖子节点布局/材质；贴图节点忽略鼠标。Feedback独立层保留工具栏四角/标记/快捷键，调色盘分类与翻页不画四角。

按图2，物品悬停填充同分类色扇区并连到中心，离开取消；不用物品四角。圆盘坑洼来自旧_pixel_disk()圆周点吸附5px再连线，已换为draw_circle抗锯齿，悬停扇区保持精细圆弧，无粗网格吸附。代码定位PaletteWheel._draw()/_draw_sector()，尺寸由场景Wheel Control控制。

原生Godot4.7.2/D3D12检查504项通过，三尺寸截图已查看，包括用户子节点/Shader保持、同步不重排、鼠标透传、扇区实际像素和已有快捷键/坐标/菜单边界；报告local_debug_output/editor-art-children-verification.json、截图art-children-*.png及同名前缀日志。技术通过不代表视觉认可。原主场景/默认物理/project.godot哈希保持，未提交/推送。本次耦合修正由Codex完成，无Gemini调用。下一步负责人F6调整节点与检查圆盘效果。

后续Cap/字体反馈：12个CapView已按保存的火焰花核对统一为9.636364px，各自颜色保持。按钮先前指定MARIOMAKER而Label/计时器使用MPLUS导致字体不同；Theme现在统一MARIOMAKER。场景内静态英文直接保存，Godot编辑器预览不再显示MAKER_PLAY_CAPTION等翻译键。原生三尺寸523项检查通过，新增同字体/文字宽度/英文Caption与参考Cap高度核对；证据editor-cap-font-verification.json、cap-font-*.png、editor-cap-font-capture.log，旧报告保持。主场景/物理/project.godot哈希保持，视觉认可待负责人确认。此次小范围修正由Codex直接处理，无Gemini调用。


随后按负责人要求，将全部12个CapView的position.y统一为−8；同步移动上下偏移，保持9.636364px高度、X和颜色。已核对保存的场景值，此次仅布局数值调整，未重跑完整交互检查。

## 移除快捷键徽标与UI清晰度：2026-10-09

按最新反馈删除B/E浮动字母绘制、V的KeyBadge子树及废弃主题样式，B/E/V等逻辑Action保持。SVG底板/图标/Cap使用独立线性采样，PNG物件/背景最近邻；编辑器窗口随参考比例设置SVG oversampling，UI几何4×MSAA，退出还原此前设置。本地MARIOMAKER/MSDF、用户ArtView布局/Shader、全部CapView.y=−8保持。未修改全局像素过滤或F5配置。

原生Godot4.7.2/D3D12检查654项通过，960×540、1280×720、1920×1080、2560×1440、3840×2160截图检查完成。实测SVG从105×115到4K的420×460，背景4029点最大RGB差0；覆盖快捷键/坐标/遮挡/调色盘与退出渲染设置还原。独立场景启动通过，无新增脚本/资源错误；已有证书/screen=-1环境错误单独记录。报告local_debug_output/editor-sharp-ui-verification.json，截图sharp-ui-*.png，启动与渲染日志editor-sharp-ui*.log。主场景/默认物理/project.godot/用户Shader哈希保持；小范围关联修正由Codex完成，无Gemini调用，未提交/推送。下一步负责人F6视觉验收，再继续编辑数据工作。
