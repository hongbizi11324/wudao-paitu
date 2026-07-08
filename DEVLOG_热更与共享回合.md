# 武道牌途 · Lua 热更 + 双人共享回合 开发日志

> 日期：2026-07-06
> 涉及模块：Lua 热更新系统、双人同屏/联机共享回合制、卡牌效果迁移

---

## 一、技术栈

### 运行时

| 层级 | 技术 | 版本/说明 |
|------|------|-----------|
| 游戏引擎 | Godot Engine | 4.7 (Forward+) |
| 宿主脚本 | GDScript | 负责节点生命周期、信号、渲染、输入 |
| 热更脚本 | Lua | 5.4（内嵌于 lua-gdextension） |
| 桥接层 | lua-gdextension v0.8.1 | gilzoide/lua-gdextension |
| 网络协议 | ENetMultiplayerPeer | Godot 内置 RPC（@rpc 注解） |

### 架构模式

```
GDScript（宿主层）              Lua（热更层）
──────────────────              ──────────────
main.gd                         cards.lua (58张卡效果)
  ├ 节点生命周期                enemy_ai.lua (意图规划/执行)
  ├ 信号连接/UI渲染             battle.lua (POWER触发/回合逻辑)
  ├ 输入处理/出牌校验
  └ 调用 Lua → 应用结果         ← GDScript 回调函数注入 Lua
                                 (gd_player_heal / gd_enemy_take_damage 等)
LuaRuntime (autoload)
  ├ LuaState 生命周期管理
  ├ do_file / load_string / invoke
  ├ 自动热更（每秒检测文件修改时间）
  └ Ctrl+R 强制热重载
```

**专业术语：**
- **脚本热更（Lua 热更）** — 修改逻辑不需重启游戏
- **宿主-脚本桥接架构** — 宿主(GDScript)管理生命周期，脚本(Lua)驱动逻辑
- **Shared Turn（共享回合）** — 双方共享一个玩家阶段，不分 P1回合/P2回合
- **Async Input + Immediate Resolution** — 各自独立出牌，立即结算，不锁对方

---

## 二、完成的工作

### 1. Lua 热更系统

#### 安装 lua-gdextension

- 从 GitHub release 下载预编译包（Lua 5.4 版）
- 放入 `addons/lua-gdextension/`
- `project.godot` 启用插件 + 注册 `LuaRuntime` autoload
- Windows x86_64 DLL（debug + release）

#### 桥接层 (`autoload/lua_runtime.gd`)

- `LuaState` 生命周期管理（创建、加载脚本、热重载）
- 30+ GDScript 回调函数注入 Lua 全局表，供 Lua 调用：
  - `gd_player_heal/add_block/gain_energy` — 玩家状态操作
  - `gd_player_chan_plus/jianyi_plus` — 门派资源操作
  - `gd_enemy_take_damage` — 敌人伤害
  - `gd_hand_card_ids/discard_card_by_index` — 手牌操作
  - `gd_add_card_to_hand/draw_cards` — 牌堆操作
  - `gd_set_power/gd_get_power` — POWER 标记
  - `gd_update_ui` — UI 刷新
- 自动热更：每秒 `FileAccess.get_modified_time()` 检测文件变更
- Ctrl+R 强制热重载

#### Lua 脚本

| 文件 | 内容 | 行数 |
|------|------|------|
| `lua/cards.lua` | 全部 58 张卡牌效果 | ~670 |
| `lua/enemy_ai.lua` | 敌人意图规划 + 执行（Boss三阶段） | ~100 |
| `lua/battle.lua` | POWER 效果触发 + 回合逻辑 | ~60 |

#### GDScript 接入

- `_execute_card()` 中新增 Lua 路径，优先调用 Lua，无实现则回退 GDScript
- `_trigger_power_effects()` 接入 Lua，回退旧逻辑
- 卡牌预览：`update_preview()` 调用 Lua 计算实际伤害/格挡，显示在卡牌描述下方

### 2. 双人共享回合

#### 之前

```
P1回合 → P1出牌/结束 → P2回合 → P2出牌/结束 → 敌人 → P1回合
```

#### 现在

```
共享玩家回合：
  P1出牌 → 立即结算 ← P2随时也可出牌 → 立即结算
  P1点结束 → 弃P1手牌 → 标记p1_ended
  P2点结束 → 弃P2手牌 → 标记p2_ended
  双方都结束 → 敌人回合 → 下一回合
```

#### 改动

| 文件 | 改动 |
|------|------|
| `turn_manager.gd` | 新增 `p1_ended`/`p2_ended` 标记，双人模式等双方都结束才进敌人回合；补回 `turn_started` 信号 |
| `main.gd _apply_turn` | 双人模式开局时双方都抽牌、回能、POWER 触发 |
| `main.gd _switch_to` | 同屏双人只显示当前激活玩家手牌，另一方隐藏 |
| `main.gd _on_card_played` | 出牌时校验牌属于哪个玩家，同屏模式只能出当前激活玩家的牌 |
| `main.gd _on_end_turn` | 双人模式标记当前玩家结束，自动切换到未结束方 |
| `main.gd _do_end_turn_for` | 新增：弃指定玩家手牌而不切换回合 |
| `main.gd _update_active_indicator` | 新增：头像高亮 + 回合标签显示双方结束状态 |

### 3. 联机模式适配

#### 改动

| 改动点 | 说明 |
|--------|------|
| `_on_card_played` | 主机出P1牌直接执行，客机出P2牌通过 `request_play` RPC 发给主机 |
| `_on_end_turn` | 主机结束P1，客机RPC请求结束P2，双方都结束才进敌人回合 |
| `network_execute_play` | 主机收到客机出牌请求，切换别名执行，不改变 `_active_player` |
| `network_execute_end_turn` | 主机收到客机结束请求，标记 `p2_ended` |
| `build_snapshot` | 快照加入 `p1_ended`/`p2_ended` 状态 |
| `apply_snapshot` | 客机同步结束状态，显示等待提示 |
| `_on_node_selected` | 双方都能选关卡，客机通过 `request_select_node` RPC 发给主机 |
| `_on_battle_end` | 主机开奖励界面 + `sync_reward_open` 广播给客机 |
| `_on_reward_chosen/skipped` | 双方选完奖励后主机开地图 + `sync_show_map` 广播 |

---

## 三、遇到的问题与解决方案

### 1. Lua 运行时类未注册

**现象：** `Identifier "LuaRuntime" not declared in the current scope`

**原因：** Godot 编辑器运行中安装的 GDExtension 不会热加载，`LuaState` 等类型未注册 → `lua_runtime.gd` 编译失败 → autoload 未注册

**解决：** 完全关闭 Godot 编辑器后重新打开

### 2. `func_ref.call(ctx)` 崩溃

**现象：** `Invalid call error argument index` — 出一张牌后闪退

**原因：** `LuaFunction` 继承自 `Object`，`Object` 有内置 `call(method_name, ...)` 方法。GDScript 把 `func_ref.call(ctx)` 理解为"调用名为 ctx 的方法"，而不是执行 Lua 函数

**解决：** 改用 `load_string().invoke()` 间接调用（参考 lua_repl.gd 的模式）

### 3. `var func` 语法错误

**现象：** `Expected variable name after "var"`

**原因：** `func` 是 GDScript 保留关键字，不能做变量名

**解决：** 改为 `var lua_func`

### 4. `turn_changed` 信号未连接

**现象：** P2 点结束回合后卡住，不进敌人回合

**原因：** `TurnManager` 有 `turn_started` 和 `turn_changed` 两个信号，`end_player_turn()` emit 的是 `turn_changed`，但 main.gd 只连了 `turn_started`

**解决：** `turn_manager.turn_changed.connect(_on_turn_started)` 同时连两个信号

### 5. 双人手牌互相遮挡

**现象：** 双人模式开局时 P2 手牌覆盖在 P1 上方，看不到自己的牌

**原因：** `_apply_turn` 中 `hand2.visible = true` 覆盖了 `_switch_to(1)` 设置的 `hand2.visible = false`

**解决：** 删掉 `hand2.visible = true`，双人同屏只显示当前激活玩家手牌

### 6. 客机 `turn_manager` 为 nil 崩溃

**现象：** `Invalid access to property or key 'p2_ended' on a base object of type 'Nil'`

**原因：** 场景重载后 `turn_manager` 还没创建，但代码直接访问 `turn_manager.p1_ended`

**解决：** 所有访问处加 `if turn_manager:` 判空

### 7. RPC 发给自己报错

**现象：** `RPC 'request_select_node' on yourself is not allowed`

**原因：** 主机也走了 `rpc_id(1, ...)` 发给自己，`@rpc` 默认不允许 `call_local`

**解决：** 主机直接执行 `_do_select_node`，不走 RPC；只有客机走 `rpc_id(1, ...)`

### 8. `static func` 被 autoload 实例调用

**现象：** `STATIC_CALLED_ON_INSTANCE`

**原因：** `GameStateSync.build_snapshot()` 声明为 `static func`，但 `NetworkManager` autoload 实例调用它

**解决：** 去掉 `static` 关键字

### 9. `card_pool.gd` 变量遮蔽

**现象：** `The variable "obj" is declared below in the parent block`

**原因：** `acquire()` 中内层循环的 `var obj` 和外层的 `var obj` 同名遮蔽

**解决：** 内层改为 `var new_obj`

### 10. Lua `repeat` 保留字冲突

**现象：** Lua 运行时错误

**原因：** `ctx.repeat` 中 `repeat` 是 Lua 保留关键字，不能用作 table key

**解决：** 改为 `ctx["repeat"]`

---

## 四、学习路线（给后来者的参考）

### 阶段一：PoC（概念验证）

1. 安装 lua-gdextension，让 `LuaState.new()` 能跑
2. 写一个最简单的 Lua 函数（`return {damage=6}`），从 GDScript 调用
3. 验证热重载：改 Lua 文件 → 保存 → 游戏中按 Ctrl+R → 效果变化

### 阶段二：卡牌效果迁移

1. 先迁移简单卡牌（strike/defend/bash）—— 只有数值，无副作用
2. 再迁移门派卡（少林禅意/武当剑意）—— 需要特殊标记 `special` 字段
3. 最后迁移复杂卡（小无相功复制/袖里乾坤选牌）—— 需要桥接层回调函数
4. 每一步都测试：出牌 → 控制台打印 `[Lua] xxx → dmg=X blk=Y`

### 阶段三：战斗系统迁移

1. POWER 效果触发（达摩/八荒/逍遥游）
2. 敌人 AI（意图规划/执行/Boss 三阶段）
3. 回合逻辑（抽牌/回能/格挡重置）

### 阶段四：双人模式

1. 先做同屏双人（共享回合 + 立即结算）
2. 再做联机（主机权威 + 快照同步）
3. 最后处理非战斗节点（奖励/地图选择同步）

### 关键原则

- **先跑通再完善** — 每一步都要能测试
- **Lua 只做计算，GDScript 做执行** — Lua 返回结果 Dictionary，GDScript 应用伤害/格挡/抽牌
- **保留回退路径** — Lua 出错时自动回退 GDScript，不会卡死游戏
- **`if turn_manager:` 判空** — 场景重载时机不确定，所有跨场景引用都要判空
- **RPC 不要发给自己** — 主机直接执行，只有客机走 `rpc_id(1, ...)`

---

## 五、文件清单

```
E:\godotsave\card\
├── lua/                        ← Lua 热更脚本
│   ├── cards.lua               (58张卡牌效果)
│   ├── enemy_ai.lua            (敌人AI)
│   └── battle.lua              (POWER/回合逻辑)
├── autoload/
│   ├── lua_runtime.gd          (桥接层: LuaState管理 + 30+回调 + 热重载)
│   ├── network_manager.gd      (联机RPC)
│   ├── game_state_sync.gd      (快照构建)
│   └── card_pool.gd            (卡牌对象池)
├── scripts/
│   ├── main.gd                 (主场景: Lua接入 + 双人回合 + 联机)
│   ├── turn_manager.gd         (回合状态机: p1_ended/p2_ended)
│   ├── card.gd                 (卡牌: update_preview预览)
│   ├── player.gd               (玩家数据)
│   ├── enemy.gd                (敌人数据)
│   └── ...
├── addons/
│   └── lua-gdextension/        (gilzoide/lua-gdextension v0.8.1)
└── project.godot               (启用lua插件 + 注册LuaRuntime autoload)
```

---

## 六、遗留问题

1. **联机异步** — 快照同步有延迟，客机出牌后手牌更新可能滞后一帧
2. **非战斗节点联机** — 商店/休息/事件节点的联机同步未完整实现
3. **断线重连** — 客机断开后游戏不暂停，无重连机制
4. **卡牌描述热更** — Lua 只热更效果逻辑，卡牌 UI 显示的描述文字仍读 `.tres` 文件
5. **双人模式卡牌预览** — 预览数值只反映当前 `_active_player` 的状态，切换时需手动刷新
