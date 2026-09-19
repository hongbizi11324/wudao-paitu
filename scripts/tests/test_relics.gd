class_name TestRelics
# ==============================
# 遗物系统测试
# 覆盖：获取/去重/随机抽取 / 各钩子效果（战斗开始/回合开始/出牌修正/减伤/回合结束/胜利收益）
# ==============================

static func run() -> bool:
	TestBase.describe("遗物系统：获取与钩子效果")

	GameData.new_run()
	TestBase.assert_eq(GameData.player_relics.size(), 0, "新局无遗物")

	# ---------- 1. 获取与去重 ----------
	TestBase.assert_true(GameData.add_relic("war_token"), "获得遗物")
	TestBase.assert_false(GameData.add_relic("war_token"), "不能重复获得")
	TestBase.assert_true(GameData.has_relic("war_token"), "has_relic 判定")
	TestBase.assert_false(GameData.add_relic("not_exist"), "非法遗物id拒绝")

	# ---------- 2. 随机抽取不重复 ----------
	GameData.new_run()
	for rid in GameData.RELICS.keys():
		GameData.add_relic(rid)
	TestBase.assert_eq(GameData.get_random_relic(), "", "全部拥有后随机返回空")

	GameData.new_run()
	GameData.add_relic("war_token")
	var r1 := GameData.get_random_relic()
	TestBase.assert_true(r1 != "" and r1 != "war_token", "随机抽取排除已拥有")

	# ---------- 3. 战斗开始钩子 ----------
	GameData.new_run()
	GameData.add_relic("iron_bracer")
	GameData.add_relic("qi_furnace")
	var p := TestBase.make_player()
	p.energy = 3
	p.max_energy = 5
	p.energy_per_turn = 3
	p.block = 0
	RelicEffects.on_battle_start(p)
	TestBase.assert_eq(p.block, 5, "玄铁护腕：战斗开始+5格挡")
	TestBase.assert_eq(p.max_energy, 6, "聚气丹炉：内力上限+1")
	TestBase.assert_eq(p.energy, 4, "聚气丹炉：立即+1内力")

	# ---------- 4. 回合开始钩子 ----------
	GameData.new_run()
	GameData.add_relic("prayer_beads")
	GameData.add_relic("snake_gall")
	var p2 := TestBase.make_player()
	p2.chan = 0
	p2.hp = 20   # < 50%
	p2.max_hp = 60
	p2.block = 0
	var track := {}
	var out: Dictionary = RelicEffects.on_turn_start(p2, track)
	TestBase.assert_eq(p2.chan, 1, "菩提佛珠：回合开始+1禅意")
	TestBase.assert_eq(p2.block, 3, "蛇胆：低血时+3格挡")
	TestBase.assert_false(bool(track.get("first_attack_used", true)), "回合标记复位(first_attack_used)")

	# 高血量不触发蛇胆
	p2.hp = 50
	p2.block = 0
	RelicEffects.on_turn_start(p2, {})
	TestBase.assert_eq(p2.block, 0, "蛇胆：满血不触发")

	# 龙脉之心：上回合未受伤则多抽1
	GameData.new_run()
	GameData.add_relic("dragon_vein")
	var track2 := {"took_damage_last_turn": false}
	TestBase.assert_eq(RelicEffects.on_turn_start(p2, track2).get("extra_draw", 0), 1, "龙脉之心：未受伤多抽1")
	var track3 := {"took_damage_last_turn": true}
	TestBase.assert_eq(RelicEffects.on_turn_start(p2, track3).get("extra_draw", 0), 0, "龙脉之心：受伤后不触发")

	# ---------- 5. 出牌清单修正 ----------
	GameData.new_run()
	GameData.add_relic("war_token")
	GameData.add_relic("iron_manual")
	GameData.add_relic("sword_tassel")
	GameData.add_relic("arhat_manual")
	var atk := CardData.new()
	atk.card_id = "strike"
	atk.card_type = CardData.CardType.ATTACK
	var skl := CardData.new()
	skl.card_id = "defend"
	skl.card_type = CardData.CardType.SKILL

	var t1 := {"first_attack_used": false}
	var res_atk := {"damage": 6, "block": 0}
	RelicEffects.modify_card_result(res_atk, atk, p2, t1)
	TestBase.assert_eq(res_atk["damage"], 6 + 1 + 4, "破军令+1 与 剑穗+4（首张攻击）")
	TestBase.assert_eq(res_atk.get("armor_break", 0), 5, "罗汉拳谱：首张攻击破甲+5")
	TestBase.assert_true(bool(t1.get("first_attack_used", false)), "首张攻击标记已消耗")

	# 第二张攻击只吃破军令
	var res_atk2 := {"damage": 6}
	RelicEffects.modify_card_result(res_atk2, atk, p2, t1)
	TestBase.assert_eq(res_atk2["damage"], 7, "第二张攻击仅+1（非首张）")
	TestBase.assert_false(res_atk2.has("armor_break"), "第二张攻击无破甲")

	# 技能牌格挡
	var res_skl := {"block": 5}
	RelicEffects.modify_card_result(res_skl, skl, p2, t1)
	TestBase.assert_eq(res_skl["block"], 7, "铁布衫秘卷：技能牌格挡+2")

	# ---------- 6. 减伤钩子（每回合仅一次）----------
	GameData.new_run()
	GameData.add_relic("heart_mirror")
	var t2 := {}
	TestBase.assert_eq(RelicEffects.modify_incoming_damage(10, t2), 8, "护心镜：首次受击-2")
	TestBase.assert_eq(RelicEffects.modify_incoming_damage(10, t2), 10, "护心镜：同回合第二次不减")

	# ---------- 7. 回合结束钩子（龟息符）----------
	GameData.new_run()
	GameData.add_relic("turtle_charm")
	var p3 := TestBase.make_player()
	p3.hp = 40
	p3.block = 12
	RelicEffects.on_turn_end(p3)
	TestBase.assert_eq(p3.hp, 42, "龟息符：格挡≥10 回复2生命")
	p3.block = 5
	RelicEffects.on_turn_end(p3)
	TestBase.assert_eq(p3.hp, 42, "龟息符：格挡不足不回复")

	# ---------- 8. 战斗胜利收益 ----------
	GameData.new_run()
	GameData.add_relic("coin_sword")
	GameData.add_relic("meditation_cushion")
	GameData.add_relic("blood_jade")
	var p4 := TestBase.make_player()
	p4.hp = 40
	var bonus: Dictionary = RelicEffects.on_battle_end(p4)
	TestBase.assert_eq(bonus["gold"], 10, "铜钱剑：+10金币")
	TestBase.assert_eq(bonus["cultivation"], 5, "悟道蒲团：+5修为")
	TestBase.assert_eq(p4.hp, 46, "血玉：胜利回复6生命")

	# 无遗物时无收益
	GameData.new_run()
	var bonus2: Dictionary = RelicEffects.on_battle_end(p4)
	TestBase.assert_eq(bonus2["gold"], 0, "无遗物无额外金币")

	# ---------- 9. 存档回环 ----------
	GameData.new_run()
	GameData.add_relic("iron_bracer")
	GameData.add_relic("qi_furnace")
	var save_exists := GameData.has_save()
	var backup := ""
	if save_exists:
		var f = FileAccess.open(GameData.SAVE_PATH, FileAccess.READ)
		backup = f.get_as_text() if f else ""
	GameData.save_game()
	GameData.new_run()
	TestBase.assert_eq(GameData.player_relics.size(), 0, "新局清空遗物")
	GameData.load_game()
	TestBase.assert_true(GameData.has_relic("iron_bracer") and GameData.has_relic("qi_furnace"),
		"存档回环：遗物恢复")
	# 恢复原存档
	if save_exists:
		var f2 = FileAccess.open(GameData.SAVE_PATH, FileAccess.WRITE)
		f2.store_string(backup)
		f2.close()
	else:
		GameData.delete_save()

	TestBase.free_node(p)
	TestBase.free_node(p2)
	TestBase.free_node(p3)
	TestBase.free_node(p4)
	# CardData 是 RefCounted，自动回收，不能 free()

	return TestBase.failed == 0
