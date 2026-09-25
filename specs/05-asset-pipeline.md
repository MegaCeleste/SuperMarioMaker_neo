# 05 - 资产管线契约 (Asset Pipeline)

> **状态**: draft
> **版本**: 0.2.0
> **日期**: 2026-09-24
> **Changelog**: 0.1.0 初版（自 `.spec` v1.1.0 §13 拆分并具体化；按用户决定确立“仓库零媒体文件”原则）→ 0.2.0 明确原始素材与标准化副本、统一命名、批量清单生成、玩家贴图锚点与导入校验规则
> **引用**: REQ-LGT-003（法线图生成）、REQ-STD-005（i18n）

## 1. 合规红线与素材来源

**REQ-AST-001**: 仓库**不含任何游戏媒体文件**。`textures/`、`audio/` 目录整体被 `.gitignore` 排除，任何图片/音频/字体二进制禁止提交入库。清单 JSON、源名映射、生成脚本和验证报告属于文本元数据，可以入库。全新克隆的仓库通过 `tools/gen_placeholders.gd` 生成占位素材（16px 纯色块 + 语义文字标注）；真实素材由本地资产管线提供，只存于本地磁盘与 `user://assets/`。

**REQ-AST-002**: 素材源为本地私有素材库（当前为 GodotWE 旧工程，不入库）：
- 精灵图为横向帧条或明确声明布局的图集。原始文件名可以保留上游命名；导入副本使用 `spr_<STYLE>_<ASSET_ID>_Strip<N>.png`，例如 `spr_SMW_mario_small_walk_Strip2.png`。`STYLE` 使用大写风格代号，`ASSET_ID` 使用小写蛇形命名，`N` 是正整数帧数。
- UI：SVG 向量图（`extra/`、`icons/` 目录），导出时按需栅格化；
- 音频：按风格分目录的 ogg/wav。
- 标准化不得覆盖或移动原始素材。任何拼写修正必须在映射清单中同时记录原名与标准名；含义不明的缩写原样保留，等待人工确认。

## 2. 精灵清单与批量生成

**REQ-AST-003**: 每张精灵表配套一份同名 JSON 清单，例如 `spr_SMW_mario_small_walk_Strip2.png` 配 `spr_SMW_mario_small_walk_Strip2.json`。清单至少包含：

```json
{
  "schema_version": 1,
  "asset_id": "SMW/mario_small_walk",
  "source": "spr_SMW_mario_small_walk_Strip2.png",
  "source_original": "mario_small_walk_Strip2.png",
  "frame_width": 16,
  "frame_height": 32,
  "frame_count": 2,
  "layout": "horizontal_strip",
  "pivot": null,
  "frame_offsets": null,
  "animations": {},
  "metadata_state": "draft",
  "unresolved": [
    "logical_animation_mapping",
    "pivot_or_alignment_profile",
    "frame_offsets_if_needed",
    "animation_fps",
    "animation_loop"
  ]
}
```

- `layout` 取值：`horizontal_strip`、`grid`、`single`。`grid` 必须给出 `columns`。
- `horizontal_strip` 的 `frame_count` 可从 `_StripN` 自动读取；仅当图片宽度可被 `N` 整除时，才可自动计算 `frame_width = image_width / N` 和 `frame_height = image_height`。不满足时必须报告并跳过，禁止猜测或自动裁图。
- `pivot` 使用单帧左上角为原点的像素坐标。`frame_offsets` 如提供，必须按帧序逐帧给出偏移量；不需要逐帧偏移时用空数组。草稿可将未知字段设为 `null`，但导入器不得加载 `metadata_state` 不是 `verified` 的贴图。
- `animations` 以逻辑动画名为键，值必须明确给出帧索引、`fps` 和 `loop`。清单生成器可以按左到右切分帧，但不得猜测动画名称、播放速度、循环方式或贴图语义。
- 玩家贴图必须提供已确认的 `pivot` 或引用已确认的对齐配置；不得静默采用纹理中心或底边中点。只有清单显式声明 `pivot_mode` 时，非玩家素材才可使用命名锚点默认值。

**REQ-AST-007**: `tools/asset_pipeline/generate_sprite_manifests.py` 从原始素材批量生成标准化副本、逐图清单草稿及 `asset_catalog.json`。生成器只自动填写可从文件名与 PNG 尺寸确定的信息，并记录原始文件名与内容哈希；它不得修改原始文件、复制旧 `.import` 元数据、自动重排帧、裁切透明边缘、缩放贴图或猜测未确认字段。重名、格式错误、宽度不能整除帧数等情况必须列入报告并阻止对应素材进入导入。

**REQ-AST-008**: 玩家视觉锚点与物理碰撞形状分开定义。玩家图集清单中的 `pivot` / `frame_offsets` 只控制画面相对玩家视觉根节点的位置；碰撞盒仍由玩家物理规格定义，禁止从贴图透明边界推断。不同形态或动画若无法共用同一对齐配置，必须在清单中显式引用不同配置或给出逐帧偏移。

**REQ-AST-009**: 素材验证器必须检查清单与图片一一对应、帧尺寸与源图匹配、帧索引及 pivot/offset 不越界、`asset_id` 无冲突，并输出逐帧预览（帧格、序号及已配置锚点叠加）。未解决字段、空帧和可疑对齐必须明确报告；不得静默修复。

## 3. 导入向导 (AssetImportWizard)

**REQ-AST-004**: AssetImportWizard 输入 = 本地素材文件夹（PNG 精灵表 + JSON 清单 + SVG + 音频），输出至 `user://assets/` 覆盖加载。精灵表只有在清单完整且 `metadata_state` 为 `verified` 时才可导入。加载优先级：`user://assets/` > `res://` 占位素材。真机 Switch dump 解包为**远期可选项**，不在 M0~M5 范围。

**REQ-AST-005**: 法线贴图生成挂接本管线，解析优先级与规则见 REQ-LGT-003（手工 `*_n.png` > 自动生成 > 平面法线兜底）。

## 4. 像素完美渲染基线

**REQ-AST-006**: 全局纹理过滤为 Nearest（`default_texture_filter=0`）；窗口拉伸 `canvas_items` + `keep_height`；游戏内 1 格 = 16px（REQ-ARC-005）。禁止对像素素材启用线性过滤或 Mipmap。
