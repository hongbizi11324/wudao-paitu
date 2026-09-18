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
var is_dual_mode: bool = false  # 是否双人模式
var selected_character_2: String = "" # P2选择的角色ID（双人模式）

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
		"name": "云芷", "title": "逍遥散人",
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

# 双人模式 - 玩家2数据
var player2_hp: int = 60
var player2_max_hp: int = 60
var player2_deck: Array = []
var player2_realm: int = 0

# ---------- 楼层系统 ----------

enum FloorType { NORMAL, ELITE, BOSS }

var current_floor: int = 1         # 当前楼层（从第1层开始）


func get_floor_type() -> FloorType:
	return _calc_floor_type(current_floor)


## 敌人数值曲线（1.15 复合增长 + 类型系数）：
## 普通层 floor10 ≈ 88 HP、精英 ×1.4、Boss ×3.8
## Boss 系数经平衡模型标定：玩家境界成长（内力上限+1/境）使输出增长快于
## 1.15^n，旧 ×2.2 会让第6层 Boss 仅 4 回合被秒。×3.8 后第6层≈7回合、第12层≈10回合。
func get_enemy_hp() -> int:
	var multiplier = pow(1.15, current_floor - 1)
	var base_hp = ceili(25 * multiplier)
	match _calc_floor_type(current_floor):
		FloorType.ELITE:
			return ceili(base_hp * 1.4)
		FloorType.BOSS:
			return ceili(base_hp * 3.8)
		_:
			return base_hp


func get_enemy_damage_range() -> Array:
	var multiplier = pow(1.15, current_floor - 1)
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


# 楼层推进的唯一入口是地图：select_map_node() 选中节点时直接把
# current_floor 设为该节点的楼层号。
# ⚠️ 曾有 bug：选战斗节点后额外调 advance_floor() 再 +1，导致
# Boss 楼（每 6 层）永远错位成普通战。禁止再写任何"再推进一层"的函数。


# ---------- 地图节点系统 ----------

enum NodeType {
	BATTLE_NORMAL,
	BATTLE_ELITE,
	SHOP,
	REST,
	EVENT
}

# ---------- 战斗奖励（按楼层类型缩放，与地图悬停提示一致） ----------

func get_battle_reward() -> Dictionary:
	match _calc_floor_type(current_floor):
		FloorType.BOSS:
			return {"cultivation": 40, "gold": 50}
		FloorType.ELITE:
			return {"cultivation": 20, "gold": 20}
		_:
			return {"cultivation": 10, "gold": 12}


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
	},
	{
		"id": "hermit",
		"title": "隐世高人",
		"desc": "一位鹤发童颜的老者席地而坐，见你路过微微一笑：「小友骨骼清奇，老夫这有一门绝学，想不想学？」",
		"options": [
			{"text": "传功（消耗 20 修为，随机获得一张新卡牌）", "action": "teach"},
			{"text": "请教一二（获得 5 修为）", "action": "ask"},
			{"text": "不敢叨扰前辈", "action": "skip"}
		]
	},
	{
		"id": "duel",
		"title": "拦路武者",
		"desc": "一名武者横刀立于路中央：「此路是我开！要从此过，先胜过我手中这把刀！」",
		"options": [
			{"text": "接受挑战（-12 HP，胜者得 25 修为 + 15 金币）", "action": "fight"},
			{"text": "绕路而行", "action": "skip"}
		]
	},
	{
		"id": "hotspring",
		"title": "灵泉",
		"desc": "山涧中一汪温泉雾气氤氲，泉水泛着淡淡的灵光，泡上一泡定能祛除疲惫、疏通经脉。",
		"options": [
			{"text": "浸泡灵泉（花费 8 金币，恢复 40% 最大生命）", "action": "bath"},
			{"text": "灵气可能有害，绕行", "action": "skip"}
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
	"xy_xiaoyaoyou", "xy_xingluo", "xy_fengjuan",
	"xy_guicang", "xy_fuguang", "xy_yufeng",
	"xy_duanliu", "xy_wanxiang", "xy_xiuli",
	"xy_lianhuan", "xy_houfa", "xy_jinghua",
	"xy_wujian", "xy_xushi", "xy_yixing",
	"xy_hantan", "xy_qiguan", "xy_tuna",
	"xy_longxiang", "xy_baoyuan", "xy_xixing",
	"xy_guanxing", "xy_fange", "xy_yibizhi", "xy_duotian",
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


# ---------- 门派感知卡池 ----------

# 通用基础卡（所有角色可获得）
const NEUTRAL_CARDS: Array = [
	"punch", "meditate", "light_step", "strike", "defend",
	"double_strike", "tactics", "iron_wall", "vigor", "whirlwind",
	"flowing_cloud_sword", "triple_stab", "sword_energy",
	"iron_shirt", "vajra_fist", "golden_bell", "bash", "heal",
	# 新卡（2026-09-18）
	"thunder_strike", "iron_skin", "blood_exchange", "spirit_guard", "whirlwind_slash",
]

# 门派专属卡
const SCHOOL_CARDS: Dictionary = {
	"shaolin": ["sl_fist", "sl_iron", "sl_golden", "sl_arhat", "sl_damo", "sl_bodhi"],
	"wudang": ["wd_taiji", "wd_soft", "wd_steps", "wd_heavy", "wd_twoway", "wd_sanqing"],
	"xiaoyao": [
		"xy_beiming", "xy_lingbo", "xy_wuxiang", "xy_zhemel", "xy_bahuang",
		"xy_xiaoyaoyou", "xy_xingluo", "xy_fengjuan", "xy_guicang", "xy_fuguang",
		"xy_yufeng", "xy_duanliu", "xy_wanxiang", "xy_xiuli", "xy_lianhuan",
		"xy_houfa", "xy_jinghua", "xy_wujian", "xy_xushi", "xy_yixing",
		"xy_hantan", "xy_qiguan", "xy_tuna", "xy_longxiang", "xy_baoyuan",
		"xy_xixing", "xy_guanxing", "xy_fange", "xy_yibizhi", "xy_duotian",
		"xy_taixu",
	],
}


## 角色可选卡池 = 通用 + 本门派专属。
## extra_schools: 双人模式下另一名玩家的门派也并入（奖励/商店对全队开放）
func get_character_pool(character_id: String = "", extra_schools: Array = []) -> Array:
	var cid = character_id if character_id != "" else selected_character
	var pool: Array = NEUTRAL_CARDS.duplicate()
	var schools: Array = [character_data.get(cid, {}).get("school", "")]
	schools.append_array(extra_schools)
	for sk in schools:
		if sk is String and sk != "" and SCHOOL_CARDS.has(sk):
			for c in SCHOOL_CARDS[sk]:
				if not pool.has(c):
					pool.append(c)
	return pool


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
		0: return 5
		1: return 6
		2: return 7
		3: return 8
		_: return 10

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


# ==============================
# 进入一局游戏的唯一入口（A3 修复）
# ==============================

## 设置本局的模式，并重置与之绑定的派生状态。
##
## 这是全项目【唯一】允许写 is_dual_mode 的地方。
##
## 为什么要收敛：AutoLoad 挂在 SceneTree 根下，change_scene_to_file 只换
## current_scene、不碰 AutoLoad，所以 AutoLoad 上的状态是进程级的，
## 上一局的模式会残留到下一局。原先有 8 个地方直接给 is_dual_mode 赋值，
## 分散在 3 个文件里，漏掉的那个（"测试牌组"入口）就是 bug 来源。
##
## 规则：放在 AutoLoad 上的每一份状态，都必须有明确的重置点。
func start_run(dual: bool, from_save: bool = false) -> void:
	is_dual_mode = dual
	loading_save = from_save
	print("[GameData] start_run: dual=%s from_save=%s" % [dual, from_save])


# ==============================
# 新游戏初始化（完整重置所有持久状态）
# ==============================

func _reset_map_state():
	map_active = false
	map_act_count = -1
	map_layers = []
	map_connections = []
	map_node_states = []
	map_current_offset = 0
	loading_save = false


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
	selected_character_2 = ""
	player2_hp = 60
	player2_max_hp = 60
	player2_deck = []
	player2_realm = 0
	_reset_map_state()
	print("【新局】第1层·淬体境起步，牌组 %d 张" % player_deck.size())


func new_run_custom(deck: Array):
	new_run()
	gold = 999
	player_deck = deck.duplicate()
	print("【测试】第1层·自定义牌组 %d 张" % player_deck.size())


# ---------- 双人模式函数 ----------

func new_dual_run():
	new_run()
	# 玩家2初始化（new_run 已把 P1 初始化完成）
	player2_hp = 60
	player2_max_hp = 60
	player2_deck = starter_deck.duplicate()
	player2_realm = 0
	print("【双人模式】第1层·双玩家起步，每人 %d 张牌" % player_deck.size())


func heal_player2(percent: float):
	player2_hp = mini(player2_max_hp, player2_hp + ceili(player2_max_hp * percent))
	print("玩家2恢复 %d%% 血量，当前 %d/%d" % [percent * 100, player2_hp, player2_max_hp])


func add_card_to_player2(card_id: String):
	player2_deck.append(card_id)
	print("玩家2牌组 +%s（共 %d 张）" % [card_id, player2_deck.size()])


func remove_card_from_player2_deck(card_id: String) -> bool:
	var idx = player2_deck.find(card_id)
	if idx == -1:
		return false
	player2_deck.remove_at(idx)
	print("玩家2牌组 -%s（剩余 %d 张）" % [card_id, player2_deck.size()])
	return true


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

# ---- 战斗场景生态 ----
enum Biome { FOREST, VILLAGE, GOV_OFFICE, SECT }

const MAP_COLUMN_COUNT: int = 7          # 地图列数（杀戮尖塔风格）
const MAP_TOTAL_LAYERS: int = 12         # 每大关总层数（含起点+Boss）
const MAP_NODE_MIN_PER_LAYER: int = 1    # 每层最少节点
const MAP_NODE_MAX_PER_LAYER: int = 3    # 每层最多节点
var current_biome: Biome = Biome.FOREST  # 当前大关的战斗场景
var map_active: bool = false           # 地图是否已激活
var loading_save: bool = false        # 正在从存档加载（标记，防止冲突）
var map_layers: Array = []             # 每层的节点数据
var map_connections: Array = []        # 连线: [{from_layer,from_node,to_layer,to_node}]
var map_node_states: Array = []        # 每个节点状态: "locked" / "available" / "visited" / "boss"
var map_current_offset: int = 0        # 当前在地图中的层偏移 (0=第一层可选层)
var map_act_count: int = -1            # 第几个大关（-1表示未开始，第一次generate变为0）


func get_map_floor(offset: int) -> int:
	"""地图内第 offset 层对应的实际楼层号。offset 0=起点"""
	var start_floor = map_act_count * MAP_TOTAL_LAYERS + 1
	return start_floor + offset


func get_layer_count() -> int:
	"""当前大关的可选层数（含Boss层）"""
	return map_layers.size()


func generate_new_act():
	"""
	生成一个大关的地图布局。
	固定12层：0=起点 → 1~10=路径 → 11=Boss
	同时随机选取本大关的战斗场景（biome）。
	"""
	map_act_count += 1
	var start_floor = map_act_count * MAP_TOTAL_LAYERS + 1
	map_current_offset = 0
	map_layers = []
	map_connections = []
	map_node_states = []
	var total_layers = MAP_TOTAL_LAYERS
	
	# 根据大关随机选场景
	if map_act_count == 0:
		current_biome = [Biome.FOREST, Biome.VILLAGE].pick_random()
	else:
		current_biome = [Biome.GOV_OFFICE, Biome.SECT].pick_random()
	
	# 生成每层节点
	for i in range(total_layers):
		var floor_num = start_floor + i
		var ft = _calc_floor_type(floor_num)
		var nodes = _gen_column_nodes(ft, i, total_layers)
		map_layers.append(nodes)
	
	# 先生成连线
	_gen_column_connections()
	
	# 再初始化状态
	for i in range(total_layers):
		var states = []
		for j in range(map_layers[i].size()):
			if i == 0:
				states.append("visited")  # 起点已访问
			else:
				states.append("locked")
		map_node_states.append(states)
	
	# 解锁从起点出发可达的下一层节点
	for c in map_connections:
		if c.from_layer == 0 and c.to_layer == 1:
			map_node_states[c.to_layer][c.to_node] = "available"
	
	map_active = true
	print("【地图】第%d大关生成! 起始楼层=%d, 共%d层, %s" % [
		map_act_count, start_floor, total_layers, _dump_map()
	])


# ============================================================
# Column-based 节点生成 (12层: 起点→路径→Boss)
# ============================================================

func _gen_column_nodes(ft: FloorType, layer_idx: int, total: int) -> Array:
	"""
	按列生成一层的节点。每个节点: {type, col, is_boss?, is_start?}
	layer 0 = 起点（固定col=3）
	layer 1~7 = 随机列 (1-3个节点)
	layer 8~10 = 汇拢（限制中间列，最多2个）
	layer 11 = Boss（col=3）
	"""
	if layer_idx == 0:
		return [{ "type": NodeType.EVENT, "col": int(MAP_COLUMN_COUNT / 2.0), "is_start": true }]
	if layer_idx == total - 1:
		return [{ "type": NodeType.BATTLE_ELITE, "is_boss": true, "col": int(MAP_COLUMN_COUNT / 2.0) }]
	
	var count = randi_range(MAP_NODE_MIN_PER_LAYER, MAP_NODE_MAX_PER_LAYER)
	
	# 建列候选池
	var all_cols: Array
	if layer_idx >= total - 4:
		# 末尾汇拢：限制在中间4列，最多2个节点
		all_cols = [2, 3, 4]
		all_cols.shuffle()
		count = mini(count, 2)
	else:
		all_cols = range(MAP_COLUMN_COUNT)
		all_cols.shuffle()
	
	var used_cols = all_cols.slice(0, count)
	used_cols.sort()
	
	# 构造节点类型池
	var types = []
	if ft == FloorType.ELITE:
		types.append(NodeType.BATTLE_ELITE)
	else:
		types.append(NodeType.BATTLE_NORMAL)

	var pool = [NodeType.BATTLE_NORMAL, NodeType.SHOP, NodeType.REST, NodeType.EVENT]
	if ft == FloorType.ELITE:
		pool.append(NodeType.BATTLE_ELITE)
	if ft == FloorType.BOSS:
		# Boss楼层：唯一战斗节点即Boss战，其余候选全为非战斗
		pool = [NodeType.SHOP, NodeType.REST, NodeType.EVENT]
	pool.shuffle()
	
	for i in range(count - 1):
		var chosen = pool[i % pool.size()]
		var battle_count = 0
		for t in types:
			if t == NodeType.BATTLE_NORMAL or t == NodeType.BATTLE_ELITE:
				battle_count += 1
		if battle_count >= 2 and (chosen == NodeType.BATTLE_NORMAL or chosen == NodeType.BATTLE_ELITE):
			for alt in [NodeType.SHOP, NodeType.REST, NodeType.EVENT]:
				if not types.has(alt):
					chosen = alt
					break
		types.append(chosen)
	
	types.shuffle()
	var nodes = []
	for i in range(count):
		nodes.append({ "type": types[i], "col": used_cols[i] })
	
	# 大关中Boss楼层（每6层，如第6/18层）：该层的战斗节点标记 is_boss，
	# 地图用Boss图标显示，战斗用Boss数值（否则图标与实际难度不符）
	if ft == FloorType.BOSS:
		for node in nodes:
			if node.type == NodeType.BATTLE_NORMAL or node.type == NodeType.BATTLE_ELITE:
				node.is_boss = true
	nodes.sort_custom(func(a, b): return a.col < b.col)
	return nodes


func _gen_column_connections():
	"""
	Column-based 连线生成。
	规则：只连列差 <= 1 的相邻列节点，确保每个节点至少有一条路。
	"""
	map_connections = []
	
	for i in range(map_layers.size() - 1):
		var cur = map_layers[i]
		var nxt = map_layers[i + 1]
		
		# 为当前层每个节点找下一层的连接目标
		for ci in range(cur.size()):
			var node = cur[ci]
			
			# 找下一层相邻列（col diff <= 1）的节点
			var candidates = []
			for ni in range(nxt.size()):
				if abs(node.col - nxt[ni].col) <= 1:
					candidates.append(ni)
			
			if candidates.size() > 0:
				# 随机连1-2个
				candidates.shuffle()
				var conn_count = mini(randi_range(1, 2), candidates.size())
				for j in range(conn_count):
					map_connections.append({
						"from_layer": i, "from_node": ci,
						"to_layer": i + 1, "to_node": candidates[j]
					})
			else:
				# 没有相邻列的，连列差最近的一个
				var closest_ni = 0
				var min_dist = 999
				for ni in range(nxt.size()):
					var dist = abs(node.col - nxt[ni].col)
					if dist < min_dist:
						min_dist = dist
						closest_ni = ni
				map_connections.append({
					"from_layer": i, "from_node": ci,
					"to_layer": i + 1, "to_node": closest_ni
				})
		
		# 确保下层每个节点至少有1条入线
		for ni in range(nxt.size()):
			var has_incoming = false
			for c in map_connections:
				if c.to_layer == i + 1 and c.to_node == ni:
					has_incoming = true
					break
			if not has_incoming:
				# 找上层最近节点连过来
				var closest_ci = 0
				var min_dist = 999
				for ci in range(cur.size()):
					var dist = abs(nxt[ni].col - cur[ci].col)
					if dist < min_dist:
						min_dist = dist
						closest_ci = ci
				map_connections.append({
					"from_layer": i, "from_node": closest_ci,
					"to_layer": i + 1, "to_node": ni
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
			if n.has("is_start") and n.is_start:
				ts = "出"
			var st = map_node_states[i][j][0]  # l/a/v
			names.append("%s(C%d)[%s]" % [ts, n.col, st])
		s += "层%d: %s | " % [i, " ".join(names)]
	return s


# ==============================
# 存档系统
# ==============================

const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://save.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save():
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
		print("[存档] 已删除")


func save_game():
	var data = {
		"version": SAVE_VERSION,
		# 模式标志必须进存档：它决定游戏行为，不存的话读档回来行为就变了（A4）
		"is_dual_mode": is_dual_mode,
		"player": {
			"character": selected_character,
			"realm": current_realm,
			"cultivation": cultivation,
			"gold": gold,
			"hp": player_hp,
			"max_hp": player_max_hp,
			"deck": player_deck.duplicate()
		},
		"player2": {
			"character": selected_character_2,
			"realm": player2_realm,
			"hp": player2_hp,
			"max_hp": player2_max_hp,
			"deck": player2_deck.duplicate()
		},
		"progress": {
			"current_floor": current_floor,
			"biome": current_biome,
			"act_count": map_act_count,
			"map_active": map_active,
			"map_offset": map_current_offset,
			"map_layers": map_layers.duplicate(),
			"map_connections": map_connections.duplicate(),
			"map_node_states": map_node_states.duplicate()
		},
		"settings": {
			"music": BgmManager.is_enabled if BgmManager else true
		}
	}
	
	var json_str = JSON.stringify(data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		print("[存档] 已保存")
	else:
		push_error("[存档] 写入失败: " + SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	
	var json_str = file.get_as_text()
	var parsed = JSON.parse_string(json_str)
	if parsed == null:
		push_error("[存档] 解析失败")
		return false
	
	# 模式标志：老存档没有这个字段，用 get 兜底（A4）
	is_dual_mode = parsed.get("is_dual_mode", false)

	var p = parsed["player"]
	selected_character = p["character"]
	current_realm = p["realm"]
	cultivation = p["cultivation"]
	gold = p["gold"]
	player_hp = p["hp"]
	player_max_hp = p["max_hp"]
	player_deck = p["deck"]
	
	var p2 = parsed.get("player2", {})
	selected_character_2 = p2.get("character", "")
	player2_realm = p2.get("realm", 0)
	player2_hp = p2.get("hp", 60)
	player2_max_hp = p2.get("max_hp", 60)
	player2_deck = p2.get("deck", [])
	
	var prog = parsed.get("progress", {})
	current_floor = prog.get("current_floor", 1)
	current_biome = prog.get("biome", 0)
	map_act_count = prog.get("act_count", -1)
	map_active = prog.get("map_active", false)
	map_current_offset = prog.get("map_offset", 0)
	# JSON 会把整数转成浮点数（1→1.0），恢复成 int
	# JSON 会把整数转成浮点数（1→1.0），恢复成 int
	map_layers = _fix_int_fields(prog.get("map_layers", []))
	map_connections = _fix_int_fields(prog.get("map_connections", []))
	map_node_states = prog.get("map_node_states", [])
	
	# 恢复设置
	var sett = parsed.get("settings", {})
	var music_on = sett.get("music", true)
	if BgmManager:
		if music_on != BgmManager.is_enabled:
			BgmManager.toggle()
	
	print("[存档] 已读取")
	return true


# JSON 序列化会把整数变浮点，递归修复所有层
func _fix_int_fields(data) -> Array:
	var result = []
	for item in data:
		var t = typeof(item)
		if t == TYPE_DICTIONARY:
			var fixed = {}
			for k in item:
				var v = item[k]
				if typeof(v) == TYPE_FLOAT and v == floor(v):
					v = int(v)
				elif typeof(v) == TYPE_ARRAY:
					v = _fix_int_fields(v)
				fixed[k] = v
			result.append(fixed)
		elif t == TYPE_ARRAY:
			result.append(_fix_int_fields(item))
		else:
			result.append(item)
	return result
