# 武道牌途 · 开发日志

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
