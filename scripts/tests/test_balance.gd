class_name TestBalance
# ==============================
# 平衡性模拟测试
#
# 模型假设（简化的"平均玩家"）：
#   - 每回合 3 点内力，平均每点内力产出 5.5 伤害（1费≈6伤的基础牌，随奖励卡质量提升）
#   - 境界加成：每回合约打出 2.5 张牌，每张 +realm 伤害
#   - 玩家会在 3 费之内尽量打光（存在浪费，系数 0.92）
#   - 出牌数随牌组厚度增长：4张手牌限制
#
# 断言目标（击杀回合数）：
#   普通战 2~5 回合 / 精英 3~7 回合 / Boss 6~14 回合
# 超出范围即红——防止"数值爆炸"或"刮痧耗死"
# ==============================

static func run() -> bool:
	TestBase.describe("平衡性模拟：输出模型 vs 敌人血量曲线")

	var all_ok := true
	for floor_num in [1, 2, 3, 4, 5, 6, 7, 9, 12]:
		GameData.current_floor = floor_num
		var ft := GameData.get_floor_type()
		var enemy_hp := GameData.get_enemy_hp()

		# 玩家输出模型
		var realm := _realm_at_floor(floor_num)
		var dmg_per_energy := 5.5
		var energy_per_turn := 3.0 + realm  # 突破加内力上限
		var realm_bonus := float(realm) * 2.5  # 约2.5张牌/回合
		var dps: float = (dmg_per_energy * energy_per_turn + realm_bonus) * 0.92

		var turns := ceili(enemy_hp / maxf(dps, 1.0))

		var min_ok := 2
		var max_ok := 5
		match ft:
			GameData.FloorType.ELITE:
				min_ok = 3
				max_ok = 7
			GameData.FloorType.BOSS:
				min_ok = 6
				max_ok = 14

		var ok := turns >= min_ok and turns <= max_ok
		if not ok:
			all_ok = false
		var ft_name: String = ["普通", "精英", "Boss"][ft]
		TestBase.assert_true(ok,
			"第%d层%s: HP=%d, 模型%d回合（预期%d~%d）" % [floor_num, ft_name, enemy_hp, turns, min_ok, max_ok])

	# 奖励曲线：单次战斗收益应能支撑突破节奏（修为）
	# 20+30+40=90 修为即可在第1大关内升到 3 境界（能量 6）
	var cultivation_total := 0
	for f in range(1, 13):
		GameData.current_floor = f
		cultivation_total += GameData.get_battle_reward()["cultivation"]
	TestBase.assert_true(cultivation_total >= 90, "第一大关总修为 %d ≥ 90（可突破到3境）" % cultivation_total)

	GameData.current_floor = 1
	return TestBase.failed == 0


## 假设：每场战斗 10~12 修为奖励 → 第 N 层时的境界
static func _realm_at_floor(floor_num: int) -> int:
	var cultivation := 0
	var realm := 0
	var need := 20
	for f in range(1, floor_num):
		# 简化：平均每场 12 修为（普通10/精英20混合）
		cultivation += 12
		while cultivation >= need and realm < 8:
			cultivation -= need
			realm += 1
			need = 20 + realm * 10
	return realm
