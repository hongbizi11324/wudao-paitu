

## Codely Structured Memories

### User
- [2026-09-19 11:00:23] 用户偏好（本项目迭代中体现）：希望我自主推进、少打断，朝着"完整游戏"持续迭代（玩法/手感/数值/系统/素材全都要）；用中文交流；认可并主动建议派子助理做独立研究（如数值平衡）；对游戏"手感"和"平衡性"很在意，会自己试玩并反馈（如"打了几遍都没打过去"）；推送 git 需其先连 VPN。

### Feedback
- [2026-09-19 11:00:05] 平衡性测试必须同时建模「输出」与「承伤」，只有输出模型会给假绿灯：曾把 Boss HP 系数调到 ×3.8、测试仍全绿，但玩家只有 4 张手牌，无法同时满足"7回合击杀"与"挡住三阶段爆发"，第6/12层Boss 数学上必死（玩家反馈"打了几遍都过不去"）。现用双模型断言（击杀回合区间 + 承伤≤血量预算）并打印数值面板。任何"平衡性调参"都必须过这关，且优先派子助理做独立数值研究再改数。

### Project
- [2026-09-19 10:59:50] Godot 工具链与验证工作流（E:\godotsave\card）：编辑器 E:\steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe（4.7.2）；无头测试 `godot --headless --path . res://tests/test_boot.tscn --quit-after 3000`（退出码0=全过，9套件：回合机/数据地图/结算器/Lua/一致性/平衡双模型/敌人/遗物/丹药/战斗集成）；新建或改名 class_name 后必须先 `--headless --import` 刷新全局类缓存，否则引用方解析失败且无头运行会静默挂死；无头跑测试永远带 --quit-after 兜底。
- [2026-09-19 10:59:58] 编辑本项目文本资源的两个必踩坑（已多次造成真 bug）：1) 不要用 PowerShell `Set-Content -Encoding utf8` 写 .tres——会带 BOM，Godot 报 `Parse Error: Expected '['`；必须用 `[System.IO.File]::WriteAllText/WriteAllBytes`。2) PowerShell 单引号字符串里的 `\`n 是字面量不会换行，拼接多行内容要用双引号或 `"`r`n"`，否则会往源码里写入字面反引号n。改完 .tres 必须跑一次 --headless --import 验证。
- [2026-09-19 11:00:15] 架构不变量（改动前必读）：出牌唯一路径 = main._calc_card_cost 算费 → Lua 纯函数（lua/cards/ 五模块，只读 ctx 返回结果清单，禁止写状态/禁止引用 host）→ CardExecutor.apply() 原子执行 → Lua 不可用才走 main._fallback_result。遗物/丹药走 RelicEffects / PotionEffects 静态钩子（battle_start / turn_start / modify_card_result / modify_incoming_damage / turn_end / battle_end）。卡牌资源统一用 GameData.load_card()（强化卡 id 带 "+" 映射 _plus.tres，Lua 侧自动解析到基础卡）。新增卡牌流程：写 .tres（无BOM）+ lua/cards/ 实现 + 加入 GameData.NEUTRAL_CARDS 或 SCHOOL_CARDS + 跑 res://tools/gen_upgrades.tscn 生成强化版；一致性测试会强制校验每张 .tres 都有 Lua 实现且资源可加载。

### Reference

