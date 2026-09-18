extends Node2D

# ====================================================================
# 武道牌途 · 主场景控制器
#
# 架构（Command Pattern，见 scripts/card_executor.gd）：
#   出牌 = GDScript 算费用 → Lua 纯函数算「结果清单」→ CardExecutor 原子执行
#   Lua 不可用/无实现 → _fallback_result 通用结算兜底
#   旧的 700 行 match 分支 / 事务快照回滚 / EffectResource 效果系统已全部移除
#
# 回合追踪按玩家分开（_track[1] / _track[2]），修复共享回合下
# P1/P2 互相污染计数的问题。
# ====================================================================

var draw_pile = []        # 牌库（P1）
var discard_pile = []     # 弃牌堆（P1）
var draw_pile_p2 = []     # 牌库（P2，双人模式）
var discard_pile_p2 = []  # 弃牌堆（P2，双人模式）
var game_over = false

var turn_manager: TurnManager  # 回合状态机
var card_scene: PackedScene    # 卡牌场景（运行时 load，避免编译期 preload 连坐失败）

@onready var hand1 = $Hand1
@onready var hand2 = $Hand2
@onready var player1 = $Player1
@onready var player2 = $Player2
@onready var enemy = $Enemy
@onready var gm = $GameManager

@onready var p1_hp_label = $Player1HpLabel
@onready var p2_hp_label = $Player2HpLabel
@onready var p1_energy_label = $EnergyLabel
@onready var p1_block_label = $BlockLabel
@onready var enemy_hp_label = $EnemyHPLabel
@onready var enemy_block_label = $EnemyBlockLabel
@onready var enemy_intent_label = $EnemyIntentLabel
@onready var floor_label = $FloorLabel

@onready var end_turn_btn = $EndTurnBtn
@onready var turn_label = $TurnLabel
@onready var deck_label = $DeckLabel
@onready var discard_label = $DiscardLabel
@onready var pile_viewer = $PileViewer
@onready var reward_screen = $RewardScreen
@onready var shop_screen = $ShopScreen
@onready var node_map = $NodeMap
@onready var rest_screen = $RestScreen
@onready var event_screen = $EventScreen
@onready var card_picker = $CardPicker
@onready var retry_btn = $RetryBtn
@onready var menu_btn = $MenuBtn  # 战斗中常显，点击回主菜单
@onready var p1_portrait = $Player1Portrait
@onready var p2_portrait = $Player2Portrait
@onready var chan_icon = $ChanIcon
@onready var jianyi_icon = $JianyiIcon
@onready var p1_name_label = $Player1NameLabel
@onready var p2_name_label = $Player2NameLabel
@onready var enemy_portrait = $EnemyPortrait

var _active_player: int = 1  # 1=玩家1, 2=玩家2（仅用于UI切换）

# 当前活跃玩家的别名（方便现有代码直接引用）
var hand: Node2D
var player: Node
var player_portrait: TextureRect
var player_name_label: Label
var hp_label: Label
var energy_label: Label
var block_label: Label

# ---- 回合追踪（按玩家分开，共享回合下互不污染） ----
# 字段：skill_played / energy_used / cards_played / attacks_played /
#       next_two_discount / last_type / last_id
var _track: Dictionary = {1: {}, 2: {}}

# ---- 非战斗节点完成守卫（联机下防止双方各推一次结果） ----
var _node_result_done: bool = false
# ---- 联机奖励流程（双端各自选完再开地图） ----
var _p1_reward_done: bool = false
var _p2_reward_done: bool = false
# ---- 同屏双人奖励流程（P1 选完轮到 P2） ----
var _reward_picker: int = 1

var _scene_loaded: bool = false
var _waiting_mask: ColorRect = null
var fx: BattleFX  # 战斗表现层（飘字/受击/横幅）

# 战斗统计（胜利战报用）
var _battle_stats: Dictionary = {"turns": 0, "cards": 0, "damage": 0, "max_hit": 0, "block": 0}

# 首次战斗教学提示（每局只弹一次）
var _tutorial_shown: bool = false

# ==============================
# 模式查询 / 玩家上下文
# ==============================

## 当前是否双人模式。唯一数据源 GameData.is_dual_mode。
func _is_dual() -> bool:
	if turn_manager and is_instance_valid(turn_manager):
		return turn_manager.is_dual()
	return GameData.is_dual_mode


## 联机下每个端固定操作自己的玩家：主机恒 P1，客机恒 P2。
func _resolve_active_player(p: int) -> int:
	if NetworkManager.is_lan:
		return 1 if NetworkManager.is_host else 2
	return p


## 只切换"当前玩家别名"的指向，不碰 UI 可见性。
func _apply_aliases(p: int) -> void:
	if p == 2:
		hand = hand2
		player = player2
		player_portrait = p2_portrait
		player_name_label = p2_name_label
		hp_label = p2_hp_label
	else:
		hand = hand1
		player = player1
		player_portrait = p1_portrait
		player_name_label = p1_name_label
		hp_label = p1_hp_label
	# 场景里只有一套 EnergyLabel / BlockLabel，由 _update_ui 按 player 实时刷新
	energy_label = p1_energy_label
	block_label = p1_block_label


## 在指定玩家的上下文里执行一段逻辑，结束后自动恢复别名。
func _with_player(pid: int, fn: Callable) -> void:
	var saved_active := _active_player
	_active_player = pid
	_apply_aliases(pid)
	fn.call()
	_active_player = saved_active
	_apply_aliases(saved_active)


func _player_node(pid: int) -> Player:
	return player2 if pid == 2 else player1


func _hand_node(pid: int) -> Hand:
	return hand2 if pid == 2 else hand1


func _draw_pile_of(pid: int) -> Array:
	return draw_pile_p2 if pid == 2 else draw_pile


func _discard_pile_of(pid: int) -> Array:
	return discard_pile_p2 if pid == 2 else discard_pile


# ---- 战斗场景资源 ----
const BIOME_BG = {
	GameData.Biome.FOREST: preload("res://assets/main_screen/竹林.tres"),
	GameData.Biome.VILLAGE: preload("res://assets/main_screen/村庄.tres"),
	GameData.Biome.GOV_OFFICE: preload("res://assets/main_screen/官府.tres"),
	GameData.Biome.SECT: preload("res://assets/main_screen/门派.tres"),
}

const BIOME_ENEMIES = {
	GameData.Biome.FOREST: {
		"normal": ["山匪", "强盗"],
		"elite": ["老虎", "熊"],
	},
	GameData.Biome.VILLAGE: {
		"normal": ["流民", "顽童"],
		"elite": ["官兵", "门派弟子"],
	},
	GameData.Biome.GOV_OFFICE: {
		"normal": ["官兵", "门派弟子"],
		"elite": ["门派弟子·女"],
	},
	GameData.Biome.SECT: {
		"normal": ["门派弟子", "门派弟子·女"],
		"elite": ["门派长老"],
	},
}
# Boss 战使用专属 boss_bg.png / boss_lord.png（每6层的镇关Boss）

@onready var _battle_bg: TextureRect = $BattleBg

# 敌人立绘基础姿态（死亡动画后恢复用）
var _enemy_portrait_base := {"pos": Vector2.ZERO, "rot": 0.0}


# ==============================
# 生命周期
# ==============================

func _ready():
	card_scene = load("res://scenes/card.tscn")

	# 战斗表现层（特效）
	fx = BattleFX.new()
	fx.name = "BattleFX"
	add_child(fx)

	# 记录敌人立绘基础姿态（死亡动画后恢复用）
	_enemy_portrait_base["pos"] = enemy_portrait.position
	_enemy_portrait_base["rot"] = enemy_portrait.rotation

	# 先设置别名，确保信号触发时不会 null
	hand = hand1
	player = player1
	hp_label = p1_hp_label
	energy_label = p1_energy_label
	block_label = p1_block_label
	player_portrait = p1_portrait
	player_name_label = p1_name_label

	# 连接信号 — 双方都连
	hand1.card_selected.connect(_on_card_played)
	hand2.card_selected.connect(_on_card_played)
	hand1.hand_full.connect(func(): _on_hand_full(1))
	hand2.hand_full.connect(func(): _on_hand_full(2))
	player1.energy_changed.connect(_on_energy_changed)
	player2.energy_changed.connect(_on_energy_changed)
	player1.hp_changed.connect(_on_hp_changed)
	player2.hp_changed.connect(_on_hp_changed)
	player1.block_changed.connect(_on_block_changed)
	player2.block_changed.connect(_on_block_changed)
	enemy.hp_changed.connect(_on_enemy_hp_changed)
	player1.died.connect(_on_player_died)
	player2.died.connect(_on_player_died)
	enemy.died.connect(_on_enemy_died_by_signal)
	enemy.block_changed.connect(_on_enemy_block_changed)
	enemy.intent_changed.connect(_on_enemy_intent_changed)
	reward_screen.card_chosen.connect(_on_reward_chosen)
	reward_screen.skipped.connect(_on_reward_skipped)
	shop_screen.continue_requested.connect(_on_shop_done)
	shop_screen.buy_requested.connect(_on_shop_buy_requested)
	shop_screen.delete_requested.connect(_on_shop_delete_requested)
	shop_screen.refresh_requested.connect(_on_shop_refresh_requested)
	shop_screen.refreshed.connect(_on_shop_refreshed)
	node_map.node_selected.connect(_on_node_selected)
	rest_screen.closed.connect(_on_rest_closed)
	rest_screen.upgrade_requested.connect(_open_upgrade_picker)
	event_screen.closed.connect(_on_event_closed)
	card_picker.card_picked.connect(_on_upgrade_picked)
	card_picker.cancelled.connect(_on_upgrade_cancelled)

	# 断线/重连信号
	if not NetworkManager.player_disconnected.is_connected(_on_player_disconnected):
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
	if not NetworkManager.player_reconnected.is_connected(_on_player_reconnected):
		NetworkManager.player_reconnected.connect(_on_player_reconnected)

	# 局域网：用共享种子保证地图/牌序一致
	if NetworkManager.is_lan:
		seed(NetworkManager.shared_seed)

	# 局域网客机：不执行任何逻辑，等主机推快照
	if NetworkManager.is_lan and not NetworkManager.is_host:
		if GameData.loading_save:
			GameData.loading_save = false
			_show_waiting_mask("重连成功，同步状态...")
		else:
			_show_waiting_mask("等待主机同步状态...")
		_scene_loaded = true
		return

	if GameData.loading_save:
		GameData.loading_save = false
		_prepare_battle_ui()
		node_map.open()
		_scene_loaded = true
		return

	# 新游戏：先选路再开打
	if GameData.current_floor == 1 and not GameData.map_active:
		GameData.generate_new_act()
		_prepare_battle_ui()
		node_map.open()
		# LAN 主机：通知客机也打开地图
		if NetworkManager.is_lan and NetworkManager.is_host:
			NetworkManager.rpc("sync_show_map")
		_scene_loaded = true
		return

	# 地图已激活/楼层>1 的续战场景：直接开打
	# （必须走 _reset_battle_state 初始化牌库，否则空牌库开局）
	_reset_battle_state()

	# 创建回合状态机（客机不启动，完全听主机指挥）
	turn_manager = TurnManager.new()
	turn_manager.name = "TurnManager"
	add_child(turn_manager)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.turn_changed.connect(_on_turn_started)
	turn_manager.start_battle()

	_scene_loaded = true
	_update_ui()


## 战斗 UI 基础初始化（玩家节点 / 头像 / 可见性 / 退出按钮）
func _prepare_battle_ui():
	player1.init()
	player2.init(true)

	# 单人模式：隐藏玩家2
	if not _is_dual():
		hand2.visible = false
		p2_portrait.visible = false
		p2_name_label.visible = false
		p2_hp_label.visible = false
		hand1.visible = true

	# 加载头像
	if GameData.selected_character != "":
		p1_portrait.texture = load("res://assets/images/player/%s.tres" % GameData.selected_character)
		p1_name_label.text = GameData.character_data[GameData.selected_character]["name"]
	if _is_dual() and GameData.selected_character_2 != "":
		p2_portrait.texture = load("res://assets/images/player/%s.tres" % GameData.selected_character_2)
		p2_name_label.text = GameData.character_data[GameData.selected_character_2]["name"]
	else:
		p2_name_label.text = "玩家2"

	# 退出按钮（角落常显）
	menu_btn.text = "✕"
	menu_btn.size = Vector2(36, 36)
	menu_btn.position = Vector2(10, 10)
	menu_btn.visible = true

	_update_ui()


# ==============================
# 回合状态机回调
# ==============================

func _on_turn_started(turn: int):
	_apply_turn(turn)
	# 战斗统计：玩家回合计数
	if turn == TurnManager.Turn.PLAYER1:
		_battle_stats["turns"] = int(_battle_stats.get("turns", 0)) + 1
	# 表现层：敌人回合横幅（玩家回合不弹，避免噪音）
	if fx and turn == TurnManager.Turn.ENEMY:
		fx.show_banner("敌人回合", "小心对方的意图", Color(0.95, 0.4, 0.35))
	# 局域网：主机同步回合给客机
	if NetworkManager.is_lan and NetworkManager.is_host:
		NetworkManager.push_snapshot()


func _apply_turn(turn: int):
	match turn:
		TurnManager.Turn.PLAYER1:
			# 共享回合：双方各自抽牌/回能/触发 POWER（存活的才处理）
			if not _is_dual():
				_start_player_turn(1)
			else:
				_start_player_turn(1)
				_start_player_turn(2)
			end_turn_btn.text = "结束回合"
			end_turn_btn.disabled = false
			_switch_to(_active_player)
			_update_deck_ui()
			_refresh_card_previews()

		TurnManager.Turn.ENEMY:
			end_turn_btn.disabled = true
			end_turn_btn.text = "敌人回合..."
			_update_turn_label("敌人回合")
			# 延迟一帧执行，让 UI 先刷新
			_execute_enemy_turn.call_deferred()


## 单个玩家的回合开始处理：回能 → 重置追踪 → 抽牌 → POWER 触发
func _start_player_turn(pid: int):
	var p := _player_node(pid)
	var h := _hand_node(pid)

	# 已阵亡的玩家：自动标记结束，不抽牌（合作模式另一人继续）
	if p.hp <= 0:
		if turn_manager and _is_dual():
			turn_manager.mark_player_ended(pid)
		return

	_with_player(pid, func():
		p.refill_energy()
		_reset_turn_track(pid)

		var draw_count := CardExecutor.DRAW_PER_TURN
		# 夜啸被动【血影】：HP<50% 时回合开始多抽1张
		if p.character_id == "yexiao" and p.hp < p.max_hp * 0.5:
			draw_count += 1
			print("【被动·血影】HP<50%% → 多抽1张牌")

		var ex := _make_executor(pid)
		ex.draw_cards(draw_count)
		_trigger_power_effects(p, pid)
		h.apply_limit_mod(p.hand_limit_mod)
	)


func _reset_turn_track(pid: int) -> void:
	_track[pid] = {
		"skill_played": 0,
		"energy_used": 0,
		"cards_played": 0,
		"attacks_played": 0,
		"next_two_discount": 0,
		"last_type": -1,
		"last_id": "",
	}


func _execute_enemy_turn():
	# 双人模式：敌人从存活玩家中随机选目标（宿主权威 RNG）
	var players: Array = [player1]
	if _is_dual():
		players = [player1, player2]

	# 记录双方状态，用于表现层判定"谁挨打了"
	var p1_hp_before: int = player1.hp
	var p2_hp_before: int = player2.hp
	var p1_blk_before: int = player1.block
	var p2_blk_before: int = player2.block

	var alive = gm.execute_enemy_turn(players, enemy)
	if game_over:
		return

	# 表现层：敌人攻击反馈
	if fx:
		if enemy.intent_type == Enemy.IntentType.ATTACK:
			fx.shake(enemy_portrait, 5.0, 0.22)
			if player1.hp < p1_hp_before:
				_play_player_hit_fx(1, p1_hp_before - player1.hp)
			elif player2.hp < p2_hp_before:
				_play_player_hit_fx(2, p2_hp_before - player2.hp)
			elif player1.block < p1_blk_before:
				fx.float_text(_player_fx_pos(1), "格挡", BattleFX.COLOR_BLOCK)
			elif player2.block < p2_blk_before:
				fx.float_text(_player_fx_pos(2), "格挡", BattleFX.COLOR_BLOCK)

	if alive:
		turn_manager.end_enemy_turn()


## 玩家受击表现：红字 + 立绘闪红 + 屏幕闪红
## 玩家受击表现：红字 + 立绘闪红 + 屏幕闪红
func _play_player_hit_fx(pid: int, dmg: int) -> void:
	if fx == null:
		return
	var pt: TextureRect = p2_portrait if pid == 2 else p1_portrait
	fx.float_text(_player_fx_pos(pid), "-%d" % dmg, BattleFX.COLOR_DAMAGE, 26)
	fx.flash(pt, Color(1.5, 0.7, 0.7, 1.0))
	fx.shake(pt, 6.0, 0.25)
	fx.screen_flash(Color(1, 0, 0), 0.18, 0.3)
	BgmManager.play_sfx("hurt")


## 手牌已满提示
func _on_hand_full(pid: int) -> void:
	if fx == null:
		return
	var h := _hand_node(pid)
	fx.float_text(h.global_position + Vector2(0, -20), "手牌已满", BattleFX.COLOR_ARMOR_BREAK, 18)


# ==============================
# 玩家切换 / 可见性
# ==============================

func _switch_to(p: int):
	p = _resolve_active_player(p)
	_active_player = p
	_apply_aliases(p)
	_update_player_visibility(p)
	_update_ui()
	_update_active_indicator()


func _update_player_visibility(p: int) -> void:
	if NetworkManager.is_lan:
		# 联机：每个端只看得到自己的手牌
		hand1.visible = NetworkManager.is_host
		hand2.visible = not NetworkManager.is_host
		_hide_waiting_mask()
	elif _is_dual():
		# 双人同屏：只显示当前激活玩家的手牌
		hand1.visible = (p == 1)
		hand2.visible = (p == 2)
	else:
		hand1.visible = true
		hand2.visible = false


func _on_p1_portrait_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if NetworkManager.is_lan:
			return
		if _is_dual() and turn_manager and not turn_manager.has_player_ended(1):
			_switch_to(1)


func _on_p2_portrait_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if NetworkManager.is_lan:
			return
		if _is_dual() and turn_manager and not turn_manager.has_player_ended(2):
			_switch_to(2)


func _unhandled_input(event):
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_dual() and not NetworkManager.is_lan:
			hand1.deselect()
			hand2.deselect()
		else:
			hand.deselect()


# ==============================
# 出牌（Command Pattern 单一路径）
# ==============================

func _on_card_played(card):
	if game_over:
		return

	# 判断牌属于哪个玩家
	var card_owner = 0
	if card.get_parent() == hand1:
		card_owner = 1
	elif card.get_parent() == hand2:
		card_owner = 2
	else:
		return

	# 双人同屏：只能出当前激活玩家的牌，已结束回合的不能出
	if _is_dual() and not NetworkManager.is_lan:
		if card_owner != _active_player:
			return
		if turn_manager and turn_manager.has_player_ended(card_owner):
			return

	# LAN 模式：主机只能出P1，客机只能出P2
	if NetworkManager.is_lan:
		if NetworkManager.is_host and card_owner != 1:
			return
		if not NetworkManager.is_host and card_owner != 2:
			return
		if turn_manager and turn_manager.has_player_ended(card_owner):
			return

	# 切换别名到出牌方
	_switch_to(card_owner)

	# LAN 客机：出牌请求发给主机执行
	if NetworkManager.is_lan and not NetworkManager.is_host:
		NetworkManager.rpc_id(1, "request_play", card.card_data.card_id, 2)
		return

	# 主机 / 单机：直接执行
	_execute_card(card)

	# 主机执行完后推快照
	if NetworkManager.is_lan and NetworkManager.is_host:
		NetworkManager.push_snapshot()


## 费用计算的唯一入口。返回 {cost, used_next, used_two}。
## 折扣只在出牌成功后才消耗（修复：出牌失败吞折扣的旧 bug）。
func _calc_card_cost(data: CardData, pid: int) -> Dictionary:
	var p := _player_node(pid)
	var t: Dictionary = _track[pid]
	var cost := data.cost

	# 逍遥游 POWER：攻击/内力牌永久 -1
	if p.attack_discounted and (data.card_type == CardData.CardType.ATTACK or data.card_type == CardData.CardType.INNER):
		cost = max(0, cost - 1)

	# 凌波微步：下一张牌 -N
	var used_next := 0
	if p.next_card_discount > 0:
		used_next = min(cost, p.next_card_discount)
		cost -= used_next

	# 虚实相生：下 N 张牌 -2/-3
	var used_two := 0
	var two_left := int(t.get("next_two_discount", 0))
	if two_left > 0:
		used_two = min(cost, two_left)
		cost -= used_two

	# 云芷被动【奇策】：每回合第一次出牌费用-1
	if p.character_id == "yunzhi" and int(t.get("cards_played", 0)) == 0 and cost > 0:
		cost = max(0, cost - 1)

	return {"cost": cost, "used_next": used_next, "used_two": used_two}


## 打出一张卡：算费用 → 算清单 → 原子执行
func _execute_card(card):
	var data: CardData = card.card_data
	var pid := _active_player
	var t: Dictionary = _track[pid]

	# ---- 费用 ----
	var calc := _calc_card_cost(data, pid)
	if not player.spend_energy(calc.cost):
		# 内力不足：不消耗任何折扣，取消选中 + 抖动反馈
		hand.deselect()
		if fx:
			fx.shake(card, 4.0, 0.2)
		BgmManager.play_sfx("defeat")
		print("[费用不足] %s 需要 %d 内力" % [data.card_name, calc.cost])
		return

	# ---- 成功：消耗折扣 + 更新追踪 ----
	player.next_card_discount = 0
	t["next_two_discount"] = int(t.get("next_two_discount", 0)) - calc.used_two
	t["energy_used"] = int(t.get("energy_used", 0)) + calc.cost
	t["last_type"] = data.card_type
	t["last_id"] = data.card_id
	t["cards_played"] = int(t.get("cards_played", 0)) + 1
	if data.card_type == CardData.CardType.ATTACK:
		t["attacks_played"] = int(t.get("attacks_played", 0)) + 1
	if data.card_type == CardData.CardType.SKILL:
		t["skill_played"] = int(t.get("skill_played", 0)) + 1

	# ---- 计算结果清单：Lua 纯函数优先，GDScript 通用结算兜底 ----
	var result := {}
	if LuaRuntime and LuaRuntime.enabled:
		var ctx := _build_state_ctx(pid, calc.cost)
		_merge_card_fields(ctx, data)
		result = LuaRuntime.execute_card(data.card_id, ctx)
	if result.is_empty():
		result = _fallback_result(data)

	# ---- 原子执行 ----
	var e_hp_before: int = enemy.hp
	var e_block_before: int = enemy.block
	var p_hp_before: int = player.hp
	var p_block_before: int = player.block
	var p_energy_before: int = player.energy
	var p_chan_before: int = player.chan
	var p_jianyi_before: int = player.jianyi

	var ex := _make_executor(pid)
	ex.played_card = card
	ex.played_card_id = data.card_id
	ex.played_card_type = data.card_type
	ex.apply(result)

	# ---- 表现层：数值变化 → 特效（CardExecutor 保持纯逻辑）----
	_play_card_fx(data, result, card,
		e_hp_before, e_block_before, p_hp_before, p_block_before, p_energy_before,
		p_chan_before, p_jianyi_before)

	_update_deck_ui()
	_update_sect_ui()

	if enemy.hp <= 0 and not game_over:
		_on_battle_end(true)


## 出牌特效：伤害飘字/闪白、格挡/回血/内力飘字、POWER横幅、卡牌飞行
func _play_card_fx(data: CardData, result: Dictionary, card,
		e_hp_before: int, e_block_before: int,
		p_hp_before: int, p_block_before: int, p_energy_before: int,
		p_chan_before: int, p_jianyi_before: int) -> void:
	if fx == null:
		return

	# 出牌音效
	BgmManager.play_sfx("play")

	# 战斗统计累计
	_battle_stats["cards"] = int(_battle_stats.get("cards", 0)) + 1
	_battle_stats["damage"] = int(_battle_stats.get("damage", 0)) + max(0, e_hp_before - enemy.hp)
	_battle_stats["max_hit"] = maxi(int(_battle_stats.get("max_hit", 0)), e_hp_before - enemy.hp)
	_battle_stats["block"] = int(_battle_stats.get("block", 0)) + max(0, player.block - p_block_before)

	# 伤害：敌人HP减少 → 飘红字 + 闪白 + 抖动
	var dmg_dealt: int = e_hp_before - enemy.hp
	var armor_broken: bool = int(result.get("armor_break", 0)) > 0 and e_block_before > 0
	if dmg_dealt > 0:
		fx.damage_text(_enemy_fx_pos(), dmg_dealt, armor_broken)
		fx.flash(enemy_portrait)
		fx.shake(enemy_portrait)
		BgmManager.play_sfx("hit")

	# 破甲摧毁护盾但无伤害 → 橙字
	if e_block_before > enemy.block and dmg_dealt == 0:
		fx.float_text(_enemy_fx_pos(), "破甲%d" % (e_block_before - enemy.block), BattleFX.COLOR_ARMOR_BREAK)

	# 格挡
	var blk_gained: int = player.block - p_block_before
	if blk_gained > 0:
		fx.float_text(_player_fx_pos(_active_player), "格挡+%d" % blk_gained, BattleFX.COLOR_BLOCK)
		BgmManager.play_sfx("block")

	# 回血
	if player.hp > p_hp_before:
		fx.float_text(_player_fx_pos(_active_player), "+%d" % (player.hp - p_hp_before), BattleFX.COLOR_HEAL)
		BgmManager.play_sfx("heal")

	# 内力
	if player.energy > p_energy_before:
		fx.float_text(_player_fx_pos(_active_player, Vector2(0, -34)), "内力+%d" % (player.energy - p_energy_before), BattleFX.COLOR_ENERGY)
		BgmManager.play_sfx("energy")

	# 门派资源
	if player.chan > p_chan_before:
		fx.float_text(_player_fx_pos(_active_player, Vector2(0, -68)), "禅+%d" % (player.chan - p_chan_before), BattleFX.COLOR_CHAN, 18)
	if player.jianyi > p_jianyi_before:
		fx.float_text(_player_fx_pos(_active_player, Vector2(0, -68)), "剑+%d" % (player.jianyi - p_jianyi_before), BattleFX.COLOR_JIANYI, 18)

	# POWER 激活横幅
	var set_power: String = str(result.get("set_power", ""))
	if set_power != "":
		var power_names := {
			"damo": "达摩一苇",
			"twoway": "太极两仪",
			"bahuang": "八荒六合",
			"longxiang": "龙象般若",
			"xiaoyaoyou": "逍遥游",
			"bodhi": "菩提心",
		}
		fx.show_banner("「%s」 激活！" % power_names.get(set_power, set_power), "每回合自动生效", BattleFX.COLOR_VICTORY)
		BgmManager.play_sfx("power")

	# 卡牌飞行：攻击飞向敌人，其余飞向自身
	var to_pos: Vector2 = _enemy_fx_pos() if data.card_type == CardData.CardType.ATTACK else _player_fx_pos(_active_player)
	fx.card_flight(card.global_position, to_pos, data)
	# 原卡缩小消失（视觉连贯）
	fx.card_exit(card.global_position, data)


func _enemy_fx_pos() -> Vector2:
	return enemy_portrait.global_position + enemy_portrait.size * 0.45


func _player_fx_pos(pid: int, offset: Vector2 = Vector2.ZERO) -> Vector2:
	var pt: TextureRect = p2_portrait if pid == 2 else p1_portrait
	return pt.global_position + pt.size * 0.45 + offset


## Lua 不可用时的通用结算（数值来自 .tres + 少量特例）。
## 这是降级兜底，完整效果逻辑以 lua/cards/ 为准。
func _fallback_result(data: CardData) -> Dictionary:
	var r := {
		"damage": data.damage + GameData.get_damage_bonus(),
		"block": data.block + GameData.get_block_bonus(),
		"heal": data.heal,
		"draw": data.draw,
		"energy_gain": data.energy_gain,
		"repeat_count": max(1, data.repeat),
		"armor_break": data.armor_break,
		"is_consumed": false,
	}
	match data.card_id:
		"punch":
			r["damage"] = GameData.get_punch_damage()
		"meditate":
			r["energy_gain"] = GameData.get_meditate_gain()
		"sl_damo":
			r["set_power"] = "damo"; r["is_consumed"] = true
		"sl_bodhi":
			r["set_power"] = "bodhi"; r["is_consumed"] = true
		"wd_twoway":
			r["set_power"] = "twoway"; r["is_consumed"] = true
		"xy_bahuang":
			r["set_power"] = "bahuang"; r["is_consumed"] = true
		"xy_longxiang":
			r["set_power"] = "longxiang"; r["is_consumed"] = true
		"xy_xiaoyaoyou":
			r["set_power"] = "xiaoyaoyou"; r["is_consumed"] = true
		"sl_fist", "sl_iron":
			r["chan_add"] = 1
		"wd_taiji":
			r["jianyi_add"] = 1
		_:
			pass
	return r


# ==============================
# 统一状态打包（TODO P2/P3：出牌与预览共用一份）
# ==============================

## 打包指定玩家的战斗只读上下文（不含卡牌自身字段，由调用方合并）。
func _build_state_ctx(pid: int, actual_cost: int = 0) -> Dictionary:
	var p := _player_node(pid)
	var t: Dictionary = _track[pid]
	var dc := _discard_pile_of(pid)
	return {
		# 玩家
		"player_hp": p.hp, "player_max_hp": p.max_hp,
		"player_energy": p.energy, "player_max_energy": p.max_energy,
		"player_block": p.block,
		"player_chan": p.chan, "player_jianyi": p.jianyi,
		"player_next_card_discount": p.next_card_discount,
		# 敌人
		"enemy_hp": enemy.hp, "enemy_max_hp": enemy.max_hp,
		"enemy_block": enemy.block,
		"enemy_intent_type": enemy.intent_type, "enemy_intent_value": enemy.intent_value,
		# 手牌/弃牌
		"hand_size": _hand_node(pid).cards.size(),
		"discard_csv": ",".join(PackedStringArray(dc)),
		# 折扣信息（卡牌预览显示实际费用用）
		"player_attack_discounted": p.attack_discounted,
		"next_two_discount": t.get("next_two_discount", 0),
		"player_character": p.character_id,
		# 回合追踪
		"last_played_card_id": t.get("last_id", ""),
		"last_played_card_type": t.get("last_type", -1),
		"skill_played_this_turn": t.get("skill_played", 0),
		"energy_used_this_turn": t.get("energy_used", 0),
		"cards_played_this_turn": t.get("cards_played", 0),
		"attacks_played_this_turn": t.get("attacks_played", 0),
		"actual_cost": actual_cost,
		# 境界加成
		"damage_bonus": GameData.get_damage_bonus(),
		"block_bonus": GameData.get_block_bonus(),
		"punch_damage": GameData.get_punch_damage(),
		"meditate_gain": GameData.get_meditate_gain(),
	}


func _merge_card_fields(ctx: Dictionary, data: CardData) -> void:
	ctx["card_id"] = data.card_id
	ctx["cost"] = data.cost
	ctx["card_type"] = data.card_type
	ctx["damage"] = data.damage
	ctx["block"] = data.block
	ctx["heal"] = data.heal
	ctx["draw"] = data.draw
	ctx["repeat"] = data.repeat
	ctx["armor_break"] = data.armor_break
	ctx["school"] = data.school


func _make_executor(pid: int, dp: Array = [], dc: Array = []) -> CardExecutor:
	if dp.is_empty():
		dp = _draw_pile_of(pid)
	if dc.is_empty():
		dc = _discard_pile_of(pid)
	return CardExecutor.new(_player_node(pid), enemy, _hand_node(pid), dp, dc, _track[pid], card_scene)


# ==============================
# 门派 POWER 回合触发（每玩家独立）
# ==============================

func _trigger_power_effects(p: Player, pid: int):
	if LuaRuntime and LuaRuntime.enabled:
		var ctx := {
			"powers": {
				"damo": p.power_damo,
				"twoway": p.power_twoway,
				"bahuang": p.power_bahuang,
				"longxiang": p.power_longxiang,
				"xiaoyaoyou": p.power_xiaoyaoyou,
				"bodhi": p.power_bodhi,
			},
		}
		var result := LuaRuntime.battle_trigger_powers(ctx)
		var ex := _make_executor(pid)
		ex.apply_power_trigger(result)
		return

	# Lua 不可用：GDScript 兜底
	if p.power_damo:
		p.chan += 2
		p.add_block(3)
		print("达摩一苇：禅意+2，格挡+3")
	if p.power_bodhi:
		p.chan += 1
		p.add_block(1)
		print("菩提心：禅意+1，格挡+1")
	if p.power_bahuang:
		p.heal(3)
		var ex := _make_executor(pid)
		ex.apply_power_trigger({"bahuang_card": true})
	if p.power_xiaoyaoyou:
		p.hand_limit_mod = 2
		p.attack_discounted = true
		print("逍遥游：手牌上限+2，攻击/内力牌费用-1")


# ==============================
# 结束回合
# ==============================

func _on_end_turn():
	# LAN 客机：turn_manager 为空也必须能结束回合
	# （旧 bug：判空 return 导致客机永远发不出 request_end_turn，联机卡死）
	if NetworkManager.is_lan and not NetworkManager.is_host:
		NetworkManager.rpc_id(1, "request_end_turn", 2)
		return

	if game_over or not turn_manager or turn_manager.current_turn == TurnManager.Turn.ENEMY:
		return

	# 共享回合（同屏双人 / 联机主机）
	if _is_dual():
		var ender := _active_player
		# 先弃该玩家的手牌，再标记结束
		_do_end_turn_for(ender)
		_update_deck_ui()

		var advanced := turn_manager.mark_player_ended(ender)
		if not advanced:
			# 自动切换到还没结束的玩家
			var next_p := turn_manager.first_unended_player()
			if next_p != 0:
				_switch_to(next_p)
			else:
				_update_active_indicator()
		if NetworkManager.is_lan and NetworkManager.is_host:
			NetworkManager.push_snapshot()
		return

	_do_end_turn()


## 单人模式：弃手牌并推进回合
func _do_end_turn():
	if hand.selected_card != null:
		hand.deselect()
	var my_discard: Array = discard_pile
	for c in hand.cards.duplicate():
		if c.card_data.retain:
			continue
		my_discard.append(c.card_data.card_id)
		hand.remove_card(c)
		CardPool.release(c)
	turn_manager.end_player_turn()


## 弃指定玩家手牌（不切换回合）
func _do_end_turn_for(player_id: int):
	var target_hand := _hand_node(player_id)
	var target_discard := _discard_pile_of(player_id)

	if target_hand.selected_card != null:
		target_hand.deselect()

	for c in target_hand.cards.duplicate():
		if c.card_data.retain:
			continue
		target_discard.append(c.card_data.card_id)
		target_hand.remove_card(c)
		CardPool.release(c)


# ==============================
# 局域网 RPC 回调（主机执行）
# ==============================

func network_execute_play(card_id: String, player_id: int):
	"""客机请求P2出牌（仅主机执行）"""
	if not NetworkManager.is_host:
		return
	_with_player(player_id, func():
		for c in hand.cards:
			if c.card_data.card_id == card_id:
				_execute_card(c)
				break
	)


func network_execute_end_turn(player_id: int):
	"""客机请求P2结束回合（仅主机执行）"""
	if not NetworkManager.is_host:
		return
	_do_end_turn_for(player_id)
	turn_manager.mark_player_ended(player_id)
	_update_deck_ui()
	NetworkManager.push_snapshot()


# ==============================
# 状态快照同步（客机渲染）
# ==============================

func apply_snapshot(snap: Dictionary):
	# 全局进度（客机预览/界面显示需要与主机一致的境界、金币）
	GameData.current_realm = snap.get("realm", GameData.current_realm)
	GameData.max_energy_per_realm = snap.get("max_energy_per_realm", GameData.max_energy_per_realm)
	GameData.gold = snap.get("gold", GameData.gold)
	GameData.cultivation = snap.get("cultivation", GameData.cultivation)

	# 同步结束状态（客机可能没有 turn_manager）
	var p1_ended = snap.get("p1_ended", false)
	var p2_ended = snap.get("p2_ended", false)
	if turn_manager and is_instance_valid(turn_manager):
		turn_manager.apply_network_end_state(p1_ended, p2_ended)

	# 回合显示
	var turn_val = snap.get("turn", -1)
	match turn_val:
		TurnManager.Turn.PLAYER1:
			if p1_ended and not p2_ended:
				turn_label.text = "等待P2结束回合..."
			elif p2_ended and not p1_ended:
				turn_label.text = "等待P1结束回合..."
			else:
				turn_label.text = "玩家回合"
			end_turn_btn.disabled = false
		TurnManager.Turn.ENEMY:
			turn_label.text = "敌人回合"
			end_turn_btn.disabled = true

	_switch_to(snap.get("active_player", 1))

	# 玩家1
	player1.hp = snap.get("p1_hp", player1.hp)
	player1.max_hp = snap.get("p1_max_hp", player1.max_hp)
	player1.block = snap.get("p1_block", 0)
	player1.energy = snap.get("p1_energy", 0)
	player1.chan = snap.get("p1_chan", 0)
	player1.jianyi = snap.get("p1_jianyi", 0)
	_diff_hand(hand1, snap.get("p1_hand_ids", []))
	deck_label.text = "牌库 %d" % snap.get("p1_draw_count", 0)
	discard_label.text = "弃牌 %d" % snap.get("p1_discard_count", 0)

	# 玩家2
	if snap.get("is_dual", false) and player2:
		player2.hp = snap.get("p2_hp", player2.hp)
		player2.max_hp = snap.get("p2_max_hp", player2.max_hp)
		player2.block = snap.get("p2_block", 0)
		player2.energy = snap.get("p2_energy", 0)
		player2.chan = snap.get("p2_chan", 0)
		player2.jianyi = snap.get("p2_jianyi", 0)
		_diff_hand(hand2, snap.get("p2_hand_ids", []))

	# 敌人
	if enemy and snap.get("enemy_exists", false):
		enemy.hp = snap.get("enemy_hp", enemy.hp)
		enemy.max_hp = snap.get("enemy_max_hp", enemy.max_hp)
		enemy.block = snap.get("enemy_block", 0)
		enemy.intent_type = snap.get("enemy_intent_type", 0)
		enemy.intent_value = snap.get("enemy_intent_val", 0)
		enemy.intent_times = snap.get("enemy_intent_times", 1)
		enemy.strength = snap.get("enemy_strength", 0)
		enemy.intent_changed.emit(enemy.intent_type, enemy.intent_value)

	# 敌人头像同步
	var tex_path = snap.get("enemy_portrait_path", "")
	if tex_path != "":
		enemy_portrait.texture = load(tex_path)

	game_over = snap.get("game_over", false)
	if game_over:
		retry_btn.visible = snap.get("show_retry", false)
	_update_ui()
	_refresh_card_previews()


func _diff_hand(hand_node, target_ids: Array):
	"""增量更新手牌：只增删有变化的卡，不重建全部"""
	var current_ids = []
	for c in hand_node.cards:
		current_ids.append(c.card_data.card_id)

	# 移除多余的（必须回池，修复客机节点泄漏）
	var to_remove = []
	for i in range(current_ids.size()):
		if current_ids[i] not in target_ids:
			to_remove.append(hand_node.cards[i])
	for card in to_remove:
		hand_node.remove_card(card)
		CardPool.release(card)

	# 添加缺少的
	for cid in target_ids:
		var found = false
		for c in hand_node.cards:
			if c.card_data.card_id == cid:
				found = true
				break
		if not found:
			var data = GameData.load_card(cid)
			if data:
				var card = CardPool.acquire(card_scene)
				card.setup(data)
				hand_node.add_card(card)


# ==============================
# 等待遮罩
# ==============================

func _show_waiting_mask(text: String):
	_hide_waiting_mask()
	_waiting_mask = ColorRect.new()
	_waiting_mask.color = Color(0, 0, 0, 0.8)
	_waiting_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_waiting_mask.mouse_filter = Control.MOUSE_FILTER_STOP
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 24)
	label.anchor_right = 1.0; label.anchor_bottom = 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_waiting_mask.add_child(label)
	add_child(_waiting_mask)


func _hide_waiting_mask():
	if _waiting_mask:
		_waiting_mask.queue_free()
		_waiting_mask = null


# ==============================
# 战斗结束 / 奖励
# ==============================

func _on_battle_end(won):
	if game_over:
		return
	game_over = true
	end_turn_btn.disabled = true

	if not won:
		_update_turn_label("败北...")
		retry_btn.visible = true
		if fx:
			fx.show_banner("败 北", "道心蒙尘，重整旗鼓", Color(0.9, 0.3, 0.3))
		BgmManager.play_sfx("defeat")
		if NetworkManager.is_lan and NetworkManager.is_host:
			NetworkManager.push_snapshot()
		return

	_update_turn_label("胜利！")
	if fx:
		fx.show_banner("胜 利", "此战功成", BattleFX.COLOR_VICTORY)
		fx.show_stats_panel(_battle_stats)
	BgmManager.play_sfx("victory")

	# 奖励随楼层类型缩放（与地图提示一致：普通10/12 精英20/20 Boss40/50）
	var realm_before: int = GameData.current_realm
	var reward: Dictionary = GameData.get_battle_reward()
	GameData.add_cultivation(reward["cultivation"])
	GameData.add_gold(reward["gold"])
	# 突破横幅
	if GameData.current_realm > realm_before:
		if fx:
			fx.show_banner("突 破！", "%s境 · 内力上限+1" % GameData.realm_names[GameData.current_realm], BattleFX.COLOR_ENERGY)
		BgmManager.play_sfx("breakthrough")

	var options := _roll_reward_options()

	if NetworkManager.is_lan:
		if NetworkManager.is_host:
			_p1_reward_done = false
			_p2_reward_done = false
			reward_screen.open(options)
			NetworkManager.rpc("sync_reward_open", options)
		return

	# 同屏双人：P1 先选，选完轮到 P2
	if _is_dual():
		_reward_picker = 1
	reward_screen.open(options)


func _roll_reward_options() -> Array:
	# 奖励池 = 通用 + 本队门派（不再把别派卡塞给玩家）
	var extra: Array = []
	if _is_dual():
		var s2: String = GameData.character_data.get(GameData.selected_character_2, {}).get("school", "")
		if s2 != "":
			extra.append(s2)
	var pool := GameData.get_character_pool("", extra)
	pool.shuffle()
	return pool.slice(0, 3)


func _on_reward_chosen(card_id: String):
	GameData.add_card(card_id)
	print("选择了奖励卡牌: %s" % card_id)
	GameData.save_game()

	if NetworkManager.is_lan and NetworkManager.is_host:
		_p1_reward_done = true
		_try_finish_lan_rewards()
		return

	# 同屏双人：P1 选完轮到 P2 选
	if _is_dual() and _reward_picker == 1:
		_reward_picker = 2
		reward_screen.open(_roll_reward_options(), "玩家2选择奖励")
		return

	_show_map()


func _on_reward_skipped():
	print("跳过了奖励")
	GameData.save_game()

	if NetworkManager.is_lan and NetworkManager.is_host:
		_p1_reward_done = true
		_try_finish_lan_rewards()
		return

	if _is_dual() and _reward_picker == 1:
		_reward_picker = 2
		reward_screen.open(_roll_reward_options(), "玩家2选择奖励")
		return

	_show_map()


## 主机收到客机的奖励选择 → 加进 P2 牌组
func network_reward_done(card_id: String):
	if not NetworkManager.is_host or _node_result_done:
		return
	if card_id != "":
		GameData.add_card_to_player2(card_id)
		print("P2 选择了奖励卡牌: %s" % card_id)
	GameData.save_game()
	_p2_reward_done = true
	_try_finish_lan_rewards()


func _try_finish_lan_rewards():
	if _p1_reward_done and _p2_reward_done:
		_show_map()
		NetworkManager.rpc("sync_show_map")


# 客机收到：开奖励界面
func network_reward_open(options: Array):
	reward_screen.open(options)


# 客机收到：显示地图
func network_show_map():
	_show_map()


# ==============================
# 地图节点选择
# ==============================

func _on_node_selected(node_type: int):
	if NetworkManager.is_lan:
		if NetworkManager.is_host:
			_do_select_node(node_type)
			NetworkManager.rpc("sync_select_node", node_type)
			if node_type == GameData.NodeType.BATTLE_NORMAL or node_type == GameData.NodeType.BATTLE_ELITE:
				# 战斗节点：等场景重置完成后再推快照
				await get_tree().create_timer(1.0).timeout
			NetworkManager.push_snapshot()
		else:
			NetworkManager.rpc_id(1, "request_select_node", node_type)
		return

	_do_select_node(node_type)


func network_select_node(node_type: int):
	"""RPC回调：执行节点选择（客机收主机广播）"""
	_do_select_node(node_type)


func _do_select_node(node_type: int):
	_node_result_done = false

	match node_type:
		GameData.NodeType.BATTLE_NORMAL, GameData.NodeType.BATTLE_ELITE:
			# 楼层已由 GameData.select_map_node 设定（禁止再 advance！）
			_reset_battle_state()

			# 重启回合管理器（客机不启动，等快照）
			if turn_manager:
				turn_manager.queue_free()
			turn_manager = TurnManager.new()
			turn_manager.name = "TurnManager"
			add_child(turn_manager)
			if not (NetworkManager.is_lan and not NetworkManager.is_host):
				turn_manager.turn_started.connect(_on_turn_started)
				turn_manager.turn_changed.connect(_on_turn_started)
				turn_manager.start_battle()
			_update_ui()
			_update_deck_ui()
			node_map.visible = false
			_hide_waiting_mask()
			if NetworkManager.is_lan and not NetworkManager.is_host:
				_show_waiting_mask("同步战斗状态...")

		GameData.NodeType.SHOP:
			_open_shop()

		GameData.NodeType.REST:
			_open_rest()

		GameData.NodeType.EVENT:
			_open_event()


## 重置战斗状态并初始化本场敌人
func _reset_battle_state():
	game_over = false
	end_turn_btn.disabled = false
	retry_btn.visible = false
	_battle_stats = {"turns": 0, "cards": 0, "damage": 0, "max_hit": 0, "block": 0}
	player1.init()
	player2.init(true)
	hand1.clear()
	hand2.clear()
	discard_pile.clear()
	discard_pile_p2.clear()
	_reset_turn_track(1)
	_reset_turn_track(2)
	_start_battle()

	draw_pile = GameData.player_deck.duplicate()
	draw_pile.shuffle()
	if _is_dual():
		draw_pile_p2 = GameData.player2_deck.duplicate()
		draw_pile_p2.shuffle()


func _start_battle():
	# 恢复敌人立绘姿态（上一场死亡动画可能改变了位置/旋转/透明度）
	enemy_portrait.modulate = Color(1, 1, 1, 1)
	enemy_portrait.rotation = _enemy_portrait_base["rot"]
	enemy_portrait.position = _enemy_portrait_base["pos"]

	var ft = GameData.get_floor_type()
	var ft_names = ["普通", "精英", "Boss"]
	enemy.init_from_floor(GameData.current_floor, ft)

	# Boss 战（含大关中段Boss）：专属背景 + 立绘，一眼识别
	if ft == GameData.FloorType.BOSS:
		_battle_bg.texture = load("res://assets/images/backgrounds/boss_bg.png")
		enemy_portrait.texture = load("res://assets/images/enemies/boss_lord.png")
		print("敌人: 武道盟主（镇关Boss）")
		if fx:
			fx.show_banner("镇 关 之 战", "武道盟主 现身！", Color(0.9, 0.3, 0.3))
		_update_floor_label()
		print("===== 第 %d 层 · %s战 =====" % [GameData.current_floor, ft_names[ft]])
		return

	# 设置背景图
	var bg_tex = BIOME_BG.get(GameData.current_biome)
	if bg_tex:
		_battle_bg.texture = bg_tex

	# 从当前生态的敌人池里按楼层选一个（两端一致）
	var pool = BIOME_ENEMIES.get(GameData.current_biome, {})
	var key = "elite" if ft == GameData.FloorType.ELITE else "normal"
	var candidates = pool.get(key, ["山匪"])
	if candidates.size() > 0:
		var idx = GameData.current_floor % candidates.size()
		var eid = candidates[idx]
		var tex_path = "res://assets/images/enemies/%s.tres" % eid
		enemy_portrait.texture = load(tex_path)
		print("敌人: %s" % eid)
		if fx:
			var lv_tag := "精英" if ft == GameData.FloorType.ELITE else "普通"
			fx.show_banner("遭遇 · %s" % eid, "%s战 · 第%d层" % [lv_tag, GameData.current_floor], BattleFX.COLOR_INFO)
		_show_tutorial_if_needed()

	_update_floor_label()
	var biome_names = ["竹林", "村庄", "官府", "门派"]
	var biome_name = biome_names[GameData.current_biome] if GameData.current_biome < biome_names.size() else "?"
	print("===== 第 %d 层 · %s战 · %s =====" % [GameData.current_floor, ft_names[ft], biome_name])


func _update_floor_label():
	var ft = GameData.get_floor_type()
	var ft_names = ["战斗", "⚔精英", "♛Boss"]
	floor_label.text = "第 %d 层 · %s" % [GameData.current_floor, ft_names[ft]]


## 首次战斗的操作引导（仅第一局第1层弹一次）
func _show_tutorial_if_needed() -> void:
	if _tutorial_shown or fx == null:
		return
	if GameData.current_floor > 2 or GameData.current_realm > 0:
		return
	_tutorial_shown = true
	fx.show_banner("点击卡牌选中", "再次点击同一张卡即可打出", BattleFX.COLOR_INFO)
	fx.show_banner("注意敌人意图", "⚔攻击会打你，🛡防御会给它叠盾", Color(0.95, 0.7, 0.3))
	fx.show_banner("结束回合", "打不出牌时点击「结束回合」", BattleFX.COLOR_VICTORY)


# ==============================
# 休息 / 事件 / 商店（含联机同步）
# ==============================

func _open_rest():
	if NetworkManager.is_lan:
		if NetworkManager.is_host:
			rest_screen.open(true)
			NetworkManager.rpc("sync_rest_open", GameData.player_hp, GameData.player2_hp, GameData.gold)
		else:
			_show_waiting_mask("等待主机...")
	else:
		rest_screen.open(true)


func network_rest_open(p1_hp: int, p2_hp: int, gold: int):
	"""客机收到：打开休息点（只展示，选择权在主机）"""
	GameData.player_hp = p1_hp
	GameData.player2_hp = p2_hp
	GameData.gold = gold
	_hide_waiting_mask()
	rest_screen.open(false)


func _on_rest_closed(next_action: String):
	# 只在「本端发起」时结算（客机的休息界面不可交互）
	if NetworkManager.is_lan and not NetworkManager.is_host:
		return
	if _node_result_done:
		return

	match next_action:
		"heal":
			GameData.heal_player(0.3)
			if _is_dual():
				GameData.heal_player2(0.3)
			print("休息点·调息: P1 %d/%d" % [GameData.player_hp, GameData.player_max_hp])
		"cultivate":
			GameData.add_cultivation(10)
			GameData.add_gold(10)
			print("休息点·冥想: 修为+10, 金币+10")

	GameData.save_game()
	_node_result_done = true
	if NetworkManager.is_lan and NetworkManager.is_host:
		_show_map()
		NetworkManager.rpc("sync_show_map")
	else:
		_show_map()


func network_rest_done(next_action: String):
	"""旧接口保留：客机的休息选择（现客机不可交互，理论不会触发）"""
	_on_rest_closed(next_action)


# ==============================
# 卡牌强化（休息点）
# ==============================

## 打开强化选择器：单人选P1牌组；双人把P2牌组也并进来
func _open_upgrade_picker():
	if _node_result_done:
		return
	var candidates: Array = []
	for cid in GameData.upgradeable_cards(1):
		candidates.append(cid)
	if _is_dual():
		for cid in GameData.upgradeable_cards(2):
			candidates.append(cid)
	if candidates.is_empty():
		return
	card_picker.open(candidates, "选择要强化的卡牌（永久提升）")


func _on_upgrade_cancelled():
	# 取消后回到休息点面板，不消耗这次休息
	rest_screen.open(true)


func _on_upgrade_picked(card_id: String):
	var ok := GameData.upgrade_card(card_id)
	if not ok and _is_dual():
		ok = GameData.upgrade_card_p2(card_id)
	if ok:
		BgmManager.play_sfx("power")
		if fx:
			fx.show_banner("强化成功", "%s 永久提升" % card_id, BattleFX.COLOR_JIANYI)
	else:
		print("[强化] 失败: %s" % card_id)
		return

	GameData.save_game()
	_node_result_done = true
	rest_screen.visible = false
	if NetworkManager.is_lan and NetworkManager.is_host:
		_show_map()
		NetworkManager.rpc("sync_show_map")
		NetworkManager.push_snapshot()
	else:
		_show_map()


func _open_event():
	if NetworkManager.is_lan:
		if NetworkManager.is_host:
			var event_data: Dictionary = GameData.get_random_event()
			event_screen.open(event_data)
			NetworkManager.rpc("sync_event_open", event_data)
		else:
			_show_waiting_mask("等待主机...")
	else:
		event_screen.open(GameData.get_random_event())


func network_event_open(event_data: Dictionary):
	"""客机收到：显示主机的事件（两端内容一致，谁先选谁算）"""
	_hide_waiting_mask()
	event_screen.open(event_data)


func _apply_event_action(action: String):
	match action:
		"buy_discount":
			if GameData.gold >= 5:
				GameData.spend_gold(5)
				GameData.add_card(GameData.get_random_new_card())
		"help":
			GameData.player_hp = maxi(1, GameData.player_hp - 5)
			GameData.add_card(GameData.get_random_new_card())
		"open":
			GameData.add_gold(20)
			GameData.add_cultivation(5)
		"heal":
			# 双人模式事件治疗全队
			GameData.heal_player(0.0)
			GameData.player_hp = mini(GameData.player_max_hp, GameData.player_hp + 15)
			if _is_dual():
				GameData.player2_hp = mini(GameData.player2_max_hp, GameData.player2_hp + 15)
		"cultivate":
			GameData.add_cultivation(15)
		"teach":
			# 传功：消耗20修为换随机新卡
			if GameData.cultivation >= 20:
				GameData.spend_cultivation(20)
				GameData.add_card(GameData.get_random_new_card())
		"ask":
			GameData.add_cultivation(5)
		"fight":
			# 挑战：掉血换修为+金币
			GameData.player_hp = maxi(1, GameData.player_hp - 12)
			GameData.add_cultivation(25)
			GameData.add_gold(15)
		"bath":
			# 灵泉：8金币恢复40%最大生命（双人全队）
			if GameData.spend_gold(8):
				GameData.heal_player(0.4)
				if _is_dual():
					GameData.heal_player2(0.4)
		"skip":
			pass


func _on_event_closed(_event_id: String, action: String):
	if _node_result_done:
		return
	_apply_event_action(action)
	GameData.save_game()
	_node_result_done = true
	if NetworkManager.is_lan:
		if NetworkManager.is_host:
			_show_map()
			NetworkManager.rpc("sync_show_map")
		else:
			NetworkManager.rpc_id(1, "request_event_done", _event_id, action)
	else:
		_show_map()


func network_event_done(_event_id: String, action: String):
	"""主机收到客机的事件选择"""
	if not NetworkManager.is_host or _node_result_done:
		return
	_apply_event_action(action)
	GameData.save_game()
	_node_result_done = true
	_show_map()
	NetworkManager.rpc("sync_show_map")


func _open_shop():
	if NetworkManager.is_lan:
		if NetworkManager.is_host:
			shop_screen.open()
			NetworkManager.rpc("sync_shop_open", shop_screen.stock, shop_screen.sold)
		else:
			_show_waiting_mask("等待主机商店数据...")
	else:
		shop_screen.open()


func network_shop_open(stock: Array, sold: Array):
	"""客机收到：打开与主机一致的商店"""
	_hide_waiting_mask()
	shop_screen.open(stock, sold)


func _on_shop_buy_requested(card_id: String, target_player: int):
	"""客机的购买请求 → 转发主机结算"""
	if NetworkManager.is_lan and not NetworkManager.is_host:
		NetworkManager.rpc_id(1, "request_shop_buy", card_id, target_player)


func _on_shop_delete_requested(card_id: String, target_player: int):
	"""客机的删牌请求 → 转发主机结算"""
	if NetworkManager.is_lan and not NetworkManager.is_host:
		NetworkManager.rpc_id(1, "request_shop_delete", card_id, target_player)


func _on_shop_refresh_requested():
	"""客机的刷新请求 → 转发主机结算"""
	if NetworkManager.is_lan and not NetworkManager.is_host:
		NetworkManager.rpc_id(1, "request_shop_refresh")


func _on_shop_refreshed(stock: Array, sold: Array):
	"""本端刷新成功 → 联机主机广播新库存"""
	if NetworkManager.is_lan and NetworkManager.is_host:
		NetworkManager.rpc("sync_shop_open", stock, sold)
		NetworkManager.push_snapshot()


func network_shop_refresh():
	"""主机收到客机刷新请求：扣钱+换货+广播"""
	if not NetworkManager.is_host or _node_result_done:
		return
	if shop_screen.try_refresh():
		NetworkManager.rpc("sync_shop_open", shop_screen.stock, shop_screen.sold)
		NetworkManager.push_snapshot()


func network_shop_buy(card_id: String, target_player: int):
	"""主机收到客机购买：扣钱、加牌组、广播新库存"""
	if not NetworkManager.is_host or _node_result_done:
		return
	if not GameData.spend_gold(shop_screen.BUY_PRICE):
		return
	shop_screen.apply_remote_buy(card_id, target_player)
	NetworkManager.rpc("sync_shop_update", shop_screen.stock, shop_screen.sold, GameData.gold)
	NetworkManager.push_snapshot()


func network_shop_delete(card_id: String, target_player: int):
	"""主机收到客机删牌：扣钱、删牌、广播"""
	if not NetworkManager.is_host or _node_result_done:
		return
	if not GameData.spend_gold(shop_screen.DELETE_PRICE):
		return
	shop_screen.apply_remote_delete(card_id, target_player)
	NetworkManager.rpc("sync_shop_update", shop_screen.stock, shop_screen.sold, GameData.gold)
	NetworkManager.push_snapshot()


func network_shop_sync(stock: Array, sold: Array, gold: int):
	"""客机收到：商店库存/金币更新"""
	GameData.gold = gold
	shop_screen.refresh_synced(stock, sold)


func network_shop_done():
	"""主机收到客机：逛完商店了"""
	if not NetworkManager.is_host or _node_result_done:
		return
	GameData.save_game()
	_node_result_done = true
	_show_map()
	NetworkManager.rpc("sync_show_map")


func _on_shop_done():
	if NetworkManager.is_lan and not NetworkManager.is_host:
		NetworkManager.rpc_id(1, "request_shop_done")
		return
	if _node_result_done:
		return
	GameData.save_game()
	_node_result_done = true
	if NetworkManager.is_lan and NetworkManager.is_host:
		_show_map()
		NetworkManager.rpc("sync_show_map")
	else:
		_show_map()


# ==============================
# 显示地图 / 节点推进
# ==============================

func _show_map():
	# 关闭所有可能还开着的弹层（联机下对端可能在等）
	reward_screen.visible = false
	shop_screen.visible = false
	rest_screen.visible = false
	event_screen.visible = false
	_hide_waiting_mask()
	if GameData.is_map_complete():
		GameData.generate_new_act()
	node_map.open()


# ==============================
# 重试 / 返回
# ==============================

func _on_retry():
	game_over = false
	retry_btn.visible = false
	end_turn_btn.disabled = false
	_reset_battle_state()
	turn_manager.start_battle()


func _on_back_to_menu():
	if NetworkManager.is_lan:
		NetworkManager.cleanup()
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


# ==============================
# UI 更新
# ==============================

func _update_ui():
	_on_hp_changed(player.hp, player.max_hp)
	_on_energy_changed(player.energy, player.max_energy)
	_on_block_changed(player.block)
	_on_enemy_hp_changed(enemy.hp, enemy.max_hp)
	_update_sect_ui()


func _update_sect_ui():
	var parts = []
	if player.chan > 0:
		parts.append("禅%d" % player.chan)
	if player.jianyi > 0:
		parts.append("剑%d" % player.jianyi)
	var sl = get_node_or_null("SectLabel")
	if sl:
		sl.text = "  ".join(parts) if parts.size() > 0 else ""
	chan_icon.visible = player.chan > 0
	jianyi_icon.visible = player.jianyi > 0
	_refresh_card_previews()


func _update_deck_ui():
	if _is_dual():
		var dp = _draw_pile_of(_active_player)
		var dc = _discard_pile_of(_active_player)
		deck_label.text = "牌库 %d" % dp.size()
		discard_label.text = "弃牌 %d" % dc.size()
	else:
		deck_label.text = "牌库 %d" % draw_pile.size()
		discard_label.text = "弃牌 %d" % discard_pile.size()


func _on_energy_changed(cur, max_val):
	energy_label.text = "内力 %d/%d" % [cur, max_val]
	_refresh_card_previews()


func _on_hp_changed(cur, max_val):
	hp_label.text = "HP %d/%d" % [cur, max_val]


func _on_block_changed(cur):
	block_label.text = "格挡 %d" % cur if cur > 0 else ""


## 刷新所有手牌的预览数值（每只手用各自玩家的上下文）
func _refresh_card_previews():
	if not LuaRuntime or not LuaRuntime.enabled:
		return
	if not card_scene:
		return
	if hand1.visible:
		var ctx1 := _build_state_ctx(1)
		for c in hand1.cards:
			if is_instance_valid(c):
				c.update_preview(ctx1)
	if hand2.visible:
		var ctx2 := _build_state_ctx(2)
		for c in hand2.cards:
			if is_instance_valid(c):
				c.update_preview(ctx2)


func _on_enemy_hp_changed(cur, max_val):
	enemy_hp_label.text = "敌人 HP %d/%d" % [cur, max_val]
	if enemy.block > 0:
		enemy_block_label.text = "护盾 %d" % enemy.block
	else:
		enemy_block_label.text = ""


func _on_enemy_block_changed(cur):
	if cur > 0:
		enemy_block_label.text = "护盾 %d" % cur
	else:
		enemy_block_label.text = ""


func _on_enemy_intent_changed(type: int, value: int):
	var intent_names = ["⚔攻击", "🛡防御", "⚔⚔连击", "💪强化"]
	var text := "%s %d" % [intent_names[type], value]
	if type == Enemy.IntentType.MULTI_ATTACK:
		text += "×%d" % enemy.intent_times
	elif type == Enemy.IntentType.BUFF:
		text = "💪强化 +%d" % value
	enemy_intent_label.text = text
	if enemy.strength > 0:
		enemy_intent_label.text += "（力%d）" % enemy.strength
	# 意图切换弹跳动画（手感）
	enemy_intent_label.pivot_offset = enemy_intent_label.size / 2.0
	var tw := create_tween()
	tw.tween_property(enemy_intent_label, "scale", Vector2(1.25, 1.25), 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(enemy_intent_label, "scale", Vector2.ONE, 0.12)


# ==============================
# 牌堆查看
# ==============================

func _on_deck_label_clicked(event: InputEvent):
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		var dp = _draw_pile_of(_active_player)
		var shuffled = dp.duplicate()
		shuffled.shuffle()
		pile_viewer.open(shuffled, "牌库")


func _on_discard_label_clicked(event: InputEvent):
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		var dc = _discard_pile_of(_active_player)
		pile_viewer.open(dc, "弃牌堆")


# ==============================
# 回合标签 / 激活指示
# ==============================

func _update_turn_label(suffix: String):
	turn_label.text = "%s境 · %s" % [GameData.realm_names[GameData.current_realm], suffix]


func _update_active_indicator():
	if not _is_dual() or NetworkManager.is_lan:
		_update_turn_label("玩家%d的回合" % _active_player)
		return

	# 双人同屏：高亮当前激活玩家
	p1_portrait.modulate = Color(1, 1, 1, 1.0) if _active_player == 1 else Color(0.5, 0.5, 0.5, 0.6)
	p2_portrait.modulate = Color(1, 1, 1, 1.0) if _active_player == 2 else Color(0.5, 0.5, 0.5, 0.6)

	if not (turn_manager and is_instance_valid(turn_manager)):
		_update_turn_label("玩家%d回合" % _active_player)
		return
	var p1_ended := turn_manager.has_player_ended(1)
	var p2_ended := turn_manager.has_player_ended(2)

	if p1_ended and not p2_ended:
		_update_turn_label("玩家2回合 (P1已结束)")
	elif p2_ended and not p1_ended:
		_update_turn_label("玩家1回合 (P2已结束)")
	elif p1_ended and p2_ended:
		_update_turn_label("敌人回合...")
	else:
		_update_turn_label("玩家%d回合 (点击头像切换)" % _active_player)


# ==============================
# 断线 / 重连处理
# ==============================

func _on_player_died():
	_on_battle_end(false)


func _on_enemy_died_by_signal():
	if not game_over:
		# 死亡动画（表现层），随后进入战斗结算
		if fx:
			fx.enemy_death(enemy_portrait)
		_on_battle_end(true)


func _on_player_disconnected():
	if NetworkManager.is_host:
		_show_waiting_mask("P2已断开，等待重连...")
		print("[断线] 主机等待客机重连")
	else:
		print("[断线] 客机返回主菜单")
		get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _on_player_reconnected():
	if NetworkManager.is_host:
		print("[重连] 客机重连中，推送快照...")
		NetworkManager.send_reconnect_data()
		_hide_waiting_mask()
		_update_turn_label("P2已重连")
