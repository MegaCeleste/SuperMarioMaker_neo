# SMMWE 物理与操控研究

日期：2026-10-08。状态：源码研究与数值对照完成；后续行为调校/人工试玩尚未开始。

## 目标

从负责人提供的 SMMWE 源码提取可追溯的运动数值、输入规则、更新顺序和碰撞辅助，与当前 SMMneo 对照，解释手感差异并提出后续调参/实现顺序。本轮研究不修改玩家行为或关卡地形。

## 步骤

- [x] 读取工程入口、当前 Player 模块与运行配置。
- [x] 确认提供的 GitHub 仓库仅有下载索引，选择其中最新列出的 SMMWE 4.0.0。
- [x] 下载、核对并仅提取分析所需文本源码，记录来源与 SHA-256。
- [x] 用 antigravity-delegate 将独立参数/输入提取交给 Gemini，Codex 追踪调用链并验收。
- [x] 建立按图块和 60 Hz 统一单位的比较，计算确定性运动曲线。
- [x] 保存研究、证据、委派验收、局限及可执行的后续建议，更新 roadmap。

## 当前依据与边界

SMMneo 使用 PlayerInputFrame 捕获逻辑动作，PlayerMotion 更新速度/跳跃窗口，PlayerCollision 配置形状和修正，Player 在 move_and_slide 前后协调。当前基础物理多数标记 CANDIDATE。

来源：https://github.com/arichornlover/SMMWE-SourceCode ，其 README 中 SMMWE 4.0.0 链接：https://drive.google.com/file/d/1Uv6Fqpp5eXy70mPek1QIxEL2ipoh4vuq/view 。原 ZIP 与本地分析材料放在被忽略的 local_debug_output/smmwe-research/；原始研究素材不替换。

源码确认、离散计算、引擎运行和人工试玩分别标注。SMMWE 的实现只能说明该同人版本，不能作为 SMM2 官方实测。尚未运行 SMMWE，也尚未得到负责人试玩认可。

## 完成与交接

详见 [研究报告](../research/2026-10-08-smmwe-physics.md)，数值/逐帧CSV/曲线放 docs/research/smmwe-4.0.0/。可复现工具在 tools/research/measure_player_motion.gd、相邻 tscn 与 analyze_smmwe_physics.py。

Gemini 3.8 Flash Medium 完成独立审查；Codex验收核心参数通过，修订P槽相位、限速时序与条件性离地窗口。结果在 local_debug_output/delegations/2026-10-08-smmwe-physics/run-01/。当前玩家参数、源码、project.godot与地形哈希保持。本次运行的是数值探针，不是整游戏的回归或交互验收。

下一步以实验配置优先比较空中反向力和完整跳跃曲线，再调地面松键/只松跑键的差别；保留既有负责人确认的跑姿、蹲跳和满速跳表现规则。NSMBU独立对象的半尺度数值需单独运行核验，不能混入SMW参考表。
