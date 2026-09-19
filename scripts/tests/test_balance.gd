class_name TestBalance
# ==============================
# 平衡性模拟测试（输出 + 承伤 双模型）
#
# 教训：只有"输出模型"会给假绿灯。第一版模型只算"几回合打死敌人"，
# 于是把 Boss 系数调到 ×3.8 仍然全绿，实际玩家 4 张手牌既不够快速击杀、
# 也挡不住三段爆发 → 第6/12层数学上必死（玩家反馈"打了几遍都过不去"）。
#
# 现模型同时约束两件事：
#   1) 击杀回合数在合理区间
#   2) 击杀所需的"全力输出"下，剩余手牌能否挡住敌人期望伤害
# ==============================

static func run() -> bool:
	TestBase.describe("平衡性模拟：输出 + 承伤双模型")

	var all_ok := true
	for floor_num in [1, 2, 3, 4, 5, 6, 7, 9, 12]:
		GameData.current_floor = floor_num
		var ft := GameData.get_floor_type()
		var enemy_hp := GameData.get_enemy_hp()
		var dmg_range := GameData.get_enemy_damage_range()

		var realm := _realm_at_floor(floor_num)
		var energy := 3 + realm            # 内力上限随境界 +1
		var cards_per_turn := 4 + (realm + 1) / 2  # 抽牌随境界成长（main._start_player_turn）
		var card_slots: int = mini(energy, cards_per_turn)

		# 单卡效率（1 费 ≈ 6 伤 / 5 格挡，含境界加成）
		var dmg_per_card := 6.0 + realm
		var block_per_card := 5.0 + realm

		# 最快击杀：每回合能打出的伤害（受手牌/内力双重限制）
		var max_dps := card_slots * dmg_per_card
		var turns := ceili(enemy_hp / maxf(max_dps, 1.0))

		# 承伤模型：为在 turns 内击杀，每回合需留多少手牌防御
		var offense_cards_needed := float(enemy_hp) / (float(turns) * dmg_per_card)
		var defense_cards := maxf(0.0, float(card_slots) - offense_cards_needed)
		var block_per_turn := defense_cards * block_per_card

		# 敌人期望伤害/回合（含多段与 Boss 三阶段加权）
		var avg_dmg := (float(dmg_range[0]) + float(dmg_range[1])) / 2.0
		var attack_chance := 0.7
		var phase_mult := 1.0
		if ft == GameData.FloorType.BOSS:
			# 三阶段（1.0 / 1.3 / 1.6 倍，见 enemy._calc_attack_damage）加权
			phase_mult = (1.0 + 1.3 + 1.6) / 3.0
		var incoming_per_turn := avg_dmg * attack_chance * phase_mult * 1.1  # 1.1=多段期望
		var net_per_turn := maxf(0.0, incoming_per_turn - block_per_turn)
		var total_incoming := net_per_turn * turns

		# 血量预算：初始 60 + 大关中 1~2 次休息/丹药 ≈ 35
		var hp_budget := 95.0

		var ft_name: String = ["普通", "精英", "Boss"][ft]

		# ---- 断言1：击杀回合数 ----
		var min_turns := 2
		var max_turns := 5
		match ft:
			GameData.FloorType.ELITE:
				min_turns = 2
				max_turns = 7
			GameData.FloorType.BOSS:
				min_turns = 3
				max_turns = 14
		var turns_ok := turns >= min_turns and turns <= max_turns
		if not turns_ok:
			all_ok = false
		# 调参面板：始终打印关键数值
		print("    · 第%2d层%-2s HP=%-4d 伤%-3d~%-3d | 境界%d 手牌%d/%d费 单卡%.0f伤%.0f挡 | %d回合 | 敌%.1f/回合 挡%.1f → 承伤%.0f/预算%.0f" % [
			floor_num, ft_name, enemy_hp, dmg_range[0], dmg_range[1],
			realm, card_slots, energy, dmg_per_card, block_per_card,
			turns, incoming_per_turn, block_per_turn, total_incoming, hp_budget])
		TestBase.assert_true(turns_ok,
			"第%d层%s：HP=%d，模型 %d 回合（预期%d~%d）" % [floor_num, ft_name, enemy_hp, turns, min_turns, max_turns])

		# ---- 断言2：生存（承伤 ≤ 血量预算）----
		var survive_ok := total_incoming <= hp_budget
		if not survive_ok:
			all_ok = false
		TestBase.assert_true(survive_ok,
			"第%d层%s 生存：承伤 %.0f ≤ 预算 %.0f（敌期望%.1f/回合，格挡%.1f/回合）" % [
				floor_num, ft_name, total_incoming, hp_budget, incoming_per_turn, block_per_turn])

	# 奖励曲线：单次战斗收益应能支撑突破节奏（修为）
	var cultivation_total := 0
	for f in range(1, 13):
		GameData.current_floor = f
		cultivation_total += GameData.get_battle_reward()["cultivation"]
	TestBase.assert_true(cultivation_total >= 90, "第一大关总修为 %d ≥ 90（可突破到3境）" % cultivation_total)

	GameData.current_floor = 1
	return TestBase.failed == 0


## 假设：每场战斗约 12 修为奖励 → 第 N 层时的境界
static func _realm_at_floor(floor_num: int) -> int:
	var cultivation := 0
	var realm := 0
	var need := 20
	for f in range(1, floor_num):
		cultivation += 12
		while cultivation >= need and realm < 8:
			cultivation -= need
			realm += 1
			need = 20 + realm * 10
	return realm
