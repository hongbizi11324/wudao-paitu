# 武道牌途（Wudao Paitu）

基于 **Godot 4** 的 Roguelike 卡牌对战游戏：单机闯关 + 双人局域网联机对战原型。

## 技术栈

- 引擎：Godot 4.x（GDScript）
- 脚本扩展：Lua（通过 `lua-gdextension` 集成）
- 联机：Godot 高层网络（RPC / ENet），主机权威（host-authoritative）
- 开发辅助：MCP 服务 + AI 智能体（提示词本地保留，不公开）

## 架构

```
project.godot           工程配置
scripts/                GDScript 游戏逻辑
  card.gd / card_data.gd    卡牌实体与数据
  hand.gd / pile_viewer.gd  手牌与牌堆查看
  turn_manager.gd           回合管理
  player.gd / enemy.gd      角色逻辑
  game_manager.gd           全局流程
  start / select_school / shop / rest / reward / event_screen.gd   各界面
  tests/ tools/             测试与工具
autoload/               全局单例（AutoLoad）
  game_data.gd         全局数据 / 存档
  game_state_sync.gd   状态同步
  card_pool.gd         卡池
  network_manager.gd   网络管理
  lua_runtime.gd       Lua 运行时
  bgm_manager.gd       音乐管理
lua/                   Lua 脚本（玩法逻辑 / 热更新）
  battle.lua cards.lua enemy_ai.lua
addons/lua-gdextension/   Lua 集成插件
mcp-server.js          AI 开发辅助服务端（MCP）
```

## 技术亮点

- **Lua 热更新**：集成 `lua-gdextension`，项目侧实现 `LuaRuntime`、GDScript↔Lua 调用约定、热重载与回退机制，玩法逻辑可用 Lua 热更迭代。
- **对象池**：卡牌、特效等频繁创建销毁的对象走对象池复用，降低实例化开销与 GC 压力。
- **UI 节点复用与优化**：Control 节点按需复用，减少冗余绘制与重建。
- **Lua GC 调优**：针对 Lua 增量 GC 做参数调优，缓解长帧卡顿。
- **双人联机（原型）**：基于主机权威的局域网联机；战斗节点同步已跑通，**非战斗节点同步、断线重连仍在迭代**。
- **AI 辅助开发**：通过 MCP 服务 + AI 智能体提示词，构建开发辅助流程。

> 诚实声明：本项目为个人学习 / 面试作品，核心系统已实现，整体仍在持续完善中。

## 怎么跑

1. 安装 **Godot 4.x**（建议 4.3+）。
2. 克隆仓库，用 Godot 打开 `project.godot`。
3. 在 `Project Settings → Plugins` 中启用 `lua-gdextension` 插件。
4. 按 **F5** 运行；主菜单选择模式进入。
5. 联机：一端「创建房间」（主机），另一端输入主机 IP「加入」。

## 目录约定

- 卡牌数值与配置集中管理，逻辑与表现分离。
- 全局状态走 AutoLoad 单例，避免跨节点强耦合。
