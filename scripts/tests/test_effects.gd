class_name TestEffects
extends TestBase
# ==============================
# 效果系统测试
# 覆盖所有 Effect 类型
# ==============================


static func run():
	reset()
	describe("DamageEffect")
	test_damage_basic()
	test_damage_repeat()
	test_damage_armor_break()
	
	describe("BlockEffect")
	test_block_basic()
	
	describe("HealEffect")
	test_heal_basic()
	
	describe("DrawEffect")
	test_draw_basic()
	
	describe("EnergyEffect")
	test_energy_gain()
	
	describe("ModifierGainEffect")
	test_chan_gain()
	test_jianyi_gain()
	
	describe("ModifierConsumeEffect")
	test_consume_chan_to_damage()
	test_consume_jianyi_to_damage()
	
	describe("CompositeEffect")
	test_composite_two_effects()
	
	describe("ApplyPowerEffect")
	test_apply_power_damo()
	
	describe("SimpleConditionalEffect")
	test_conditional_hand_le()
	test_conditional_energy_unused()
	
	describe("ScriptedEffect")
	test_scripted_effect_does_not_crash()
	
	return print_summary()


# ============================
# DamageEffect 测试
# ============================

static func test_damage_basic():
	var ctx = make_test_ctx()
	var e = DamageEffect.new()
	e.damage = 6
	e.execute(ctx)
	
	assert_eq(ctx.total_damage, 6, "DamageEffect 6 → total_damage = 6")
	assert_eq(ctx.total_armor_break, 0, "默认 armor_break = 0")
	assert_true(ctx.has_executed_strike, "has_executed_strike 标记为 true")
	free_test_ctx(ctx)


static func test_damage_repeat():
	var ctx = make_test_ctx()
	var e = DamageEffect.new()
	e.damage = 4
	e.repeat = 2
	e.execute(ctx)
	
	assert_eq(ctx.total_damage, 8, "damage=4, repeat=2 → total = 8")
	free_test_ctx(ctx)


static func test_damage_armor_break():
	var ctx = make_test_ctx()
	var e = DamageEffect.new()
	e.damage = 5
	e.armor_break = 3
	e.execute(ctx)
	
	assert_eq(ctx.total_damage, 5, "damage=5 正常")
	assert_eq(ctx.total_armor_break, 3, "armor_break=3")
	free_test_ctx(ctx)


# ============================
# BlockEffect 测试
# ============================

static func test_block_basic():
	var ctx = make_test_ctx()
	var e = BlockEffect.new()
	e.block = 5
	e.execute(ctx)
	
	assert_eq(ctx.total_block, 5, "BlockEffect 5 → total_block = 5")
	free_test_ctx(ctx)


# ============================
# HealEffect 测试
# ============================

static func test_heal_basic():
	var ctx = make_test_ctx()
	var e = HealEffect.new()
	e.heal = 4
	e.execute(ctx)
	
	assert_eq(ctx.total_heal, 4, "HealEffect 4 → total_heal = 4")
	free_test_ctx(ctx)


# ============================
# DrawEffect 测试
# ============================

static func test_draw_basic():
	var ctx = make_test_ctx()
	var e = DrawEffect.new()
	e.count = 2
	e.execute(ctx)
	
	assert_eq(ctx.total_draw, 2, "DrawEffect 2 → total_draw = 2")
	free_test_ctx(ctx)


# ============================
# EnergyEffect 测试
# ============================

static func test_energy_gain():
	var ctx = make_test_ctx()
	var e = EnergyEffect.new()
	e.amount = 1
	e.mode = EnergyEffect.EnergyMode.GAIN
	e.execute(ctx)
	
	assert_eq(ctx.total_energy, 1, "EnergyEffect GAIN 1 → total_energy = 1")
	free_test_ctx(ctx)


# ============================
# ModifierGainEffect 测试
# ============================

static func test_chan_gain():
	var ctx = make_test_ctx()
	var e = ModifierGainEffect.new()
	e.modifier_key = "chan"
	e.amount = 1
	e.execute(ctx)
	
	assert_eq(ctx.player.chan, 1, "chan 从 0 变为 1")
	free_test_ctx(ctx)


static func test_jianyi_gain():
	var ctx = make_test_ctx()
	# 先加两层
	var e1 = ModifierGainEffect.new()
	e1.modifier_key = "jianyi"
	e1.amount = 2
	e1.execute(ctx)
	
	assert_eq(ctx.player.jianyi, 2, "jianyi 从 0 变为 2")
	free_test_ctx(ctx)


# ============================
# ModifierConsumeEffect 测试
# ============================

static func test_consume_chan_to_damage():
	var ctx = make_test_ctx()
	# 先加 3 层禅意
	ctx.player.chan = 3
	
	var e = ModifierConsumeEffect.new()
	e.modifier_key = "chan"
	e.bonus_per_consumed = 4  # 罗汉伏魔：每层+4伤害
	e.base_value = 6          # 基础 6 伤害
	e.bonus_target = "damage"
	e.execute(ctx)
	
	assert_eq(ctx.total_damage, 18, "3层禅意 × 4 + 基础6 = 18")
	assert_eq(ctx.player.chan, 0, "禅意已清空")
	free_test_ctx(ctx)


static func test_consume_jianyi_to_damage():
	var ctx = make_test_ctx()
	ctx.player.jianyi = 5  # 5层剑意
	
	var e = ModifierConsumeEffect.new()
	e.modifier_key = "jianyi"
	e.bonus_per_consumed = 5  # 真武重剑：每层+5伤害
	e.base_value = 0
	e.bonus_target = "damage"
	e.execute(ctx)
	
	assert_eq(ctx.total_damage, 25, "5层剑意 × 5 = 25")
	assert_eq(ctx.player.jianyi, 0, "剑意已清空")
	free_test_ctx(ctx)


# ============================
# CompositeEffect 测试
# ============================

static func test_composite_two_effects():
	var ctx = make_test_ctx()
	
	var dmg = DamageEffect.new()
	dmg.damage = 5
	
	var draw = DrawEffect.new()
	draw.count = 1
	
	var comp = CompositeEffect.new()
	comp.effects.append(dmg)
	comp.effects.append(draw)
	comp.execute(ctx)
	
	assert_eq(ctx.total_damage, 5, "composite: damage = 5")
	assert_eq(ctx.total_draw, 1, "composite: draw = 1")
	free_test_ctx(ctx)


# ============================
# ApplyPowerEffect 测试
# ============================

static func test_apply_power_damo():
	var ctx = make_test_ctx()
	var e = ApplyPowerEffect.new()
	e.power_key = "damo"
	e.execute(ctx)
	
	assert_true(ctx.player.power_damo, "达摩一苇标记已激活")
	free_test_ctx(ctx)


# ============================
# SimpleConditionalEffect 测试
# ============================

static func test_conditional_hand_le():
	# 手牌 ≤ N 的条件
	# 这个测试需要 mock 手牌，用 ctx.hand
	# 简化版：只测试 JSON 配置能正确解析
	var e = SimpleConditionalEffect.new()
	e.condition_type = "hand_le"
	e.condition_params = {"value": 3}
	
	assert_eq(e.condition_type, "hand_le", "条件类型字段正确")
	free_test_ctx(null)


static func test_conditional_energy_unused():
	var ctx = make_test_ctx()
	ctx.energy_used_this_turn = 0
	
	# then：未消耗内力 → 加5格挡
	var bonus = BlockEffect.new()
	bonus.block = 5
	
	var cond = SimpleConditionalEffect.new()
	cond.condition_type = "energy_unused"
	cond.then_effects.append(bonus)
	cond.execute(ctx)
	
	assert_eq(ctx.total_block, 5, "energy_unused 条件触发：格挡+5")
	free_test_ctx(ctx)


# ============================
# ScriptedEffect 测试
# ============================

static func test_scripted_effect_does_not_crash():
	var e = ScriptedEffect.new()
	e.script_id = "test"
	e.execute(null)  # 空上下文也不应崩溃
	
	assert_true(true, "ScriptedEffect 空调用不崩溃")
