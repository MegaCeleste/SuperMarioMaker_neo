# 关卡格式

更新：2026-10-08。当前 `format_version = 1`，文件为 JSON，通常使用 `.smmlevel` 后缀。文档体系替换不改变现有保存格式或重写用户关卡。

## 当前实现与边界

`src/autoload/level_manager.gd` 可以建立空关卡，保存/读取 `level_data`，以及编码/解码 RLE。加载目前只检查 JSON 是 Dictionary 并存在三个顶层键；尚未执行完整格式版本、实体、区域、类型或未知对象校验，也没有把任意关卡还原成完整运行场景。

主场景的 Godot `tile_map_data` 仍是场景数据，没有在本次迁移中转换成 `.smmlevel`。下面的数据约定用于逐步接通保存、编辑和试玩；不能认为仅有 LevelManager 就已经实现编辑器和全部关卡机制。

## 顶层结构

必需 `format_version`、`metadata`、`main_area`；`sub_area`、`pipe_connections` 可选。

```json
{
  "format_version": 1,
  "metadata": {
    "title": "示例",
    "author": "",
    "description": "",
    "game_style": "smw",
    "creation_timestamp": 0,
    "timer": 300,
    "clear_condition": {"type": "none", "target_id": "", "count_required": 0}
  },
  "main_area": {
    "theme": "ground",
    "is_night": false,
    "autoscroll_speed": "none",
    "bounds": {"left": 0, "top": 0, "right": 4, "bottom": 2},
    "tilemap_layers": [{"layer_id": "terrain", "tiles_rle": "0:8"}],
    "entities": [{
      "instance_id": "ent_001",
      "object_id": "smm.block.question",
      "grid_pos": [1, 1],
      "properties": {"contained_item": "smm.item.fire_flower"}
    }]
  },
  "pipe_connections": []
}
```

该例只展示格式：目前没有完整的场景加载器可直接游玩它。

## 元信息与区域

| 字段 | 约定 |
|---|---|
| title / author / description | 字符串 |
| game_style | smb1 / smb3 / smw；未来扩展应检查加载兼容性 |
| creation_timestamp | Unix 秒；当前 new_level 使用 Godot 浮点时间返回值，严格整数归一化尚未实现 |
| timer | 秒，约定 0 表示不限时；运行计时器尚未接入 |
| clear_condition | 目前 type 为 none；其他目标是后续功能 |
| theme | 当前空关卡为 ground；环境主题加载尚未完整实现 |
| is_night | 月夜选项预留 |
| autoscroll_speed | none / slow / medium / fast 设计取值，运行卷轴待实现 |
| bounds | 格单位边界，约定右/下边界不包含；面积为 `(right-left)*(bottom-top)` |
| tilemap_layers / entities | 图块层列表与语义实体列表 |

新建主区域目前默认 240×27 格。旧文档中的副区域尺寸/垂直区域规则没有运行校验，后续结合编辑器实际需求决定，不用历史文字冒充现有限制。

## 图块 RLE

每层包含 `layer_id` 和 `tiles_rle`。现有约定层键为 terrain、semisolid、background、liquid；每段是逗号分隔的 `<tile_id>:<count>`。0 表示空，按左到右、上到下展平，段数之和应等于区域面积。

例：`0:3,34:2,0:3` 展开为 8 格。当前 rle_decode 检查段结构和总长度，但整数语法、负数/超大 count、tile_id 映射等校验仍需加强。不能在未校验的输入上依赖 to_int 自动转换。

## 实体与注册表

实体持久化语义 ID、网格位置与属性，不保存 Node、场景实例、运行速度、受击/搬运状态或引擎二进制。

- `instance_id` 为整关唯一字符串。编辑器未来负责生成与去重。
- `object_id` 对应 `data/registry/objects.json` 中的对象。
- `grid_pos` 为区域内格坐标。格与像素的原点/实体锚点转换需在场景加载器实现时统一，不能直接套当前调试场地的像素坐标。
- `properties` 使用 Registry 的属性 schema/default/enum。当前工厂拒绝未声明属性。
- 历史规划中的 `is_winged`/`has_parachute` 并非当前工厂的自动内建属性；示例不默认加入这些未实现参数。

Registry 能创建独立 play 节点，但深度关卡验证、未知对象占位与无损保存尚未实现。未来遇到不认识的对象/字段应保留原数据，给出可修正的提示；不能默默删除后再覆盖原文件。

## 管道与版本演进

`pipe_connections` 预留数组，每项包含 source_area、source_pipe_id、target_area、target_pipe_id，引用区域中的管道 instance_id。双向配对、重复连接检查和运行传送尚未实现。

新增兼容字段应定义默认值；破坏性格式变化递增 format_version，提供显式迁移、备份和失败处理。加载器应拒绝不支持版本或以可恢复方式打开，避免静默重写。后续值得先完成深度校验、受限 RLE 解码、稳定图块 ID 映射和一次存读/试玩闭环。
