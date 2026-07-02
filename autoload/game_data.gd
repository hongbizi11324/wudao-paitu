extends Node

# ==============================
# 全局游戏数据（自动加载）
# 武道牌途 — 跨战斗数据
# ==============================

# ---------- 境界系统 ----------

var realm_names = [
	"淬体", "先天", "筑基", "金丹", "元婴",
	"化神", "合体", "大乘", "武帝"
]

var current_realm: int = 0         # 当前境界索引 (0-8)
var cultivation: int = 0           # 当前修为（突破用）
var cultivation_to_next: int = 20  # 突破所需修为
var gold: int = 0                   # 金币（商店用）
var max_energy_per_realm: int = 3  # 初始内力上限（淬体境）

# ---------- 角色 ----------

var selected_character: String = ""  # 选择的角色ID

var character_data = {
	"huiming": {
		"name": "慧明", "title": "禅宗行者",
		"desc": "自幼出家，精通佛法与武学",
		"school": "shaolin"
	},
	"linfeng": {
		"name": "林风", "title": "剑道奇才",
		"desc": "山林中领悟剑意，快意恩仇",
		"school": "wudang"
	},
	"yunzhi": {
		"name": "云止", "title": "逍遥散人",
		"desc": "云游四方，随性而为",
		"school": "xiaoyao"
	},
	"moyao": {
		"name": "墨瑶", "title": "墨门传人",
		"desc": "精通机关术与暗器",
		"school": ""
	},
	"xuanweng": {
		"name": "玄翁", "title": "隐世奇人",
		"desc": "隐居深山，精通奇门遁甲",
		"school": ""
	},
	"yexiao": {
		"name": "夜啸", "title": "江湖浪客",
		"desc": "独行江湖，出手狠辣",
		"school": ""
	}
}

# ---------- 玩家跨战斗数据 ----------

var player_hp: int = 60
var player_max_hp: int = 60

# ---------- 楼层系统 ----------

enum FloorType { NORMAL, ELITE, BOSS }

var current_floor: int = 1         # 当前楼层（从第1层开始）


func get_floor_type() -> FloorType:
	return _calc_floor_type(current_floor)


func get_enemy_hp() -> int:
	var multiplier = pow(1.2, current_floor - 1)
	var base_hp = ceili(25 * multiplier)
	match _calc_floor_type(current_floor):
		FloorType.ELITE:
			return ceili(base_hp * 1.5)
		FloorType.BOSS:
			return ceili(base_hp * 2.5)
		_:
			return base_hp


func get_enemy_damage_range() -> Array:
	var multiplier = pow(1.2, current_floor - 1)
	var dmg_min = maxi(1, ceili(3 * multiplier))
	var dmg_max = maxi(2, ceili(6 * multiplier))
	match _calc_floor_type(current_floor):
		FloorType.ELITE:
			dmg_min = ceili(dmg_min * 1.2)
			dmg_max = ceili(dmg_max * 1.2)
		FloorType.BOSS:
			dmg_min = ceili(dmg_min * 1.5)
			dmg_max = ceili(dmg_max * 1.5)
	return [dmg_min, dmg_max]


func _calc_floor_type(floor_num: int) -> FloorType:
	if floor_num % 6 == 0:
		return FloorType.BOSS
	if floor_num % 3 == 0:
		return FloorType.ELITE
	return FloorType.NORMAL


func advance_floor():
	current_floor += 1
	print("【楼层推进】当前第 %d 层" % current_floor)


# ---------- 地图节点系统 ----------

enum NodeType {
	BATTLE_NORMAL,
	BATTLE_ELITE,
	SHOP,
	REST,
	EVENT
}

# 为当前楼层生成节点选项（返回 NodeType 数组）
func generate_node_options() -> Array:
	var options = []
	
	# 始终包含一个战斗节点
	var battles = [NodeType.BATTLE_NORMAL]
	# 如果是精英/Boss楼层，加入精英战斗选项
	var ft = _calc_floor_type(current_floor)
	if ft == FloorType.ELITE or ft == FloorType.BOSS:
		battles.append(NodeType.BATTLE_ELITE)
	
	# 从战斗池里随机选一个
	battles.shuffle()
	options.append(battles[0])
	
	# 其余格子：非战斗节点
	var non_battle = [NodeType.SHOP, NodeType.REST, NodeType.EVENT]
	non_battle.shuffle()
	
	# 选 1-2 个非战斗节点（总共 2-3 个选项）
	var extra_count = randi() % 2 + 1  # 1 或 2
	for i in range(min(extra_count, non_battle.size())):
		options.append(non_battle[i])
	
	options.shuffle()
	print("【节点】第 %d 层选项: " % current_floor, options)
	return options


# ---------- 随机事件数据 ----------

var event_pool = [
	{
		"id": "merchant",
		"title": "行脚商人",
		"desc": "一位行脚商人迎面走来，他车上的卡牌琳琅满目。「小友，今日有缘，给你打个五折，要不要看看？」",
		"options": [
			{"text": "买一张（半价5金币，随机卡牌）", "action": "buy_discount"},
			{"text": "囊中羞涩，算了", "action": "skip"}
		]
	},
	{
		"id": "wounded",
		"title": "受伤武者",
		"desc": "路边躺着一位浑身是血的武者，看到你后艰难地抬起手。「小兄弟…救我一命…必有重谢…」",
		"options": [
			{"text": "耗费气血救他（-5HP，获得一张随机卡牌）", "action": "help"},
			{"text": "多一事不如少一事", "action": "skip"}
		]
	},
	{
		"id": "chest",
		"title": "神秘宝箱",
		"desc": "路中央放着一个古朴的青铜宝箱，上面刻满了看不懂的符文，似乎在等你打开。",
		"options": [
			{"text": "打开看看（获得 20 金币 + 5 修为）", "action": "open"},
			{"text": "可能有诈，绕路走", "action": "skip"}
		]
	},
	{
		"id": "garden",
		"title": "废弃药园",
		"desc": "一片早已废弃的药园，杂草丛生中竟还藏着几株泛着微光的灵药。",
		"options": [
			{"text": "采集灵药（恢复 15 HP）", "action": "heal"},
			{"text": "药园可能有主，别惹麻烦", "action": "skip"}
		]
	},
	{
		"id": "cave",
		"title": "修炼洞府",
		"desc": "一处隐蔽的洞府，石壁上刻满了先辈的修炼心得，虽然年代久远但字迹依然清晰。",
		"options": [
			{"text": "静心参悟（获得 15 修为）", "action": "cultivate"},
			{"text": "赶路要紧，不能耽搁", "action": "skip"}
		]
	}
]


# 随机获取一个未用的事件
func get_random_event() -> Dictionary:
	var pool = event_pool.duplicate()
	pool.shuffle()
	return pool[0]


# ---------- 卡牌池 ----------

var all_card_pool = [
	"punch", "meditate", "light_step", "strike", "defend",
	"double_strike", "tactics", "iron_wall", "vigor", "whirlwind",
	"flowing_cloud_sword", "triple_stab", "sword_energy",
	"iron_shirt", "vajra_fist", "golden_bell",
	"bash", "heal",
	# ---- 门派卡 ----
	"sl_fist", "sl_iron", "sl_golden", "sl_arhat",
	"wd_taiji", "wd_soft", "wd_steps", "wd_heavy",
	"xy_beiming", "xy_lingbo", "xy_wuxiang", "xy_zhemel",
	# ---- 门派核心（商店专用） ----
	"sl_damo", "wd_twoway", "xy_bahuang"
]


# 随机获取一张玩家牌组中没有的卡牌
func get_random_new_card() -> String:
	var pool = all_card_pool.duplicate()
	pool.shuffle()
	for card_id in pool:
		if not player_deck.has(card_id):
			return card_id
	return all_card_pool[randi() % all_card_pool.size()]


# ---------- 牌组 ----------

var player_deck: Array = []

var starter_deck = [
	"punch", "punch", "punch",
	"meditate", "meditate", "meditate",
	"strike", "defend",
	"light_step", "light_step"
]


# ---------- 境界加成 ----------

func get_damage_bonus() -> int:
	return current_realm


func get_block_bonus() -> int:
	return current_realm


func get_punch_damage() -> int:
	match current_realm:
		0: return 2
		1: return 4
		2: return 5
		3: return 6
		_: return 8

func get_meditate_gain() -> int:
	match current_realm:
		0: return 1
		1: return 2
		2: return 2
		3: return 3
		_: return 4


# ---------- 操作 ----------

const BUY_PRICE: int = 10
const DELETE_PRICE: int = 6


func new_run():
	current_floor = 1
	current_realm = 0
	cultivation = 0
	cultivation_to_next = 20
	gold = 20
	max_energy_per_realm = 3
	player_deck = starter_deck.duplicate()
	player_hp = 60
	player_max_hp = 60
	selected_character = ""
	print("【新局】第1层·淬体境起步，牌组 %d 张" % player_deck.size())


func new_run_custom(deck: Array):
	current_floor = 1
	current_realm = 0
	cultivation = 0
	cultivation_to_next = 20
	gold = 999
	max_energy_per_realm = 3
	player_deck = deck.duplicate()
	player_hp = 60
	player_max_hp = 60
	print("【测试】第1层·自定义牌组 %d 张" % player_deck.size())


func add_cultivation(amount: int):
	cultivation += amount
	print("修为 +%d（%d/%d）" % [amount, cultivation, cultivation_to_next])
	while cultivation >= cultivation_to_next and current_realm < 8:
		_breakthrough()


func spend_cultivation(amount: int) -> bool:
	if cultivation < amount:
		return false
	cultivation -= amount
	print("修为 -%d（剩余 %d）" % [amount, cultivation])
	return true


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	print("金币 -%d（剩余 %d）" % [amount, gold])
	return true


func add_gold(amount: int):
	gold += amount
	print("金币 +%d（共 %d）" % [amount, gold])


func remove_card_from_deck(card_id: String) -> bool:
	var idx = player_deck.find(card_id)
	if idx == -1:
		return false
	player_deck.remove_at(idx)
	print("牌组 -%s（剩余 %d 张）" % [card_id, player_deck.size()])
	return true


func _breakthrough():
	cultivation -= cultivation_to_next
	current_realm += 1
	max_energy_per_realm += 1
	cultivation_to_next = 20 + current_realm * 10
	print("🎉 突破！当前境界：%s 境，内力上限：%d" % [
		realm_names[current_realm], max_energy_per_realm
	])


func add_card(card_id: String):
	player_deck.append(card_id)
	print("牌组 +%s（共 %d 张）" % [card_id, player_deck.size()])


func heal_player(percent: float):
	player_hp = mini(player_max_hp, player_hp + ceili(player_max_hp * percent))
	print("玩家恢复 %d%% 血量，当前 %d/%d" % [percent * 100, player_hp, player_max_hp])


# ============================================================
# 杀戮尖塔风格地图系统
# ============================================================

const MAP_NODES_PER_LAYER: int = 3    # 每层3个节点位
var map_active: bool = false           # 地图是否已激活
var map_layers: Array = []             # 每层的节点数据
var map_connections: Array = []        # 连线: [{from_layer,from_node,to_layer,to_node}]
var map_node_states: Array = []        # 每个节点状态: "locked" / "available" / "visited" / "boss"
var map_current_offset: int = 0        # 当前在地图中的层偏移 (0=第一层可选层)
var map_act_count: int = -1            # 第几个大关（-1表示未开始，第一次generate变为0）


func get_map_floor(offset: int) -> int:
	"""地图内第 offset 层对应的实际楼层号"""
	# 大关起始楼层 = 第一层可选楼层
	# 第1大关: 楼层2-6 (5层可选，含Boss)
	# 第2大关: 楼层7-11的下一大关 楼层8-12
	# 公式: start = (当前大关 * 6) + 2
	var start_floor = map_act_count * 6 + 2
	return start_floor + offset


func get_layer_count() -> int:
	"""当前大关的可选层数（含Boss层）"""
	return map_layers.size()


func generate_new_act():
	"""生成一个大关的地图布局"""
	map_act_count += 1
	var start_floor = map_act_count * 6 + 2  # 第1大关从第2层开始
	map_current_offset = 0
	map_layers = []
	map_connections = []
	map_node_states = []
	
	# 计算当前大关包含多少层（直到下个Boss）
	var total_layers = 0
	for f in range(start_floor, start_floor + 10):  # 最多10层
		total_layers += 1
		if f % 6 == 0:  # Boss层
			break
	
	# 生成每层的节点
	for i in range(total_layers):
		var floor_num = start_floor + i
		var ft = _calc_floor_type(floor_num)
		var nodes = _gen_layer_nodes(ft, i, total_layers)
		map_layers.append(nodes)
	
	# 初始化节点状态层
	for i in range(total_layers):
		var states = []
		for j in range(map_layers[i].size()):
			states.append("locked")
		map_node_states.append(states)
	
	# 第一层全部可用
	for j in range(map_layers[0].size()):
		map_node_states[0][j] = "available"
	
	# 生成路径连线
	_generate_map_connections(total_layers)
	
	# 解锁第一层节点
	for j in range(map_layers[0].size()):
		map_node_states[0][j] = "available"
	
	map_active = true
	print("【地图】第%d大关生成! 起始楼层=%d, 共%d层, 节点:%s" % [
		map_act_count, start_floor, total_layers, _dump_map()
	])


func _gen_layer_nodes(ft: FloorType, layer_idx: int, total: int) -> Array:
	"""生成一层的节点列表"""
	# 如果是Boss层，只有1个Boss节点
	if ft == FloorType.BOSS or layer_idx == total - 1:
		return [{ "type": NodeType.BATTLE_ELITE, "is_boss": true }]
	
	var nodes = []
	
	# 确保至少包含正确的战斗节点
	nodes.append({ "type": NodeType.BATTLE_NORMAL })
	
	# 第2/3个节点随机选
	var pool = [NodeType.SHOP, NodeType.REST, NodeType.EVENT, NodeType.BATTLE_NORMAL]
	if ft == FloorType.ELITE:
		pool.append(NodeType.BATTLE_ELITE)
	
	pool.shuffle()
	for i in range(MAP_NODES_PER_LAYER - 1):
		var chosen = pool[i % pool.size()]
		# 避免同一层全是战斗
		var battle_count = 0
		for n in nodes:
			if n.type == NodeType.BATTLE_NORMAL or n.type == NodeType.BATTLE_ELITE:
				battle_count += 1
		if chosen == NodeType.BATTLE_NORMAL or chosen == NodeType.BATTLE_ELITE:
			if battle_count >= 2:
				# 换一个非战斗
				for alt in [NodeType.SHOP, NodeType.REST, NodeType.EVENT]:
					if not _has_type(nodes, alt):
						chosen = alt
						break
		nodes.append({ "type": chosen })
	
	# 打乱顺序
	nodes.shuffle()
	return nodes


func _has_type(nodes: Array, node_type: int) -> bool:
	for n in nodes:
		if n.type == node_type:
			return true
	return false


func _generate_map_connections(total_layers: int):
	"""在各层之间生成路径连线"""
	for i in range(total_layers - 1):
		var from_layer = i
		var to_layer = i + 1
		
		var from_count = map_layers[from_layer].size()
		var to_count = map_layers[to_layer].size()
		
		for fi in range(from_count):
			# 每个节点连接到下一层 1-2 个节点
			var targets = []
			
			# Boss层或最后一层：全部连到唯一节点
			if to_count == 1:
				targets = [0]
			else:
				# 随机连接 1-2 个
				var count = randi() % 2 + 1
				var candidates = range(to_count)
				candidates.shuffle()
				for j in range(min(count, candidates.size())):
					targets.append(candidates[j])
			
			for ti in targets:
				map_connections.append({
					"from_layer": from_layer,
					"from_node": fi,
					"to_layer": to_layer,
					"to_node": ti
				})
		
		# 确保下层每个节点至少有1条入线
		for ti in range(to_count):
			var has_incoming = false
			for c in map_connections:
				if c.to_layer == to_layer and c.to_node == ti:
					has_incoming = true
					break
			if not has_incoming:
				# 随机连一个上层节点过来
				var fi = randi() % from_count
				map_connections.append({
					"from_layer": from_layer,
					"from_node": fi,
					"to_layer": to_layer,
					"to_node": ti
				})


func select_map_node(layer_offset: int, node_idx: int) -> Dictionary:
	"""玩家选择了某个节点，返回节点数据，更新状态"""
	if layer_offset < 0 or layer_offset >= map_layers.size():
		return {}
	if node_idx < 0 or node_idx >= map_layers[layer_offset].size():
		return {}
	if map_node_states[layer_offset][node_idx] != "available":
		return {}
	
	# 标记为已访问
	map_node_states[layer_offset][node_idx] = "visited"
	map_current_offset = layer_offset
	
	# 锁定同层其他节点
	for j in range(map_layers[layer_offset].size()):
		if j != node_idx and map_node_states[layer_offset][j] == "available":
			map_node_states[layer_offset][j] = "locked"
	
	# 如果有下一层，解锁可达节点
	var next_offset = layer_offset + 1
	if next_offset < map_layers.size():
		for c in map_connections:
			if c.from_layer == layer_offset and c.from_node == node_idx:
				if c.to_layer == next_offset:
					if map_node_states[c.to_layer][c.to_node] == "locked":
						map_node_states[c.to_layer][c.to_node] = "available"
	
	# 推进楼层
	var floor_num = get_map_floor(layer_offset)
	current_floor = floor_num
	print("【地图】选择第%d层节点[%d], 推进至第%d层" % [layer_offset, node_idx, floor_num])
	
	return map_layers[layer_offset][node_idx]


func advance_map():
	"""从非战斗节点出来，推进到当前层的下一层"""
	map_current_offset += 1
	print("【地图】推进至偏移 %d/%d" % [map_current_offset, map_layers.size() - 1])


func is_map_complete() -> bool:
	"""当前大关是否已完成（打完Boss）"""
	if not map_active or map_layers.is_empty():
		return false
	return map_current_offset >= map_layers.size() - 1


func _dump_map() -> String:
	var s = ""
	for i in range(map_layers.size()):
		var names = []
		for j in range(map_layers[i].size()):
			var n = map_layers[i][j]
			var type_str = ["战","⚔","商","休","?"]
			var ts = type_str[n.type]
			if n.has("is_boss") and n.is_boss:
				ts = "♛"
			var st = map_node_states[i][j][0]  # l/a/v
			names.append(ts + "[" + st + "]")
		s += "层%d: %s | " % [i, " ".join(names)]
	return s
