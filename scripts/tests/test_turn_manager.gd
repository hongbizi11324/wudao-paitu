class_name TestTurnManager
# ==============================
# TurnManager 单元测试
# 覆盖：单人推进 / 双人共享回合（双方都结束才进敌人回合）/ 联机状态注入
# ==============================

static func run() -> bool:
	TestBase.describe("TurnManager 回合状态机")

	# ---------- 1. 单人模式 ----------
	GameData.is_dual_mode = false
	var tm := TurnManager.new()
	tm.start_battle()
	TestBase.assert_eq(tm.current_turn, TurnManager.Turn.PLAYER1, "开局玩家回合")
	TestBase.assert_true(tm.active, "状态机激活")

	tm.end_player_turn()
	TestBase.assert_eq(tm.current_turn, TurnManager.Turn.ENEMY, "单人：结束→敌人回合")

	tm.end_enemy_turn()
	TestBase.assert_eq(tm.current_turn, TurnManager.Turn.PLAYER1, "敌人回合→玩家回合")

	# ---------- 2. 双人共享回合 ----------
	GameData.is_dual_mode = true
	var tm2 := TurnManager.new()
	tm2.start_battle()
	TestBase.assert_false(tm2.has_player_ended(1), "P1未结束")
	TestBase.assert_false(tm2.has_player_ended(2), "P2未结束")

	# 单人入口在双人模式下的静默忽略
	tm2.end_player_turn()
	TestBase.assert_eq(tm2.current_turn, TurnManager.Turn.PLAYER1, "双人下单人结束被忽略")

	var advanced = tm2.mark_player_ended(1)
	TestBase.assert_false(advanced, "P1先结束不推进")
	TestBase.assert_false(tm2.has_player_ended(2) and not tm2.has_player_ended(1), "状态正确")

	advanced = tm2.mark_player_ended(2)
	TestBase.assert_true(advanced, "双方都结束→推进敌人回合")
	TestBase.assert_eq(tm2.current_turn, TurnManager.Turn.ENEMY, "进敌人回合")
	TestBase.assert_false(tm2.has_player_ended(1), "推进后结束标记复位")

	# ---------- 3. 非法输入 ----------
	TestBase.assert_false(tm2.mark_player_ended(3), "非法 player_id 拒绝")
	TestBase.assert_false(tm2.has_player_ended(9), "非法查询返回 false")

	# ---------- 4. 联机状态注入 ----------
	tm2.apply_network_end_state(true, false)
	TestBase.assert_true(tm2.has_player_ended(1), "注入P1结束")
	TestBase.assert_false(tm2.has_player_ended(2), "注入P2未结束")

	GameData.is_dual_mode = false
	tm.free()
	tm2.free()
	return TestBase.failed == 0
