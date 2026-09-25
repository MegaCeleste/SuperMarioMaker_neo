# 03 - 关卡数据契约 (.smmlevel)

> **状态**: draft
> **版本**: 0.1.0
> **日期**: 2026-09-22
> **Changelog**: 0.1.0 初版（自 `.spec` v1.1.0 §5.1 拆分；明确定义 RLE 编码）
> **引用**: REQ-ARC-005（16px 网格）、REQ-REG-003/004（属性与未注册对象规则）

关卡以自包含 JSON 持久化，文件后缀 `.smmlevel`（或 `.json`）。契约核心原则：**数据与运行时表现彻底解耦**——关卡文件只描述语义 ID、网格坐标与参数，禁止存储场景实例、节点路径或任何引擎二进制数据。

## 1. 顶层结构

**REQ-LVL-001**: 关卡文件必须包含 `format_version`、`metadata`、`main_area` 三个键；`sub_area` 与 `pipe_connections` 可选。`format_version` 当前为 `1`；任何破坏性契约变更必须递增版本号并在 `LevelManager` 中提供旧版迁移。

## 2. metadata

**REQ-LVL-002**: 字段定义：

| 字段 | 类型 | 说明 |
|---|---|---|
| `title` / `author` / `description` | string | 关卡元信息 |
| `game_style` | enum | `smb1` / `smb3` / `smw`（整关单一风格，决定物理 Profile 与视觉集） |
| `creation_timestamp` | int | Unix 秒 |
| `timer` | int | 限时秒数，0 = 不限时 |
| `clear_condition` | object | `{ "type": enum, "target_id": string, "count_required": int }`；`type` 初版取值：`none`，后续扩充（`defeat_all`、`collect_coins`、`reach_goal_with_item`…） |

## 3. 区域（main_area / sub_area）

**REQ-LVL-003**: 每个区域字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `theme` | enum | `ground` / `underground` / `underwater` / `castle` 等（完整主题清单随主题系统 spec 扩充） |
| `is_night` | bool | 月夜模式开关 |
| `autoscroll_speed` | enum | `none` / `slow` / `medium` / `fast` |
| `bounds` | object | `{ "left", "top", "right", "bottom" }`，单位：格（16px）。主区域默认 `0,0 → 240,27`；副区域最大 `120,27`，垂直区域固定宽 27 格 |
| `tilemap_layers` | array | 见 §4 |
| `entities` | array | 见 §5 |

## 4. 图块层 RLE 编码

**REQ-LVL-004**: `tilemap_layers` 每个元素为 `{ "layer_id": string, "tiles_rle": string }`。`layer_id` 初版取值：`terrain`（主碰撞层）、`semisolid`（单向板层）、`background`（装饰层）、`liquid`（液体动画层）。

**REQ-LVL-005**: `tiles_rle` 为行优先（从左到右、从上到下）展平后的游程编码，格式为逗号分隔的 `<tile_id>:<count>` 段，如 `0:15,34:4,0:20` 表示 15 格空、4 格 tile 34、20 格空。`tile_id` 0 恒为空；所有段的 `count` 之和必须恰好等于区域 `bounds` 面积（宽 × 高格数），校验失败拒绝加载。

## 5. 实体

**REQ-LVL-006**: `entities` 每个元素：

```json
{
  "instance_id": "ent_001",
  "object_id": "smm.block.question",
  "grid_pos": [12, 18],
  "properties": {
    "contained_item": "smm.item.super_mushroom",
    "is_winged": false
  }
}
```

- `instance_id`：关卡内唯一字符串，由编辑器生成（`ent_` + 递增序号）；
- `object_id`：必须命中注册表（REQ-REG-001）；
- `grid_pos`：格坐标 `[x, y]`，必须落在所属区域 `bounds` 内；
- `properties`：只允许注册表声明的属性 + 内建属性（REQ-REG-003），缺省值由注册表补齐。

## 6. 管道连接

**REQ-LVL-007**: `pipe_connections` 描述跨区域传送门管道配对：

```json
{
  "source_area": "main_area",
  "source_pipe_id": "pipe_01",
  "target_area": "sub_area",
  "target_pipe_id": "pipe_02"
}
```

连接为双向；每个管道实体（`instance_id`）最多出现在一条连接中。生成器型管道（内藏物定时吐出）不出现在本表，由内藏物属性表达。

## 7. 完整示例

```json
{
  "format_version": 1,
  "metadata": {
    "title": "Course Title",
    "author": "Creator",
    "description": "Level description",
    "game_style": "smw",
    "creation_timestamp": 1726920000,
    "timer": 300,
    "clear_condition": { "type": "none", "target_id": "", "count_required": 0 }
  },
  "main_area": {
    "theme": "ground",
    "is_night": false,
    "autoscroll_speed": "none",
    "bounds": { "left": 0, "top": 0, "right": 240, "bottom": 27 },
    "tilemap_layers": [
      { "layer_id": "terrain", "tiles_rle": "0:6480" }
    ],
    "entities": [
      {
        "instance_id": "ent_001",
        "object_id": "smm.block.question",
        "grid_pos": [12, 18],
        "properties": { "contained_item": "smm.item.super_mushroom", "is_winged": false }
      }
    ]
  },
  "sub_area": {
    "theme": "underground",
    "is_night": false,
    "autoscroll_speed": "none",
    "bounds": { "left": 0, "top": 0, "right": 120, "bottom": 27 },
    "tilemap_layers": [],
    "entities": []
  },
  "pipe_connections": []
}
```
