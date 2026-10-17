# SMMWE 同步后轻飘反馈复核

2026-10-09。负责人试玩当前默认后反馈“轻飘飘，像在月球上”。本轮调查单位、时序和来源差异，没有直接加倍重力或修改游戏运行参数。

## 确定的结论

当前长按普通跳的上升重力由同步前900降到360px/s²；原地到顶点24→36帧，腾空46→61帧。满速到顶点29→40帧，腾空58→68帧。这可以解释长按时上升慢、滞空更长的感受；负责人尚未认可此配置。

再次执行真实PlayerMotion数值探针，当前结果保持：原地高度75.4px/36帧到顶点/61帧腾空，满速89.8px/40/68；原地点按1帧26.65px/13/27。完整结果在 [本次JSON](smmwe-float-audit-2026-10-09.json)。该探针是合成同高平地，不测用户窗口输入延迟或GameMaker。

单位转换并未发现多除一次2、多乘一次delta、重复积分等错误：GameMaker速度为px/step，加速度为px/step²，转本工程px/s、px/s²应分别乘60和3600，再应用空间尺度。32px→16px需乘0.5，故HD用30、1800。实际运动只有一次velocity+=gravity*delta，再由move_and_slide执行位移。Godot项目没有新增time_scale或physics_ticks改动。

但此前证据的实际含义需要说清：检查通过证明Godot实现与所选源码模型一致，**没有证明等同于SMMWE发布版手感**。README标4.0.0的下载包内部为HD分支，此事实上轮已记录，但还缺普通分支对照与GameMaker运行校准。

## 新增独立源码对照

找到 [yohexp/smmwe3.4.2F-sc](https://github.com/yohexp/smmwe3.4.2F-sc)，作者README称其为3.4.2F源码，版本标签仍未独立验证。仅下载4份公开文本，没有执行第三方游戏或代码。

直接证据：[普通运动GML](https://github.com/yohexp/smmwe3.4.2F-sc/blob/main/objects/obj_mario/Other_12.gml)、[16px实心方块](https://github.com/yohexp/smmwe3.4.2F-sc/blob/main/sprites/spr_square/spr_square.yy)、[60Hz选项](https://github.com/yohexp/smmwe3.4.2F-sc/blob/main/options/main/options_main.yy)。文件哈希/大小/URL保存在JSON，原文放 ignored 的 local_debug_output/2026-10-09-float-audit/。

| 项目 | 当前HD归一值 | 普通16px源码归一值 |
|---|---|---|
| 原地 / 移动 / 高速初速 px/s | −237 / −243 / −258 | −237 / −243 / −258 |
| 长按上升 / 下落重力 px/s² | 360 / 1080 | 360 / 1080 |
| 普通旋跳 px/s | −198 | −198 |
| 跑速 / 同向 / 反向 | 180 / 216 / 468 | 180 / 216 / 468 |
| 大重力切换速度 px/s | >−30 | >−60 |
| round(hspeed/2)==0对应慢档范围 | abs(vx)<30 | abs(vx)<60 |

普通分支跳速−3.95/−4.05/−4.3、重力0.1/0.3，直接乘60/3600后与HD主数值一致。这反驳“HD重力被错误减半，应直接改成720”的猜测。真正的跨版本差别是没有相同比例缩放的阈值；不能单凭文件名把阈值差别或低重力本身宣布为GameMaker运行bug。

将两个阈值改为普通分支值，在ignored临时Resource运行同一数值探针：原地73.05px、33帧到顶点、57帧腾空；满速87.6px、36/65。原地点按1帧未变。顶点缩短3–4帧、总腾空缩短3–4帧，仅能解释部分差别；当前默认未切换到这份实验资源。

[GameMaker gravity官方说明](https://manual.gamemaker.io/lts/en/GameMaker_Language/GML_Reference/Asset_Management/Instances/Instance_Variables/gravity.htm)确认其为累积加速；完整自动移动与碰撞顺序仍需在GameMaker或发布版录像中验证。两版本GML对照不是发布版逐帧实测。

## 处理边界与下一步

已将负责人反馈记入player_parameter_evidence.json；tuned仍false。base_physics、PlayerMotion、Player、主场景和project.godot的本轮起始哈希全部保持。只更新调查/证据/交接，不把缺乏源码或运行证据的任意重力倍数当作已找到的纠错。

如果目标是更紧凑的跳跃节奏，应同时约束跳高、到顶点帧数、短跳和落速，配对调整起跳初速与重力。理想连续模型H=v²/(2g)：保持起速却把上升重力翻倍会大幅压低跳高；保持跳高且缩短时间需要一起提高起速和重力，并同步近顶点阈值/终端落速。这样的调整属于基于负责人反馈的手感调校，需与原始参考配置分别标记。

最小外部校准是同风格/形态、同高平地的短按/长按/满速起跳录像，记录真实帧率、首次位移、顶点、落地和格高；先确认选用版本，再判断引擎时序或参数是否应改变。

Gemini通过官方Antigravity CLI完成单位复核，实际模型gemini-3.8-flash-medium，SUCCESS、非空回答，无工具调用或拒绝。Codex采纳单位公式、两分支主数值一致与时间变长的结论；收窄“完整还原”的表述，不采纳作者遗漏意图、关卡彻底损坏等未经验证的推断。连续模型78px估算不能替代实际75.4px测量。原始结果与codex-acceptance.md在 local_debug_output/delegations/2026-10-09-float-audit/run-01/。
