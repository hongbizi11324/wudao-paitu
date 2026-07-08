extends Node2D

var draw_pile = []      # 牌库（P1）
var discard_pile = []    # 弃牌堆（P1）
var draw_pile_p2 = []    # 牌库（P2，双人模式）
var discard_pile_p2 = [] # 弃牌堆（P2，双人模式）
var game_over = false

var turn_manager: TurnManager  # 回合状态机

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

# 云芷卡牌追踪变量
var last_played_card_type: int = -1  # 上一张打出的卡牌类型
var last_played_card_id: String = ""  # 上一张打出的卡牌ID
var skill_played_this_turn: int = 0   # 本回合打出技能牌计数
var energy_used_this_turn: int = 0    # 本回合已消耗内力
var consecutive_discount_used: bool = false  # 虚实相生第二段折扣是否已用
var next_two_cards_discount: int = 0  # 虚实相生下两张折扣数

# 当前活跃玩家的别名（方便现有代码直接引用）
var hand: Node2D
var player: Node
var player_portrait: TextureRect
var player_name_label: Label
var hp_label: Label
var energy_label: Label
var block_label: Label

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
		"boss": ["山寨头领"],
	},
	GameData.Biome.VILLAGE: {
		"normal": ["流民", "顽童"],
		"elite": ["官兵", "门派弟子"],
		"boss": ["丐帮掌门"],
	},
	GameData.Biome.GOV_OFFICE: {
		"normal": ["官兵", "门派弟子"],
		"elite": ["门派弟子·女"],
		"boss": ["官兵统领", "少林掌门"],
	},
	GameData.Biome.SECT: {
		"normal": ["门派弟子", "门派弟子·女"],
		"elite": ["门派长老"],
		"boss": ["武当掌门"],
	},
}


@onready var _battle_bg: TextureRect = $BattleBg


func _ready():
	# 设置 Lua 宿主引用
	LuaRuntime.host = self
	
	# 先设置别名，确保信号触发时不会null
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
	node_map.node_selected.connect(_on_node_selected)
	rest_screen.closed.connect(_on_rest_closed)
	event_screen.closed.connect(_on_event_closed)
	
	# 从存档恢复：直接显示地图
	# 局域网：用共享种子保证地图/牌序一致
	if NetworkManager.is_lan:
		seed(NetworkManager.shared_seed)
	if GameData.loading_save:
		GameData.loading_save = false
		node_map.open()
		return
	
	# 新游戏：先选路再开打
	if GameData.current_floor == 1 and not GameData.map_active:
		GameData.generate_new_act()
		node_map.open()
		return
	
	# 初始化
	player1.init()
	player2.init(true)
	_start_battle()
	
	# 单人模式：隐藏玩家2
	if not GameData.is_dual_mode:
		hand2.visible = false
		p2_portrait.visible = false
		p2_name_label.visible = false
		p2_hp_label.visible = false
		hand1.visible = true
	
	draw_pile = GameData.player_deck.duplicate()
	draw_pile.shuffle()
	
	if GameData.is_dual_mode:
		draw_pile_p2 = GameData.player2_deck.duplicate()
		draw_pile_p2.shuffle()
	
	# 加载头像
	if GameData.selected_character != "":
		p1_portrait.texture = load("res://assets/images/player/%s.tres" % GameData.selected_character)
		p1_name_label.text = GameData.character_data[GameData.selected_character]["name"]
	if GameData.is_dual_mode and GameData.selected_character_2 != "":
		p2_portrait.texture = load("res://assets/images/player/%s.tres" % GameData.selected_character_2)
		p2_name_label.text = GameData.character_data[GameData.selected_character_2]["name"]
	else:
		p2_name_label.text = "玩家2"
	
	# 设置退出按钮（角落常显）
	menu_btn.text = "✕"
	menu_btn.size = Vector2(36, 36)
	menu_btn.position = Vector2(10, 10)
	menu_btn.visible = true
	
	# 创建回合状态机（客机不启动，完全听主机指挥）
	turn_manager = TurnManager.new()
	turn_manager.name = "TurnManager"
	add_child(turn_manager)
	
	if NetworkManager.is_lan and not NetworkManager.is_host:
		# 客机：不启动 TurnManager，等主机的 RPC 驱动
		_switch_to(1)
		_update_ui()
		_show_waiting_mask("等待主机同步状态...")
		_update_deck_ui()
	else:
		turn_manager.turn_started.connect(_on_turn_started)
		turn_manager.turn_changed.connect(_on_turn_started)
		turn_manager.start_battle(GameData.is_dual_mode)
	
	_scene_loaded = true
	_update_ui()


# ==============================
# 回合状态机回调
# TurnManager 驱动，单/双人统一处理
# ==============================

var _scene_loaded: bool = false

func _on_turn_started(turn: int):
	# 重置回合追踪变量
	skill_played_this_turn = 0
	energy_used_this_turn = 0
	next_two_cards_discount = 0
	consecutive_discount_used = false
	
	_apply_turn(turn)
	
	# 局域网：主机同步回合给客机
	if NetworkManager.is_lan and NetworkManager.is_host:
		NetworkManager.push_snapshot()


func network_sync_turn(turn: int):
	"""客机收到主机回合同步后执行"""
	# 同步屏障：场景未就绪则等待
	if not _scene_loaded:
		await get_tree().process_frame
	
	# 重置回合追踪变量
	skill_played_this_turn = 0
	energy_used_this_turn = 0
	next_two_cards_discount = 0
	consecutive_discount_used = false
	_apply_turn(turn)


func _apply_turn(turn: int):
	match turn:
		TurnManager.Turn.PLAYER1:
			_switch_to(1)
			_switch_draw(hand1, draw_pile, discard_pile)
			player1.refill_energy()
			if GameData.is_dual_mode:
				player2.refill_energy()
				_switch_draw(hand2, draw_pile_p2, discard_pile_p2)
			_trigger_power_effects()
			end_turn_btn.text = "结束回合"
			end_turn_btn.disabled = false
			_update_ui()
			_update_deck_ui()
			_refresh_card_previews()
		
		TurnManager.Turn.PLAYER2:
			# 旧路径保留：单人模式不会走到这里
			_switch_to(2)
			_switch_draw(hand2, draw_pile_p2, discard_pile_p2)
			player2.refill_energy()
			end_turn_btn.text = "结束回合"
			end_turn_btn.disabled = false
			_update_ui()
			_update_deck_ui()
			_refresh_card_previews()
		
		TurnManager.Turn.ENEMY:
			end_turn_btn.disabled = true
			end_turn_btn.text = "敌人回合..."
			_update_turn_label("敌人回合")
			# 延迟一帧执行，让 UI 先刷新
			_execute_enemy_turn.call_deferred()


func _execute_enemy_turn():
	var alive = gm.execute_enemy_turn(player1, enemy)
	if game_over:
		return
	if alive:
		turn_manager.end_enemy_turn()


# ==============================
# 玩家操作别名（方便现有代码引用）
# ==============================

func _switch_to(p: int):
	_active_player = p
	
	if NetworkManager.is_lan:
		if NetworkManager.is_host:
			hand = hand1
			player = player1
			player_portrait = p1_portrait
			player_name_label = p1_name_label
			hp_label = p1_hp_label
			energy_label = p1_energy_label
			block_label = p1_block_label
			hand1.visible = true
			hand2.visible = false
			_hide_waiting_mask()
		else:
			hand = hand2
			player = player2
			player_portrait = p2_portrait
			player_name_label = p2_name_label
			hp_label = p2_hp_label
			energy_label = p1_energy_label
			block_label = p1_block_label
			hand1.visible = false
			hand2.visible = true
			_hide_waiting_mask()
	else:
		# 同屏模式：只显示当前激活玩家的手牌
		if p == 1:
			hand = hand1
			player = player1
			player_portrait = p1_portrait
			player_name_label = p1_name_label
			hp_label = p1_hp_label
			energy_label = p1_energy_label
			block_label = p1_block_label
		else:
			hand = hand2
			player = player2
			player_portrait = p2_portrait
			player_name_label = p2_name_label
			hp_label = p2_hp_label
			energy_label = p1_energy_label
			block_label = p1_block_label
		
		if GameData.is_dual_mode:
			# 双人同屏：只显示当前激活玩家的手牌
			hand1.visible = (p == 1)
			hand2.visible = (p == 2)
		else:
			hand1.visible = true
			hand2.visible = false
	
	_update_ui()
	_update_active_indicator()


func _on_p1_portrait_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if NetworkManager.is_lan:
			return
		if GameData.is_dual_mode and not NetworkManager.is_lan:
			if not turn_manager.p1_ended:
				_switch_to(1)


func _on_p2_portrait_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if NetworkManager.is_lan:
			return
		if GameData.is_dual_mode and not NetworkManager.is_lan:
			if not turn_manager.p2_ended:
				_switch_to(2)


# ==============================
# 牌库操作
# ==============================

func _switch_draw(h: Node2D, pile: Array, discard_ref: Array, count: int = 4):
	"""给指定手牌抽指定数量牌，牌库空则回收对应的弃牌堆"""
	var card_scene = load("res://scenes/card.tscn")
	for i in range(count):
		if pile.size() == 0:
			if discard_ref.size() > 0:
				# 回收弃牌堆到牌库
				for cid in discard_ref:
					pile.append(cid)
				discard_ref.clear()
				pile.shuffle()
			else:
				break
		var card_id = pile.pop_back()
		var path = "res://resources/cards/%s.tres" % card_id
		var data = load(path)
		var card = CardPool.acquire(card_scene)
		card.setup(data)
		if not h.add_card(card):
			CardPool.release(card)
	print("抽牌完成")


func _unhandled_input(event):
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		if GameData.is_dual_mode and not NetworkManager.is_lan:
			hand1.deselect()
			hand2.deselect()
		else:
			hand.deselect()


# ==============================
# 出牌
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
	if GameData.is_dual_mode and not NetworkManager.is_lan:
		if card_owner != _active_player:
			print("[拒绝] 当前激活的是P%d，不能出P%d的牌" % [_active_player, card_owner])
			return
		if turn_manager:
			if card_owner == 1 and turn_manager.p1_ended:
				return
			if card_owner == 2 and turn_manager.p2_ended:
				return
	
	# LAN 模式：主机只能出P1，客机只能出P2
	if NetworkManager.is_lan:
		if NetworkManager.is_host and card_owner != 1:
			return
		if not NetworkManager.is_host and card_owner != 2:
			return
		# 已结束回合的不能出
		if turn_manager:
			if card_owner == 1 and turn_manager.p1_ended:
				return
			if card_owner == 2 and turn_manager.p2_ended:
				return
	
	# 切换别名到出牌方
	_switch_to(card_owner)
	
	var _caller = "主机" if NetworkManager.is_host else "客机" if NetworkManager.is_lan else "单机"
	print("[%s] P%d 出牌: %s" % [_caller, card_owner, card.card_data.card_id])
	
	# LAN 模式：客机 P2 出牌 → 发 RPC 给主机执行
	if NetworkManager.is_lan and not NetworkManager.is_host:
		NetworkManager.rpc_id(1, "request_play", card.card_data.card_id, 2)
		return
	
	# 主机 / 单机：直接执行
	_execute_card(card)
	
	# 主机执行完后推快照
	if NetworkManager.is_lan and NetworkManager.is_host:
		NetworkManager.push_snapshot()


	
func _execute_card(card):
	var data = card.card_data

	# ===== 费用（凌波微步折扣） =====
	var actual_cost = data.cost
	# 逍遥游：攻击/内力牌费用-1
	if player.attack_discounted and (data.card_type == CardData.CardType.ATTACK or data.card_type == CardData.CardType.INNER):
		actual_cost = max(0, actual_cost - 1)
	# 凌波微步折扣
	if player.next_card_discount > 0:
		actual_cost = max(0, actual_cost - player.next_card_discount)
		player.next_card_discount = 0
	# 虚实相生折扣
	if next_two_cards_discount > 0:
		var dc = mini(actual_cost, next_two_cards_discount)
		actual_cost -= dc
		next_two_cards_discount -= dc
		consecutive_discount_used = true
	if not player.spend_energy(actual_cost):
		return
	energy_used_this_turn += actual_cost
	
	# 追踪上一张牌
	last_played_card_type = data.card_type
	last_played_card_id = data.card_id
	if data.card_type == CardData.CardType.SKILL:
		skill_played_this_turn += 1
	
	# ===== Lua 热更路径（PoC） =====
	if LuaRuntime and LuaRuntime.enabled:
		var lua_result = _try_execute_card_via_lua(card, data, actual_cost)
		if lua_result:
			return
	
	# ===== NEW: 效果系统（优先执行） =====
	if data.has_effects():
		_execute_card_via_effects(card, data)
		return
	
	# ===== 效果计算（旧版回退） =====
	var times = max(1, data.repeat)
	# 基础值统一从 .tres 读取（含境界加成），match分支只处理特殊逻辑
	var dmg = data.damage + GameData.get_damage_bonus()
	var blk = data.block + GameData.get_block_bonus()
	var eg = data.energy_gain
	var extra_draw = 0
	var is_consumed = false  # true=POWER/小无相功 不进弃牌
	
	match data.card_id:
		# ---- 基础牌特殊结算 ----
		"punch":
			dmg = GameData.get_punch_damage()
		"meditate":
			eg = GameData.get_meditate_gain()
		
		# ---- 🏯 少林（chan 特殊效果追加，基础值来自 .tres） ----
		"sl_fist":
			player.chan += 1
			print("罗汉拳 禅意+1 (%d)" % player.chan)
		"sl_iron":
			player.chan += 1
			print("铁布衫 禅意+1 (%d)" % player.chan)
		"sl_golden":
			blk += player.chan * 3
			print("金钟罩 消耗%d层禅意 → 格挡%d" % [player.chan, blk])
			player.chan = 0
		"sl_arhat":
			dmg += player.chan * 4
			print("罗汉伏魔 消耗%d层禅意 → 伤害%d" % [player.chan, dmg])
			player.chan = 0
		"sl_damo":
			player.power_damo = true
			is_consumed = true
			print("达摩一苇 激活！")
		
		# ---- ☯️ 武当（jianyi 特殊效果追加，基础值来自 .tres） ----
		"wd_taiji":
			player.jianyi += 1
			print("太极拳 剑意+1 (%d)" % player.jianyi)
		"wd_soft":
			if player.jianyi > 0:
				dmg += 4
				player.jianyi -= 1
				print("柔云剑 消耗1剑意 → 伤害%d" % dmg)
		"wd_steps":
			if player.jianyi > 0:
				extra_draw = 1
				player.jianyi -= 1
				print("梯云纵 消耗1剑意 → 多抽1")
		"wd_heavy":
			dmg = player.jianyi * 5
			print("真武重剑 消耗%d层剑意 → 伤害%d" % [player.jianyi, dmg])
			player.jianyi = 0
		"wd_twoway":
			player.power_twoway = true
			player.first_hit_this_turn = true
			is_consumed = true
			print("太极两仪 激活！")
		
		# ---- 🦋 逍遥（基础值来自 .tres，match只做特殊效果） ----
		"xy_beiming":
			pass  # heal 直接用 data.heal = 2
		"xy_lingbo":
			player.next_card_discount = 1
			print("凌波微步 下张牌费用-1")
		"xy_wuxiang":
			is_consumed = true
			var copied_id = ""
			var reversed = discard_pile.duplicate()
			reversed.reverse()
			for cid in reversed:
				if cid not in ["sl_damo","wd_twoway","xy_bahuang","xy_wuxiang"]:
					copied_id = cid
					break
			if copied_id != "":
				var cpath = "res://resources/cards/%s.tres" % copied_id
				var cdata = load(cpath)
				var cscene = load("res://scenes/card.tscn")
				var new_card = cscene.instantiate()
				new_card.setup(cdata)
				hand.add_card(new_card)
				print("小无相功 复制 -> %s" % copied_id)
			else:
				print("小无相功 弃牌堆无牌可复制")
		"xy_zhemel":
			if hand.cards.size() <= 3:
				dmg = 12
				print("天山折梅手 手牌≤3 → 伤害12")
		"xy_bahuang":
			player.power_bahuang = true
			is_consumed = true
			print("八荒六合 激活！")
		
		# ---- 🦋 云芷新卡（基础值来自 .tres，match只做条件追加） ----
		
		"xy_xiaoyaoyou":
			player.power_xiaoyaoyou = true
			is_consumed = true
			print("逍遥游 激活！")
		
		"xy_xingluo":
			if hand.cards.size() >= 6:
				dmg += 5
				print("星落九天 手牌≥6 → 伤害%d" % dmg)
		
		"xy_fengjuan":
			dmg += mini(hand.cards.size(), 4)
			print("风卷残云 手牌%d张 → 伤害%d" % [hand.cards.size(), dmg])
		
		"xy_guicang":
			extra_draw = 2
			if hand.cards.size() >= 5:
				extra_draw = 3
				print("归藏于渊 手牌≥5 → 抽3")
		
		"xy_fuguang":
			extra_draw = 1
			if hand.cards.size() <= 3:
				extra_draw = 2
				print("浮光掠影 手牌≤3 → 抽2")
		
		"xy_yufeng":
			if hand.cards.size() >= 4:
				blk += 4
				print("御风而行 手牌≥4 → 格挡%d" % blk)
		
		"xy_duanliu":
			# 弃1张牌，伤害+3
			var to_discard = null
			for c in hand.cards:
				if c != card:
					to_discard = c
					break
			if to_discard != null:
				dmg += 3
				var dc = discard_pile_p2 if _active_player == 2 else discard_pile
				dc.append(to_discard.card_data.card_id)
				hand.remove_card(to_discard)
				CardPool.release(to_discard)
				print("断水流 弃牌→伤害%d" % dmg)
		
		"xy_wanxiang":
			dmg = hand.cards.size() * 3
			print("万象归一 手牌%d张 → 伤害%d" % [hand.cards.size(), dmg])
			# 弃掉所有手牌
			var dc = discard_pile_p2 if _active_player == 2 else discard_pile
			for c in hand.cards.duplicate():
				if c != card:
					dc.append(c.card_data.card_id)
					hand.remove_card(c)
					CardPool.release(c)
		
		"xy_xiuli":
			# 将1张手牌移至牌顶。若移除的是攻击牌，抽1张
			var to_move = null
			for c in hand.cards:
				if c != card:
					to_move = c
					break
			if to_move != null:
				var dp = draw_pile_p2 if _active_player == 2 else draw_pile
				dp.append(to_move.card_data.card_id)
				var is_attack = to_move.card_data.card_type == CardData.CardType.ATTACK
				hand.remove_card(to_move)
				CardPool.release(to_move)
				if is_attack:
					extra_draw += 1
					print("袖里乾坤 移走攻击牌 → 抽1")
		
		"xy_lianhuan":
			blk = skill_played_this_turn * 2
			print("连环计 本回合打出%d张技能 → 格挡%d" % [skill_played_this_turn, blk])
		
		"xy_houfa":
			if last_played_card_type == CardData.CardType.ATTACK:
				blk = 8
				extra_draw = 1
				print("后发制人 上张是攻击 → 格挡8, 抽1")
		
		"xy_jinghua":
			if last_played_card_id != "" and last_played_card_id != "xy_jinghua":
				var last_path = "res://resources/cards/%s.tres" % last_played_card_id
				var last_data = load(last_path)
				if last_data and last_data.card_type != CardData.CardType.POWER:
					var cscene = load("res://scenes/card.tscn")
					var new_card = cscene.instantiate()
					new_card.setup(last_data)
					hand.add_card(new_card)
					print("镜花水月 复制 -> %s" % last_played_card_id)
				else:
					print("镜花水月 上一张是POWER/无效，跳过")
			else:
				print("镜花水月 无上一张牌，跳过")
		
		"xy_wujian":
			if last_played_card_type == CardData.CardType.SKILL:
				dmg *= 2
				print("无间道 上张是技能 → 伤害%d" % dmg)
		
		"xy_xushi":
			next_two_cards_discount = 2
			if consecutive_discount_used:
				next_two_cards_discount = 3
				print("虚实相生 连续技能 → 下3减")
			else:
				print("虚实相生 下2减")
		
		"xy_yixing":
			extra_draw = 1
			if last_played_card_type == CardData.CardType.MOVEMENT:
				extra_draw = 2
				print("移形换影 上张是移动 → 抽2")
		
		"xy_hantan":
			eg = 1
			if player.energy >= player.max_energy - 1:
				eg = 2
				print("寒潭映月 满内力 → 得2内力")
		
		"xy_qiguan":
			if player.energy >= 2:
				player.energy -= 2
				energy_used_this_turn += 2
				player.energy_changed.emit(player.energy, player.max_energy)
				dmg += 6
				print("气贯长虹 额外+2内力 → 伤害%d" % dmg)
		
		"xy_tuna":
			eg = 2
			if energy_used_this_turn <= actual_cost:
				eg = 3
				print("吐纳归元 未额外消耗内力 → 回3内力")
		
		"xy_longxiang":
			player.power_longxiang = true
			is_consumed = true
			print("龙象般若 激活！")
		
		"xy_baoyuan":
			if energy_used_this_turn == 0:
				blk += 5
				print("抱元守一 未消耗内力 → 格挡%d" % blk)
		
		"xy_xixing":
			if enemy.block > 0:
				dmg += 5
				player.heal(dmg)
				print("吸星大法 敌有护盾 → 伤害%d, 回%dHP" % [dmg, dmg])
		
		"xy_guanxing":
			if enemy.intent_type == enemy.IntentType.DEFEND:
				blk = 6
				print("观星望斗 敌人防御 → 格挡6")
		
		"xy_fange":
			if enemy.intent_type == enemy.IntentType.ATTACK:
				dmg = 16
				print("反戈一击 敌人攻击 → 伤害%d" % dmg)
		
		"xy_yibizhi":
			blk = enemy.intent_value
			print("以彼之道 复制%d点格挡" % blk)
		
		"xy_duotian":
			if float(enemy.hp) / float(enemy.max_hp) < 0.3:
				dmg = 30
				print("夺天造化 敌人血量<30%% → 伤害%d" % dmg)
		
		# ---- 通用基础卡：已通过顶部的 dmg/blk/eg 从 .tres 赋值 ----
		_:
			pass
	
	# 🦋 龙象般若：未使用内力提供伤害加成
	if player.power_longxiang and dmg > 0:
		var bonus = player.energy * 2
		dmg += bonus
		print("龙象般若 未用内力%d → 伤害+%d" % [player.energy, bonus])
	
	# ===== 执行伤害/格挡/回血 =====
	for i in range(times):
		if dmg > 0 or data.armor_break > 0:
			enemy.take_damage(dmg, data.armor_break)
		if blk > 0:
			player.add_block(blk)
		if data.heal > 0:
			player.heal(data.heal)
	
	if eg > 0:
		player.gain_energy(eg)
	
	# ===== 抽牌 =====
	if data.draw + extra_draw > 0:
		var dp = draw_pile_p2 if _active_player == 2 else draw_pile
		var dc = discard_pile_p2 if _active_player == 2 else discard_pile
		_switch_draw(hand, dp, dc, data.draw + extra_draw)
	
	# ===== 弃牌/消耗 =====
	if not is_consumed:
		var dc = discard_pile_p2 if _active_player == 2 else discard_pile
		dc.append(card.card_data.card_id)
	
	hand.remove_card(card)
	CardPool.release(card)
	_update_deck_ui()
	_update_sect_ui()
	
	if enemy.hp <= 0:
		_on_battle_end(true)


# ====================================================================
# Lua 热更路径（PoC）
# 尝试用 Lua 执行卡牌效果，成功返回 true，无实现返回 false
# ====================================================================

func _try_execute_card_via_lua(card, data: CardData, actual_cost: int) -> bool:
	# 构建上下文
	var ctx = {
		"card_id": data.card_id,
		"cost": data.cost,
		"card_type": data.card_type,
		"damage": data.damage,
		"block": data.block,
		"heal": data.heal,
		"draw": data.draw,
		"energy_gain": data.energy_gain,
		"repeat": data.repeat,
		"armor_break": data.armor_break,
		"school": data.school,
		"player_hp": player.hp,
		"player_max_hp": player.max_hp,
		"player_energy": player.energy,
		"player_block": player.block,
		"player_chan": player.chan,
		"player_jianyi": player.jianyi,
		"player_next_card_discount": player.next_card_discount,
		"enemy_hp": enemy.hp,
		"enemy_max_hp": enemy.max_hp,
		"enemy_block": enemy.block,
		"enemy_intent_type": enemy.intent_type,
		"enemy_intent_value": enemy.intent_value,
		"hand_size": hand.cards.size(),
		"last_played_card_id": last_played_card_id,
		"last_played_card_type": last_played_card_type,
		"skill_played_this_turn": skill_played_this_turn,
		"energy_used_this_turn": energy_used_this_turn,
		"damage_bonus": GameData.get_damage_bonus(),
		"block_bonus": GameData.get_block_bonus(),
	}
	
	var result = LuaRuntime.execute_card(data.card_id, ctx)
	if result.is_empty():
		return false
	
	# 提取结果
	var dmg = int(result.get("damage", 0))
	var blk = int(result.get("block", 0))
	var heal_amt = int(result.get("heal", 0))
	var extra_draw = int(result.get("draw", 0))
	var eg = int(result.get("energy_gain", 0))
	var is_consumed = result.get("is_consumed", false)
	var special = result.get("special", "")
	var repeat_times = int(result.get("repeat_count", 1))
	repeat_times = max(1, repeat_times)
	
	print("[Lua] %s → dmg=%d blk=%d heal=%d draw=%d energy=%d consumed=%s" % [
		data.card_id, dmg, blk, heal_amt, extra_draw, eg, is_consumed])
	
	# 处理特殊效果
	match special:
		"chan_plus_1":
			player.chan += 1
			print("  [Lua] 禅意+1 (%d)" % player.chan)
		"chan_reset":
			print("  [Lua] 消耗%d层禅意" % player.chan)
			player.chan = 0
		"jianyi_plus_1":
			player.jianyi += 1
			print("  [Lua] 剑意+1 (%d)" % player.jianyi)
		"jianyi_minus_1":
			player.jianyi = max(0, player.jianyi - 1)
			print("  [Lua] 剑意-1 (%d)" % player.jianyi)
		"jianyi_reset":
			print("  [Lua] 消耗%d层剑意" % player.jianyi)
			player.jianyi = 0
		_:
			if special.begins_with("set_discount_"):
				var discount_val = int(special.substr(len("set_discount_")))
				next_two_cards_discount = discount_val
				if consecutive_discount_used:
					next_two_cards_discount = discount_val + 1
					print("  [Lua] 虚实相生 连续技能 → 下%d减" % next_two_cards_discount)
				else:
					print("  [Lua] 虚实相生 下%d减" % next_two_cards_discount)
	
	# 龙象般若：未使用内力提供伤害加成
	if player.power_longxiang and dmg > 0:
		var bonus = player.energy * 2
		dmg += bonus
		print("  [Lua] 龙象般若 内力%d → 伤害+%d" % [player.energy, bonus])
	
	# 执行效果
	for i in range(repeat_times):
		if dmg > 0 or data.armor_break > 0:
			enemy.take_damage(dmg, data.armor_break)
		if blk > 0:
			player.add_block(blk)
		if heal_amt > 0:
			player.heal(heal_amt)
	
	if eg > 0:
		player.gain_energy(eg)
	elif eg < 0:
		var spend = -eg
		player.energy = max(0, player.energy - spend)
		energy_used_this_turn += spend
		player.energy_changed.emit(player.energy, player.max_energy)
	
	# 抽牌
	if extra_draw > 0:
		var dp = draw_pile_p2 if _active_player == 2 else draw_pile
		var dc = discard_pile_p2 if _active_player == 2 else discard_pile
		_switch_draw(hand, dp, dc, extra_draw)
	
	# 弃牌/消耗
	if not is_consumed:
		var dc = discard_pile_p2 if _active_player == 2 else discard_pile
		dc.append(card.card_data.card_id)
	
	hand.remove_card(card)
	CardPool.release(card)
	_update_deck_ui()
	_update_sect_ui()
	
	if enemy.hp <= 0:
		_on_battle_end(true)
	
	return true


# ====================================================================
# 效果系统（NEW）
# 替代旧版 _execute_card 的 match 分支
# 卡牌如有 effects 数组则走此路径，否则回退旧路径
# ====================================================================

func _execute_card_via_effects(card_node, data: CardData):
	var dp = draw_pile_p2 if _active_player == 2 else draw_pile
	var dc = discard_pile_p2 if _active_player == 2 else discard_pile
	
	# 构建效果执行上下文
	var ctx = EffectContext.new()
	ctx.player = player
	ctx.enemy = enemy
	ctx.hand = hand
	ctx.draw_pile = dp
	ctx.discard_pile = dc
	ctx.card_data = data
	ctx.last_played_card_id = last_played_card_id
	ctx.last_played_card_type = last_played_card_type
	ctx.skill_played_this_turn = skill_played_this_turn
	ctx.energy_used_this_turn = energy_used_this_turn
	ctx.next_card_discount = player.next_card_discount
	
	# 遍历并执行每个效果
	for effect in data.effects:
		if effect is ScriptedEffect:
			# 复杂效果：分派到旧版逻辑
			_handle_scripted_effect(effect.script_id, ctx, card_node)
		else:
			effect.execute(ctx)
		
		# 需要等待玩家选择（如小无相功/袖里乾坤）
		# 后续操作由回调继续
		if ctx.wait_for_reply:
			# 标记等待中，卡牌不丢弃，等回调完成
			return
	
	# 应用效果结果
	_apply_effect_results(card_node, data, ctx)


func _handle_scripted_effect(script_id: String, ctx: EffectContext, card_node):
	# 效果系统兜底：复杂的独特卡牌效果
	# 这些效果因为涉及复杂操作（选牌、复制等），暂时无法数据驱动
	match script_id:
		"xy_lingbo":
			player.next_card_discount = 1
			print("凌波微步 下张牌费用-1")
		
		"xy_wuxiang":
			ctx.is_consumed = true
			var copied_id = ""
			var reversed = ctx.discard_pile.duplicate()
			reversed.reverse()
			for cid in reversed:
				if cid not in ["sl_damo","wd_twoway","xy_bahuang","xy_wuxiang"]:
					copied_id = cid
					break
			if copied_id != "":
				var cpath = "res://resources/cards/%s.tres" % copied_id
				var cdata = load(cpath)
				var cscene = load("res://scenes/card.tscn")
				var new_card = cscene.instantiate()
				new_card.setup(cdata)
				hand.add_card(new_card)
				print("小无相功 复制 -> %s" % copied_id)
			else:
				print("小无相功 弃牌堆无牌可复制")
		
		"xy_jinghua":
			if ctx.last_played_card_id != "" and ctx.last_played_card_id != "xy_jinghua":
				var last_path = "res://resources/cards/%s.tres" % ctx.last_played_card_id
				var last_data = load(last_path)
				if last_data and last_data.card_type != CardData.CardType.POWER:
					var cscene = load("res://scenes/card.tscn")
					var new_card = cscene.instantiate()
					new_card.setup(last_data)
					hand.add_card(new_card)
					print("镜花水月 复制 -> %s" % ctx.last_played_card_id)
				else:
					print("镜花水月 上一张是POWER/无效，跳过")
			else:
				print("镜花水月 无上一张牌，跳过")
		
		"xy_xiuli":
			var to_move = null
			for c in hand.cards:
				if c != card_node:
					to_move = c
					break
			if to_move != null:
				var dp = ctx.draw_pile
				dp.append(to_move.card_data.card_id)
				var is_attack = to_move.card_data.card_type == CardData.CardType.ATTACK
				hand.remove_card(to_move)
				CardPool.release(to_move)
				if is_attack:
					ctx.total_draw += 1
					print("袖里乾坤 移走攻击牌 → 抽1")
		
		"xy_duanliu":
			var to_discard = null
			for c in hand.cards:
				if c != card_node:
					to_discard = c
					break
			if to_discard != null:
				ctx.total_damage += 3
				var dc = ctx.discard_pile
				dc.append(to_discard.card_data.card_id)
				hand.remove_card(to_discard)
				CardPool.release(to_discard)
				print("断水流 弃牌→伤害+3")
		
		"xy_wanxiang":
			var hand_size = hand.cards.size()
			ctx.total_damage = hand_size * 3
			print("万象归一 手牌%d张 → 伤害%d" % [hand_size, ctx.total_damage])
			var dc = ctx.discard_pile
			for c in hand.cards.duplicate():
				if c != card_node:
					dc.append(c.card_data.card_id)
					hand.remove_card(c)
					CardPool.release(c)
		
		"xy_xushi":
			next_two_cards_discount = 2
			if consecutive_discount_used:
				next_two_cards_discount = 3
				print("虚实相生 连续技能 → 下3减")
			else:
				print("虚实相生 下2减")
		
		"xy_qiguan":
			if player.energy >= 2:
				player.energy -= 2
				energy_used_this_turn += 2
				player.energy_changed.emit(player.energy, player.max_energy)
				ctx.total_damage += 6
				print("气贯长虹 额外+2内力 → 伤害%d" % (6))
		
		"xy_xixing":
			if enemy.block > 0:
				ctx.total_damage += 5
				var healamount = ctx.total_damage
				# 回血要在 apply 阶段处理
				ctx.total_heal += healamount
				print("吸星大法 敌有护盾 → 伤害+5, 回血%d" % healamount)
		
		"xy_yibizhi":
			ctx.total_block = enemy.intent_value
			print("以彼之道 复制%d点格挡" % ctx.total_block)
		
		_:
			push_warning("ScriptedEffect: unhandled script_id '%s'" % script_id)


func _apply_effect_results(card_node, data: CardData, ctx: EffectContext):
	# ===== 执行伤害 =====
	if ctx.total_damage > 0 or ctx.total_armor_break > 0:
		enemy.take_damage(ctx.total_damage, ctx.total_armor_break)
	
	# ===== 执行格挡 =====
	if ctx.total_block > 0:
		player.add_block(ctx.total_block)
	
	# ===== 执行回血 =====
	if ctx.total_heal > 0:
		player.heal(ctx.total_heal)
	
	# ===== 执行抽牌 =====
	if ctx.total_draw > 0:
		_switch_draw(hand, ctx.draw_pile, ctx.discard_pile, ctx.total_draw)
	
	# ===== 执行内力 =====
	if ctx.total_energy > 0:
		player.gain_energy(ctx.total_energy)
	elif ctx.total_energy < 0:
		# 消耗内力（气贯长虹等已在 scripted 里处理了）
		var spend = -ctx.total_energy
		player.energy = max(0, player.energy - spend)
		energy_used_this_turn += spend
		player.energy_changed.emit(player.energy, player.max_energy)
	
	# ===== 弃牌/消耗 =====
	if not ctx.is_consumed:
		ctx.discard_pile.append(card_node.card_data.card_id)
	
	hand.remove_card(card_node)
	CardPool.release(card_node)
	_update_deck_ui()
	_update_sect_ui()
	
	if enemy.hp <= 0:
		_on_battle_end(true)


func _on_end_turn():
	if game_over or turn_manager.current_turn == TurnManager.Turn.ENEMY:
		return
	
	# 双人同屏：标记当前玩家结束，双方都结束才进敌人回合
	if GameData.is_dual_mode and not NetworkManager.is_lan:
		var ender = _active_player
		print("[结束回合] P%d 结束, p1_ended=%s p2_ended=%s" % [ender, turn_manager.p1_ended, turn_manager.p2_ended])
		
		if ender == 1:
			turn_manager.p1_ended = true
		else:
			turn_manager.p2_ended = true
		
		_do_end_turn_for(ender)
		_update_deck_ui()
		
		print("[结束回合] 更新后 p1_ended=%s p2_ended=%s" % [turn_manager.p1_ended, turn_manager.p2_ended])
		
		if turn_manager.p1_ended and turn_manager.p2_ended:
			print("[结束回合] 双方都结束，进敌人回合")
			turn_manager.end_player_turn()
		else:
			# 自动切换到未结束的玩家
			if ender == 1 and not turn_manager.p2_ended:
				_switch_to(2)
			elif ender == 2 and not turn_manager.p1_ended:
				_switch_to(1)
			else:
				_update_active_indicator()
		return
	
	# LAN 模式：共享回合，双方各自结束
	if NetworkManager.is_lan:
		if NetworkManager.is_host:
			# 主机：P1 结束
			turn_manager.p1_ended = true
			_do_end_turn_for(1)
			if turn_manager.p1_ended and turn_manager.p2_ended:
				turn_manager.end_player_turn()
			NetworkManager.push_snapshot()
		else:
			# 客机：P2 请求结束
			NetworkManager.rpc_id(1, "request_end_turn", 2)
		return
	
	_do_end_turn()


func _do_end_turn():
	"""纯结束回合逻辑（不含网络路由）"""
	if hand.selected_card != null:
		hand.deselect()
	
	var my_discard = discard_pile_p2 if _active_player == 2 else discard_pile
	for c in hand.cards.duplicate():
		if c.card_data.retain:
			continue
		my_discard.append(c.card_data.card_id)
		hand.remove_card(c)
		CardPool.release(c)
	
	turn_manager.end_player_turn()


func _do_end_turn_for(player_id: int):
	"""弃指定玩家手牌（不切换回合）"""
	var target_hand = hand1 if player_id == 1 else hand2
	var target_discard = discard_pile if player_id == 1 else discard_pile_p2
	
	if target_hand.selected_card != null:
		target_hand.deselect()
	
	for c in target_hand.cards.duplicate():
		if c.card_data.retain:
			continue
		target_discard.append(c.card_data.card_id)
		target_hand.remove_card(c)
		CardPool.release(c)


# ==============================
# 局域网 RPC 回调
# NetworkManager 的 sync_play / sync_end_turn 调用这里
# ==============================

func network_execute_play(card_id: String, player_id: int):
	"""RPC回调：客机请求P2出牌（仅主机执行）"""
	if not NetworkManager.is_host:
		return
	var target_hand = hand1 if player_id == 1 else hand2
	var target_player = player1 if player_id == 1 else player2
	var saved_hand = hand
	var saved_player = player
	var saved_active = _active_player
	
	hand = target_hand
	player = target_player
	_active_player = player_id
	
	for c in hand.cards:
		if c.card_data.card_id == card_id:
			_execute_card(c)
			break
	
	hand = saved_hand
	player = saved_player
	_active_player = saved_active


func network_execute_end_turn(player_id: int):
	"""RPC回调：客机请求P2结束回合（仅主机执行）"""
	if not NetworkManager.is_host:
		return
	turn_manager.p2_ended = true
	_do_end_turn_for(2)
	if turn_manager.p1_ended and turn_manager.p2_ended:
		turn_manager.end_player_turn()
	NetworkManager.push_snapshot()


# ==============================
# 🆕 状态快照同步（客机）
# ==============================

var _waiting_mask: ColorRect = null


func apply_snapshot(snap: Dictionary):
	# 同步结束状态（客机可能没有 turn_manager）
	var p1_ended = snap.get("p1_ended", false)
	var p2_ended = snap.get("p2_ended", false)
	if turn_manager:
		turn_manager.p1_ended = p1_ended
		turn_manager.p2_ended = p2_ended
	
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
		TurnManager.Turn.ENEMY:
			turn_label.text = "敌人回合"
			end_turn_btn.disabled = true
	_active_player = snap["active_player"]
	_switch_to(snap["active_player"])
	
	# 玩家1
	player1.hp = snap["p1_hp"]
	player1.max_hp = snap["p1_max_hp"]
	player1.block = snap["p1_block"]
	player1.energy = snap["p1_energy"]
	_diff_hand(hand1, snap["p1_hand_ids"])
	deck_label.text = "牌库 %d" % snap["p1_draw_count"]
	discard_label.text = "弃牌 %d" % snap["p1_discard_count"]
	
	# 玩家2
	if snap["is_dual"] and player2:
		player2.hp = snap["p2_hp"]
		player2.max_hp = snap["p2_max_hp"]
		player2.block = snap["p2_block"]
		player2.energy = snap["p2_energy"]
		_diff_hand(hand2, snap["p2_hand_ids"])
	
	# 敌人
	var e = get_node_or_null("Enemy")
	if e and snap["enemy_exists"]:
		e.hp = snap["enemy_hp"]; e.max_hp = snap["enemy_max_hp"]
		e.block = snap["enemy_block"]
		e.intent_type = snap["enemy_intent_type"]; e.intent_value = snap["enemy_intent_val"]
		e.intent_changed.emit(e.intent_type, e.intent_value)
	
	# 敌人头像同步
	var tex_path = snap.get("enemy_portrait_path", "")
	if tex_path != "":
		enemy_portrait.texture = load(tex_path)
	
	# 全局
	game_over = snap["game_over"]
	_update_ui()
	# 遮罩由 _switch_to 管理


func _diff_hand(hand_node, target_ids: Array):
	"""增量更新手牌：只增删有变化的卡，不重建全部"""
	var current_ids = []
	for c in hand_node.cards:
		current_ids.append(c.card_data.card_id)
	
	# 移除多余的
	var to_remove = []
	for i in range(current_ids.size()):
		if current_ids[i] not in target_ids:
			to_remove.append(hand_node.cards[i])
	for card in to_remove:
		hand_node.remove_card(card)
	
	# 添加缺少的
	for cid in target_ids:
		var found = false
		for c in hand_node.cards:
			if c.card_data.card_id == cid:
				found = true
				break
		if not found:
			var path = "res://resources/cards/%s.tres" % cid
			var data = load(path)
			if data:
				var card_scene = load("res://scenes/card.tscn")
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
# 门派POWER回合触发
# ==============================

func _trigger_power_effects():
	if LuaRuntime and LuaRuntime.enabled:
		var ctx = {
			"turn": turn_manager.current_turn if turn_manager else 0,
			"is_player_turn": true,
		}
		LuaRuntime.battle_trigger_powers(ctx)
		return
	
	# 回退：旧版 GDScript 逻辑
	player.first_hit_this_turn = true
	
	if player.power_damo:
		player.chan += 2
		player.add_block(3)
		print("达摩一苇：禅意+2，格挡+3")
	
	if player.power_bahuang:
		player.heal(3)
		var base_pool = ["strike", "defend", "punch", "meditate"]
		base_pool.shuffle()
		var card_id = base_pool[0]
		var path = "res://resources/cards/%s.tres" % card_id
		var data = load(path)
		var card_scene = load("res://scenes/card.tscn")
		var card = CardPool.acquire(card_scene)
		card.setup(data)
		if hand.add_card(card):
			print("八荒六合：回复3HP，获得 %s" % card_id)
		else:
			CardPool.release(card)
			discard_pile.append(card_id)
	
	if player.power_xiaoyaoyou:
		player.hand_limit_mod = 2
		player.attack_discounted = true
		print("逍遥游：手牌上限+2，攻击/内力牌费用-1")


# ==============================
# 战斗结束
# ==============================

func _on_battle_end(won):
	if game_over:
		return
	game_over = true
	end_turn_btn.disabled = true
	
	if won:
		_update_turn_label("胜利！")
		GameData.add_cultivation(10)
		GameData.add_gold(12)
		
		# 局域网：主机给客机也加奖励，然后双方都显示地图
		if NetworkManager.is_lan:
			if NetworkManager.is_host:
				# 主机选奖励
				var pool = _get_reward_pool()
				pool.shuffle()
				var options = pool.slice(0, 3)
				reward_screen.open(options)
				# 通知客机也开奖励界面
				NetworkManager.rpc("sync_reward_open", options)
			return
		
		# 同屏/单机：正常开奖励界面
		var pool = _get_reward_pool()
		pool.shuffle()
		var options = pool.slice(0, 3)
		reward_screen.open(options)
	else:
		_update_turn_label("败北...")
		retry_btn.visible = true


func _on_player_died():
	_on_battle_end(false)


func _on_enemy_died_by_signal():
	if not game_over:
		_on_battle_end(true)


func _on_retry():
	game_over = false
	end_turn_btn.disabled = false
	retry_btn.visible = false
	player.init()
	_start_battle()
	# 重置牌组
	draw_pile = GameData.player_deck.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()
	if GameData.is_dual_mode:
		draw_pile_p2 = GameData.player2_deck.duplicate()
		draw_pile_p2.shuffle()
		discard_pile_p2.clear()
		hand1.clear()
		hand2.clear()
	else:
		hand.clear()
	
	# 重启回合管理器（自动触发 P1 抽牌）
	turn_manager.start_battle(GameData.is_dual_mode)


func _on_back_to_menu():
	if NetworkManager.is_lan:
		NetworkManager.cleanup()
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


# ==============================
# 战斗奖励 → 地图节点
# ==============================

func _on_reward_chosen(card_id: String):
	GameData.add_card(card_id)
	print("选择了奖励卡牌: %s" % card_id)
	GameData.save_game()
	if NetworkManager.is_lan:
		if NetworkManager.is_host:
			_show_map()
			NetworkManager.rpc("sync_show_map")
		else:
			NetworkManager.rpc_id(1, "request_reward_done", card_id)
	else:
		_show_map()


func _on_reward_skipped():
	print("跳过了奖励")
	GameData.save_game()
	if NetworkManager.is_lan:
		if NetworkManager.is_host:
			_show_map()
			NetworkManager.rpc("sync_show_map")
		else:
			NetworkManager.rpc_id(1, "request_reward_done", "")
	else:
		_show_map()


# 客机收到：开奖励界面
func network_reward_open(options: Array):
	reward_screen.open(options)


# 客机收到：显示地图
func network_show_map():
	_show_map()


# 主机收到客机的奖励选择结果
func network_reward_done(card_id: String):
	if card_id != "":
		GameData.add_card(card_id)
	GameData.save_game()
	_show_map()
	NetworkManager.rpc("sync_show_map")


func _get_reward_pool() -> Array:
	return [
		"punch", "meditate", "light_step",
		"double_strike", "tactics", "iron_wall", "vigor", "whirlwind",
		"flowing_cloud_sword", "triple_stab", "sword_energy",
		"iron_shirt", "vajra_fist", "golden_bell",
		"strike", "defend", "bash", "heal",
		"sl_fist", "sl_iron", "sl_golden", "sl_arhat",
		"wd_taiji", "wd_soft", "wd_steps", "wd_heavy",
		"xy_beiming", "xy_lingbo", "xy_wuxiang", "xy_zhemel",
		"xy_xiaoyaoyou", "xy_xingluo", "xy_fengjuan",
		"xy_guicang", "xy_fuguang", "xy_yufeng",
		"xy_duanliu", "xy_wanxiang", "xy_xiuli",
		"xy_lianhuan", "xy_houfa", "xy_jinghua",
		"xy_wujian", "xy_xushi", "xy_yixing",
		"xy_hantan", "xy_qiguan", "xy_tuna",
		"xy_longxiang", "xy_baoyuan", "xy_xixing",
		"xy_guanxing", "xy_fange", "xy_yibizhi", "xy_duotian"
	]


func _show_map():
	# 显示杀戮尖塔风格地图
	if GameData.is_map_complete():
		GameData.generate_new_act()
	node_map.open()


# ==============================
# 地图节点选择
# ==============================

func _on_node_selected(node_type: int):
	if NetworkManager.is_lan:
		if NetworkManager.is_host:
			# 主机：直接执行 + 广播给客机
			_do_select_node(node_type)
			NetworkManager.rpc("sync_select_node", node_type)
			NetworkManager.push_snapshot()
		else:
			# 客机：请求主机执行
			NetworkManager.rpc_id(1, "request_select_node", node_type)
		return
	
	_do_select_node(node_type)


func network_select_node(node_type: int):
	"""RPC回调：执行节点选择"""
	_do_select_node(node_type)


func _do_select_node(node_type: int):
	match node_type:
		GameData.NodeType.BATTLE_NORMAL, GameData.NodeType.BATTLE_ELITE:
			# 战斗节点 → 进入战斗场景
			get_tree().reload_current_scene()
		
		GameData.NodeType.SHOP:
			_open_shop()
		
		GameData.NodeType.REST:
			$RestScreen.open()
		
		GameData.NodeType.EVENT:
			var event_data = GameData.get_random_event()
			$EventScreen.open(event_data)


# 非战斗节点完成 → 进下一层地图
func _on_rest_closed(next_action: String):
	match next_action:
		"heal":
			GameData.heal_player(0.3)
			print("休息点·调息: HP -> %d/%d" % [GameData.player_hp, GameData.player_max_hp])
		"cultivate":
			GameData.add_cultivation(10)
			GameData.add_gold(10)
			print("休息点·冥想: 修为+10, 金币+10")
	
	GameData.save_game()
	_show_map()


func _on_event_closed(_event_id: String, action: String):
	match action:
		"buy_discount":
			if GameData.gold >= 5:
				GameData.spend_gold(5)
				var card_id = GameData.get_random_new_card()
				GameData.add_card(card_id)
				print("事件: 行脚商人 → 购买 %s" % card_id)
			else:
				print("事件: 行脚商人 → 金币不足")
		
		"help":
			GameData.player_hp = maxi(1, GameData.player_hp - 5)
			var card_id = GameData.get_random_new_card()
			GameData.add_card(card_id)
			print("事件: 受伤武者 → -5HP, +%s" % card_id)
		
		"open":
			GameData.add_gold(20)
			GameData.add_cultivation(5)
			print("事件: 神秘宝箱 → 金币+20, 修为+5")
		
		"heal":
			GameData.heal_player(0.0)
			GameData.player_hp = mini(GameData.player_max_hp, GameData.player_hp + 15)
			print("事件: 废弃药园 → HP+15 (%d)" % GameData.player_hp)
		
		"cultivate":
			GameData.add_cultivation(15)
			print("事件: 修炼洞府 → 修为+15")
		
		"skip":
			print("事件: 跳过了")
	
	GameData.save_game()
	_show_map()


# ==============================
# 商店
# ==============================

func _open_shop():
	shop_screen.open()


func _on_shop_done():
	GameData.save_game()
	_show_map()


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
	if GameData.is_dual_mode:
		var dp = draw_pile_p2 if _active_player == 2 else draw_pile
		var dc = discard_pile_p2 if _active_player == 2 else discard_pile
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

## 刷新所有手牌的预览数值（调用 Lua 计算实际伤害/格挡等）
func _refresh_card_previews():
	if not LuaRuntime or not LuaRuntime.enabled:
		return
	if not hand or not player or not enemy:
		return
	var ctx = _build_card_ctx()
	for c in hand.cards:
		if is_instance_valid(c):
			c.update_preview(ctx)

func _build_card_ctx() -> Dictionary:
	return {
		"card_id": "", "cost": 0, "card_type": 0,
		"damage": 0, "block": 0, "heal": 0, "draw": 0,
		"energy_gain": 0, "repeat": 0, "armor_break": 0, "school": "",
		"player_hp": player.hp, "player_max_hp": player.max_hp,
		"player_energy": player.energy, "player_max_energy": player.max_energy,
		"player_block": player.block,
		"player_chan": player.chan, "player_jianyi": player.jianyi,
		"player_next_card_discount": player.next_card_discount,
		"enemy_hp": enemy.hp, "enemy_max_hp": enemy.max_hp,
		"enemy_block": enemy.block,
		"enemy_intent_type": enemy.intent_type, "enemy_intent_value": enemy.intent_value,
		"hand_size": hand.cards.size(),
		"last_played_card_id": last_played_card_id,
		"last_played_card_type": last_played_card_type,
		"skill_played_this_turn": skill_played_this_turn,
		"energy_used_this_turn": energy_used_this_turn,
		"actual_cost": 0,
		"damage_bonus": GameData.get_damage_bonus(),
		"block_bonus": GameData.get_block_bonus(),
	}

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
	var intent_names = ["⚔攻击", "🛡防御"]
	enemy_intent_label.text = "%s %d" % [intent_names[type], value]


# ==============================
# 牌堆查看
# ==============================

func _on_deck_label_clicked(event: InputEvent):
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		var dp = draw_pile_p2 if _active_player == 2 else draw_pile
		var shuffled = dp.duplicate()
		shuffled.shuffle()
		pile_viewer.open(shuffled, "牌库")


func _on_discard_label_clicked(event: InputEvent):
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		var dc = discard_pile_p2 if _active_player == 2 else discard_pile
		pile_viewer.open(dc, "弃牌堆")


# ==============================
# 楼层与战斗初始化
# ==============================

func _start_battle():
	var ft = GameData.get_floor_type()
	var ft_names = ["普通", "精英", "Boss"]
	enemy.init_from_floor(GameData.current_floor, ft)
	
	# 设置背景图
	var biome_names = ["竹林", "村庄", "官府", "门派"]
	var bg_tex = BIOME_BG.get(GameData.current_biome)
	if bg_tex:
		_battle_bg.texture = bg_tex
	
	# 从当前生态的敌人池里随机选一个
	var pool = BIOME_ENEMIES.get(GameData.current_biome, {})
	var key = "boss" if ft == GameData.FloorType.BOSS else ("elite" if ft == GameData.FloorType.ELITE else "normal")
	var candidates = pool.get(key, ["山匪"])
	if candidates.size() > 0:
		# 用楼层做种子确保两边选同一只
		var idx = GameData.current_floor % candidates.size()
		var eid = candidates[idx]
		var tex_path = "res://assets/images/enemies/%s.tres" % eid
		enemy_portrait.texture = load(tex_path)
		print("敌人: %s" % eid)
	
	_update_floor_label()
	var biome_name = biome_names[GameData.current_biome] if GameData.current_biome < biome_names.size() else "?"
	print("===== 第 %d 层 · %s战 · %s =====" % [GameData.current_floor, ft_names[ft], biome_name])


func _update_floor_label():
	var ft = GameData.get_floor_type()
	var ft_names = ["战斗", "⚔精英", "♛Boss"]
	floor_label.text = "第 %d 层 · %s" % [GameData.current_floor, ft_names[ft]]


func _update_turn_label(suffix: String):
	turn_label.text = "%s境 · %s" % [GameData.realm_names[GameData.current_realm], suffix]


## 更新当前激活玩家的视觉指示（头像边框高亮 + 回合标签）
func _update_active_indicator():
	if not GameData.is_dual_mode or NetworkManager.is_lan:
		# 单人/联机模式：不需要指示
		_update_turn_label("玩家%d的回合" % _active_player)
		return
	
	# 双人同屏：高亮当前激活玩家
	p1_portrait.modulate = Color(1, 1, 1, 1.0) if _active_player == 1 else Color(0.5, 0.5, 0.5, 0.6)
	p2_portrait.modulate = Color(1, 1, 1, 1.0) if _active_player == 2 else Color(0.5, 0.5, 0.5, 0.6)
	
	# 显示双方结束状态
	var p1_status = " ✓" if turn_manager.p1_ended else ""
	var p2_status = " ✓" if turn_manager.p2_ended else ""
	
	if turn_manager.p1_ended and not turn_manager.p2_ended:
		_update_turn_label("玩家2回合%s (P1已结束)" % p2_status)
	elif turn_manager.p2_ended and not turn_manager.p1_ended:
		_update_turn_label("玩家1回合%s (P2已结束)" % p1_status)
	elif turn_manager.p1_ended and turn_manager.p2_ended:
		_update_turn_label("敌人回合...")
	else:
		_update_turn_label("玩家%d回合 (点击头像切换)" % _active_player)
