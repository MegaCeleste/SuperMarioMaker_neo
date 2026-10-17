# SMMWE 普通运动同步

目标：按负责人要求将默认玩家运动切为研究中 SMMWE 4.0.0 普通白天 SMW 的 16px/60Hz 换算，供直接试玩。保留旧配置和负责人已确认的姿态规则、输入辅助；不改主场景地形。

步骤：

1. 保存现有基线，增加可切换运动模型和默认参考参数。
2. 同步地面/空中反向、超速回落、三档起跳及重力时序；仪表盘提供新旧切换。
3. Gemini 只读复核；Codex 编译、运行数值探针并检查姿态/释放/缓冲/碰撞边界。
4. 更新参数证据、设计和交接，给出试玩入口。

当前：实现和技术核验完成。默认资源使用 SMMWE，旧值原样保存于 data/physics/pre_smmwe_physics.tres；负责人手工试玩待反馈。

范围：普通运动、顶头和普通踩踏反弹；碰撞盒、动画步频、道具/实体/死亡与特殊地形维持当前工程实现。参考采用先加重力后位移、落速预钳制的源码模型假设，未认定与 GameMaker 运行完全一致。

## 实际修改

| 参数 | 调整前 | 默认 SMMWE 参考 |
|---|---|---|
| 走 / 跑速度 px/s | 84 / 180 | 78 / 180 |
| 同向加速度 px/s² | 地面225，空中146.25 | 地面/空中216 |
| 反向加速度 px/s² | 地面540到零，空中146.25 | 地面/空中468，单步越零 |
| 松方向摩擦 px/s² | 225 | 180；空中仍为0 |
| 地面超速回落 px/s² | 225回到上限 | 独立90；保留源码分支门槛 |
| 普通跳初速 px/s | −360至−430连续插值 | 原地−237 / 移动−243 / 高速−258 |
| 三档门槛 px/s | walk至run插值 | abs(vx)<30 / ≥30 / >168，水平更新前选档 |
| 旋跳初速 px/s | −280 | −198 |
| 上升 / 下落重力 px/s² | 900 / 1800 | 360 / 1080 |
| 大重力切换 | 松本次起跳键或vy≥0 | 松本次起跳键或vy>−30，锁存 |
| 起跳帧重力 | 跳过一次 | 首个移动帧正常积分 |
| 下落速度阈值 px/s | 积分后270 | 积分前240，60Hz实际输出最高258 |
| 顶头速度 px/s | 10 | 0 |
| 踩踏初速 px/s | 短−180 / 长−360 / 旋−120 | 均−253.5，保持键控制重力 |

PlayerPhysicsProfile 用 MotionModel 区分算法，类缺省 LEGACY 避免旧资源被隐式改动；base_physics 显式使用 SMMWE。PlayerMotion 完成运动、锁存和速度，Player 只把踩踏输入快照交给 Motion，不移动地形或复制第三方引擎碰撞。

蹲跳保持到落地、满速起跳姿态保持到落地、速度决定跑姿、P槽不控速/跳高、本次起跳来源键、6帧土狼/5帧缓冲/3px擦角保留。参考专属的0.5px旋跳/反弹y--偏移没有迁移。Gemini 提醒的踩踏来源键疑点由 Codex 缩窄到“旋跳键降级普通跳”场景，已在参考路径修复；旧路径维持旧规则。

仪表盘新增参考/调整前预设选择，切换复制全部字段到同一个Profile并复位玩家和测量；新参数可调，旧模式禁用参考专属字段。参数步长调整到能够显示216、468、−237、−253.5，避免SpinBox取整造成显示/实际不一致。恢复基线返回SMMWE，导出记录所选preset与完整快照。

## 检查结果

- Godot 4.7.2 导入/编译、主场景及仪表盘启动检查通过。环境已有根证书、编辑器MCP/设置权限及退出残留问题与 gameplay 解析错误分别记录。
- 真正的PlayerMotion在新/旧Profile各测24组数据。对独立历史参考模型及旧实现的139项数值比较通过；长短跳1/6/12帧、原地/走/跑/旋跳与反向结果一致，旧配置数值未漂移。
- 合成地面上的实际Player + move_and_slide：原地长跳75.409px、36帧到顶点、61帧腾空；满速89.800px、40/68帧；蹲跳75.400px、36/61帧。误差来自地面求解margin。数值预期为75.4 / 89.8。
- 160次边界断言通过，含来源键释放/重新保持、近顶点阈值、预输入起跳首帧、踩踏、死亡/复位、满速与蹲跳锁到落地、新旧资源/共享引用/调参显示和编辑状态。
- 验证辅助场景曾在同一物理回调内销毁临时仪表盘并直接退出时出现Windows访问异常；辅助脚本改为等两次process_frame清理后退出，最终返回0。该首次退出不计作成功运行；断言结果与最终运行分别保留日志。没有据此归因为游戏运动错误。
- 主场景、PlayerCollision、PlayerAnimator、project.godot原哈希保持；Player.gd只有反弹输入参数交接这一行变化。没有提交/推送，既有工作区修改保留。

数值与实现哈希保存在 [同步测量JSON](../research/smmwe-sync-2026-10-08.json)，本地逐帧/日志在 local_debug_output/smmwe-sync/。

Gemini 官方CLI，实际 **gemini-3.8-flash-medium**，SUCCESS、非空回答，无工具调用/拒绝。Codex采纳来源键问题的可复现部分；反向越零、258落速、缓冲多积分及切换脏状态结论不符合源码/实际调用链，判作误报。参见 [原始结果](../../local_debug_output/delegations/2026-10-08-smmwe-sync/run-01/result.json) 与 [Codex验收](../../local_debug_output/delegations/2026-10-08-smmwe-sync/run-01/codex-acceptance.md)。

## 试玩与复现

重启游戏，Godot编辑器F5运行现有主场景即可使用默认参考物理。对比时选 src/gameplay/debug/physics_dashboard.tscn 并F6运行，在下拉框切换预设。先试静止起跑、松方向、只松跑键、地面/空中反向，再试点按/长按、满速跳、旋跳、蹲跳、踩怪。观察空中更快转向、上升节奏变长、短跳/满速跳高度降低；手感是否正确由负责人试玩判断。

```powershell
& 'C:\!application\tools\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . 'res://tools/research/measure_player_motion.tscn' --quit-after 60 -- --output 'res://local_debug_output/smmwe-sync/native-metrics.json'
& 'C:\!application\tools\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . 'res://tools/research/measure_player_motion.tscn' --quit-after 60 -- --profile 'res://data/physics/pre_smmwe_physics.tres' --output 'res://local_debug_output/smmwe-sync/previous-metrics.json'
& 'C:\!application\tools\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . 'res://tools/research/verify_smmwe_sync.tscn' --fixed-fps 60 --quit-after 720
python tools/research/check_smmwe_sync.py
```

此验证是普通运动专项检查，没有完整GameMaker执行、人工A/B、全项目自动回归或试听；SMMWE参考并非官方SMM2测量。下一步收集负责人试玩反馈，再决定是否调碰撞盒、步频或辅助窗口。
