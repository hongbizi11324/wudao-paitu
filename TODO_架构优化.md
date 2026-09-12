# 武道牌途 — 架构优化 TODO

> 基于面试复盘整理，按优先级排序。每项包含：问题描述、当前方案、优化方案、改动范围。

---

## 优先级 1：Lua Command Pattern 重构（消除事务快照）

### 问题
当前 Lua 通过 `gd_*` 回调边算边改状态，报错时产生"半截崩溃"，需要事务快照兜底。每张卡出牌拍一次快照（20+ 字段），开销大且有视觉残留风险。

### 当前方案
```
Lua 执行 → 边算边调 gd_* 改状态 → 报错 → _rollback_battle_state 回滚 → return false → GDScript match 接管
```

### 优化方案
Lua 不直接调 `gd_*` 回调，只算并返回命令清单（Dictionary{commands = [...]}）。GDScript 拿到清单后原子执行。Lua 报错时清单没返回，GDScript 什么都不执行，状态天然干净，不需要快照也不需要回滚。

### 改动范围
- `lua/cards.lua`：58 张卡函数改为返回命令清单
- `lua_runtime.gd`：`_setup_godot_bindings()` 里的 30+ 个 `gd_*` 回调逐步废弃
- `main.gd`：`_try_execute_card_via_lua()` 改为解析命令清单并执行
- `main.gd`：`_snapshot_battle_state()` / `_rollback_battle_state()` 可删除

---

## 优先级 2：统一状态打包接口（单一数据源）

### 问题
当前有三处各自打包游戏状态：`build_snapshot()`（网络同步）、`_try_execute_card_via_lua` 里的 ctx（Lua 调用）、`_snapshot_battle_state()`（事务回滚）。三处代码重复，字段可能不一致。

### 当前方案
三处各自写一遍打包逻辑：
- `game_state_sync.gd build_snapshot()` — 25 字段
- `main.gd _try_execute_card_via_lua` 内联 ctx — 30 字段
- `main.gd _snapshot_battle_state()` — 20 字段

### 优化方案
统一成一个 `build_game_state()` 函数。网络同步、Lua ctx、事务回滚三处复用。保证字段一致。

### 改动范围
- `main.gd`：新增 `build_game_state()` 统一函数
- `game_state_sync.gd`：`build_snapshot()` 改为调用 `main.build_game_state()`
- `main.gd`：`_snapshot_battle_state()` 改为调用 `build_game_state()`
- `main.gd`：`_try_execute_card_via_lua` 里的 ctx 改为调用 `build_game_state()`

---

## 优先级 3：合并 pre_snap（出牌前只拍一次）

### 问题
当前出牌前拍两次：一次给事务回滚（`_snapshot_battle_state`），一次给 Lua 当 ctx（内联构建）。数据完全一样，白拷贝一次。

### 当前方案
```
var snap = _snapshot_battle_state()    # 拍照1：事务
var ctx = { player_hp: player.hp, ... }  # 拍照2：Lua ctx（数据同上）
```

### 优化方案
拍一次 `pre_snap`，同时给 Lua 当 ctx 和事务回滚用。如果 Lua 不改状态（Command Pattern 实现后），连回滚都不需要。

### 改动范围
- `main.gd`：`_try_execute_card_via_lua()` 合并拍照逻辑
- 注意：如果 Lua 侧仍直接改状态，传给 Lua 的 ctx 需要 `duplicate(true)` 防止污染 pre_snap

---

## 优先级 4：网络增量快照（Delta Snapshot）

### 问题
当前每次出牌后推全量快照（25 字段，约 300 字节）。出 strike 只改了敌人 HP，其他 24 个字段白传。

### 当前方案
```gdscript
rpc("sync_game_state", build_snapshot(main))  # 全量 25 字段
```

### 优化方案
出牌后对比 `pre_snap`，只推变化的字段。用位掩码（dirty mask）标记脏字段。

### 改动范围
- `main.gd`：新增 `_build_delta(pre_snap)` 函数
- `main.gd`：`push_snapshot()` 改为推 delta
- `main.gd`：`apply_snapshot()` 改为支持增量合并（有字段就更新，没字段就跳过）

---

## 优先级 5：LuaFunction 编译缓存

### 问题
当前每次出牌都 `load_string` 重新编译 Lua 代码，产生临时 LuaFunction 闭包对象，增加 GC 压力。

### 当前方案
```gdscript
var lua_func = _lua.load_string("return CardEffects['strike'](_G._call_ctx)")
var result = lua_func.invoke()
```

### 优化方案
预编译所有卡牌函数，缓存到 Dictionary。热重载时清缓存。

### 改动范围
- `lua_runtime.gd`：新增 `_func_cache: Dictionary`
- `lua_runtime.gd`：`execute_card()` 改为先查缓存再编译
- `lua_runtime.gd`：`reload()` 末尾加 `_func_cache.clear()`

---

## 优先级 6：Lua 模块化拆分（require + 清缓存）

### 问题
200+ 张卡全在一个 `cards.lua` 文件里（2000+ 行），维护困难。

### 当前方案
单文件 `cards.lua`，`do_file` 覆盖全局表。

### 优化方案
按门派拆分子文件，主文件用 `require` 聚合。热重载时清 `package.loaded` 缓存再重新 require。

### 改动范围
- `lua/cards/basic.lua`、`lua/cards/shaolin.lua`、`lua/cards/wudang.lua`、`lua/cards/xiaoyao.lua`
- `lua/cards.lua`：改为 `require` 聚合
- `lua_runtime.gd`：`reload()` 末尾加 `package.loaded[path] = nil` 清缓存

---

## 优先级 7：Lua 回调参数校验

### 问题
200+ 张卡多人协作时，必然有人传错参数给 `gd_*` 回调（类型错误、空值等）。当前无校验。

### 当前方案
```gdscript
_lua.globals["gd_player_heal"] = func(amount):
    host.player.heal(amount)  # ← 如果 amount 是 nil 直接崩
```

### 优化方案
桥接层加防御性校验，非法参数 push_error 不执行。

### 改动范围
- `lua_runtime.gd`：所有 `gd_*` 回调加 `is_instance_valid` + 类型校验
