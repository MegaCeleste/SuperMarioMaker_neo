# 02 - 对象注册表契约 (objects.json)

> **状态**: draft
> **版本**: 0.1.0
> **日期**: 2026-09-22
> **Changelog**: 0.1.0 初版（自 `.spec` v1.1.0 §4.1 拆分并具体化 Schema）
> **引用**: REQ-ARC-005（16px 网格）、REQ-STD-005（i18n）

全量游戏对象（地形、方块、道具、敌人、机关）必须在 `res://data/registry/objects.json` 中以语义 ID 注册。编辑器调色板、关卡序列化、游玩实例化三方共用此注册表，禁止绕过注册表硬编码对象。

## 1. 顶层结构

**REQ-REG-001**: `objects.json` 顶层为对象数组，每个元素必须符合 §2 Schema。运行时由 `Registry` 单例加载并建立 `id → 定义` 索引；加载时发现重复 ID 或 Schema 校验失败必须报错并中止，禁止静默跳过。

## 2. 对象条目 Schema

**REQ-REG-002**: 每个对象条目字段如下（`*` 为必填）：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` * | string | 全局唯一语义 ID，命名空间格式 `smm.<category>.<name>`（如 `smm.block.question`） |
| `category` * | enum | `terrain` / `block` / `item` / `enemy` / `gizmo` |
| `palette_category` * | string | 编辑器调色板分组键 |
| `display_name_key` * | string | i18n 键，对应 `strings.csv` |
| `styles` * | string[] | 可用风格子集：`smb1` / `smb3` / `smw` |
| `scenes` * | object | `{ "play": "res://...", "editor_preview": "res://..." }` 场景路径 |
| `components` | string[] | 默认挂载的组件名（见组件库，如 `WingedComponent` 不在此列，由属性触发） |
| `properties_schema` | object | 可调属性定义，键为属性名，值为 `{ "type": ..., "default": ..., "enum": [...]? }` |

**REQ-REG-003**: 内建可组合属性（任何对象均可拥有，无需在条目里重复声明）：`is_winged`（bool）、`has_parachute`（bool）。其余属性必须在该对象 `properties_schema` 中声明才允许出现在关卡数据中。

**REQ-REG-004**: 关卡文件中出现的每个 `object_id` 必须能在注册表命中；反序列化遇到未注册 ID 时，必须保留原始数据并以占位对象显示，禁止丢弃（保证关卡不丢数据、可回编辑器修正）。

## 3. 示例条目

```json
[
  {
    "id": "smm.block.question",
    "category": "block",
    "palette_category": "blocks",
    "display_name_key": "OBJ_QUESTION_BLOCK",
    "styles": ["smb1", "smb3", "smw"],
    "scenes": {
      "play": "res://src/gameplay/blocks/question_block.tscn",
      "editor_preview": "res://src/editor/previews/question_block_preview.tscn"
    },
    "components": ["BumpableComponent", "ContainerComponent"],
    "properties_schema": {
      "contained_item": { "type": "object_id", "default": "smm.item.coin" }
    }
  },
  {
    "id": "smm.enemy.goomba",
    "category": "enemy",
    "palette_category": "enemies",
    "display_name_key": "OBJ_GOOMBA",
    "styles": ["smb1", "smb3", "smw"],
    "scenes": {
      "play": "res://src/gameplay/enemies/goomba.tscn",
      "editor_preview": "res://src/editor/previews/goomba_preview.tscn"
    },
    "components": ["GravityMovementComponent", "HitboxComponent"],
    "properties_schema": {}
  }
]
```

## 4. 组件库登记

**REQ-REG-005**: `components` 字段只允许引用已在 `res://src/core/components/` 实现的组件。M0 组件基座清单（后续里程碑可扩充，扩充需升版本号）：

| 组件 | 基类 | 职责 |
|---|---|---|
| `HitboxComponent` | Area2D | 头部受击、足底踩踏、侧面碰撞事件（挂 Layer 7 传感器，见 REQ-COL-003） |
| `BumpableComponent` | Node | 方块被顶起的弹性缓动与上方实体动量推离 |
| `ContainerComponent` | Node | 内藏物品（金币、蘑菇）的弹出缓动与激活 |
| `GravityMovementComponent` | Node | 敌人巡逻走动、撞墙调头、悬崖检测 |
| `WingedComponent` | Node | 翅膀正弦振翅悬浮与跳跃动力学 |
| `ParachuteComponent` | Node | 降落伞低速降落、触地自动脱落 |
| `ICarryable` | 接口 | 被抓取、手持、踢出、高抛的行为契约 |
