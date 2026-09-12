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
scripts/                GDScript 宿主层
  main.gd               主场景：回合流转 / 出牌调度 / 联机回调 / UI
  card_executor.gd      ★ CardExecutor：出牌结算唯一执行入口（Command Pattern）
  turn_manager.gd       回合状态机（双人共享回合）
  player.gd / enemy.gd  角色与敌人数据（含六英雄被动、意图系统、Boss三阶段）
  hand.gd / card.gd     手牌扇形布局 / 卡牌画面（预览实际数值+折扣费用）
  start / select_school / shop / rest / reward / event_screen.gd  各界面
  tests/                无头测试套件
autoload/               全局单例（AutoLoad）
  game_data.gd          全局数据 / 地图生成 / 存档 / 门派卡池
  game_state_sync.gd    联机快照构建
  network_manager.gd    网络管理（请求→执行→广播 + 非战斗节点同步）
  card_pool.gd          卡牌对象池
  lua_runtime.gd        Lua 桥接层（模块化加载 / 编译缓存 / 热重载）
  bgm_manager.gd        音乐管理
lua/                    Lua 热更层（纯函数：只读 ctx，返回结果清单）
  cards/                按门派拆分：basic / shaolin / wudang / xiaoyao / yunzhi
  battle.lua            POWER 回合触发
addons/lua-gdextension/   Lua 集成插件
mcp-server.js          AI 开发辅助服务端（MCP）
```

## 技术亮点

- **Lua Command Pattern 热更新**：卡牌效果是纯函数——Lua 只读上下文、返回「结果清单」，由 GDScript 侧 `CardExecutor` 原子执行。Lua 报错则清单不返回、状态零污染，无需事务快照/回滚/沙箱；预览与出牌共用同一份逻辑。
- **单一路径多级兜底**：Lua → GDScript 通用结算，卡牌逻辑只有 `lua/cards/` 一份事实来源。
- **对象池**：卡牌节点走对象池复用，回收时重置信号连接与数据。
- **双人联机（原型）**：主机权威 + 全量快照；商店/事件/休息非战斗节点已同步；断线重连仍在迭代。
- **AI 辅助开发**：MCP 服务 + AI 智能体工作流，素材（Boss 背景/立绘）由 AI 生成。
- **无头测试**：`godot --headless res://tests/test_boot.tscn` 跑回合机/数据/结算器/Lua/真实战斗集成五套测试。

> 诚实声明：本项目为个人学习 / 面试作品，核心系统已实现并有测试覆盖，整体仍在持续完善中。

## 怎么跑

1. 安装 **Godot 4.x**（建议 4.3+）。
2. 克隆仓库，用 Godot 打开 `project.godot`。
3. 在 `Project Settings → Plugins` 中启用 `lua-gdextension` 插件。
4. 按 **F5** 运行；主菜单选择模式进入。
5. 联机：一端「创建房间」（主机），另一端输入主机 IP「加入」。
6. 测试：`godot --headless --path . res://tests/test_boot.tscn`（退出码 0=全部通过）。

## 目录约定

- 卡牌数值与配置集中管理，逻辑与表现分离。
- 全局状态走 AutoLoad 单例，避免跨节点强耦合。
