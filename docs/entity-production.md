# 怪物与物品制作规范

更新：2026-10-10。当前交付为 SMW 地面白天版。阅读顺序：本页 → [数值与交互矩阵](research/2026-10-09-smmwe-entities.md) → [分阶段实现及试玩](plans/2026-10-09-entity-batch.md)。

## 分类与状态所有权

统一的是制作接口和共用能力。`Enemy`、`PowerUpPickup`、`InteractableBlock` 分别保留分类基类；金币继承 `Area2D`，不用怪物状态机模拟拾取。

| 模块 | 拥有的数据及修改时机 |
|---|---|
| `Enemy` | 公共 WALKING/STUNNED/HELD/THROWN/SQUASHED/DEAD，运动、传感器、死亡；通过转换入口修改 |
| `Koopa` / `NakedKoopa` | 颜色、脱壳方向；无壳龟独立的滑行/恢复/寻壳/跳入阶段和免疫时间 |
| `KoopaShell` | 壳种类、占用者、翻倒、滑动、高抛、踢出保护、恢复时间、扫掠接触去重 |
| `BobOmb` / `BombFuse` | 怪物负责点燃/搬运/投掷；组件独立拥有剩余引信，只允许首次点燃初始化 |
| `PiranhaPlant` | 管口锚点、方向、露出长度、伸出/停留/缩回/等待；按露出长度更新碰撞和裁剪 |
| `PickupInteraction` | 接触候选和一次性消费；接受回调成功才标记已拾取，失败保留接触以供下一活动帧重试 |
| `BlockContent` | 统一 `release_from_block(player, start, target, frames)`；具体内容负责自身运动与奖励 |
| `PlayerStatusEffects` | 星星剩余600活动帧与颜色相位；Player 在活动物理步末递减，形态由 PowerUpManager 继续负责 |
| `GameManager` | 当前试玩金币与“获得的额外生命”，复位清零；没有生命耗尽或 Game Over |

`ICarryable` 与 `PlayerCarry` 管理抓取候选、挂起碰撞、跟随和释放；不统一所有对象的计时方式。Galoomba 随自主过程挂起恢复计时；炸弹引信使用独立 `PROCESS_MODE_PAUSABLE` 子节点，携带时仍计时。场景暂停与 GameManager 变身冻结都停止引信。`GameplayFreezeGate` 保留节点处理模式，释放时恢复正确模式。

## 命中与奖励入口

`EntityHit` 明确区分 STOMP、SPIN、FIREBALL、SHELL、THROWN、BUMP、STAR、EXPLOSION，并携带来源、玩家、方向。`receive_hit()` 返回 `EntityHitResult`：是否生效、攻击物是否消耗、NONE/NORMAL/SAFE_SPIN 反弹。安全旋跳可以不伤害怪物而反弹玩家；钢盔龟可以不受火球伤害而消耗火球。

Player、PlayerFireball、壳、投掷 Galoomba、顶块、爆炸统一发送命中请求；调用者不直接决定其他怪物 `die()`。各类型按自己的分支选择死亡、脱壳、点燃、缩壳或忽略。普通玩家反弹继续使用既有运动模块，临时星星通过 `motion.speed_bonus` 改走/跑门槛，永久 Profile 不变。

旋跳秒杀使用`Enemy.spin_defeat()`：复用具体类型清理与defeated信号，当帧隐藏并移除，生成由所在世界拥有的四颗星光（16活动帧），按负责人要求没有烟雾。其他攻击继续采用各自死亡表现；刺顶安全反弹与炸弹点燃不进入秒杀入口。Galoomba翻倒/携带/投掷用原行走帧上下翻转，恢复转正。表现节点位于`src/gameplay/effects/`；玩家SkidDust拥有刹车烟尘的发射、逐帧动画和清理，独立于运动状态机与普通物理数值。

拾取提交在安全物理步完成；奖励仅结算一次。金币使用带面额的同一实现，三种大金币只允许场景放置。问号块通过 Registry 创建对象、检查 `BlockContent`、变成已用块并调用出块入口，支持金币、蘑菇、火焰花、星星、1UP。

## 统一制作步骤

1. 从公开来源追踪对象 `.yy` 的父类、Create/Step/Alarm/Collision/User Event，先分清 SMW 白天分支与其他风格。记录原值、单位、换算、工程适配；同步前配置保存在 `data/gameplay/pre_smmwe_entities.json`。
2. 选择合适基类，列专属状态和允许转换；派生对象由所属怪物生成，不给无壳龟、爆炸、翻倒刺壳增加独立编辑器入口。共享红绿龟、各类壳及各面额金币的代码。
3. 逐帧查看源 PNG，核对完整尺寸、用途、风格、锚点和索引。多外观图不是动画，壳旋转帧不用 walk，花嘴循环不用 walk。爆炸从已存 ZIP 按 YY 帧顺序拼接原始 PNG，不重采样。
4. 在 `data/assets/basic_smw.json` 登记元数据，用 `tools/asset_pipeline/install_basic_assets.py` 复制素材并生成清单和 `data/visuals/basic_smw_*.tres`。运行时 BasicSpriteLibrary 与静态预览读取同一映射。
5. 在 `prototype_entities.json` 添加类型配置；在 `objects.json` 登记稳定 ID、共享场景、属性类型/枚举、风格。工厂先校验属性，再实例化；整数枚举兼容 JSON 的整数浮点表示，拒绝小数及越界值。
6. 将可放置对象加入 EditorCatalog 的圆盘槽位、名称和静态预览，以及独立试玩 JSON 的分区入口。静态预览不实例化 gameplay；不修改编辑器布局或实际放置功能。
7. 先回归现有对象，再验证交互矩阵、真实移动/碰撞、计时/暂停/冻结、死亡/复位/退出。分别保存导入、原生物理、窗口观察和负责人认可记录，不用一类证据替代另一类。

## 扩展时容易遗漏的边界

- 转换实体先保存 `feet_position()`；净空不足延迟恢复。完成转换用 `retire()`，真正死亡用 `die()`。
- 新建 Node 组件在 `_ready()` 中创建并挂入树，避免场景预览或继承场景初始化产生未挂入树的节点残留。
- 高速壳使用前后位置扫掠查询，持续接触去重；双壳互相结算。墙面反弹后正常恢复玩家伤害，保护窗口不能无限延长。
- 引信和恢复时间不能在每次拾取、投掷、踩停中重新初始化。死亡停止引信，移出场景释放本轮火球/携带对象并清空临时效果。
- 爆炸按目标 ID 去重，身体与传感器查询可命中同一对象但只结算一次；已转动的翻转块也能被爆炸破坏。手持爆炸明确包含持有者，仍走普通伤害免疫规则。
- 食人花完全隐藏时禁用伤害和攻击查询；半程前的源码 hardness 保护与“露出部分会伤害玩家”是两个不同规则。

当前源码参考不等于 SMM2 实测。碰撞盒、接近区域、携带偏移、部分警告动画仍是明确的工程候选；负责人试玩认可留在 roadmap。
