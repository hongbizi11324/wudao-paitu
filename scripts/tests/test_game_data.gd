class_name TestGameData
# ==============================
# GameData 单元测试
# 覆盖：楼层类型 / 战斗奖励 / 地图生成不变量 / 楼层推进（双推进bug回归）/ 存档回环
# ==============================

static func run() -> bool:
	TestBase.describe("GameData 全局数据与地图")

	GameData.new_run()

	# ---------- 1. 楼层类型 ----------
	TestBase.assert_eq(GameData._calc_floor_type(1), GameData.FloorType.NORMAL, "1层普通")
	TestBase.assert_eq(GameData._calc_floor_type(3), GameData.FloorType.ELITE, "3层精英")
	TestBase.assert_eq(GameData._calc_floor_type(6), GameData.FloorType.BOSS, "6层Boss")
	TestBase.assert_eq(GameData._calc_floor_type(12), GameData.FloorType.BOSS, "12层Boss")
	TestBase.assert_eq(GameData._calc_floor_type(13), GameData.FloorType.NORMAL, "13层普通")

	# ---------- 2. 战斗奖励与地图提示一致 ----------
	GameData.current_floor = 3
	TestBase.assert_eq(GameData.get_battle_reward()["gold"], 20, "精英奖励金币20")
	GameData.current_floor = 6
	TestBase.assert_eq(GameData.get_battle_reward()["cultivation"], 40, "Boss奖励修为40")
	GameData.current_floor = 1
	TestBase.assert_eq(GameData.get_battle_reward()["gold"], 12, "普通奖励金币12")

	# ---------- 3. 地图生成不变量 ----------
	GameData._reset_map_state()
	GameData.map_act_count = -1
	GameData.generate_new_act()
	var layers = GameData.map_layers
	TestBase.assert_eq(layers.size(), 12, "12层地图")
	TestBase.assert_eq(layers[0].size(), 1, "起点层1个节点")
	TestBase.assert_true(layers[11][0].get("is_boss", false), "末层是Boss节点")
	TestBase.assert_eq(GameData.map_node_states[0][0], "visited", "起点已访问")

	# 中段Boss层（第6层=offset 5）的战斗节点带 is_boss 标记
	var has_mid_boss = false
	for nd in layers[5]:
		if nd.get("is_boss", false):
			has_mid_boss = true
	TestBase.assert_true(has_mid_boss, "第6层(中段Boss)战斗节点带is_boss")

	# 每个非起点节点至少有一条入线
	var reachable = true
	for li in range(1, layers.size()):
		for ni in range(layers[li].size()):
			var has_in = false
			for c in GameData.map_connections:
				if c.to_layer == li and c.to_node == ni:
					has_in = true
					break
			if not has_in:
				reachable = false
	TestBase.assert_true(reachable, "所有节点可达")

	# ---------- 4. 楼层推进（回归：双推进bug）----------
	# 选 offset=3 的可用节点 → current_floor 应恰好为 start_floor+3，不再 +1
	GameData._reset_map_state()
	GameData.map_act_count = -1
	GameData.generate_new_act()
	# 解锁第1层所有可达节点后选一个 offset=3 的
	var picked := {}
	for ni in range(GameData.map_layers[1].size()):
		if GameData.map_node_states[1][ni] == "available":
			var nd = GameData.select_map_node(1, ni)
			if not nd.is_empty():
				picked = nd
			break
	TestBase.assert_eq(GameData.current_floor, 2, "选offset1节点 → 楼层=2（无双推进）")

	# ---------- 5. 门派卡池 ----------
	var pool_yz = GameData.get_character_pool("yunzhi")
	TestBase.assert_true(pool_yz.has("xy_fengjuan"), "云芷池含门派卡")
	TestBase.assert_true(pool_yz.has("strike"), "云芷池含通用卡")
	TestBase.assert_false(pool_yz.has("sl_fist"), "云芷池不含少林卡")
	var pool_sl = GameData.get_character_pool("huiming")
	TestBase.assert_true(pool_sl.has("sl_fist"), "慧明池含少林卡")
	TestBase.assert_false(pool_sl.has("xy_fengjuan"), "慧明池不含逍遥卡")

	# ---------- 6. 存档回环（备份/恢复用户存档）----------
	var save_exists = GameData.has_save()
	var backup: String = ""
	if save_exists:
		backup = _read_save()
	GameData.new_run()
	GameData.gold = 77
	GameData.current_realm = 2
	GameData.add_card("strike")
	GameData.save_game()
	GameData.new_run()
	GameData.load_game()
	TestBase.assert_eq(GameData.gold, 77, "存档回环：金币")
	TestBase.assert_eq(GameData.current_realm, 2, "存档回环：境界")
	TestBase.assert_true(GameData.player_deck.has("strike"), "存档回环：牌组")

	# 恢复原存档
	if save_exists:
		var f = FileAccess.open(GameData.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		GameData.delete_save()

	return TestBase.failed == 0


static func _read_save() -> String:
	var f = FileAccess.open(GameData.SAVE_PATH, FileAccess.READ)
	return f.get_as_text() if f else ""
