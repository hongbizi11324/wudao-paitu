extends Node2D

var draw_pile = []   # 牌库
var discard_pile = [] # 弃牌堆
var game_over = false   # 游戏是否结束

# 每回合抽牌数
var cards_per_turn: int = 4

@onready var hand = $Hand
@onready var player = $Player
@onready var enemy = $Enemy
@onready var gm = $GameManager

@onready var hp_label = $HpLabel
@onready var enemy_hp_label = $EnemyHPLabel
@onready var enemy_block_label = $EnemyBlockLabel
@onready var enemy_intent_label = $EnemyIntentLabel
@onready var floor_label = $FloorLabel
@onready var energy_label = $EnergyLabel
@onready var block_label = $BlockLabel
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
@onready var menu_btn = $MenuBtn


func _ready():
	# 连接信号
	hand.card_selected.connect(_on_card_played)
	player.energy_changed.connect(_on_energy_changed)
	player.hp_changed.connect(_on_hp_changed)
	player.block_changed.connect(_on_block_changed)
	enemy.hp_changed.connect(_on_enemy_hp_changed)
	player.died.connect(_on_player_died)
	enemy.died.connect(_on_enemy_died_by_signal)
	enemy.block_changed.connect(_on_enemy_block_changed)
	enemy.intent_changed.connect(_on_enemy_intent_changed)
	reward_screen.card_chosen.connect(_on_reward_chosen)
	reward_screen.skipped.connect(_on_reward_skipped)
	shop_screen.continue_requested.connect(_on_shop_done)
	node_map.node_selected.connect(_on_node_selected)
	rest_screen.closed.connect(_on_rest_closed)
	event_screen.closed.connect(_on_event_closed)
	
	# 新游戏：先选路再开打
	if GameData.current_floor == 1 and not GameData.map_active:
		GameData.generate_new_act()
		node_map.open()
		return
	
	# 正常战斗初始化
	player.init()
	_start_battle()
	_shuffle_deck()
	
	_update_ui()
	_update_deck_ui()
	
	_draw_cards(cards_per_turn)
	_update_turn_label("你的回合")
	_update_deck_ui()
	
	# 创建门派资源标签
	var sl = Label.new()
	sl.name = "SectLabel"
	sl.position = Vector2(20, 32)
	sl.add_theme_color_override("font_color", Color(0.7, 0.9, 1, 1))
	sl.add_theme_font_size_override("font_size", 14)
	add_child(sl)


# ==============================
# 牌库操作
# ==============================

func _shuffle_deck():
	draw_pile = GameData.player_deck.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()


func _draw_cards(count: int):
	var card_scene = load("res://scenes/card.tscn")
	var drawn = 0
	for i in range(count):
		if draw_pile.size() == 0:
			draw_pile = discard_pile.duplicate()
			draw_pile.shuffle()
			discard_pile.clear()
		if draw_pile.size() == 0:
			break
		
		var card_id = draw_pile.pop_back()
		var path = "res://resources/cards/%s.tres" % card_id
		var data = load(path)
		var card = card_scene.instantiate()
		card.setup(data)
		
		if card_id == "punch":
			card.get_node("DescLabel").text = "造成%d点伤害" % GameData.get_punch_damage()
		if card_id == "meditate":
			card.get_node("DescLabel").text = "获得%d点内力" % GameData.get_meditate_gain()
		
		var bonus = GameData.get_damage_bonus()
		if bonus > 0 and card_id != "punch" and card_id != "meditate":
			var desc = card.get_node("DescLabel")
			if data.damage > 0 or data.block > 0:
				desc.text = desc.text + " (+%d)" % bonus
		
		if hand.add_card(card):
			drawn += 1
		else:
			discard_pile.append(card_id)
			card.queue_free()
	
	print("抽了 %d 张牌（手牌 %d，牌库 %d，弃牌 %d）" % [drawn, hand.cards.size(), draw_pile.size(), discard_pile.size()])
	_update_deck_ui()


func _unhandled_input(event):
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		hand.deselect()


# ==============================
# 出牌
# ==============================

func _on_card_played(card):
	if game_over:
		return
	
	var data = card.card_data
	
	# ===== 费用（凌波微步折扣） =====
	var actual_cost = data.cost
	if player.next_card_discount > 0:
		actual_cost = max(0, data.cost - player.next_card_discount)
		player.next_card_discount = 0
	if not player.spend_energy(actual_cost):
		return
	
	# ===== 效果计算 =====
	var times = max(1, data.repeat)
	var dmg = 0
	var blk = 0
	var eg = 0
	var extra_draw = 0
	var is_consumed = false  # true=POWER/小无相功 不进弃牌
	
	match data.card_id:
		# ---- 基础牌特殊结算 ----
		"punch":
			dmg = GameData.get_punch_damage()
		"meditate":
			eg = GameData.get_meditate_gain()
		
		# ---- 🏯 少林 ----
		"sl_fist":
			dmg = 4
			player.chan += 1
			print("罗汉拳 禅意+1 (%d)" % player.chan)
		"sl_iron":
			blk = 6
			player.chan += 1
			print("铁布衫 禅意+1 (%d)" % player.chan)
		"sl_golden":
			blk = 8 + player.chan * 3
			print("金钟罩 消耗%d层禅意 → 格挡%d" % [player.chan, blk])
			player.chan = 0
		"sl_arhat":
			dmg = 6 + player.chan * 4
			print("罗汉伏魔 消耗%d层禅意 → 伤害%d" % [player.chan, dmg])
			player.chan = 0
		"sl_damo":
			player.power_damo = true
			is_consumed = true
			print("达摩一苇 激活！")
		
		# ---- ☯️ 武当 ----
		"wd_taiji":
			blk = 4
			player.jianyi += 1
			print("太极拳 剑意+1 (%d)" % player.jianyi)
		"wd_soft":
			dmg = 5
			if player.jianyi > 0:
				dmg += 4
				player.jianyi -= 1
				print("柔云剑 消耗1剑意 → 伤害%d" % dmg)
		"wd_steps":
			blk = 6
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
		
		# ---- 🦋 逍遥 ----
		"xy_beiming":
			dmg = 4
			# heal 直接用 data.heal = 2
		"xy_lingbo":
			blk = 6
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
			dmg = 7
			if hand.cards.size() <= 3:
				dmg = 12
				print("天山折梅手 手牌≤3 → 伤害12")
		"xy_bahuang":
			player.power_bahuang = true
			is_consumed = true
			print("八荒六合 激活！")
		
		# ---- 默认：通用卡牌（用数据值+境界加成） ----
		_:
			dmg = data.damage + GameData.get_damage_bonus()
			blk = data.block + GameData.get_block_bonus()
	
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
		_draw_cards(data.draw + extra_draw)
	
	# ===== 弃牌/消耗 =====
	if not is_consumed:
		discard_pile.append(card.card_data.card_id)
	
	hand.remove_card(card)
	card.queue_free()
	_update_deck_ui()
	_update_sect_ui()
	
	if enemy.hp <= 0:
		_on_battle_end(true)


# ==============================
# 回合管理
# ==============================

func _on_end_turn():
	if game_over:
		return
	if hand.selected_card != null:
		hand.deselect()
	
	for c in hand.cards.duplicate():
		if c.card_data.retain:
			continue
		discard_pile.append(c.card_data.card_id)
		hand.remove_card(c)
		c.queue_free()
	
	end_turn_btn.disabled = true
	turn_label.text = "敌人回合"
	gm.start_enemy_turn(player, enemy)
	
	if game_over:
		return
	
	_draw_cards(cards_per_turn)
	
	# POWER效果（新回合开始触发）
	_trigger_power_effects()
	
	_update_ui()
	end_turn_btn.disabled = false
	_update_turn_label("你的回合")


# ==============================
# 门派POWER回合触发
# ==============================

func _trigger_power_effects():
	# 重置太极两仪标记
	player.first_hit_this_turn = true
	
	# 达摩一苇：每回合+2禅意+3格挡
	if player.power_damo:
		player.chan += 2
		player.add_block(3)
		print("达摩一苇：禅意+2，格挡+3")
	
	# 八荒六合：每回合回3HP + 随机基础牌
	if player.power_bahuang:
		player.heal(3)
		var base_pool = ["strike", "defend", "punch", "meditate"]
		base_pool.shuffle()
		var card_id = base_pool[0]
		var path = "res://resources/cards/%s.tres" % card_id
		var data = load(path)
		var card_scene = load("res://scenes/card.tscn")
		var card = card_scene.instantiate()
		card.setup(data)
		if hand.add_card(card):
			print("八荒六合：回复3HP，获得 %s" % card_id)
		else:
			card.queue_free()
			discard_pile.append(card_id)


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
		var pool = [
			"punch", "meditate", "light_step",
			"double_strike", "tactics", "iron_wall", "vigor", "whirlwind",
			"flowing_cloud_sword", "triple_stab", "sword_energy",
			"iron_shirt", "vajra_fist", "golden_bell",
			"strike", "defend", "bash", "heal",
			# ---- 门派卡 ----
			"sl_fist", "sl_iron", "sl_golden", "sl_arhat",
			"wd_taiji", "wd_soft", "wd_steps", "wd_heavy",
			"xy_beiming", "xy_lingbo", "xy_wuxiang", "xy_zhemel"
		]
		# POWER卡（达摩一苇/太极两仪/八荒六合）不出现在奖励池，商店才能买
		pool.shuffle()
		var options = pool.slice(0, 3)
		reward_screen.open(options)
	else:
		_update_turn_label("败北...")
		retry_btn.visible = true
		menu_btn.visible = true


func _on_player_died():
	_on_battle_end(false)


func _on_enemy_died_by_signal():
	if not game_over:
		_on_battle_end(true)


func _on_retry():
	game_over = false
	end_turn_btn.disabled = false
	retry_btn.visible = false
	menu_btn.visible = false
	player.init()
	_start_battle()
	_shuffle_deck()
	hand.clear()
	_update_ui()
	_draw_cards(cards_per_turn)
	_update_turn_label("你的回合")
	_update_deck_ui()


func _on_back_to_menu():
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


# ==============================
# 战斗奖励 → 地图节点
# ==============================

func _on_reward_chosen(card_id: String):
	GameData.add_card(card_id)
	print("选择了奖励卡牌: %s" % card_id)
	_show_map()


func _on_reward_skipped():
	print("跳过了奖励")
	_show_map()


func _show_map():
	# 显示杀戮尖塔风格地图
	# 如果当前大关已完成（打完Boss），生成新的大关
	if GameData.is_map_complete():
		GameData.generate_new_act()
	node_map.open()


# ==============================
# 地图节点选择
# ==============================

func _on_node_selected(node_type: int):
	match node_type:
		GameData.NodeType.BATTLE_NORMAL, GameData.NodeType.BATTLE_ELITE:
			# 战斗节点 → 进入战斗场景
			get_tree().reload_current_scene()
		
		GameData.NodeType.SHOP:
			# 商店
			_open_shop()
		
		GameData.NodeType.REST:
			# 休息点
			$RestScreen.open()
		
		GameData.NodeType.EVENT:
			# 随机事件
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
	
	_show_map()


# ==============================
# 商店
# ==============================

func _open_shop():
	shop_screen.open()


func _on_shop_done():
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
		parts.append("🏯禅%d" % player.chan)
	if player.jianyi > 0:
		parts.append("☯剑%d" % player.jianyi)
	var sl = get_node_or_null("SectLabel")
	if sl:
		sl.text = "  ".join(parts) if parts.size() > 0 else ""

func _update_deck_ui():
	deck_label.text = "牌库 %d" % draw_pile.size()
	discard_label.text = "弃牌 %d" % discard_pile.size()

func _on_energy_changed(cur, max_val):
	energy_label.text = "内力 %d/%d" % [cur, max_val]

func _on_hp_changed(cur, max_val):
	hp_label.text = "HP %d/%d" % [cur, max_val]

func _on_block_changed(cur):
	block_label.text = "格挡 %d" % cur if cur > 0 else ""

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
		var shuffled = draw_pile.duplicate()
		shuffled.shuffle()
		pile_viewer.open(shuffled, "牌库")


func _on_discard_label_clicked(event: InputEvent):
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		pile_viewer.open(discard_pile, "弃牌堆")


# ==============================
# 楼层与战斗初始化
# ==============================

func _start_battle():
	var ft = GameData.get_floor_type()
	var ft_names = ["普通", "精英", "Boss"]
	enemy.init_from_floor(GameData.current_floor, ft)
	_update_floor_label()
	print("===== 第 %d 层 · %s战 =====" % [GameData.current_floor, ft_names[ft]])


func _update_floor_label():
	var ft = GameData.get_floor_type()
	var ft_names = ["战斗", "⚔精英", "♛Boss"]
	floor_label.text = "第 %d 层 · %s" % [GameData.current_floor, ft_names[ft]]


func _update_turn_label(suffix: String):
	turn_label.text = "%s境 · %s" % [GameData.realm_names[GameData.current_realm], suffix]
