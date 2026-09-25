# 任务单：<编号>-<简述>

> **状态**: pending | in_progress | done | rejected
> **下达日期**: YYYY-MM-DD
> **执行者**: <agent 标识>
> **关联里程碑**: M<x>

## 目标

一句话说明本任务要达成什么。

## REQ-ID 引用清单

| REQ-ID | 所在 spec | 要点摘要 |
|---|---|---|
| REQ-XXX-000 | `specs/xx.md` | |

## 涉及文件

- 新建：`<路径>`
- 修改：`<路径>`
- 禁止触碰：`<路径>`

## 实施要点

1. （步骤级指示，写到便宜模型不需要自己猜的程度）
2.

## 禁止事项

- 禁止填充任何 TBD 参数（AGENTS.md §2 铁律 5）
- 禁止修改 `approved` 状态的 spec
- （任务特定禁令）

## 验收标准

- [ ] （可勾选的客观标准，每条可独立验证）

## 验证命令

```bash
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
```

## 完成回报格式

- 完成项核对：<逐项对照验收标准>
- 验证输出：<命令结果摘要>
- TBD 阻塞：<无 / 清单>
- 范围外发现：<无 / 清单>
