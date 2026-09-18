class_name TestEnemy
# ==============================
# 敌人机制测试
# 覆盖：意图类型分布 / 力量成长加成 / 多段攻击 / 目标选择 / Boss三阶段
# ==============================

static func run() -> bool:
	TestBase.describe("敌人机制：意图/力量/多段攻击")

	GameData.new_run()
	GameData.map_act_count = 0

	# ---------- 1. 普通敌人意图分布 ----------
	var e := Enemy.new()
	e.init_from_floor(1, Enemy.FloorType.NORMAL)
	var seen := {}
	for i in range(200):
		e.plan_intent()
		seen[e.intent_type] = true
	TestBase.assert_true(seen.has(Enemy.IntentType.ATTACK), "普通敌人会出现单次攻击")
	TestBase.assert_true(seen.has(Enemy.IntentType.DEFEND), "普通敌人会出现防御")
	TestBase.assert_true(seen.has(Enemy.IntentType.MULTI_ATTACK), "普通敌人会出现多段攻击")

	# ---------- 2. 精英会出现力量成长 ----------
	var elite := Enemy.new()
	elite.init_from_floor(3, Enemy.FloorType.ELITE)
	var elite_seen := {}
	for i in range(300):
		elite.plan_intent()
		elite_seen[elite.intent_type] = true
	TestBase.assert_true(elite_seen.has(Enemy.IntentType.BUFF), "精英会出现强化意图")
	TestBase.assert_true(elite_seen.has(Enemy.IntentType.MULTI_ATTACK), "精英会出现多段攻击")

	# ---------- 3. 力量成长影响攻击伤害 ----------
	var e2 := Enemy.new()
	e2.init_from_floor(1, Enemy.FloorType.NORMAL)
	e2.strength = 0
	var dmg_before := e2._calc_attack_damage()
	e2.strength = 5
	var dmg_after := e2._calc_attack_damage()
	TestBase.assert_true(dmg_after > dmg_before, "力量提升攻击伤害（%d → %d）" % [dmg_before, dmg_after])

	# BUFF 意图执行 → 力量累积
	e2.strength = 0
	e2.intent_type = Enemy.IntentType.BUFF
	e2.intent_value = 2
	e2.execute_intent(null)
	TestBase.assert_eq(e2.strength, 2, "强化意图 +2 力量")
	e2.intent_value = 3
	e2.execute_intent(null)
	TestBase.assert_eq(e2.strength, 5, "强化可累积（2+3=5）")

	# ---------- 4. 多段攻击段数与伤害 ----------
	var e3 := Enemy.new()
	e3.init_from_floor(1, Enemy.FloorType.NORMAL)
	e3.base_damage_min = 10
	e3.base_damage_max = 10
	e3.strength = 0
	e3._set_multi_attack(3)
	TestBase.assert_eq(e3.intent_times, 3, "多段攻击段数=3")
	TestBase.assert_true(e3.is_multi_attack(), "is_multi_attack 判定")
	# 单段 = 单次伤害 55%
	TestBase.assert_eq(e3.intent_value, ceili(10 * 0.55), "多段单段伤害=55%%")
	e3.intent_times = 1
	e3._set_attack()
	TestBase.assert_eq(e3.intent_value, 10, "单次攻击伤害=基础")
	TestBase.assert_false(e3.is_multi_attack(), "非多段判定")

	# ---------- 5. 多段攻击实际连击（game_manager 执行）----------
	var target := TestBase.make_player()
	target.hp = 60
	target.block = 0
	target.character_id = ""
	var e4 := Enemy.new()
	e4.init_from_floor(1, Enemy.FloorType.NORMAL)
	e4.intent_type = Enemy.IntentType.MULTI_ATTACK
	e4.intent_times = 3
	e4.intent_value = 4
	e4.strength = 0
	var gm: Node = load("res://scripts/game_manager.gd").new()
	var alive: bool = gm.execute_enemy_turn([target], e4)
	TestBase.assert_true(alive, "多段攻击后玩家存活")
	TestBase.assert_eq(target.hp, 60 - 12, "多段攻击 4×3 = 12 伤害")

	# 格挡逐段吸收
	var target2 := TestBase.make_player()
	target2.hp = 60
	target2.block = 5
	target2.character_id = ""
	var e5 := Enemy.new()
	e5.init_from_floor(1, Enemy.FloorType.NORMAL)
	e5.intent_type = Enemy.IntentType.MULTI_ATTACK
	e5.intent_times = 2
	e5.intent_value = 4
	e5.strength = 0
	gm.execute_enemy_turn([target2], e5)
	# 第一段：格挡5吸收4（余1）；第二段：格挡1吸收1，余3进血
	TestBase.assert_eq(target2.hp, 57, "多段攻击逐段被格挡吸收")

	# ---------- 6. 目标选择（双人）----------
	var p1 := TestBase.make_player()
	var p2 := TestBase.make_player()
	p2.is_p2 = true
	var e6 := Enemy.new()
	e6.init_from_floor(1, Enemy.FloorType.NORMAL)
	var picked := {}
	for i in range(60):
		var t = e6.choose_target([p1, p2])
		picked[t] = true
	TestBase.assert_true(picked.size() == 2, "双人模式下两个玩家都可能被选为目标")
	# 阵亡玩家不会被选
	p2.hp = 0
	TestBase.assert_eq(e6.choose_target([p1, p2]), p1, "阵亡玩家不作为目标")

	# ---------- 7. Boss 三阶段 ----------
	var boss := Enemy.new()
	boss.init_from_floor(6, Enemy.FloorType.BOSS)
	# 高血量：可能防御/强化
	boss.hp = boss.max_hp
	var phase1_seen := {}
	for i in range(200):
		boss.hp = boss.max_hp
		boss.plan_intent()
		phase1_seen[boss.intent_type] = true
	TestBase.assert_true(phase1_seen.has(Enemy.IntentType.DEFEND), "Boss一阶段会叠盾")
	# 低血量狂暴：只攻击/多段
	var rage_ok := true
	for i in range(200):
		boss.hp = int(boss.max_hp * 0.2)
		boss.plan_intent()
		if boss.intent_type != Enemy.IntentType.ATTACK and boss.intent_type != Enemy.IntentType.MULTI_ATTACK:
			rage_ok = false
			break
	TestBase.assert_true(rage_ok, "Boss三阶段(HP<33%)只会攻击")

	# ---------- 8. 力量在初始化时重置 ----------
	boss.strength = 9
	boss.init_from_floor(6, Enemy.FloorType.BOSS)
	TestBase.assert_eq(boss.strength, 0, "重新初始化重置力量")

	# 清理
	for n in [e, elite, e2, e3, e4, e5, e6, boss, target, target2, p1, p2]:
		TestBase.free_node(n)
	gm.free()

	return TestBase.failed == 0
