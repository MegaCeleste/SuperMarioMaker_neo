# 0001 — 采用持续维护的项目文档

日期：2026-10-08。状态：采用。提出：项目负责人；整理与迁移：Codex。

## 背景

项目处于玩法原型和长期开发起步阶段。此前每次实现围绕 spec、REQ、版本、任务单和审批展开；部分计划文字还被误读成已完成能力。负责人要求全部废弃该 SDD 标准，并采用 architecture、game-design、level-format、decisions、roadmap 的 docs 结构。

## 决定

采用负责人提出的结构，补一个索引 README。AGENTS 只保存短的项目工作指南和导航；架构、玩法、格式分别维护当前内容，路线图记录实际进度与交接。复杂工作按需写简短计划，重要选择按需记录 ADR。

旧 specs/tasks 原样移到 docs/archive，旧 AGENTS 以不同文件名保存，附 SHA-256 迁移清单。它们用于历史查阅，旧“spec 是宪法”、REQ 编号、approved 门槛、逐次升文档版本、强制任务单和一刀切 TUNED 验收全部停止执行。代码中的历史引用可逐步清理，不为删注释重写运行逻辑。

## 原因与取舍

只改文件夹名会保留旧流程负担，完全删除则损失用户反馈与数值来源。因此迁移现有有效知识并明确历史边界。采用持续文档和可恢复进度，让 Codex 可以按当前任务选取上下文，直接推进小修复，并分阶段完成可试玩功能。

参考 OpenAI 的 [AGENTS.md 指南](https://learn.chatgpt.com/docs/agent-configuration/agents-md)、[长期计划示例](https://developers.openai.com/cookbook/articles/codex_exec_plans)及[精简项目指令的建议](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra)。本项目借鉴上下文导航与进度交接，不照搬完整 ExecPlan 的全部模板或授权规则。

## 影响

文档以 Git 历史跟踪；实际兼容性仍由数据格式版本管理。实验参数允许带候选说明进入原型，仍须保留出处和用户认可状态。素材核对与物理校准分开，不能用“去掉 SDD”作为丢失证据或过度宣称完成度的理由。

本次不改变保存格式、不重构现有 Player、不转换主场景地形。路线图已接收旧暂停交接的未完成项；以后开新会话时从当前文件和进度继续。
