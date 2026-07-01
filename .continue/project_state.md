# 武道牌途 · 项目状态

> 最后更新：2026-06-28
> 用途：AI 助手重启后读取此文件恢复项目上下文

---

## 一、项目概况

- **引擎**：Godot 4.7（Windows，D3D12）
- **项目路径**：`E:\godotsave\card\`
- **分辨率**：1280x720，stretch/mode="canvas_items"
- **启动场景**：`scenes/start_screen.tscn`
- **自动加载**：`autoload/game_data.gd`（类名 GameData）
- **Lua 可执行文件**：`lua55`（位于 `D:\lua-5.5.0_Win64_bin\lua55.exe`）
- **Lua 脚本路径**：`E:\godotsave\card\lua_playground\`

---

## 二、已完成功能

| 模块 | 文件 | 状态 |
|------|------|------|
| 开始画面 | start_screen.gd/tscn | ✅ |
| 战斗主控 | main.gd/tscn | ✅ |
| 卡牌数据 | card_data.gd | ✅ 33张卡 |
| 卡牌画面 | card.gd/tscn | ✅ |
| 手牌管理 | hand.gd | ✅ |
| 玩家 | player.gd | ✅ |
| 敌人 | enemy.gd | ✅ |
| 回合管理 | game_manager.gd | ✅ |
| 地图系统 | node_map.gd/tscn | ✅ |
| 商店 | shop_screen.gd/tscn | ✅ |
| 休息 | rest_screen.gd/tscn | ✅ |
| 奖励 | reward_screen.gd/tscn | ✅ |
| 选门派 | select_school.gd/tscn | ✅ |
| 弃牌堆查看 | pile_viewer.gd/tscn | ✅ |
| 事件 | event_screen.gd/tscn | ✅ |
| 测试卡组 | test_deck.gd/tscn | ✅ |
| 图集工具 | ui_atlas.gd | ✅ |
| 数据验证器(Lua) | lua_playground/05_card_validator.lua | ✅ 旧版 |
| 数据验证器v2(Lua) | lua_playground/06_card_validator_v2.lua | ✅ 新版，读取.tres |

---

## 三、MCP 配置

- **MCP 服务器路径**：`E:\godotsave\card\mcp-server.js`
- **已配置在**：`%USERPROFILE%\.continue\config.yaml`
- **提供工具**（9个）：
  - `project_info` — 项目概况
  - `list_scripts` — 脚本列表
  - `read_script` — 读脚本内容
  - `list_cards` — 卡牌列表
  - `read_card` — 卡牌详情
  - `search_code` — 代码搜索
  - `card_balance_report` — 平衡性分析
  - `scene_structure` — 场景结构
  - `dependency_graph` — 依赖关系
  - `error_database` — 踩坑记录

---

## 四、Lua 学习进度

- ✅ 已完成：卡牌验证器 v2（从 .tres 文件读取数据）
- ✅ 学到的 Lua 知识点：文件 IO、模式匹配（string.match/gmatch）、table 操作、函数式验证、字符串格式化（string.format）
- ⏳ 进行中：边做游戏边学 Lua

---

## 五、下一步计划

- [ ] 卡牌验证器 v3：自动扫描目录 + 输出 JSON
- [ ] Lua 战斗模拟器
- [ ] Lua 地图生成器
- [ ] Godot MCP 桥接改进

---

## 六、常见命令

```powershell
# 跑 Lua 验证器
cd E:\godotsave\card\lua_playground; lua55 06_card_validator_v2.lua

# 测试 MCP 服务器
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | node E:\godotsave\card\mcp-server.js
```

---

## 七、2026-06-28 对话总结

### 当前进度
- ✅ MCP 服务器已配置（在 %USERPROFILE%\.continue\config.yaml）
- ✅ 项目状态文件已建立（本文件）
- ✅ Lua 卡牌验证器 v2 已跑通（06_card_validator_v2.lua）
- ✅ 卡牌验证器直接从 .tres 文件读取数据

### 重要决策：学习方向调整
- **最终目标**：找游戏开发实习
- **学习重心**：C++（底层/性能）+ Lua（脚本） + 算法（LeetCode Hot 100）
- **学习方式**：每学一个算法 → 在游戏项目里找应用场景 → 写 Lua 实现 → 对照 GDScript 看实际用法
- **不是**：堆功能、写业务代码
- **导师模式**：AI 不代劳，而是讲解原理 + 审查代码 + 给学习路线 + 匹配面试知识点

### 算法在项目中的应用映射（待展开）
| 算法 | 游戏场景 |
|------|---------|
| DFS/BFS | 地图路径可达性 |
| 背包问题 | 卡组构建优化（费用限制最大化战力） |
| 并查集 | 卡牌组合效果检测 |
| 滑动窗口 | 手牌管理/效果计时 |
| 状态压缩DP | 最优出牌顺序搜索 |
| 字典树 | 卡牌关键词匹配 |

### 下次开始
- [ ] 问用户 LeetCode Hot 100 刷了多少
- [ ] 问用户 C++ 学到什么程度
- [ ] 根据用户水平匹配第一个游戏+算法练习
