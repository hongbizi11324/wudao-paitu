# 武道牌途 — 架构优化 TODO

> 基于面试复盘整理，按优先级排序。每项包含：问题描述、当前方案、优化方案、改动范围。
> ✅ 2026-09-12 大修完成状态标注如下。

---

## 优先级 1：Lua Command Pattern 重构（消除事务快照） ✅ 已完成

**已落地**：Lua 只读 ctx、返回结果清单；GDScript 侧 `CardExecutor.apply()` 原子执行。
`_snapshot_battle_state` / `_rollback_battle_state` / 全部 gd_* 写回调 / 沙箱守卫层 已删除。
`lua/cards/` 按门派拆为 basic/shaolin/wudang/xiaoyao/yunzhi 5 模块 + battle.lua（POWER 触发同为清单）。

## 优先级 2：统一状态打包接口（单一数据源） ✅ 已完成

**已落地**：`main._build_state_ctx(pid)` 是唯一的状态打包入口，出牌执行与卡牌预览共用。
网络快照（GameStateSync.build_snapshot）保持独立——它面向"客机渲染"，与"出牌上下文"
是两个关注点，强行合并反而耦合。

## 优先级 3：合并 pre_snap（出牌前只拍一次） ✅ 已完成（被 P1 取代）

Command Pattern 落地后 Lua 无副作用，快照与 ctx 合并问题不复存在。

## 优先级 4：网络增量快照（Delta Snapshot） ⏸️ 决定不做

全量快照约 30 字段、几百字节，2 人局域网回合制下增量化收益 < 引入字段缺失/时序
导致的失同步风险。留待真有带宽/性能压力时再做（若做：apply_snapshot 已全面
改用 .get() 安全读取，具备增量合并的前置条件）。

## 优先级 5：LuaFunction 编译缓存 ✅ 已完成

`lua_runtime._func_cache[card_id]`，热重载时清空。

## 优先级 6：Lua 模块化拆分 ✅ 已完成

按门派 5 模块，`LuaRuntime.CARD_MODULES` 定义加载顺序，`reload()` 按序重放全部模块。
未用 require（lua-gdextension 的 package.path 行为不可控），do_file 顺序加载最确定。

## 优先级 7：Lua 回调参数校验 ✅ 已完成（被 P1 取代）

Command Pattern 后 Lua 不再有任何回调，无需校验。

---

## 新增遗留项（2026-09-12）

1. **断线重连的 UI 提示**：主机有遮罩提示，客机重连依赖 start_screen 流程，无独立重连按钮
2. **双人模式 P2 境界**：修为奖励只进 P1 的境界线（内力上限对双方生效，因共享 GameData）
3. **卡牌描述热更**：描述文字仍读 .tres，Lua 只热更效果逻辑
4. **跨平台**：lua-gdextension 目前只带 Windows x86_64 DLL

