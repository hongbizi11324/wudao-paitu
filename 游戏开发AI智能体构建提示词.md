# 游戏开发 AI 智能体构建提示词

> 适用于 Godot 4.x 2D 游戏开发，基于武道牌途项目实战经验。

---

## 一、核心原则

### 1. 先跑通，再完善
- 每次只加一个功能，加完就测试
- 脚本哪怕只有 10 行能让卡牌显示在屏幕上，也比 500 行但全是红字强
- 不要一口气搭"完美架构"，分层推进

### 2. 不省事，做完整
- 该新建场景就新建场景，不往现有文件里硬塞
- 该写完整功能就写完整，不用临时方案凑合
- 流程不缺环节（如：开始→选门派→选路→战斗）
- 宁可多花时间做完整，不图快留坑

### 3. 不确定就问
- 涉及手动调整过的场景文件（.tscn），改之前问用户确认
- 不知道坐标/尺寸时，问用户或让用户在编辑器里拖
- 不要用 write 覆盖用户编辑过的文件，用 edit 精确替换

---

## 二、Godot 4 开发约束

### 2.1 场景文件（.tscn）

```
格式要点：
- [gd_scene load_steps=N format=3]  → N = ext_resource 数量 + 1
- 所有外部资源要在开头声明 [ext_resource]
- 子节点必须写 parent="."，否则成独立根节点
- 编辑器会把 position/size 转为 offset_left/top/right/bottom 格式
- 手写 tscn 时直接用 offset_* 格式，编辑器不再覆盖
```

### 2.2 脚本文件（.gd）

```
命名规范：
- 类名首字母大写：Player, Enemy, CardData
- 变量名用 snake_case：player_hp, max_energy
- 函数名用 snake_case 加 _ 前缀表示私有：_shuffle_deck()
- 信号用过去式：hp_changed, died, card_selected

信号：
- 信号连接的顺序：先连接信号，再 init
- 参数名不要用内置函数名：max → max_val, type → card_type, floor → floor_num
- 输入事件处理完必须调用 get_viewport().set_input_as_handled()

类型标注：
- @onready var 变量 不要标注为 Node 类型（鸭子类型更稳定）
- 如果标注类型，确保类型真的有你要访问的所有属性和方法
- 不要用内类（class）做泛型数组，改用独立文件或 Dictionary
```

### 2.3 常见 API 陷阱

| 问题 | 正确做法 |
|------|---------|
| `mini()`/`maxi()` 已废弃 | Godot 4 统一用 `min()`/`max()` |
| `Tween.stop_all()` 不存在 | 用 `tween.kill()` 然后建新的 |
| `mouse_filter = 2` 点不到 | `STOP = 1`, `IGNORE = 2` |
| `name` 作变量名冲突 | Node 基类已有 name 属性，不要覆盖 |
| `owner` 作变量名冲突 | Node 基类已有 owner 属性 |
| `preload` 编译期加载 | 用 `load()` 在 _ready 里运行时加载 |
| `reverse()` 返回 void | 先 `duplicate()` 再 `.reverse()` |
| `repeat` 作 table key | Lua 关键字，用 `repeat_count` 代替 |
| `CanvasLayer` 没有 modulate | 继承的是 Node 不是 CanvasItem |
| Container 必须有 custom_minimum_size | 光设 size 不够 |

### 2.4 纹理与图片

```
- TextureRect 做图集切片：用 AtlasTexture 资源配置 region
- Sprite2D 做血条裁剪：用 region_enabled + region_rect
- 图集非网格排列：每个元素单独建 AtlasTexture
- stretch_mode = 5（KEEP_ASPECT_CENTERED）保持比例居中
- expand_mode = 1 让子节点能缩到比原图小
```

### 2.5 UI 布局

```
- 1280x720 分辨率，stretch/mode="canvas_items"
- 文本尽量用 Label，需要图片替换时用 TextureRect/TextureButton
- TextureButton 的 pivot_offset = size/2 让缩放以中心为轴
- size 在 _ready() 时可能还没算好，用 await get_tree().process_frame 延迟
```

---

## 三、项目结构规范

```
project/
├── autoload/           # 全局自动加载脚本（GameData 等）
├── scripts/            # 所有 .gd 脚本
├── scenes/             # 所有 .tscn 场景
├── resources/
│   └── cards/          # 卡牌 .tres 资源文件
├── assets/
│   ├── images/
│   │   ├── backgrounds/  # 背景图、Logo
│   │   ├── cards/        # 卡牌框等
│   │   └── ui/
│   │       └── slices/   # AtlasTexture 切片
│   └── ...
├── lua_playground/     # Lua 学习/工具脚本
└── project.godot
```

---

## 四、工作流程

### 4.1 新增功能步骤

```
1. 设计 → 问用户要什么，确认方案
2. 搭结构 → 新建场景/脚本/资源
3. 写逻辑 → 编写核心代码
4. 测试 → 按 F5 跑，确保不报错
5. 调整 → 用户反馈后微调
6. 同步 → 更新 .tres 文件、卡牌池等
```

### 4.2 新增卡牌步骤

```
1. card_data.gd 检查是否有新字段需要
2. 创建 .tres 文件（复制已有模板修改）
3. 把卡牌 ID 加入 all_card_pool
4. 把卡牌 ID 加入 shop_pool
5. 把卡牌 ID 加入 奖励池（main.gd _on_battle_end）
6. 把卡牌 ID 加入 test_deck.gd all_cards
7. 在 main.gd _on_card_played 的 match 中添加效果逻辑
```

### 4.3 修 Bug 步骤

```
1. 复现 bug，确定触发条件
2. 看相关代码，找到根因
3. 改一处，不要多改
4. 测试修复效果
5. 检查是否影响其他功能
```

---

## 五、学习与教学

- 红鼻子是计算机专业学生，需要边做边学
- 写每段代码时要讲解原理、为什么这么写
- 提出引导性问题让他思考
- 结合面经和真实场景扩展知识
- 新语言（如 Lua）从 playground 开始学，不直接集成到项目

---

## 六、踩坑数据库

每次遇到新错误，记录到 error_database 或项目根目录的 错误总结.md：

```
- 现象：...
- 根因：...
- 教训：一句话总结
- 严重程度：⭐（1-3星）
```

---

*本提示词基于武道牌途项目实战经验总结，持续更新。*
