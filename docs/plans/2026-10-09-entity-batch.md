# 批量制作 SMW 常用怪物与物品

更新：2026-10-10。负责人授权的全部六类怪物、五类物品、派生实体和公共流程已实现；技术检查通过，手感/视觉认可等待负责人试玩。未提交或推送。

## 分阶段交付与阅读入口

| 阶段 | 状态、职责及阅读顺序 | 可观察结果 |
|---|---|---|
| 公共框架 / 现有回归 | 完成。先读 `entity_hit.gd` → `entity_hit_result.gd` → Enemy/Player/PlayerFireball。命中响应由受击类型拥有；PickupInteraction、BlockContent共享接触与释放 | Goomba踩扁、Galoomba翻倒/搬运/投掷、原有道具出块及火球行为迁移完成 |
| 红绿龟与壳 | 完成。`koopa.gd` → `naked_koopa.gd` → `koopa_shell.gd` → `entity_spawn.gd`。龟负责脱壳，无壳龟负责寻壳，壳负责占用/恢复/滑动 | 红龟悬崖转向、绿龟落下；脱壳/入壳、净空恢复、连续击敌、双壳互败、搬运/高抛/反弹 |
| 其他怪物 | 完成。Buzzy/Spiny类型命中 → BobOmb/BombFuse → EntityExplosion → PiranhaPlant | 火球免疫、安全旋跳、引信不中途刷新、手持爆炸、邻弹直接击败、四向管口循环/抑制 |
| 物品与奖励 | 完成。PowerUpPickup → SuperStar/OneUp/Coin → PlayerStatusEffects → GameManager | 星星600活动帧与刷新、普通伤害免疫和临时速度门槛；1UP、10/30/50金币一次性奖励 |
| 综合接入与验收 | 完成。Registry → EditorCatalog → 试玩JSON → native probe | 22个Registry条目、所有新对象圆盘选择/静态预览、十个试玩入口、428项检查通过 |

统一规则在 [制作规范](../entity-production.md)，来源表和完整交互矩阵在 [源码研究](../research/2026-10-09-smmwe-entities.md)。Goomba/Galoomba、蘑菇/花/金币的原配置备份和51项参考值证据均已保存。

## 负责人试玩步骤

打开 `src/gameplay/debug/basic_entities_playground.tscn` 后按 Godot F6。上方入口下拉选择分区；形态下拉选 Small/Super/Fire。默认 A/D移动、↑普通跳、↓旋跳、←跑/抓取/Fire发射，搬运时W+松开←高抛。运行中的F6暂停、F7单帧、R复位（重建所有实体，清空金币/额外生命/星星）。

1. 原有问号块、两类栗子仔和翻转块区：确认原玩法回归，Fire火球与Galoomba投掷仍工作。
2. 乌龟与壳区：普通踩红/绿龟，观察壳和无壳龟分离；让无壳龟靠近同色空壳；搬运、普通投掷、高抛、踩停滑动壳，观察反弹回伤及红龟边缘转向。
3. 钢盔龟与刺刺区：普通踩钢盔龟，Fire对钢盔无效；普通跳刺刺受伤，旋跳安全反弹；顶块可产生翻倒壳。
4. 炸弹区：踩或火球点燃，重复搬运/扔下不刷新引信；暂停/变身定格停止，手持仍继续。看爆炸破坏硬块/翻转块及释放问号块1UP。
5. 食人花区：先离开管口，观察伸32/停90/缩32/等90帧；站近口抑制下一次伸出，隐藏无伤害；继续向右查看侧向花。管口为静态地形，不接传送。
6. 星星与奖励区：拾取或顶块获得星星/1UP；跳取10/30/50金币，HUD应累计90。星星显示剩余活动帧与色循环，可接触击败怪物；再次吃星刷新600，到期恢复速度规则；R清空奖励。

## 已执行检查和证据

| 证据 | 结果与范围 |
|---|---|
| Godot 4.7.2 导入 | 退出码0，无新增脚本/资源解析错误。51素材安装成功。已有证书读取、MCP插件、编辑器设置权限和插件退出残留单独记录 |
| 原生物理与交互 | `tools/verification/entity_batch_probe.tscn`：428 checks / 0 failures，包含八类怪物×八种命中、真实壳移动/墙反弹/双壳/悬崖/入壳、恢复净空、真实火球碰撞、计时/奖励/暂停/冻结/死亡/复位/退出 |
| 实际窗口 | `tools/verification/entity_batch_capture.tscn`：1280×720、D3D12 Forward+、十个入口和星星画面，Codex查看PNG确认素材、管口裁剪、面额数字、HUD滚动与色循环；退出码0，最近窗口运行无资源残留 |
| 启动回归 | F5主场景与独立editor场景30帧启动退出0，无新增gameplay错误；目录/窗口布局不变 |
| 保留边界 | 默认普通玩家Profile、project.godot、editor.tscn与起始SHA256一致。主场景在任务期间另有保存（新增怪物实例），与起始整文件哈希不同；Codex未写入或回退该场景，保留当前内容，不据此宣称地形哈希已验证。差异与文档链接检查见收尾报告 |
| 负责人试玩 | 尚未进行；不得用自动检查或截图代替负责人手感/视觉认可 |

物理报告 `local_debug_output/entity-batch-verification.json`；导入与probe日志 `entity-batch-import.log`、`entity-batch-probe.log`；窗口日志 `entity-batch-capture.log`，截图 `entity-batch-zone-00..09.png`、`entity-batch-star.png`。Headless快速退出偶有AudioStreamPlaybackWAV残留，最后详细检查未发现新Node组件/脚本资源残留；实际窗口退出无此告警。Windows证书与screen=-1为已有环境错误。

## 可复现命令

工程根目录PowerShell，本机console版可保留日志：

```powershell
& 'C:\!application\tools\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import --quit
& 'C:\!application\tools\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . res://tools/verification/entity_batch_probe.tscn --fixed-fps 60 --log-file local_debug_output/entity-batch-probe-native.log
& 'C:\!application\tools\Godot\Godot_v4.7.2-stable_win64_console.exe' --path . res://tools/verification/entity_batch_capture.tscn --fixed-fps 60 --log-file local_debug_output/entity-batch-capture-native.log
```

资产安装使用有Pillow的Python运行 `tools/asset_pipeline/install_basic_assets.py --source ../TBDtoVERIFIED/textures/styles`；爆炸另需已保存的源码ZIP。重建数值证据执行 `tools/research/build_entity_parameter_evidence.py`。原始资料不删除，安装只复制选定源或拼接原帧。

## 委派与后续边界

Gemini公开源码整理已实际执行，模型 `gemini-3.8-flash-medium`。首个有CLI命令拒绝的空结果未通过验收；无工具的公开摘录重试成功，Codex补充事件/继承追踪、修正位移换算和遗漏后采用。结果与验收链接见研究记录；没有外发私有工程代码。

当前编辑器只选择/预览，实际放置、存读、试玩返回闭环另行推进。P开关、POW、钥匙、其他玩家形态、音乐切换、TileMap运行破坏、翅膀/刺球/爬顶/喷火/跳跃花不属于本轮。下一步从负责人分区试玩反馈继续，避免重复改普通玩家物理或重写编辑器布局。
