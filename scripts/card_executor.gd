class_name CardExecutor
extends RefCounted

# ====================================================================
# CardExecutor — 出牌结算的唯一执行入口（Command Pattern 宿主侧）
#
# Lua（或 GDScript 回退）算出一张「结果清单」(Dictionary)，本类原子应用。
# Lua 侧为纯函数：只读 ctx、返回清单，不直接写任何状态——
#   - Lua 中途报错 → 清单没返回 → 这里什么都不执行，状态天然干净
#   - 因此不再需要事务快照/回滚（旧架构每张牌拍 20+ 字段快照）
#
# 同时承载角色被动的结算侧逻辑：
#   huiming  每获得1层禅意，回复1点生命
#   linfeng  每消耗1层剑意，攻击伤害+1
#   moyao    每回合打出的第2张攻击牌，伤害+2
#
# 结果清单字段（全部可选）：
#   damage / repeat_count / armor_break / block / heal / draw / energy_gain
#   is_consumed / chan_add / chan_reset / jianyi_add / jianyi_reset / jianyi_minus
#   add_card_id / discard_other_count / discard_all_others
#   move_other_to_draw / move_draw_if_attack
#   set_power / next_discount / next_two_discount
# ====================================================================

# ---- 依赖注入（hand/played_card 为空时跳过手牌类操作，便于单元测试）----
var player: Player = null
var enemy: Enemy = null
var hand: Node2D = null
var draw_pile: Array = []
var discard_pile: Array = []
var played_card: Node = null            # 正在打出的卡牌节点（手牌操作需排除它）
var played_card_id: String = ""
var played_card_type: int = -1
var track: Dictionary = {}              # 回合追踪：skill_played/energy_used/cards_played/attacks_played
var card_scene: PackedScene = null

const DRAW_PER_TURN: int = 4


func _init(p_player: Player, p_enemy: Enemy, p_hand: Node2D = null,
		p_draw: Array = [], p_discard: Array = [], p_track: Dictionary = {},
		p_card_scene: PackedScene = null):
	player = p_player
	enemy = p_enemy
	hand = p_hand
	draw_pile = p_draw
	discard_pile = p_discard
	track = p_track
	card_scene = p_card_scene


# ====================================================================
# 主入口：原子应用结果清单
# ====================================================================

func apply(result: Dictionary) -> void:
	if result.is_empty():
		return

	var dmg: int = int(result.get("damage", 0))
	var repeat_count: int = maxi(1, int(result.get("repeat_count", 1)))
	var armor_break: int = int(result.get("armor_break", 0))
	var blk: int = int(result.get("block", 0))
	var heal_amt: int = int(result.get("heal", 0))
	var extra_draw: int = int(result.get("draw", 0))
	var eg: int = int(result.get("energy_gain", 0))
	var is_consumed: bool = bool(result.get("is_consumed", false))

	# ---- 剑意消耗（先算加成再改状态）----
	var jianyi_consumed: int = 0
	if result.get("jianyi_reset", false):
		jianyi_consumed += player.jianyi
	var jianyi_minus: int = int(result.get("jianyi_minus", 0))
	if jianyi_minus > 0:
		jianyi_consumed += min(jianyi_minus, player.jianyi)

	# ---- 林风被动：每消耗1层剑意，攻击伤害+1 ----
	if player.character_id == "linfeng" and dmg > 0 and jianyi_consumed > 0:
		dmg += jianyi_consumed
		print("【被动·剑意】消耗%d层剑意 → 伤害+%d" % [jianyi_consumed, jianyi_consumed])

	# ---- 墨瑶被动：每回合第2张攻击牌伤害+2 ----
	if player.character_id == "moyao" and played_card_type == CardData.CardType.ATTACK \
			and int(track.get("attacks_played", 0)) == 1 and dmg > 0:
		dmg += 2
		print("【被动·连弩】本回合第2张攻击牌 → 伤害+2")

	# ---- 龙象般若 POWER：剩余内力提供伤害加成 ----
	if player.power_longxiang and dmg > 0:
		var bonus: int = player.energy * 2
		dmg += bonus
		print("龙象般若 剩余内力%d → 伤害+%d" % [player.energy, bonus])

	# ---- 1. 伤害 ----
	if dmg > 0 or armor_break > 0:
		for i in range(repeat_count):
			enemy.take_damage(dmg, armor_break)

	# ---- 2. 格挡 ----
	if blk > 0:
		player.add_block(blk)

	# ---- 3. 回血 ----
	if heal_amt > 0:
		player.heal(heal_amt)

	# ---- 3.5 生命代价（如"以血换气"：直接扣血，不触发被动/死亡）----
	var hp_cost: int = int(result.get("hp_cost", 0))
	if hp_cost > 0:
		player.hp = maxi(1, player.hp - hp_cost)
		player.hp_changed.emit(player.hp, player.max_hp)
		if player.is_p2:
			GameData.player2_hp = player.hp
		else:
			GameData.player_hp = player.hp

	# ---- 4. 内力（负数=消耗）----
	if eg > 0:
		player.gain_energy(eg)
	elif eg < 0:
		var spend: int = -eg
		player.energy = max(0, player.energy - spend)
		track["energy_used"] = int(track.get("energy_used", 0)) + spend
		player.energy_changed.emit(player.energy, player.max_energy)

	# ---- 5. 抽牌 ----
	if extra_draw > 0:
		draw_cards(extra_draw)

	# ---- 6. 门派资源 ----
	var chan_add: int = int(result.get("chan_add", 0))
	if chan_add > 0:
		player.chan += chan_add
		# 慧明被动：每获得1层禅意，回复1点生命
		if player.character_id == "huiming":
			player.heal(chan_add)
			print("【被动·禅意】获得%d层禅意 → 回复%d生命" % [chan_add, chan_add])
	if result.get("chan_reset", false):
		player.chan = 0
	if jianyi_consumed > 0:
		player.jianyi = max(0, player.jianyi - jianyi_consumed)
	var jianyi_add: int = int(result.get("jianyi_add", 0))
	if jianyi_add > 0:
		player.jianyi += jianyi_add

	# ---- 7. 加牌到手牌 ----
	var add_card_id: String = str(result.get("add_card_id", ""))
	if add_card_id != "":
		_add_card_to_hand(add_card_id)

	# ---- 8. 手牌调整（全部排除正在打出的这张牌）----
	var discard_others: int = int(result.get("discard_other_count", 0))
	for i in range(discard_others):
		_discard_first_other()
	if result.get("discard_all_others", false):
		for c in hand.cards.duplicate() if hand else []:
			if c != played_card:
				discard_pile.append(c.card_data.card_id)
				hand.remove_card(c)
				CardPool.release(c)
	if result.get("move_other_to_draw", false):
		var moved_type := _move_first_other_to_draw()
		if moved_type != -1 and result.get("move_draw_if_attack", false) \
				and moved_type == CardData.CardType.ATTACK:
			draw_cards(1)
			print("袖里乾坤 移走攻击牌 → 抽1")

	# ---- 9. POWER / 折扣 ----
	var set_power: String = str(result.get("set_power", ""))
	if set_power != "":
		_set_power(set_power)
	var next_discount: int = int(result.get("next_discount", 0))
	if next_discount > 0:
		player.next_card_discount = next_discount
	var next_two: int = int(result.get("next_two_discount", 0))
	if next_two > 0:
		track["next_two_discount"] = next_two

	# ---- 10. 打出的牌：弃牌堆 or 消耗 ----
	_finish_played_card(is_consumed)


# ====================================================================
# 回合开始抽牌（供 main 调用，含牌库耗尽回收弃牌堆）
# ====================================================================

func draw_cards(count: int) -> void:
	for i in range(count):
		if draw_pile.size() == 0:
			if discard_pile.size() > 0:
				for cid in discard_pile:
					draw_pile.append(cid)
				discard_pile.clear()
				draw_pile.shuffle()
			else:
				break
		if hand == null or card_scene == null:
			# 无手牌环境（单元测试）：只消费牌堆数组
			draw_pile.pop_back()
			continue
		var card_id = draw_pile.pop_back()
		var data = GameData.load_card(card_id)
		if data == null:
			push_warning("[CardExecutor] 卡牌资源缺失: %s" % card_id)
			continue
		var card = CardPool.acquire(card_scene)
		card.setup(data)
		if not hand.add_card(card):
			CardPool.release(card)


# ====================================================================
# 内部操作
# ====================================================================

func _finish_played_card(is_consumed: bool) -> void:
	if not is_consumed:
		discard_pile.append(played_card_id)
	if hand and played_card and is_instance_valid(played_card):
		hand.remove_card(played_card)
		CardPool.release(played_card)


func _add_card_to_hand(card_id: String) -> void:
	if hand == null or card_scene == null:
		discard_pile.append(card_id)
		return
	var data = GameData.load_card(card_id)
	if data == null:
		return
	var new_card = CardPool.acquire(card_scene)
	new_card.setup(data)
	if not hand.add_card(new_card):
		# 手牌满了 → 进弃牌堆
		CardPool.release(new_card)
		discard_pile.append(card_id)


func _discard_first_other() -> bool:
	if hand == null:
		return false
	for c in hand.cards:
		if c != played_card:
			discard_pile.append(c.card_data.card_id)
			hand.remove_card(c)
			CardPool.release(c)
			return true
	return false


## 把第一张非打出牌移回牌顶。返回移走牌的类型（-1=没牌可移）。
## 注意：必须在 release 前读取 card_type（release 会 reset_pooled 清掉数据）
func _move_first_other_to_draw() -> int:
	if hand == null:
		return -1
	for c in hand.cards:
		if c != played_card:
			var moved_type: int = c.card_data.card_type
			draw_pile.append(c.card_data.card_id)
			hand.remove_card(c)
			CardPool.release(c)
			return moved_type
	return -1


func _set_power(power_name: String) -> void:
	match power_name:
		"damo": player.power_damo = true
		"twoway": player.power_twoway = true
		"bahuang": player.power_bahuang = true
		"longxiang": player.power_longxiang = true
		"xiaoyaoyou": player.power_xiaoyaoyou = true
		"bodhi": player.power_bodhi = true
		_:
			push_warning("[CardExecutor] 未知 POWER: %s" % power_name)


## POWER 回合触发（main._trigger_power_effects 用）。
## battle.lua 返回触发清单，在这里统一结算。
func apply_power_trigger(result: Dictionary) -> void:
	if result.is_empty():
		return
	if result.get("reset_first_hit", false):
		player.first_hit_this_turn = true
	var p_block: int = int(result.get("block", 0))
	if p_block > 0:
		player.add_block(p_block)
	var p_heal: int = int(result.get("heal", 0))
	if p_heal > 0:
		player.heal(p_heal)
	var p_chan: int = int(result.get("chan_add", 0))
	if p_chan > 0:
		player.chan += p_chan
		if player.character_id == "huiming":
			player.heal(p_chan)
	if result.get("bahuang_card", false):
		# 八荒六合：随机获得一张基础牌
		var base_pool: Array = ["strike", "defend", "punch", "meditate"]
		base_pool.shuffle()
		_add_card_to_hand(base_pool[0])
		print("八荒六合：获得 %s" % base_pool[0])
	if result.get("xiaoyaoyou", false):
		player.hand_limit_mod = 2
		player.attack_discounted = true
		print("逍遥游：手牌上限+2，攻击/内力牌费用-1")
