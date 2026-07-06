class_name TestBase
# ==============================
# 测试基类
# 提供 assert 工具和统计
# ==============================

static var passed: int = 0
static var failed: int = 0
static var errors: Array[String] = []


static func describe(name: String):
	print("\n  📋 %s" % name)


static func assert_eq(got, expected, msg: String = ""):
	if got == expected:
		passed += 1
		return true
	failed += 1
	var detail = "期待 %s, 实际 %s" % [str(expected), str(got)]
	var full = "  ❌ %s" % [msg if msg else detail]
	errors.append(full)
	print(full)
	print("      %s" % detail)
	return false


static func assert_true(cond: bool, msg: String = ""):
	if cond:
		passed += 1
		return true
	failed += 1
	var full = "  ❌ %s" % (msg if msg else "预期为 true")
	errors.append(full)
	print(full)
	return false


static func assert_false(cond: bool, msg: String = ""):
	return assert_true(not cond, msg)


static func print_summary():
	print("\n%s" % "=".repeat(40))
	print("  测试总结")
	print("%s" % "=".repeat(40))
	print("  ✅ 通过: %d" % passed)
	print("  ❌ 失败: %d" % failed)
	if errors.size() > 0:
		print("  ———— 失败详情 ————")
		for e in errors:
			print(e)
	print("%s" % "=".repeat(40))
	return failed == 0


static func reset():
	passed = 0
	failed = 0
	errors.clear()


# 辅助：创建测试用的上下文（最小可用的 Enemy 和 Player）
static func make_test_ctx() -> EffectContext:
	var ctx = EffectContext.new()
	
	# 创建模拟敌人
	var enemy = Enemy.new()
	enemy.hp = 40
	enemy.max_hp = 40
	enemy.block = 0
	enemy.intent_type = 0
	enemy.intent_value = 6
	ctx.enemy = enemy
	
	# 创建模拟玩家
	var player = Player.new()
	player.hp = 50
	player.max_hp = 50
	player.max_energy = 3
	player.energy = 3
	player.block = 0
	player.chan = 0
	player.jianyi = 0
	player.next_card_discount = 0
	player.power_damo = false
	player.power_twoway = false
	player.power_bahuang = false
	player.power_longxiang = false
	player.power_xiaoyaoyou = false
	ctx.player = player
	
	# 手牌、牌库（简单版本）
	ctx.hand = null  # 非手牌相关测试留空
	ctx.draw_pile = ["strike", "defend"]
	ctx.discard_pile = []
	
	return ctx


static func free_test_ctx(ctx: EffectContext):
	if ctx and ctx.enemy and is_instance_valid(ctx.enemy):
		ctx.enemy.free()
	if ctx and ctx.player and is_instance_valid(ctx.player):
		ctx.player.free()
