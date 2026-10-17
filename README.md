# SMMneo

基于 Godot 4 / GDScript 的 2D 平台跳跃与关卡创作项目，以 Super Mario Maker 2 为主要参考。目前处于可试玩原型阶段，正在打磨玩家、基础实体和长期制作流程。

## 开始阅读

- [项目文档](docs/README.md)：架构、游戏设计、关卡格式与决策。
- [路线图与当前交接](docs/roadmap.md)：实际进度、已知问题和下一步。
- [Codex 工作指南](AGENTS.md)：项目入口与协作习惯。

2026-10-08 起使用持续维护的 docs。原 spec/SDD 流程已停用，历史资料保存在 [归档](docs/archive/README.md)。

## 当前原型

- 模块化 Player：移动状态与形态演出分开，支持走跑、长短跳、下蹲/蹲跳、满速跳、旋转跳、受击/死亡、搬运与火球。
- 玩家物理仪表盘：实例调参、入口切换、暂停/单帧、速度/高度曲线与记录导出。
- 基础实体场景：蘑菇、火焰花、金币、栗子仔、板栗仔、问号块、已用块、硬块与翻转块。
- 注册表工厂与关卡 JSON/RLE 基座；完整编辑器、运行关卡加载、通关流程与多风格呈现仍待开发。

运动与交互包含工程候选，尚未完成所有试玩校准。当前玩家视觉为 SMW；栗子仔暂用明确的 SMB1 走路/踩扁素材，板栗仔用 SMW 素材。

## 本地运行

在 Godot 4.7 中导入本目录的 project.godot，主场景为 src/main/game.tscn。试玩场景：

- src/gameplay/debug/physics_dashboard.tscn
- src/gameplay/debug/basic_entities_playground.tscn

在编辑器选中场景按 F6 运行。实体试玩也可从仪表盘的“基础实体试玩”按钮进入。运行中的 R/F6/F7 分别是复位、暂停与单帧。

游戏媒体在本地 textures/、audio/，不随 Git 分发。新克隆需要配置素材，现有占位/安装工具尚不能自动补齐全部运行依赖。选定基础贴图可通过下面的脚本安装；--source 指向原始 styles 文件夹：

```powershell
python tools/asset_pipeline/install_basic_assets.py --source 'C:\Working\SMMneo\TBDtoVERIFIED\textures\styles'
```

该工具保留原图，复制核对过的帧条并生成清单/SpriteFrames。编译与检查入口见 [architecture](docs/architecture.md)。

## 贡献与许可证

提交具体问题、复现步骤、试玩反馈或小范围改动。修改时同步相关文档，保持用户关卡和素材来源可恢复。

代码按 [MIT License](LICENSE) 开源。真实游戏贴图/音频等媒体版权归各自权利人；本地媒体与文本元数据分开管理。
