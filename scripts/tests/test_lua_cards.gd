class_name TestLuaCards
# ==============================
# Lua 卡牌效果（Command Pattern 纯函数）单元测试
# 覆盖：基础数值 / 门派资源 / 条件卡 / POWER 触发
# Lua 环境不可用时跳过（视为通过但给出警告）
# ==============================

static func make_ctx(card_id: String, overrides: Dictionary = {}) -> Dictionary:
	var ctx := {
		"card_id": card_id,
		"cost": 1, "card_type": 0,
		"damage": 0, "block": 0, "heal": 0, "draw": 0,
		"repeat": 0, "armor_break": 0, "school": "",
		"player_hp": 60, "player_max_hp": 60,
		"player_energy": 3, "player_max_energy": 5, "player_block": 0,
		"player_chan": 0, "player_jianyi": 0,
		"player_next_card_discount": 0,
		"enemy_hp": 40, "enemy_max_hp": 40, "enemy_block": 0,
		"enemy_intent_type": 0, "enemy_intent_value": 6,
		"hand_size": 4, "discard_csv": "",
		"last_played_card_id": "", "last_played_card_type": -1,
		"skill_played_this_turn": 0, "energy_used_this_turn": 0,
		"cards_played_this_turn": 0, "attacks_played_this_turn": 0,
		"actual_cost": 1,
		"damage_bonus": 0, "block_bonus": 0,
		"punch_damage": 5, "meditate_gain": 1,
	}
	for k in overrides:
		ctx[k] = overrides[k]
	return ctx


static func run() -> bool:
	if not LuaRuntime or not LuaRuntime.enabled:
		push_warning("[测试] Lua 环境不可用，跳过 Lua 卡牌测试")
		print("  ⚠️ Lua 不可用，跳过")
		return true

	TestBase.describe("Lua 卡牌效果（Command Pattern）")

	# ---------- 1. 基础卡 ----------
	var r = LuaRuntime.execute_card("strike", make_ctx("strike", {"damage": 6}))
	TestBase.assert_eq(r.get("damage", -1), 6, "strike 伤害6")

	r = LuaRuntime.execute_card("defend", make_ctx("defend", {"block": 5, "card_type": 1}))
	TestBase.assert_eq(r.get("block", -1), 5, "defend 格挡5")

	r = LuaRuntime.execute_card("double_strike", make_ctx("double_strike", {"damage": 4, "repeat": 2}))
	TestBase.assert_eq(r.get("repeat_count", 0), 2, "连击 repeat=2")

	r = LuaRuntime.execute_card("punch", make_ctx("punch", {"damage": 2}))
	TestBase.assert_eq(r.get("damage", -1), 5, "punch 用境界伤害")

	r = LuaRuntime.execute_card("meditate", make_ctx("meditate", {"card_type": 3, "energy_gain": 1}))
	TestBase.assert_eq(r.get("energy_gain", -1), 1, "meditate 内力")

	# ---------- 2. 少林禅意 ----------
	r = LuaRuntime.execute_card("sl_golden", make_ctx("sl_golden", {
		"block": 5, "card_type": 1, "player_chan": 4}))
	TestBase.assert_eq(r.get("block", -1), 5 + 4 * 3, "金钟罩 禅意×3")
	TestBase.assert_true(r.get("chan_reset", false), "金钟罩 消耗禅意")

	r = LuaRuntime.execute_card("sl_arhat", make_ctx("sl_arhat", {"damage": 6, "player_chan": 3}))
	TestBase.assert_eq(r.get("damage", -1), 6 + 3 * 4, "罗汉伏魔 禅意×4")

	# ---------- 3. 武当剑意 ----------
	r = LuaRuntime.execute_card("wd_soft", make_ctx("wd_soft", {"damage": 5, "player_jianyi": 2}))
	TestBase.assert_eq(r.get("damage", -1), 5 + 4, "柔云剑 消耗1剑意+4")
	TestBase.assert_eq(r.get("jianyi_minus", 0), 1, "柔云剑 jianyi_minus=1")

	r = LuaRuntime.execute_card("wd_heavy", make_ctx("wd_heavy", {"player_jianyi": 3}))
	TestBase.assert_eq(r.get("damage", -1), 15, "真武重剑 剑意×5")

	# ---------- 4. 云芷条件卡 ----------
	r = LuaRuntime.execute_card("xy_fengjuan", make_ctx("xy_fengjuan", {"damage": 4, "hand_size": 7}))
	TestBase.assert_eq(r.get("damage", -1), 4 + 4, "风卷残云 +min(手牌,4)")

	r = LuaRuntime.execute_card("xy_zhemel", make_ctx("xy_zhemel", {"damage": 4, "hand_size": 2}))
	TestBase.assert_eq(r.get("damage", -1), 12, "折梅手 手牌≤3 → 12")

	r = LuaRuntime.execute_card("xy_duanliu", make_ctx("xy_duanliu", {"damage": 5, "hand_size": 3}))
	TestBase.assert_eq(r.get("damage", -1), 8, "断水流 +3")
	TestBase.assert_eq(r.get("discard_other_count", 0), 1, "断水流 弃1")

	r = LuaRuntime.execute_card("xy_duanliu", make_ctx("xy_duanliu", {"damage": 5, "hand_size": 1}))
	TestBase.assert_eq(r.get("damage", -1), 5, "断水流 无牌可弃不加伤")
	TestBase.assert_eq(r.get("discard_other_count", 0), 0, "断水流 不弃自己")

	r = LuaRuntime.execute_card("xy_wujian", make_ctx("xy_wujian", {"damage": 5, "last_played_card_type": 1}))
	TestBase.assert_eq(r.get("damage", -1), 10, "无间道 上张技能→翻倍")

	r = LuaRuntime.execute_card("xy_fange", make_ctx("xy_fange", {"damage": 5, "enemy_intent_type": 0}))
	TestBase.assert_eq(r.get("damage", -1), 16, "反戈一击 敌攻击→16")

	r = LuaRuntime.execute_card("xy_qiguan", make_ctx("xy_qiguan", {"damage": 5, "player_energy": 3}))
	TestBase.assert_eq(r.get("damage", -1), 11, "气贯长虹 +6")
	TestBase.assert_eq(r.get("energy_gain", 0), -2, "气贯长虹 耗2内力")

	r = LuaRuntime.execute_card("xy_xushi", make_ctx("xy_xushi", {"card_type": 1, "skill_played_this_turn": 1, "last_played_card_type": 1}))
	TestBase.assert_eq(r.get("next_two_discount", 0), 3, "虚实相生 连续技能→3")
	r = LuaRuntime.execute_card("xy_xushi", make_ctx("xy_xushi", {"card_type": 1}))
	TestBase.assert_eq(r.get("next_two_discount", 0), 2, "虚实相生 常规→2")

	# ---------- 5. 小无相功：从弃牌堆csv复制 ----------
	r = LuaRuntime.execute_card("xy_wuxiang", make_ctx("xy_wuxiang", {
		"discard_csv": "strike,sl_damo,defend"}))
	TestBase.assert_eq(r.get("add_card_id", ""), "defend", "小无相功 跳过POWER取最新")
	TestBase.assert_true(r.get("is_consumed", false), "小无相功 消耗")

	# ---------- 6. 镜花水月 ----------
	r = LuaRuntime.execute_card("xy_jinghua", make_ctx("xy_jinghua", {
		"last_played_card_id": "strike", "last_played_card_type": 0}))
	TestBase.assert_eq(r.get("add_card_id", ""), "strike", "镜花水月 复制上张")
	r = LuaRuntime.execute_card("xy_jinghua", make_ctx("xy_jinghua", {
		"last_played_card_id": "sl_damo", "last_played_card_type": 2}))
	TestBase.assert_false(r.has("add_card_id"), "镜花水月 POWER不复制")

	# ---------- 7. POWER 卡 ----------
	r = LuaRuntime.execute_card("xy_xiaoyaoyou", make_ctx("xy_xiaoyaoyou"))
	TestBase.assert_eq(r.get("set_power", ""), "xiaoyaoyou", "逍遥游 POWER")

	# ---------- 8. battle.lua POWER 触发 ----------
	var b = LuaRuntime.battle_trigger_powers({"powers": {
		"damo": true, "twoway": false, "bahuang": false,
		"longxiang": false, "xiaoyaoyou": false}})
	TestBase.assert_eq(b.get("chan_add", 0), 2, "达摩 触发禅意+2")
	TestBase.assert_eq(b.get("block", 0), 3, "达摩 触发格挡+3")

	return TestBase.failed == 0
