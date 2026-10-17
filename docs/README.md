# 项目文档

这里记录 SMMneo 当前的设计、实现和后续工作，随开发更新。代码说明实际行为，配置给出运行数值，文档解释目标与原因；三者发现差异时及时修正。

## 从哪里开始

| 文档 | 用途 |
|---|---|
| [architecture.md](architecture.md) | 当前架构、模块入口、输入/碰撞/冻结时序、数据与素材管线 |
| [game-design.md](game-design.md) | 游戏目标、已确认的玩家行为、基础实体和未来玩法 |
| [level-format.md](level-format.md) | `.smmlevel` 当前数据形状、保存/加载能力及尚未完成的校验 |
| [decisions/](decisions/README.md) | 重要选择的原因、取舍与影响 |
| [roadmap.md](roadmap.md) | 当前进度、优先级、交接和待解决问题 |
| [plans/](plans/2026-10-08-docs-and-enemy-sprites.md) | 需要跨步骤推进的工作计划；按需创建 |
| [SMMWE 物理研究](research/2026-10-08-smmwe-physics.md) | 源码参数、输入/碰撞时序、当前 PlayerMotion 数值对照与调校建议 |
| [SMMWE 数值同步与试玩](plans/2026-10-08-smmwe-physics-sync.md) | 当前默认参考配置、新旧切换、实测结果和复现入口 |
| [轻飘反馈复核](research/2026-10-09-smmwe-float-audit.md) | 重力单位、普通/HD分支阈值对照与用户试玩反馈 |
| [编辑器界面与 Godot 观察步骤](plans/2026-10-09-editor-framework.md) | 首轮界面、圆环、状态与坐标转换的教学和检查记录 |
| [实体制作规范](entity-production.md) | 分类基类、类型命中、状态所有权、素材/注册/试玩的统一流程 |
| [怪物与物品来源及矩阵](research/2026-10-09-smmwe-entities.md) | SMMWE原值/换算/适配、继承、完整怪物交互矩阵和Gemini验收 |
| [六类怪物与五类物品批次](plans/2026-10-09-entity-batch.md) | 分阶段模块入口、分区试玩步骤、技术结果与待负责人认可事项 |
| [archive/](archive/README.md) | 旧 spec、任务记录与旧 AGENTS；仅供历史查阅 |

仓库根目录 [AGENTS.md](../AGENTS.md) 是 Codex 项目指令入口。旧 SDD 已按负责人 2026-10-08 的要求停用。

## 日常协作

一次迭代应形成“具体目标 → 实现 → 有依据的检查/试玩反馈 → 修正 → 保存进度”。小修复直接做；大功能先给简短步骤，按可以看到/操作的结果分阶段推进。文档只补影响长期理解的内容，不给每次修改建立编号、审批或版本表。

向 Codex 描述一个现象、希望的行为、相关场景及素材位置即可。工作结束时记录修改、实际执行的检查和未完成事项。需要暂停时，更新 roadmap 的交接，不能仅依赖聊天记忆。

Codex 会按工作规模将独立的重复性工作或第二轮审查交给 Antigravity 的 Gemini，保留设计判断与验收职责；委派前告知范围，结束时报告实际模型、结果与验收。操作规范见根目录 AGENTS 与本机 `antigravity-delegate` skill。

例如：

> 修复板栗仔在搬运后落地的状态，保留现有地形。先读 roadmap 的交接和相关敌人/搬运代码，完成后说明具体改动与仍待试玩的边界。

> 把编辑器的放置、擦除和撤销做成一条能操作的链路。先列简短计划，分阶段实现，把实际进度和下一步写入 roadmap。

## 如何维护

- 行为变化更新 game-design；模块或时序变化更新 architecture；数据兼容变化更新 level-format。
- 影响后续维护的选择写 ADR；普通修复在 Git 差异和路线图记录即可。
- 路线图区分“已实现”“已检查”“已试玩认可”。任务完成不要求所有参数先达到 TUNED；需要说明候选对体验的影响。
- 文档使用 Git 历史追踪，取消旧 draft/approved 审批和逐次升文档版本。保存格式破坏性变化仍需明确的格式版本与迁移方案。

这套安排参考了 OpenAI 的 [AGENTS.md 指南](https://learn.chatgpt.com/docs/agent-configuration/agents-md)和[长期工作计划示例](https://developers.openai.com/cookbook/articles/codex_exec_plans)，按本项目的迭代规模采用简短指令与可恢复计划。
