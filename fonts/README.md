# Super Mario Maker 2 (SMM2) & Retro Style Font Assets

本目录整理归档了用于 **Super Mario Maker Neo** 的核心字体资源，覆盖了从现代化 SMM2 游戏界面、中日文字符回退（CJK Fallback），到经典复古 2D 风格（SMB1, SMB3, SMW）专属像素字体的完整字库支持。

---

## 1. 字体资产清单 (Font Asset Manifest)

| 文件名 | 类型 | 文件大小 | 用途定位 | 来源 / 授权 |
| :--- | :--- | :--- | :--- | :--- |
| [`MARIOMAKER.otf`](./MARIOMAKER.otf) | OTF | 296 KB | SMM2 官方标题、Logo、核心关卡编辑器标题字 | Switch RomFS 官方提取 / yell0wsuit 整理归档 |
| [`MARIO_Font_v3_Solid.otf`](./MARIO_Font_v3_Solid.otf) | OTF | 500 KB | 现代化马力欧通用实心 UI 字（数值、关卡卡片、按钮） | 官方矢量字库 / yell0wsuit 整理归档 |
| [`MPLUSRounded1c-Bold.ttf`](./MPLUSRounded1c-Bold.ttf) | TTF | 3.54 MB | **CJK 中文/日文 UI 粗体回退**（匹配 SMM2 原版圆体风格） | Google Fonts / SIL Open Font License 1.1 |
| [`MPLUSRounded1c-Regular.ttf`](./MPLUSRounded1c-Regular.ttf) | TTF | 3.38 MB | **CJK 中文/日文 常规体回退**（说明文本、对话、通关条件） | Google Fonts / SIL Open Font License 1.1 |
| [`PressStart2P-Regular.ttf`](./PressStart2P-Regular.ttf) | TTF | 118 KB | **SMB1 (NES)** 风格复古 8-bit HUD（时间、分数、金币） | CodeMan38 / SIL Open Font License 1.1 |
| [`SuperMarioBros3-NES.ttf`](./SuperMarioBros3-NES.ttf) | TTF | 11 KB | **SMB3 (NES)** 风格复古 8-bit 专用字库（对话、道具盘） | David (FontStruct) / Free for Personal Use |
| [`SuperMarioWorld-Pixel.ttf`](./SuperMarioWorld-Pixel.ttf) | TTF | 38 KB | **SMW (SNES)** 风格 16-bit 专属像素字库（标准字距） | vvye (GitHub smw-font) / MIT / Public Domain |
| [`SuperMarioWorld-WholePixel.ttf`](./SuperMarioWorld-WholePixel.ttf) | TTF | 36 KB | **SMW (SNES)** 整像素对齐版（用于 1:1 Pixel-Perfect 渲染） | vvye (GitHub smw-font) / MIT / Public Domain |

---

## 2. 样式与使用矩阵 (Style & Usage Matrix)

| 游戏风格 / UI 模块 | 主要显示字体 (Primary Font) | 字符回退字体 (Fallback Font) | 推荐字号 (Base Size) |
| :--- | :--- | :--- | :--- |
| **全局编辑器 UI / 标题栏** | `MARIOMAKER.otf` | `MPLUSRounded1c-Bold.ttf` | 18px ~ 24px |
| **编辑器按钮 / 浮动菜单 / 计数器** | `MARIO_Font_v3_Solid.otf` | `MPLUSRounded1c-Bold.ttf` | 14px ~ 18px |
| **中文字幕 / 通关条件文本 / 帮助说明** | `MPLUSRounded1c-Regular.ttf` | - | 12px ~ 16px |
| **SMB1 HUD (时间/分数/金币)** | `PressStart2P-Regular.ttf` | - | 8px (整倍数: 8, 16, 24) |
| **SMB3 HUD & 对话框** | `SuperMarioBros3-NES.ttf` | - | 8px (整倍数: 8, 16, 24) |
| **SMW HUD & 关卡文字** | `SuperMarioWorld-Pixel.ttf` / `SuperMarioWorld-WholePixel.ttf` | - | 8px (整倍数: 8, 16, 24) |

---

## 3. Godot 4.5 导入与渲染配置规范 (Godot Import Settings)

### 3.1 现代矢量字 (MARIOMAKER, MARIO_Font_v3_Solid, MPLUSRounded1c)
- **Antialiasing (抗锯齿)**: `MSDF` (Multi-channel Signed Distance Field) 或 `Linear`
  - MSDF 模式在任意放大缩放下均能保持边缘极致锐利，特别适合编辑器高 DPI 缩放。
- **Generate Mipmaps**: `Enabled` (防止缩小时产生走样抖动)
- **Subpixel Positioning**: `Auto`
- **Hinting**: `Normal`

### 3.2 复古点阵字 (PressStart2P, SuperMarioBros3-NES, SuperMarioWorld)
- **Antialiasing (抗锯齿)**: **`None`** (必须关闭抗锯齿，否则边缘模糊发虚)
- **Generate Mipmaps**: **`Disabled`**
- **Subpixel Positioning**: **`Disabled`**
- **Hinting**: **`None`**
- **字号设定法则**: 必须使用原始点阵高度的整数倍（8px, 16px, 24px, 32px），严禁使用奇数非整数缩放，以避免像素重叠变形。

### 3.3 Godot 主题多语言回退链配置 (Theme Fallback Chain)
在 Godot 4.5 的 `Theme` 资源中，通过 `FontVariation` 配置如下回退链路：
```gdscript
# 示例：编辑器全局主题配置
var base_font = load("res://assets/fonts/MARIO_Font_v3_Solid.otf")
var cjk_fallback = load("res://assets/fonts/MPLUSRounded1c-Bold.ttf")

var font_variation = FontVariation.new()
font_variation.base_font = base_font
font_variation.fallbacks = [cjk_fallback]

# 赋值给全局主题，即可在英文显示马力欧风格数字/字母，中文自动优雅回退为圆体中文
theme.set_default_font(font_variation)
```
