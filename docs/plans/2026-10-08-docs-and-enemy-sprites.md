# 文档迁移与敌人帧修复

日期：2026-10-08。状态：完成；Gemini 独立审查未产出有效报告，收尾检查由 Codex 完成。

## 目标

负责人报告“板栗”走路时在 SMW/SMB1 外观之间切换，并要求废弃 spec/SDD 标准，采用 docs/architecture、game-design、level-format、decisions、roadmap。修复当前敌人映射并落实文档与 Codex 工作入口，保留代码、地形、来源与历史。

## 进度

- [x] 读取当前工作区、旧规范、代码和暂停交接。
- [x] 直接查看 goomba_res、真实 Goomba/Galoomba 走路及踩扁/翻倒源图；查明混合外观帧被误当动画。
- [x] Goomba 换真正 SMB1 走路双帧/踩扁单帧，移除合成缩放踩扁；Galoomba 保持 SMW 映射。
- [x] 加入源图用途/风格和帧映射声明检查，生成 26 张本地原样副本及 SpriteFrames。
- [x] 归档旧 specs/tasks/AGENTS，记录原始 SHA-256，建立当前 docs 与新 AGENTS。
- [x] 修正当前 README 与活动源码/证据中的过时路径，补外层工作区导航 AGENTS。
- [x] 完成导入/编译、差异及归档完整性检查。
- [x] 将负责人新增的 Gemini 自动委派规则写入当前 AGENTS 与协作文档。
- [x] 检查 Gemini 输出与诊断，拒绝空报告，完成 Codex 收尾检查并保存交接。

## 原因与取舍

文件名 StripN 只能证明分片数，不能证明相邻帧是同一角色动画。旧“尺寸验证成功”被过度解读成语义确认，本次撤销该错误映射并用实际源帧替换。Goomba 当前明示 SMB1 美术，不伪造原生 SMW 走路资产；后续多风格呈现统一处理。

docs 按当前代码整理，区分预留/已实现/已检查。旧规范废弃但内容留作历史：迁移确认由用户本次请求提供，无需重新走旧 approved 门槛。工作流选择见 ADR 0001。

## 检查与结果

安装工具执行成功，26 张完整画布尺寸与已声明风格/帧范围检查通过。错误 goomba_res 源记入 rejected_sources，旧本地副本 JSON 改为 rejected，原 PNG 保留。

Godot 4.7.2 headless 导入/编译退出码 0，本轮未观察到新增 gameplay 或资源解析错误。日志仍包含已有 Windows 证书错误、MCP 插件 null.listen、编辑器设置保存权限与退出资源残留，不报告成“没有错误”。日志：local_debug_output/docs-and-enemy-sprites-import.log。

git diff --check 退出码 0；20 份归档原始文本的 SHA-256 全部匹配。主场景 tile_map_data 行的 SHA-256 仍为 0ABFDFAC25AA6CD5240309535C0AFF166D74B5C78F2FF9BB82F7AC12E850294B。未新增/运行测试，未进行交互试玩或试听。

按负责人新增指令尝试通过 antigravity-delegate 只读复核 docs 与代码/敌人映射。首次沙盒内模型查询失败，诊断含用户目录写入与网络代理限制；授权执行后成功启动 gemini-3.8-flash-medium。CLI 最终标为 SUCCESS，但 response.md 为 0 字节，且目录读取命令被权限规则拒绝，Codex 判定委派未通过验收，不采纳任何审查结论。未扩大权限、修改登录配置或再次重试。结果与 Codex 验收：local_debug_output/delegations/2026-10-08-docs-review-02/result.json、codex-acceptance.md。

Codex 已核对本次敌人清单与生成 SpriteFrames、运行加载器和安装工具，复核关卡文档与当前 JSON/RLE 辅助的能力边界，并完成文档相对链接、归档哈希、地形保留和导入编译检查。没有把这些检查称为全功能审查或交互验收。

## 交接

代码、素材映射、当前文档及 AGENTS 已保存。后续从 roadmap 的近期顺序继续；暂停前遗留的 HUD 滚动、交互边界与试听仍待处理。所有工程改动留在本地工作区，未提交或推送。
