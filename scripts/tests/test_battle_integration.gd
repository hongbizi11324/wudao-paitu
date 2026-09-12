class_name TestBattleIntegration
# ==============================
# 战斗流程集成测试（真实 main.tscn 场景）
# 覆盖：开局抽牌 → 出牌（Lua路径）→ 牌量守恒 → 结束回合 → 敌人回合 → 回到玩家回合
# ==============================

static func run(parent: Node) -> bool:
	TestBase.describe("战斗流程集成测试")

	# 干净的单人局
	GameData.start_run(false)
	GameData.new_run()
	GameData.selected_character = "huiming"
	GameData._reset_map_state()
	GameData.map_act_count = -1
	GameData.generate_new_act()   # 让 _ready 走"续战直接开打"分支

	var tree := parent.get_tree()
	var scene = load("res://scenes/main.tscn").instantiate()
	parent.add_child(scene)
	await tree.process_frame
	await tree.process_frame

	# ---------- 1. 开局：抽4张，牌量守恒 ----------
	TestBase.assert_eq(scene.hand1.cards.size(), 4, "开局抽4张")
	TestBase.assert_eq(
		scene.hand1.cards.size() + scene.discard_pile.size() + scene.draw_pile.size(),
		10, "牌量守恒（手+弃+抽=10）")
	TestBase.assert_true(scene.enemy.hp > 0, "敌人已初始化")

	# ---------- 2. 出一张牌（走完整 Lua + 执行器路径）----------
	var before_enemy_hp = scene.enemy.hp
	var card = scene.hand1.cards[0]
	var before_total = scene.hand1.cards.size() + scene.discard_pile.size() + scene.draw_pile.size()
	scene._switch_to(1)
	scene._execute_card(card)
	await tree.process_frame

	var after_total = scene.hand1.cards.size() + scene.discard_pile.size() + scene.draw_pile.size()
	TestBase.assert_eq(after_total, before_total, "出牌后牌量守恒")
	TestBase.assert_eq(scene.hand1.cards.size() + 1 >= 3, true, "手牌至少还有牌或已补抽")

	# ---------- 3. 打空手牌直到能量耗尽，验证不会崩 ----------
	for i in range(6):
		if scene.hand1.cards.size() > 0 and scene.player1.energy > 0:
			var c = scene.hand1.cards[0]
			scene._switch_to(1)
			scene._execute_card(c)
			await tree.process_frame
		else:
			break
	TestBase.assert_true(scene.player1.energy >= 0, "能量非负")
	TestBase.assert_true(scene.enemy.hp >= 0, "敌人HP非负")

	# ---------- 4. 结束回合 → 敌人回合 → 回到玩家回合 ----------
	var hp_before_enemy_turn = scene.player1.hp
	scene._on_end_turn()
	# _do_end_turn 同步执行：手牌在 _on_end_turn 返回时就应该清空
	TestBase.assert_eq(scene.hand1.cards.size(), 0, "结束回合后手牌清空")

	# 等整轮：敌人回合(deferred) → 回到玩家回合 → 重抽4张
	await tree.create_timer(0.3).timeout
	var turn_after = scene.turn_manager.current_turn
	TestBase.assert_eq(turn_after, TurnManager.Turn.PLAYER1, "敌人回合后回到玩家回合")
	TestBase.assert_eq(scene.hand1.cards.size(), 4, "新回合重新抽4张")
	TestBase.assert_true(scene.player1.hp <= hp_before_enemy_turn, "玩家HP只降不升（敌人回合）")

	# ---------- 5. 敌人意图已刷新 ----------
	TestBase.assert_true(scene.enemy.intent_value >= 0, "敌人意图已规划")

	# ---------- 6. Boss 战（第6层镇关Boss）：专属背景与立绘 ----------
	GameData.current_floor = 6
	scene._reset_battle_state()
	await tree.process_frame
	TestBase.assert_eq(scene.enemy.floor_type, Enemy.FloorType.BOSS, "第6层为Boss战")
	TestBase.assert_true(scene._battle_bg.texture != null, "Boss背景已加载")
	TestBase.assert_true(scene.enemy_portrait.texture != null, "Boss立绘已加载")
	TestBase.assert_true(scene.enemy.hp > 0, "Boss血量有效")
	GameData.current_floor = 1

	# 清理
	scene.queue_free()
	await tree.process_frame

	return TestBase.failed == 0
