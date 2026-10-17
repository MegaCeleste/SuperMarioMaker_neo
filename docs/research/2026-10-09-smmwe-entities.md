# SMMWE 4.0.0 怪物与物品来源

日期：2026-10-09。主要来源是本地公开源码 ZIP，索引为 [SMMWE SourceCode](https://github.com/arichornlover/SMMWE-SourceCode)，沿用上一轮保存的 4.0.0。源码目录 `local_debug_output/smmwe-research/source/`，ZIP SHA256：`ce2b957af1e1efe68c678d0c38895d325a61a5852212e1feb52e43abdeb9c528`。

机器可读记录在 `data/gameplay/entity_parameter_evidence.json`：51 个已采用数值、20 条完整继承链、来源文件 SHA256、同步前值与适配。重建工具 `tools/research/build_entity_parameter_evidence.py` 检查配置与已审核数值一致，不充当 GML 自动解释器。旧配置保存在 `data/gameplay/pre_smmwe_entities.json`。

## 换算及主要参数

源游戏32px格 → 本工程16px格，物理60Hz：速度×30、加速度×1800、距离×0.5；活动帧计时不变。这里只选 SMW/地面/白天、无翅膀/无降落伞分支；Goomba 行为选择 SMB1 踩扁分支，美术保持已决定的 SMB1 占位，Galoomba 选择 SMW 翻倒分支。

下表事件路径相对于公开源码 `objects/`。更多事件、继承与同步前值见上述 JSON。

| 对象 / 参数 | 源值 → 工程值 | 主要来源 |
|---|---|---|
| 普通敌人巡逻 | 1px/帧 → 30px/s；旧40 | `obj_galoomba/Alarm_10.gml` |
| 普通重力 / 落速阈值 | 0.4 → 720px/s²；8 → 240px/s | `obj_physicsparent/Other_14.gml` |
| 普通死亡向上初速 | spd=4、vspeed=−spd → −120px/s；旧−200 | `obj_enemy_dead/Alarm_0.gml` |
| Goomba 踩扁消失 | 30 → 30活动帧 | `obj_stomped/Create_0.gml` |
| Galoomba 恢复 | 600帧；旧300，搬运暂停 | `obj_galoomba_hold/Create_0.gml` |
| Galoomba / 普通搬运物投掷 | 4+玩家速度 → 120+玩家px/s；vy=−3→−90；高抛−12.25→−367.5 | `obj_holdparent/Other_12.gml` |
| 搬运物落地减速 | 每帧0.17 → 306px/s² | `obj_holdparent/Step_0.gml` |
| 蘑菇移动 / 顶块初速 | 2 → 60px/s；−6 → −180px/s | `obj_mushroom/Alarm_10.gml`、`Collision_obj_blockparent.gml` |
| 火焰花与金币切帧 | image_speed=0.15 → 9fps；旧5 | 各自 `Create_0.gml` |
| 出块金币 | vy=−4→−120，gravity=0.2→360，下落跨越ystart−20→−10px时结束 | `obj_blockcoin/Alarm_0.gml`、`Step_0.gml` |
| SMW 乌龟普通踩踏 | 独立空壳+无壳龟；弹出±6→±180px/s，30帧免疫 | `obj_koopa/Other_11.gml` |
| 无壳龟 | 减速0.1→180，恢复90帧，恢复跳−4→−120，入壳跳−5.2→−156 | `obj_beachkoopa/Step_0.gml`、`Alarm_10.gml` |
| 入壳变回带壳龟 | 绿60 / 红70活动帧 | `obj_beachkoopa/Collision_obj_shell.gml`、红色对应事件；`obj_shell/Alarm_7.gml` |
| 壳踢出 / 加速 | 初速4→120，普通目标4.4→132，0.1→180px/s²；移动玩家贡献半速 | `obj_shell/Other_12.gml`、`obj_shell_held/Step_0.gml` |
| 手持壳普通投掷 | 静止玩家初速4、目标5→120/150；移动玩家初速4.4+半速，目标最多6.4→192 | `obj_shell/Other_12.gml` |
| 壳踢出保护 | 15帧 | `obj_enemyparent_held/Create_0.gml` |
| 钢盔龟踩缩壳 / 顶翻壳 | 640 / 600恢复帧，壳 hardness=100 | `obj_buzzybeetle/Other_11.gml`、`Other_15.gml` |
| 乌龟顶翻壳 / 刺刺顶翻 | 乌龟600帧后脱出无壳龟；刺刺640帧后恢复 | 各自 `Other_15.gml`；`obj_shell/Alarm_4.gml` |
| 炸弹引信 | 300活动帧；余60帧闪烁；搬运继续，点燃/踩停/再次搬运不刷新 | `obj_bobomb_hold/Create_0.gml`、`obj_bobomb_ready/Other_11.gml` |
| 炸弹火球响应 | 首发点燃；已点燃时vx=±1.2→±36、vy=−1.5→−45 | `obj_fireball/Collision_obj_bobomb.gml`、`Collision_obj_bobomb_hold.gml` |
| 爆炸 | 30帧；击败 hardness<99 的敌人，邻近炸弹直接死亡 | `obj_explosion/Create_0.gml`、`Collision_obj_enemyparent.gml`、held父类爆炸事件 |
| 食人花周期 | 速度1→30；伸32+停90+缩32+等90帧；伸出32→16px | `obj_piranhaplant/Alarm_0..3.gml` |
| 食人花保护 | 行进16帧后 Alarm_5 翻转 hardness，换算为露出8px的攻击门槛 | `obj_piranhaplant/Alarm_0.gml`、`Alarm_2.gml`、`Alarm_5.gml` |
| 星星实体运动 | 水平1→30；重力0.125→225；地面跳−4→−120 | `obj_star/Alarm_10.gml`、`Step_0.gml` |
| 星星玩家效果 | 600活动帧，重复刷新600；走/跑门槛加1→30px/s | `obj_invincibility/Create_0.gml`、星星接触事件、`obj_mario/Other_12.gml` |
| 1UP运动 / 顶块 | 1→30px/s，−3→−90px/s | `obj_1up/Alarm_10.gml`、`Collision_obj_blockparent.gml` |
| 大金币奖励 | 10 / 30 / 50，源对象数字ID映射为稳定语义ID | `obj_coin10/Other_12.gml`，obj_coin30/50继承它 |

## 交互矩阵

2026-10-10反馈修正：下表“旋跳击败”表示当帧消失，仅留下四颗星光，不产生飞行尸体或烟雾。板栗仔普通翻倒按负责人要求复用原行走帧上下翻转，属于用户美术选择。星光源为`smw/objects/star_explosion_Strip1.png`，8×8单帧，运行尺寸减半；`obj_spinsmoke/Alarm_0`的每帧位移(2,1)换算为(1,0.5)px，`Alarm_1`保持16活动帧。源码同时绘制烟雾，工程遵从用户要求不使用。刹车源为`smw/miscellaneous/skidsmoke_Strip5.png`，8×8五帧；`obj_mario/Alarm_5`每8帧发射，`obj_smoke/Create_0`速度0.3帧/步换算18fps，五帧共17活动步，半尺寸贴脚底；首次发射安排在进入SKID时，这是工程适配。

“击败”走类型死亡；“安全弹”不伤害敌人、玩家安全反弹。火球命中免疫对象仍消耗。下表是本轮采用的已实现规则，原生检查覆盖八类怪物×八种命中；场景传感器负责普通踩踏伤害判定，单独的命中请求不直接扣玩家形态。

| 对象 | 普通踩踏 | SMW旋跳 | 火球 | 滑动壳 | 投掷物 | 星星 | 爆炸 | 顶块 / 搬运 |
|---|---|---|---|---|---|---|---|---|
| Goomba | 踩扁 | 击败 | 击败 | 击败 | 击败 | 击败 | 击败 | 击败 / 无 |
| Galoomba | 翻倒 | 击败 | 击败 | 击败 | 击败 | 击败 | 击败 | 翻倒弹起 / 翻倒可搬运，恢复暂停 |
| 红绿龟 | 脱壳+同色无壳龟 | 击败 | 击败 | 击败 | 击败 | 击败 | 击败 | 翻倒有龟壳 / 壳可搬运 |
| 钢盔龟 | 缩壳 | 击败 | 免疫 | 击败 | 击败 | 击败 | 击败 | 顶翻钢盔壳 / 壳可搬运 |
| 刺刺 | 玩家受伤 | 安全弹 | 击败 | 击败 | 击败 | 击败 | 击败 | 顶翻为内部刺壳 / 可搬运；不做佩戴 |
| 炸弹兵 | 点燃/踩停 | 点燃/踩停并反弹 | 首发点燃，后续推开 | 击败 | 击败 | 击败 | 击败，无连锁起爆 | 点燃弹起 / 点燃可搬运，引信继续 |
| 食人花 | 玩家受伤 | 安全弹 | 露出≥8px击败 | 露出≥8px击败 | 露出≥8px击败 | 露出时击败 | 露出≥8px击败 | 露出时击败 / 无；隐藏完全无伤害 |
| 红绿壳 | 静止踢出 / 滑动踩停 | 击败 | 击败 | 双壳互败 | 击败 | 击败 | 击败 | 弹起 / 可搬运、高抛 |
| 钢盔壳 | 踢出 / 踩停 | 击败 | 免疫 | 双壳互败 | 有龟壳免疫 | 击败 | 有龟壳免疫 | 弹起 / 可搬运、高抛 |

爆炸还会破坏硬块、翻转块（包含转动中），问号块释放原内容后保持已用状态；同次爆炸按目标ID只结算一次。TileMap 不参与运行时破坏。

## 适配与美术依据

- GameMaker像素掩码/预测碰撞改为 Godot 矩形、射线、移动求解和高速壳扫掠；恢复增加净空检测和脚底对齐。碰撞尺寸、寻壳窗口、清理边界仍是工程候选。
- 食人花横向源码接近判定的Y上/下界相等；工程采用向上区域旋转到四方向，并基于玩家脚底统一判定。完全隐藏时禁用碰撞与伤害，不照搬隐藏实体重叠伤害。
- 爆炸使用半尺寸源码mask bbox2..47得到的11.5px圆形候选。保留既有玩家搬运偏移，明确包含手持爆炸的持有者；星星仍免疫普通爆炸，强制死亡仍生效。
- 手持高抛保留纯垂直轨迹，省略源码的微小水平漂移；炸弹侧踢126px/s、警告动画/色循环及部分锚点作为候选单列，不能标为官方数值。
- 星星不改永久 Profile 或玩家形态；不移植参考的420帧音乐切换，结束后通过既有减速处理超速。1UP只增加本轮会话获得生命数。
- 食人花SMW `.yy` 指向 `spr_jumppiranha`；采用 `jumppiranha_Strip4.png` 的嘴部循环。`pplant_res_Strip4` 这种多外观预览不进入动画。51张活动素材逐帧核对，壳/刺壳/花嘴分别标明用途；爆炸14帧38×38从ZIP原帧无重采样拼接，运行时0.5显示。
- 既有 Goomba 使用 SMB1 走路/踩扁占位，Galoomba 保持 SMW 美术与翻倒身份。现有决定不被本轮数值同步覆盖。

## Gemini 整理与 Codex 验收

按 antigravity-delegate 通过官方 Google 登录 CLI 实际调用 `gemini-3.8-flash-medium`，仅提供公开SMMWE源码。run-02 的源码阅读命令被CLI拒绝且回答为空，验收失败；run-03 以公开摘录直接输入、禁用工具，SUCCESS且报告非空。未外发私有工程源码。

Codex独立追踪了报告缺失的 Alarm_10/Alarm_7/Alarm_4 及父类事件，核验并采用计时/运动摘要；修正“32px行程”需半尺寸换算，以及食人花半程hardness保护等遗漏。报告是经补充核验后采用的研究输入，不是自动证明整个交互矩阵通过。

本地结果：`local_debug_output/delegations/2026-10-09-entity-batch/run-03/response.md`、`result.json`；验收解释在同批目录 `codex-acceptance.md`。源码证据、原生物理检查、实际窗口观察和负责人手感认可四者分开保存。
