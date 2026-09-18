class_name TestCardExecutor
# ==============================
# CardExecutor 单元测试
# 覆盖：数值结算 / 角色被动 / 手牌操作（排除打出牌）/ 牌库回收 / POWER 触发
# ==============================

static func run(parent: Node) -> bool:
	TestBase.describe("CardExecutor 出牌结算")

	# ---------- 1. 基础伤害 + repeat ----------
	var player := TestBase.make_player()
	var enemy := TestBase.make_enemy()
	var ex := CardExecutor.new(player, enemy)
	ex.apply({"damage": 6})
	TestBase.assert_eq(enemy.hp, 34, "基础伤害 6")

	ex.apply({"damage": 3, "repeat_count": 3})
	TestBase.assert_eq(enemy.hp, 25, "repeat×3 伤害 9")

	# ---------- 2. 格挡 / 回血 / 内力 ----------
	player.block = 0
	player.hp = 40
	player.energy = 1
	ex.apply({"block": 5, "heal": 10, "energy_gain": 2})
	TestBase.assert_eq(player.block, 5, "格挡+5")
	TestBase.assert_eq(player.hp, 50, "回血+10")
	TestBase.assert_eq(player.energy, 3, "内力+2")

	# ---------- 3. 负内力 = 消耗并追踪 ----------
	var track := {"energy_used": 0}
	ex.track = track
	ex.apply({"energy_gain": -2})
	TestBase.assert_eq(player.energy, 1, "负内力消耗")
	TestBase.assert_eq(track["energy_used"], 2, "消耗计入追踪")

	# ---------- 4. 慧明被动：获得禅意回血 ----------
	var huiming := TestBase.make_player("huiming")
	huiming.hp = 50
	var ex2 := CardExecutor.new(huiming, enemy)
	ex2.apply({"chan_add": 3})
	TestBase.assert_eq(huiming.chan, 3, "禅意+3")
	TestBase.assert_eq(huiming.hp, 53, "慧明被动：每层禅意回1血")

	# ---------- 5. 林风被动：消耗剑意加伤害 ----------
	var linfeng := TestBase.make_player("linfeng")
	linfeng.jianyi = 3
	var enemy2 := TestBase.make_enemy()
	var ex3 := CardExecutor.new(linfeng, enemy2)
	ex3.apply({"damage": 5, "jianyi_reset": true})
	TestBase.assert_eq(enemy2.hp, 40 - 5 - 3, "林风被动：消耗3剑意伤害+3")
	TestBase.assert_eq(linfeng.jianyi, 0, "剑意清零")

	# ---------- 6. 墨瑶被动：第2张攻击牌 +2 ----------
	var moyao := TestBase.make_player("moyao")
	var enemy3 := TestBase.make_enemy()
	var ex4 := CardExecutor.new(moyao, enemy3)
	ex4.played_card_type = CardData.CardType.ATTACK
	ex4.track = {"attacks_played": 1}
	ex4.apply({"damage": 4})
	TestBase.assert_eq(enemy3.hp, 34, "墨瑶被动：第2张攻击牌伤害+2")

	# ---------- 7. 龙象般若：剩余内力×2 加伤 ----------
	moyao.character_id = ""
	var dragon := TestBase.make_player()
	dragon.power_longxiang = true
	dragon.energy = 2
	var enemy4 := TestBase.make_enemy()
	var ex5 := CardExecutor.new(dragon, enemy4)
	ex5.apply({"damage": 4})
	TestBase.assert_eq(enemy4.hp, 40 - 4 - 4, "龙象般若：2内力加伤4")

	# ---------- 8. 手牌操作（排除正在打出的牌）----------
	var hand := TestBase.make_hand(parent)
	var c_strike = TestBase.make_card(parent, "strike")
	var c_defend = TestBase.make_card(parent, "defend")
	var c_heal = TestBase.make_card(parent, "heal")
	hand.add_card(c_strike)
	hand.add_card(c_defend)
	hand.add_card(c_heal)

	var p2 := TestBase.make_player()
	var enemy5 := TestBase.make_enemy()
	var draw_pile: Array = []
	var discard_pile: Array = []
	var ex6 := CardExecutor.new(p2, enemy5, hand, draw_pile, discard_pile, {})
	ex6.played_card = c_strike
	ex6.played_card_id = "strike"
	ex6.played_card_type = CardData.CardType.ATTACK
	ex6.card_scene = load("res://scenes/card.tscn")
	ex6.apply({"damage": 1, "discard_other_count": 1})

	TestBase.assert_eq(hand.cards.size(), 1, "断水流：弃1+打出1 → 手牌剩1")
	TestBase.assert_eq(discard_pile.size(), 2, "弃牌堆：其他牌+打出的牌")
	TestBase.assert_eq(discard_pile[0], "defend", "弃掉的是第一张非打出牌")
	TestBase.assert_eq(discard_pile[1], "strike", "打出的牌最后入弃牌堆")

	# ---------- 9. 牌库耗尽回收弃牌堆 ----------
	var hand2 := TestBase.make_hand(parent)
	var p3 := TestBase.make_player()
	var dp: Array = []
	var dc: Array = ["strike", "defend"]
	var ex7 := CardExecutor.new(p3, enemy5, hand2, dp, dc, {})
	ex7.card_scene = load("res://scenes/card.tscn")
	ex7.draw_cards(5)
	TestBase.assert_eq(hand2.cards.size(), 2, "空牌库回收弃牌堆抽2")
	TestBase.assert_eq(dc.size(), 0, "弃牌堆被清空")
	TestBase.assert_eq(dp.size(), 0, "抽完后牌库为空")

	# ---------- 10. 万象归一：弃所有其他手牌 ----------
	var hand3 := TestBase.make_hand(parent)
	var m_played = TestBase.make_card(parent, "bash")
	var m_a = TestBase.make_card(parent, "strike")
	var m_b = TestBase.make_card(parent, "defend")
	hand3.add_card(m_played)
	hand3.add_card(m_a)
	hand3.add_card(m_b)
	var dp2: Array = []
	var dc2: Array = []
	var ex8 := CardExecutor.new(p3, enemy5, hand3, dp2, dc2, {})
	ex8.played_card = m_played
	ex8.played_card_id = "bash"
	ex8.card_scene = load("res://scenes/card.tscn")
	ex8.apply({"damage": 6, "discard_all_others": true})
	TestBase.assert_eq(hand3.cards.size(), 0, "万象归一：全部弃光")
	TestBase.assert_eq(dc2.size(), 3, "弃牌堆3张")

	# ---------- 11. 袖里乾坤：移牌回牌顶+攻击抽1 ----------
	var hand4 := TestBase.make_hand(parent)
	var x_played = TestBase.make_card(parent, "defend")
	var x_other = TestBase.make_card(parent, "strike")
	hand4.add_card(x_played)
	hand4.add_card(x_other)
	var dp3: Array = []
	var dc3: Array = []
	var ex9 := CardExecutor.new(p3, enemy5, hand4, dp3, dc3, {})
	ex9.played_card = x_played
	ex9.played_card_id = "defend"
	ex9.card_scene = load("res://scenes/card.tscn")
	# 移走 attack 前先保证有牌可抽
	dp3.append("heal")
	ex9.apply({"move_other_to_draw": true, "move_draw_if_attack": true})
	TestBase.assert_eq(hand4.cards.size(), 1, "袖里乾坤：移走1张→抽1张回手")
	TestBase.assert_eq(dp3.size(), 1, "移走的牌回到牌库")

	# ---------- 12. add_card：手牌满 → 进弃牌堆 ----------
	var hand5 := TestBase.make_hand(parent)
	hand5.apply_limit_mod(-5)  # 上限降到5，方便造满
	for i in range(5):
		hand5.add_card(TestBase.make_card(parent, "strike"))
	var dc4: Array = []
	var ex10 := CardExecutor.new(p3, enemy5, hand5, [], dc4, {})
	ex10.card_scene = load("res://scenes/card.tscn")
	ex10.played_card = hand5.cards[0]
	ex10.played_card_id = "bash"
	ex10.apply({"add_card_id": "heal"})
	TestBase.assert_eq(hand5.cards.size(), 4, "手牌满不加（打出的牌已移出）")
	TestBase.assert_eq(dc4, ["heal", "bash"], "满时新牌进弃牌堆（打出牌也入堆）")

	# ---------- 13. POWER 触发清单 ----------
	var bhp := TestBase.make_player("huiming")
	bhp.hp = 40
	bhp.power_damo = true
	bhp.power_bahuang = true
	var hand6 := TestBase.make_hand(parent)
	var ex11 := CardExecutor.new(bhp, enemy5, hand6, [], [], {})
	ex11.card_scene = load("res://scenes/card.tscn")
	ex11.apply_power_trigger({"reset_first_hit": true, "chan_add": 2, "block": 3, "heal": 3, "bahuang_card": true})
	TestBase.assert_eq(bhp.chan, 2, "达摩：禅意+2")
	TestBase.assert_eq(bhp.block, 3, "达摩：格挡+3")
	TestBase.assert_eq(bhp.hp, 45, "八荒回3 + 慧明被动回2")
	TestBase.assert_eq(hand6.cards.size(), 1, "八荒：获得1张基础牌")
	TestBase.assert_true(bhp.first_hit_this_turn, "回合标记复位")

	# ---------- 14. set_power ----------
	var sp := TestBase.make_player()
	var ex12 := CardExecutor.new(sp, enemy5)
	ex12.apply({"set_power": "twoway", "is_consumed": true})
	TestBase.assert_true(sp.power_twoway, "set_power=twoway")
	ex12.apply({"set_power": "bodhi", "is_consumed": true})
	TestBase.assert_true(sp.power_bodhi, "set_power=bodhi")

	# ---------- 15. hp_cost（以血换气：直接扣血不触发被动）----------
	var hc := TestBase.make_player("xuanweng")  # 玄翁被动：首击格挡+2
	hc.hp = 30
	hc.block = 0
	var enemy6 := TestBase.make_enemy()
	var ex13 := CardExecutor.new(hc, enemy6)
	ex13.apply({"hp_cost": 3, "energy_gain": 2, "draw": 1})
	TestBase.assert_eq(hc.hp, 27, "hp_cost 扣3血")
	TestBase.assert_eq(hc.block, 0, "hp_cost 不触发玄翁被动(直接扣血)")

	# 清理
	for h in [hand, hand2, hand3, hand4, hand5, hand6]:
		h.clear()
		h.queue_free()
	for n in [player, enemy, huiming, linfeng, enemy2, moyao, enemy3, dragon, enemy4, p2, enemy5, p3, bhp, sp, hc, enemy6]:
		TestBase.free_node(n)

	return TestBase.failed == 0
