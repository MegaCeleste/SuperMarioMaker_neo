# 任务单：M1-004-独立研究与 Player 完整重构

> **状态**: done
> **下达日期**: 2026-09-29
> **完成日期**: 2026-09-30
> **执行者**: Codex
> **关联里程碑**: M1

## 目标

依据可追溯的 SMM2 研究修正旧假设，替换全部遗留 Player 状态脚本，交付可以在场景中校准的玩家运动、动画、碰撞、形态与交互系统。

## REQ-ID 引用清单

REQ-ARC-003、REQ-COL-001~003、REQ-INP-001~004、REQ-STD-001~003/005；REQ-PHYS-001/005/006/008、101~106、108~117；REQ-PWR-001~009、010~013；REQ-AST-008。

## 范围

- 新建研究记录、参数证据 JSON、Player 输入/运动/碰撞/动画/变身/搬运组件。
- 修改相关 draft spec、Profile、Player 场景、仪表盘、输入配置及当前蘑菇/栗子球/问号块的对接；增加用于场景演示的火球和搬运探针。
- 删除已断开的旧 movement State / StateMachine / wrapper 及其无用 UID；保留 Player 场景 UID 和公共拾取/受击/顶块 API。
- 保留主场景及现有本地素材；禁止修改 approved spec、添加媒体到 Git、把未测值标为 VERIFIED/TUNED。
- 水下、斜坡滑铲、坐骑、飞行、NSMBU/3DW 专属动作归后续系统；本次完整范围为当前 SMB1/SMB3/SMW 常规地面与空中 Player。

## 实施要点

1. 只有可定位的 SMM2 一手证据支持的数值可标 VERIFIED；工程设计和反馈拟合明确标 CANDIDATE。
2. 运动与形态状态独立；每物理帧只执行一次正常 move_and_slide；输入快照、碰撞修改及 Area 事件队列按固定顺序处理。
3. 跑速上限统一为 run_max；P-Meter 不修改跑速/跳高。空中保留已获得的水平动量。
4. 修复蹲跳、刹车锁存、动画相位与变大误下蹲；加入独立受击盒、受伤降级、无敌帧、变身定格、死亡弧线和重置接口。
5. 仪表盘调参只修改实例 Profile；导出数据不自动覆盖基线或提升校准状态。
6. 2026-09-30 追加要求：独立完成移动状态机与形态/演出状态机，禁止外部直接写状态；死亡只经复位退出，公开进入/退出/阶段事件并在 HUD/CSV 中记录。

## 完成核对

- [x] 研究来源与参数证据落盘，错误 P-Speed 假设废弃。
- [x] 旧 Player 状态代码完全退出执行与引用。
- [x] 运动、动画、碰撞、形态和当前实体对接完成。
- [x] 独立移动状态机及形态/演出状态机完成，状态只能通过规定入口改变。
- [x] 仪表盘调参、逐帧观察、导出记录的实现交付。
- [x] Godot 导入和两个场景可启动。

## 验证与回报

执行 Godot 导入/脚本编译与主场景、仪表盘启动检查；本次不新增或运行 GUT。运行检查不能替代手感签认。记录命令摘要、未核实 SMM2 参数、范围外发现；TUNED 仍待负责人试玩。

## 完成回报

### 实装结果

- Player 编排输入快照、运动模型、碰撞查询、动画、形态及搬运；正常物理步只调用一次 move_and_slide。
- PlayerMovementStateMachine 提供 IDLE/RUN/AIR/CROUCH/SKID/DEAD、进入/退出/转换信号和死亡终态保护；PowerUpManager 提供形态转换表、ACTIVE/TRANSFORMING/DEAD 阶段及演出中断事件。
- 修正演出期间的拾取/伤害入口、死亡计时起点、复位清理、冻结时放下搬运物的恢复顺序，避免残留计时和 actor 永久停下。
- 按负责人观察接入满速切跑姿、满速跳 p_jump 保持到落地、小型下蹲及蹲跳保持；动画按位移推进，刹车锁存到归零。
- 独立地形盒/受击盒、踩踏优先的敌人接触队列、蘑菇变身、顶问号块已与新 Player 对接；Fire 火球及 ICarryable 探针用于能力校准。
- 保留 Player 场景 UID；删除全部旧 Player wrapper / State / StateMachine，src/data 中已无旧路径或 p_speed/super_jump_initial 引用。历史任务 M1-003 标记为 rejected 并保留记录。
- 相关 draft spec 已更新。工程交付范围为当前三风格常规地面/空中能力，手感签认仍待执行。

### 编译与启动输出

引擎：Godot 4.7.2 stable。命令均在项目目录执行，并将日志写入忽略的 local_debug_output。

| 命令 | 结果 |
|---|---|
| Godot --headless --path 项目目录 --import | 退出码 0，完成资源导入；无新 Player 脚本解析错误 |
| Godot --headless --path 项目目录 --quit-after 180 res://src/gameplay/debug/physics_dashboard.tscn | 退出码 0；无 Player 运行错误 |
| Godot --headless --path 项目目录 --quit-after 120 | 退出码 0；主场景启动，无 Player 运行错误 |
| git diff --check | 退出码 0，无空白格式错误 |

最终场景启动日志为 player-final-dashboard.log / player-final-main.log；导入记录为 player-final-import.log。场景输出只有系统证书读取失败与 Registry 注册信息；导入还包含既有 MCP 插件监听失败、编辑器设置无写入权限，以及嵌套 GodotWE 项目被忽略的提示。这些环境/插件问题已记录，未改插件。

未新增或执行 GUT，也未做交互式逐帧验收、导出写入验收或负责人手感签认。启动成功仅覆盖加载及场景空闲运行。

### 试玩入口

在 Godot 打开 src/gameplay/debug/physics_dashboard.tscn 并运行当前场景。

- A/D 移动、← 加速/搬运/Fire 发射、↑ 跳跃、↓ 旋转跳、S 下蹲、W 配合松开 ← 高抛（SMW）。
- 运行窗口内 R 复位、F6 暂停/继续、F7 推进一物理步；“吃蘑菇/吃火花/受击/强制阵亡”按钮可观察完整形态与演出流程。
- 调参只修改 Player 实例的 Profile；400/540/800 是刹车对照，其中 800 明示为 NSMBU 对照。
- “导出本次记录”写入 user://physics_tuning 的 .tres、逐帧 .csv 与 .json，包含实际 Profile、输入、移动状态、形态/阶段、动画、来源和测量摘要。
- 当前使用 SMW 贴图；SMB1/SMB3 选择切换能力规则，Fire 为占位着色。真实跨风格及 Fire 资产接入待资产任务。

### TBD 与签认

工程实现所需的候选 Profile 已明确授权并落盘，当前无 TBD 阻止场景运行。以下 SMM2 原始数值尚未核实：步速/加速/摩擦/空中系数、刹车曲线、跳跃及踩踏曲线、动画 stride、地形/受击尺寸、演出/无敌时长、投掷与火球参数。公开最高跑速有独立实测来源，其余预览保持 CANDIDATE；辅助窗口属于项目设计。

M1 验收仍需上述参数在仪表盘测量并由负责人签认 TUNED。调参或编译不会自动提升等级。详见[独立研究](../../TBDtoVERIFIED/smm2_player_physics_codex_research.md)及[参数证据](../data/physics/player_parameter_evidence.json)。

### 范围外发现

- MCP 插件及系统证书/编辑器目录权限问题见上表；本次没有更改插件或系统设置。
- 当前敌人、蘑菇和方块沿用原型行为，数值已放入 data/gameplay/prototype_entities.json；完整敌人状态机、全道具及死亡后的关卡生命周期归后续任务。
- 水下、斜坡滑铲、骑乘、飞行、NSMBU/3DW 动作保持任务范围中的后续安排。
