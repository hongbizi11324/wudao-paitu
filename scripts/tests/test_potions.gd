class_name TestPotions
# ==============================
# 丹药（消耗品）系统测试
# 覆盖：携带上限 / 使用效果 / 消耗 / 烈火酒加成 / 掉落概率 / 存档
# ==============================

static func run(parent: Node) -> bool:
	TestBase.describe("丹药系统：携带/使用/效果")

	GameData.new_run()
	TestBase.assert_eq(GameData.player_potions.size(), 0, "新局无丹药")

	# ---------- 1. 携带上限 ----------
	TestBase.assert_true(GameData.add_potion("small_pill"), "获得丹药")
	GameData.add_potion("focus_powder")
	GameData.add_potion("vajra_pill")
	TestBase.assert_eq(GameData.player_potions.size(), GameData.MAX_POTIONS, "携带上限=3")
	TestBase.assert_false(GameData.add_potion("swift_powder"), "满格后不能再获得")
	TestBase.assert_false(GameData.add_potion("not_exist"), "非法丹药id拒绝")

	# ---------- 2. 使用效果 ----------
	var player := TestBase.make_player()
	var enemy := TestBase.make_enemy()
	var hand := TestBase.make_hand(parent)
	var dp: Array = ["strike", "defend", "heal", "vigor"]
	var dc: Array = []
	var ex := CardExecutor.new(player, enemy, hand, dp, dc, {})
	ex.card_scene = load("res://scenes/card.tscn")
	var track := {}
	var ctx := {"player": player, "enemy": enemy, "track": track, "executor": ex}

	# 小还丹：回15血
	player.hp = 30
	TestBase.assert_true(PotionEffects.use("small_pill", ctx), "小还丹使用成功")
	TestBase.assert_eq(player.hp, 45, "小还丹回复15生命")

	# 凝神散：+2内力
	player.energy = 1
	PotionEffects.use("focus_powder", ctx)
	TestBase.assert_eq(player.energy, 3, "凝神散+2内力")

	# 金刚丹：+12格挡
	player.block = 0
	PotionEffects.use("vajra_pill", ctx)
	TestBase.assert_eq(player.block, 12, "金刚丹+12格挡")

	# 疾风散：抽2张
	var hand_before := hand.cards.size()
	PotionEffects.use("swift_powder", ctx)
	TestBase.assert_eq(hand.cards.size(), hand_before + 2, "疾风散抽2张")

	# 烈火酒：本回合攻击牌+4（通过 apply_attack_bonus）
	PotionEffects.use("fire_wine", ctx)
	TestBase.assert_eq(int(track.get("potion_attack_bonus", 0)), 4, "烈火酒标记+4")
	var atk := CardData.new()
	atk.card_type = CardData.CardType.ATTACK
	var res := {"damage": 6}
	PotionEffects.apply_attack_bonus(res, atk, track)
	TestBase.assert_eq(res["damage"], 10, "烈火酒：攻击牌+4伤害")
	var skl := CardData.new()
	skl.card_type = CardData.CardType.SKILL
	var res2 := {"damage": 0, "block": 5}
	PotionEffects.apply_attack_bonus(res2, skl, track)
	TestBase.assert_eq(res2["block"], 5, "烈火酒不影响技能牌")

	# 化功散：破甲25 + 8伤害
	var e2 := TestBase.make_enemy()
	e2.hp = 40
	e2.block = 30
	var ctx2 := {"player": player, "enemy": e2, "track": {}, "executor": ex}
	PotionEffects.use("melt_powder", ctx2)
	TestBase.assert_true(e2.block < 30, "化功散摧毁护盾（30→%d）" % e2.block)
	TestBase.assert_true(e2.hp < 40, "化功散造成伤害（40→%d）" % e2.hp)

	# 九转金丹：内力上限+2并回满
	var p3 := TestBase.make_player()
	p3.max_energy = 5
	p3.energy_per_turn = 3
	p3.energy = 1
	PotionEffects.use("golden_pill", {"player": p3, "enemy": enemy, "track": {}, "executor": ex})
	TestBase.assert_eq(p3.max_energy, 7, "九转金丹：内力上限+2")
	TestBase.assert_eq(p3.energy, 7, "九转金丹：内力回满")

	# ---------- 3. 消耗与移除 ----------
	GameData.new_run()
	GameData.add_potion("small_pill")
	TestBase.assert_true(GameData.remove_potion("small_pill"), "移除丹药")
	TestBase.assert_eq(GameData.player_potions.size(), 0, "移除后数量归零")
	TestBase.assert_false(GameData.remove_potion("small_pill"), "移除不存在的丹药失败")

	# ---------- 4. 随机抽取与掉落 ----------
	GameData.new_run()
	var drop_seen := false
	for i in range(200):
		var pid := GameData.get_random_potion("")
		if pid != "" and GameData.POTIONS.has(pid):
			drop_seen = true
	TestBase.assert_true(drop_seen, "随机丹药返回合法id")

	# Boss 掉落 100%
	GameData.current_floor = 6
	GameData.player_potions.clear()
	var boss_drop := GameData.roll_potion_drop()
	TestBase.assert_true(boss_drop != "", "Boss战必掉丹药")
	# 背包满则不掉落
	GameData.add_potion("small_pill")
	GameData.add_potion("small_pill")
	GameData.add_potion("small_pill")
	TestBase.assert_eq(GameData.roll_potion_drop(), "", "背包满时不掉落")
	GameData.current_floor = 1

	# ---------- 5. 存档回环 ----------
	GameData.new_run()
	GameData.add_potion("golden_pill")
	var save_exists := GameData.has_save()
	var backup := ""
	if save_exists:
		var f = FileAccess.open(GameData.SAVE_PATH, FileAccess.READ)
		backup = f.get_as_text() if f else ""
	GameData.save_game()
	GameData.new_run()
	GameData.load_game()
	TestBase.assert_true(GameData.player_potions.has("golden_pill"), "存档回环：丹药恢复")
	if save_exists:
		var f2 = FileAccess.open(GameData.SAVE_PATH, FileAccess.WRITE)
		f2.store_string(backup)
		f2.close()
	else:
		GameData.delete_save()

	hand.clear()
	hand.queue_free()
	TestBase.free_node(player)
	TestBase.free_node(enemy)
	TestBase.free_node(e2)
	TestBase.free_node(p3)
	ex = null

	return TestBase.failed == 0
