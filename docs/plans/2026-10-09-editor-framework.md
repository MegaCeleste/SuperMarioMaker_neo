# 编辑器第一轮：界面与交互骨架

负责人首轮确认：SMM2布局加电脑操作、独立场景F6；后续图6覆盖八槽方案，改为全屏十槽圆环；Codex实现，负责人分阶段观察并学习Godot。首版技术检查通过，但负责人否定视觉布局；当前基准改为其提供的1920×1080 SMM2截图。缺失图标先留空。

## 步骤与职责

1. `src/editor/editor.tscn`保存全屏独立SubViewport/Camera2D、覆盖其上的ReferenceUI及弹窗。十二卡片、设置托盘、侧边工具、试玩板直接保存为场景节点；Theme定义半透明浮层/字体，`maker_art_button.gd`用原图绘制可在Godot预览的按钮。
2. `editor.gd` 连接 UI 请求，拥有局部 `EditorState`；`palette_wheel.gd` 根据 Registry 分类、绘制圆环和命中槽位；`editor_catalog.gd` 只读取名称与静态帧。
3. `maker_viewport.gd` 管画布输入、相机与坐标变换；`maker_world.gd` 只绘制背景、网格、格高亮和预览。此轮没有 gameplay 实例、关卡数据写入或命令栈修改。

默认SMW地面白天、240×27格、世界网格16px、逻辑缩放2倍（范围1～4）。相机显示缩放=逻辑缩放×2.5×窗口参考比例，1920×1080初始每格80px。B/E/V、Tab、G、Esc、中键拖动、滚轮保持；位置滑条/网格按钮/缩放比例移入菜单。存读、实际编辑、撤销、重置、试玩、副区域未接通。F5、主场景与玩家物理保持。

## 给负责人的观察路径

1. 打开`src/editor/editor.tscn`。看两个同级节点：MakerViewport负责全屏世界，ReferenceUI负责覆盖界面。展开TopBar/PaletteItems的HBox、LeftBar/Column的VBox；每张卡片都有Button节点和106×116参考尺寸。调整窗口观察ReferenceUI统一缩放和右侧/底部锚点。
2. F6运行。点击金币、按E，观察金币仍为深色固定卡片，橡皮擦出现红色底板；通用说明气泡已移除；B返回绘制。阅读`_connect_controls()` → `EditorState.select_object()/select_tool()` → `_sync_state()`。八张未注册的参考卡片禁用，可用物件由圆环选择。
3. Tab 打开圆环，切换类别、悬停/选择、点击中心空区和圆环外侧、Esc 关闭。圆环 `slot_at()` 共用绘制的中心/半径/角度；空槽和中心不产生物件选择。
4. 中键平移、滚轮缩放，打开右侧菜单拖位置滑条/开关网格。对照`view_scale` → `screen_to_world()` → `cell_at()`与Camera2D，区分参考比例、世界像素和格坐标。进入工具区时预览消失，工具区内滚轮不缩放画布。

## 检查记录

首版204项检查只证明技术行为，视觉已被负责人否定。按新基准重做后，Godot4.7.2原生GUI/输入及D3D12/Forward+渲染探针334项通过。直接查看三种尺寸主界面/圆环与1280×720擦除/菜单截图；覆盖十二卡片尺寸/间距/位置、80px参考网格、Registry边界、十个圆环物件、空槽/中心/关闭、文字焦点、平移/鼠标锚点缩放/实际相机变换、遮挡预览、菜单滑条、缺图留空与数据保持。Codex截图核对和技术通过不等于负责人视觉/操作认可。

素材使用现有SVG/PNG与父级菜单图；缺失的顶部物件和主题从`TBDtoVERIFIED/textures/ui/editor/`原始图集提取。`data/assets/editor_reference.json`记录切片坐标；安装器`tools/asset_pipeline/install_editor_reference_assets.py`使用含Pillow的Python，保留原图、拒绝覆盖不同本地图，按Godot4.7的`base_scale`导入SVG。来源/输出SHA256在`local_debug_output/editor-reference-assets.json`。砖块/青蛙、卷轴相机、钟表、通关路线、多人、角色、主区域卷轴等专用界面图未找到，按负责人要求留空；后续已移除提示。

复现（工程根目录）：

```powershell
& 'C:\!application\tools\Godot\Godot_v4.7.2-stable_win64_console.exe' --path . --log-file 'local_debug_output/editor-polish-capture-engine.log' 'res://tools/verification/editor_polish_probe.tscn' -- --capture
```

无窗口检查可用`--headless`并去掉`-- --capture`；GUI命中以原生窗口为准。仅检查本轮编辑器。当前报告`editor-polish-verification.json`与`polish-`前缀截图，旧`reference-`证据保留对照；当前日志`editor-polish-capture.log`与`editor-polish-import.log`位于`local_debug_output/`。Windows证书/screen=-1、MCP插件/编辑器设置权限及退出资源残留单独记录，不能以退出码0忽略环境错误。

首轮修正工具重复点击、滑条反馈、翻译初始化和销毁回调。本次再修正全屏画布浮层下仍预览、菜单滑条被阻断、擦除取消物件标记、退出访问已销毁ReferenceUI等问题。首轮Antigravity查询被网络限制，重试被自动审批拒绝（四个私有源码摘录外发未获明确授权），无实际模型/报告。本次由Codex完成紧密关联的视觉/输入修正，没有重试被拒绝的外发。旧记录见`local_debug_output/delegations/2026-10-09-editor-framework/`。

主场景、默认物理与 project.godot 的SHA256保持；未提交/推送。下一步等待负责人的布局/操作反馈，再接编辑数据、放置/擦除和命令栈。

## ArtView/CapView与圆盘悬停修正

负责人已注释父级Art绘制并提供ThemeButton/ArtView与rounded_art_mask.gdshader；本次完整保留其偏移(5.745,2.57)、82×82尺寸、ShaderMaterial及radius=0.08。其他按钮补齐保存到场景的ArtView，12个顶部色条迁移为CapView；移除旧父级cap/cap_color/art_inset。脚本只同步texture，不自动布局，所有贴图子节点忽略鼠标，让Button处理点击。Feedback单独绘制工具栏四角/固定标记/快捷键，置于贴图之上。

调色盘分类和翻页按钮去掉四角；物品悬停不画四角，改为图2的分类色扇区与同色中心连成一体，隐藏该扇区边界虚线。盘面/中心/阴影用draw_circle与抗锯齿；删除旧_pixel_disk()对圆周点的5px吸附，修复不规则轮廓。PaletteWheel._draw()负责整体圆形/图卡，_draw_sector()负责悬停，slot_at()仍是相同角度命中。

F6观察：展开任一顶部卡片→直接改ArtView偏移/大小及CapView色调/高度→运行后不被脚本重排；Tab打开，悬停硬块→扇区与中心同色，无四角；移到翻页箭头→扇区取消，箭头无四角。圆盘尺寸可在ModalOverlay/PalettePanel/Wheel的Control尺寸调整，颜色在PaletteWheel.CATEGORY_COLORS调整。

最新Godot原生GUI/D3D12检查504项通过，覆盖保留负责人ArtView/Shader、贴图同步不重排、ArtView/CapView命中透传、分类/翻页关闭四角，以及三尺寸扇区实际像素同色、离开取消和原有输入/坐标/Registry边界。报告editor-art-children-verification.json、截图art-children-*.png，日志editor-art-children-import.log、editor-art-children-capture.log、editor-art-children-start.log。原386项报告保留为历史；当前探针仍通过editor_polish_probe.tscn启动。技术通过、Codex截图查看与负责人视觉认可分别记录。主场景/默认物理/project.godot哈希保持；本轮由Codex直接完成，无Gemini调用。

## Cap统一与字体一致性

负责人要求Cap高度与火焰花一致，并指出数字/Play字体不同。读取保存的fire_flower/CapView高度9.636364px，12个节点一致；按该参考写回并保留颜色/位置。此前Theme的Button单独指定MARIOMAKER，而默认Label与MakerTimer为MPLUS；现统一LocalUIFont.base_font为MARIOMAKER，按钮也继承共享主题。静态Label/Button文案在场景直接保存英文，编辑器预览无需等待运行时翻译，Play不再显示MAKER_PLAY_CAPTION。

F6前在场景检查CapView尺寸与Theme/LocalUIFont；选中TimeButton/Value和PlayButton/Caption看同字体，字号仍分别保留60/40。原生三尺寸523项检查通过，包括同一有效字体、文字宽度适配、英文Caption和12个Cap参考高度；报告editor-cap-font-verification.json，截图cap-font-*.png与editor-cap-font-capture.log。旧历史报告保留。主场景/物理/项目入口哈希保持，小范围修正由Codex完成，未调用Gemini。


## 后续视觉修正：图3～6与本地字体

已移除所有通用tooltip、设置/Coursebot说明弹窗和擦除提示气泡。物件图按白卡范围内缩，避开分类色条和下方阴影；按钮悬停使用现成hover.svg四角三角。菜单仍提供真实视图控件。参考UI与物件/关卡数据边界保持。

图6调色盘采用1920×1080参考坐标：圆环中心(960,630)、半径340、十槽；分类栏顶部84，选中长条600×108，未选分类108×108；关闭黑叉、两侧循环翻页。打开后隐藏主工具区，淡色遮罩仅改变背景显示颜色，不改变纹理过滤。第一道具页按金币/10金币/钥匙币/蘑菇/火焰花/斗篷/气球/星星/1UP/耀西蛋顺序读取本地图。只有已注册物件可选，其他原图与缺槽不创建假ID。绘制命令仅持有纹理RID，Catalog需保留Texture2D引用：运行截图发现的七张临时图标消失已通过缓存修正，并逐槽检查实际像素。

背景发糊已定位为SubViewport默认线性采样（实测默认枚举1）；改为默认最近邻0及World最近邻1。1920×1080下对SubViewport实际渲染与原图最近邻取样比较4029点，RGB最大差0；这验证了采样，不代表所有非整数缩放下像素宽度相同。

负责人追加要求使用fonts里的字体，又确认界面先全部英文、不做中文本地化。普通文字/数字为本地MPLUSRounded1c-Bold，调色盘标题为本地MARIOMAKER，禁止系统默认回退。现有字体缺部分简体字，已如实告知；当前不补中文字库。字体元数据/预览图的来源与覆盖声称没有在本轮作外部认证。

观察：F6运行→悬停右侧菜单看四个三角与清晰背景→点击金币看卡内留白→Tab看Items十槽、分类长条和翻页→点蘑菇后回到绘制→Esc/外侧关闭。中键、滚轮、B/E/V/G保留。阅读MakerArtButton.artwork_rect() → PaletteCategoryButton._update_width() → PaletteWheel.slot_at()/slot_center()，对应图标内框、容器尺寸、缩放后的命中区域。

最新原生Godot4.7.2/D3D12/Forward+验证386项通过，960×540、1280×720、1920×1080界面与圆环截图已查看。覆盖全部10个注册物件、未注册/空槽、中心/关闭/翻页、字体路径/无默认回退、图标内框/实际槽图渲染、遮挡输入、快捷键/文本焦点、平移/锚点缩放、实际相机变换、菜单控件和关卡数据保持。报告editor-polish-verification.json，截图polish-*.png，日志editor-polish-capture.log与editor-polish-import.log。旧204/334项报告保留作历史，不能代替当前验收；负责人视觉/操作认可待反馈。

本轮紧密关联的视觉/输入/字体修正由Codex接手，没有调用Gemini或重试此前被拒绝的源码外发。未提交/推送；F5主场景/默认物理/project.godot哈希保持。

## 快捷键徽标与窗口清晰度修正

最新要求：移除浮动字母，保留电脑操作，提高矢量UI清晰度。删除MakerArtButton.shortcut_label、Feedback内B/E圆徽标，以及SelectButton/KeyBadge与V字母子树/废弃主题样式。操作仍由editor.gd读取逻辑Action修改EditorState。

场景将SVG底板/ArtView/CapView设为线性过滤，PNG物件/主题ArtView显式最近邻。保持实际窗口分辨率；关闭Window内容缩放的独立编辑器需在_resize_reference_ui同步oversampling_override=max(1,2×参考比例)。DPITexture由SVG重栅格化，窗口UI的4×MSAA处理几何边缘，World SubViewport过滤与像素图不变。入场保存/退出还原MSAA和oversampling。没有增加像素素材细节或替换本地字体。

F6观察：调整窗口，看橡皮擦外圆、放大镜、字体与圆盘边缘；B/E/V切工具但无浮动字母，Tab与G仍生效。Godot中查看SVG ArtView的Texture Filter=Linear、PNG ArtView=Nearest；阅读editor.gd的_ready → _resize_reference_ui → _exit_tree，理解窗口级渲染状态的保存与还原。CapView.y统一−8，用户ThemeButton/ArtView位置/材质保留。

Godot4.7.2原生D3D12检查654项通过，包含三种基础窗口及1440p/4K的可见区域、调色盘、SVG实际GPU纹理尺寸和退出设置还原。橡皮擦显示大小为4K下约219×240，实际SVG纹理420×460；1920×1080纹理210×230，原先105×115。背景4029点与原图最大RGB差0。独立场景启动无新增脚本/资源错误；日志中的Windows证书/screen=-1是已有环境问题。报告editor-sharp-ui-verification.json、截图sharp-ui-*.png、日志editor-sharp-ui*.log；sharp-ui-before与旧历史证据保留。主场景/默认物理/project.godot/用户Shader哈希保持。此次由Codex直接处理，无Gemini调用；视觉认可待负责人反馈，未提交/推送。
