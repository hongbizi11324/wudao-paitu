# 武道牌途 · 开发日志

---

## 2026-09-12 大修：12+ 核心 bug 修复 + 架构重置（Lua Command Pattern）

### 背景

对全项目做了系统性摸底（通读全部核心脚本 + 无头导入扫描 + 场景核对），
修复了所有确认的 bug，并把出牌逻辑从「三套并行系统」收敛为单一 Command Pattern 路径。

### 修复的核心 bug

| # | Bug | 根因 | 修复 |
|---|-----|------|------|
| 1 | Boss 战永远打不出来 | `select_map_node` 已设楼层，`_do_select_node` 又调 `advance_floor()` 双推进 | 楼层推进唯一入口=地图选点，删除 advance_floor |
| 2 | 双人模式敌人只打 P1 | `execute_enemy_turn(player1)` 写死 | 敌人用宿主权威 RNG 从存活玩家随机选目标；Boss 楼层只保留唯一战斗节点 |
| 3 | P2 掉血写坏 P1 存档血量 | `take_damage` 无条件写 `GameData.player_hp` | Player 带 `is_p2`，分别同步 player/player2 字段 |
| 4 | 联机客机永远无法结束回合 | 客机无 turn_manager，`_on_end_turn` 判空直接 return | LAN 客机分支前置，先发 `request_end_turn` 再判空 |
| 5 | 太极两仪被动一回合后失效 | Lua 里 `host` 全局从未绑定恒为 nil，`if host and ...` 静默跳过 | Command Pattern 后 Lua 为纯函数，彻底根除 |
| 6 | 断水流/万象归一/袖里乾坤把自己也弃掉 | Lua 写回调直接操作手牌节点，不排除打出牌 | 结果清单改由执行器结算，手牌操作强制排除打出牌 |
| 7 | 出牌失败吞折扣 | `next_card_discount` 在 `spend_energy` 校验前清零 | `_calc_card_cost` 统一算费，成功后才消耗 |
| 8 | 逍遥游"手牌上限+2"是空话 | `hand_limit_mod` 从未接入 Hand | `Hand.apply_limit_mod()`，回合开始按玩家应用 |
| 9 | 商店买/删一次整体刷新进货 | 买/删后调用 `_restock()` | 售罄制：买走的槽位标记已售出 |
| 10 | 双人模式 P2 的 POWER 不触发 | `_trigger_power_effects` 只跑当前别名玩家 | 回合开始按玩家逐一结算 |
| 11 | 三个英雄被动是"宣传诈骗" | 描述存在、代码不存在 | 六英雄被动全部落地（慧明/林风/云芷/墨瑶/玄翁/夜啸） |
| 12 | 客机手牌 diff 节点泄漏 | `_diff_hand` 移除卡不回池 | `CardPool.release()` |
| 13 | 地图返回按钮重复叠加 | `node_map.open()` 每次新建按钮 | 只创建一次 |
| 14 | 奖励数值与地图提示不符 | 悬停提示"精英20/20"实给 10/12 | `get_battle_reward()` 按楼层类型缩放 |

### 架构重置（Command Pattern）

```
旧（三套并行，互相漂移）：
  _execute_card 700行 match 分支  +  cards.lua 边算边写 gd_* 回调  +  EffectResource 效果系统
  └─ Lua 报错 → 半截状态 → 20+字段事务快照 → 回滚（有视觉残留风险）

新（单一路径）：
  _calc_card_cost 统一算费
    → Lua 纯函数（只读 ctx）算「结果清单」Dictionary
    → CardExecutor.apply() 原子执行
    → Lua 报错 → 清单没返回 → 什么都不执行 → 状态天然干净（无需快照/回滚/沙箱）
    → Lua 整体不可用 → _fallback_result 通用数值结算兜底
```

- **lua/cards/** 按门派拆 5 个模块（basic/shaolin/wudang/xiaoyao/yunzhi），按序加载、按序热重载
- **LuaFunction 编译缓存**：每卡只 load_string 一次，热重载清缓存
- **预览 = 出牌**：同一份纯函数，预览零副作用（旧沙箱/守卫层整体删除）
- **回合追踪按玩家分开**（`_track[1]/_track[2]`），共享回合下 P1/P2 互不污染
- **效果系统（EffectResource 全套 12 个类 + 16 张卡的 effects 数组）整体移除**
- 删除死代码：enemy_ai.lua、sync_turn/sync_play/sync_end_turn RPC、main_backup.gd、autoload 空文件等

### 联机补齐

- 商店：库存由主机生成并同步（sync_shop_open/update），客机购买/删牌请求转发主机结算，双人可选买入/删除哪个牌组
- 事件：主机生成后广播事件内容（两端一致，谁先选谁算，`_node_result_done` 防双推）
- 休息：主机选择（客机只展示），治疗全队
- 奖励：主机(P1)与客机(P2)各自选完再开地图；同屏双人 P1 选完轮到 P2
- 快照补充 realm/gold/cultivation/chan/jianyi → 客机预览数值与商店金币不再漂移

### 玩法成熟化

- 六英雄被动落地：慧明（禅意回血）/ 林风（剑意加伤）/ 云芷（首牌减费）/ 墨瑶（第2张攻击+2）/ 玄翁（首击格挡+2）/ 夜啸（低血多抽）
- 奖励/商店卡池按门派过滤（不再把别派卡塞给玩家）
- 敌人数值曲线调优：1.2→1.15 复合增长，Boss ×2.5→×2.2（旧曲线 12 层 Boss 466HP 拖成消耗战）
- Boss 战专属背景 + 立绘（AI 生成水墨素材，每 6 层镇关Boss 一眼识别）
- 卡牌预览显示折扣后实际费用，内力不足费用标红
- 测试模式可选全量 58 张卡

### 测试基建

新增无头测试套件 `tests/test_boot.tscn`（`godot --headless --path . res://tests/test_boot.tscn`）：
- TestTurnManager：状态机推进/共享回合/非法输入/联机注入
- TestGameData：楼层类型/奖励/地图生成不变量/门派卡池/存档回环（自动备份恢复用户存档）
- TestCardExecutor：数值结算/六被动/手牌操作排除打出牌/牌库回收/POWER触发
- TestLuaCards：58 卡 Lua 纯函数语义（条件分支/门派资源/复制类）
- TestBattleIntegration：真实 main.tscn 场景跑完整回合循环（抽牌→出牌→守恒→结束→敌人回合→再抽）
- 全部通过 ✅

### 踩坑新记录（详见 错误总结.md）

- PowerShell `Set-Content -Encoding utf8` 给 .tres 写入 BOM → Godot 解析 `Expected '['`（用 WriteAllBytes 去头）
- 新建 class_name 必须先 `--headless --import` 刷新全局类缓存，否则引用它的脚本解析失败
- 场景 `_ready` 期间往 root add_child 会报 "Parent node is busy"，用业务节点做父级

---

## 2026-07-06 Lua 热更 PoC

### 完成的工作

1. **安装 lua-gdextension v0.8.1**（Lua 5.4 版）
   - 从 GitHub release 下载预编译包，放入 `addons/lua-gdextension/`
   - `project.godot` 启用插件 + 注册 `LuaRuntime` autoload
   - Windows x86_64 DLL（debug + release）

2. **LuaRuntime 桥接层** (`autoload/lua_runtime.gd`)
   - 管理 `LuaState` 生命周期
   - 注入 GDScript 回调：`gd_get_damage_bonus` / `gd_get_punch_damage` 等
   - `execute_card(card_id, ctx)` — 调用 Lua 卡牌效果函数
   - `reload()` / `check_and_reload()` — 热重载机制
   - **Ctrl+R** 快捷键热重载所有 Lua 文件

3. **Lua 卡牌效果脚本** (`lua/cards.lua`)
   - 全局表 `CardEffects[card_id] = function(ctx) -> Dictionary`
   - 已迁移 17 张卡：strike / defend / bash / punch / meditate / heal /
     double_strike / light_step / sl_fist / sl_iron / sl_golden / sl_arhat /
     wd_taiji / wd_soft / xy_beiming / xy_zhemel / xy_fengjuan
   - 返回 Godot `Dictionary{}`，支持 `special` 字段触发 chan/jianyi 变化

4. **main.gd 接入 Lua 路径**
   - `_try_execute_card_via_lua()` — 构建上下文 Dictionary，调用 Lua
   - 在 `_execute_card` 中费用扣除后、match 分支前插入
   - 无 Lua 实现时自动回退原有 GDScript 逻辑

### 架构

```
GDScript（宿主）               Lua（可热更）
─────────────                  ──────────
main.gd                        cards.lua
  _execute_card                  CardEffects.strike(ctx)
    → _try_execute_card_via_lua    → return Dictionary{damage=6, ...}
    → apply results                ← GDScript 执行伤害/格挡/回血
```

### 热更流程
1. 游戏运行中修改 `lua/cards.lua`
2. 按 **Ctrl+R**（或调用 `LuaRuntime.reload()`）
3. `_lua.do_file()` 重新执行 Lua 文件，全局 `CardEffects` 表更新
4. 下次出牌即用新逻辑

### 已知限制（PoC 阶段）
- 复杂卡牌效果（小无相功复制、袖里乾坤选牌等）未迁移
- POWER 卡激活逻辑未迁移
- 联机模式下 Lua 路径仅在主机执行（客机不执行逻辑，无影响）
- Lua 错误时自动禁用 Lua 路径，回退 GDScript

---

## 2026-07-03 大改

### 地图系统
- 全面重写为 Slay the Spire 风格 column-based（7列）
- 12层固定：0=起点 → 1~10=路径 → 11=Boss
- 末尾几层（8~10）汇拢到中间列
- 从下到上布局（底部起点 → 顶部Boss）
- ScrollContainer 可滑动，背景图在内容区内随滚动移动
- 连线改为手绘水墨风（正弦波抖动 + 墨色）

### 卡牌手牌布局
- 从线性排列改为圆弧扇形展开
- 悬停仅高亮（不上浮），点击选中才上浮回正
- @export 参数可在 Inspector 调节（弧形半径、展开角度等）

### 战斗场景
- 4张场景图（竹林/村庄/官府/门派），每大关随机一个
- 敌人立绘从 npc_1.png 裁剪，按生态+难度匹配
- BGM管理器（跨场景持久播放 + 开关记忆）
- 全局点击音效（仅播放1~2秒有效部分）

### 双人热座模式（进行中）
- 开始界面新增「双人合作」按钮
- 选人：P1先选→P2再选，各带不同门派起始牌
- 战斗中点击头像切换操作对象
- 双方都准备就绪后敌人行动

### 已知问题（未修复）
1. P1/P2 角色头像显示相同（怀疑 `show_hero` 覆盖 `selected_character`）
2. 战斗 1~2 回合后不发牌（弃牌堆回收逻辑）
3. 双人结束回合流程可能有遗漏

### 杂项
- Godot MCP 插件已安装（`@yanhuifair/godot-mcp`），端口3001
- 可视化编辑规则：所有带图的节点必须在.tscn设默认纹理

## 2026-07-05 局域网联机大重构

### 完成的工作

1. **状态快照同步体系**
   - 新增 `GameStateSync` autoload: 构建完整游戏状态快照
   - `NetworkManager.push_snapshot()` + `sync_game_state` RPC
   - 主机每次关键操作后推快照，客机只接收不执行逻辑

2. **客机端 `apply_snapshot`**
   - `_diff_hand` 增量更新手牌（不闪烁）
   - 同步玩家HP/能量/格挡、敌人HP/意图
   - 回合切换、等待遮罩

3. **清除旧同步体系**
   - 删除 `sync_play` / `sync_end_turn` / `sync_turn` 调用链
   - `request_play` / `request_end_turn` 改为推快照
   - `_on_turn_started` 改为推快照

4. **Bug修复**
   - `mouse_filter` 未设导致头像点不了
   - `autoload` 顺序导致 GameStateSync 找不到
   - `seed()` 在地图生成后才调用导致图不同
   - `_in_rpc` 拦死正常执行
   - `_on_card_played` 逻辑拆分

5. **文档**
   - 项目知识图谱 `项目知识图谱.md`
   - 局域网联机代码全集 `E:\局域网联机代码全集.txt`
   - BUG备忘录 `BUG备忘录_局域网联机.md`

### 遗留问题
- 战斗仍有异步（奖励画面、敌人伤害等未完全覆盖）
- 商店/休息/事件节点联机未实现
- 断线重连未实现

### Git log
```
3304e3b 🧹 清理旧 sync_play/sync_end_turn 调用
bde6857 🐛 修复地图不同步：seed 移到 _ready 最前端
80315df 🔊 添加出牌和快照日志
1234641 🐛 修复 autoload 顺序 + apply_snapshot
756670f ♻️ 状态快照同步替换操作同步
...
```
