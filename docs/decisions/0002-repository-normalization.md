# 0002 — 仓库规范化：行尾、忽略规则与媒体边界

日期：2026-10-17。状态：采用。整理：Codex；决定：项目负责人。

## 背景

项目长期以本地工作区方式推进：`docs/` 整套文档、`src/editor/` 编辑器、基础实体批次等文件从未进入版本库；根目录 `.DS_Store` 被跟踪；工作区有 248 个已跟踪文本文件以 CRLF 检出；`.gitattributes` 把 Godot 的 `*.import` 当作二进制。准备首次完整推送前，需要把仓库整理成可持续维护、跨平台一致的状态。

## 决定

1. **文本统一 LF**：保留 `* text=auto eol=lf`，补充 `*.smmlevel`、`*.py`；`*.import` 从 `binary` 改为 `text eol=lf`。二进制媒体仍显式标记 `binary`。
2. **忽略规则分层**：Godot 缓存与导出配置、Mono、本地媒体（`textures/`、`audio/`）、本地日志（`local_debug_output/`）、代理目录（`.kimi/`）、系统临时文件（`**/.DS_Store`、`Thumbs.db`、`*.swp`）。参考工程不再需要忽略规则，因为它已移出工程目录（见第 4 条）。
3. **清理无引用旧实现**：删除 `src/vfx/skid_smoke.*`。它已被 `src/gameplay/effects/player_skid_dust.gd` 取代，且没有任何场景引用；备份保存在本地 `local_debug_output/normalize-backup-2026-10-17/`，不入库。
4. **参考工程移出工程目录**：本地旧工程 `GodotWE/` 从 `SuperMarioMaker_neo/` 移到工作区级的 `../references/GodotWE/`，并补一个 `references/README.md` 说明用途。它本来就被忽略，但留在工程内会让 Godot 每次扫描都提示存在嵌套 `project.godot`。

## 原因与取舍

- 媒体不入库沿用既有约定：原始拆包素材保留在仓库外的 `TBDtoVERIFIED/`，游戏内媒体由 `tools/asset_pipeline/` 安装。字体、`data/`、`docs/` 必须入库，否则新克隆无法打开编辑器界面或复现数值记录。
- `*.import` 是 Godot 生成的文本导入配置，入库才能让资源导入设置可 diff、可复现；标成二进制会掩盖换行和内容变化。
- 不把 `.vscode/` 加入忽略：其中 `settings.json` 是共享的编辑器配置。
- 不重写历史（不 rebase / squash 既有提交），首次完整推送按主题拆分新提交即可，避免破坏已有记录。
- 现有主场景地形与负责人的手动改动不做任何内容修改，只随仓库提交。

## 影响

- 新克隆仍是“代码可读、媒体需安装”的状态，安装步骤见 `docs/architecture.md`。
- `.DS_Store`、日志与临时文件不会再进入后续提交。
- 后续新增文本文件默认按 LF 入库；Windows 检出由 Git 负责转换，不依赖个人编辑器设置。
