extends Node
# ==============================
# 测试启动器（场景模式）
# 运行：godot --headless --path . res://tests/test_boot.tscn
# 退出码：0=全部通过 1=有失败
# ==============================

func _ready():
	print("\n%s" % "=".repeat(40))
	print("  武道牌途 — 单元测试")
	print("  Godot %s" % Engine.get_version_info().get("string", "?"))
	print("%s" % "=".repeat(40))

	TestBase.reset()
	var all_ok := true

	# 1. 回合状态机
	print("\n▶ TurnManager ...")
	TestBase.reset()
	if not TestTurnManager.run():
		all_ok = false

	# 2. 全局数据与地图
	print("\n▶ GameData ...")
	TestBase.reset()
	if not TestGameData.run():
		all_ok = false

	# 3. 出牌结算器
	print("\n▶ CardExecutor ...")
	TestBase.reset()
	if not TestCardExecutor.run(self):
		all_ok = false

	# 4. Lua 卡牌效果
	print("\n▶ LuaCards ...")
	TestBase.reset()
	if not TestLuaCards.run():
		all_ok = false

	# 4.5 平衡性模拟
	print("\n▶ Balance ...")
	TestBase.reset()
	if not TestBalance.run():
		all_ok = false

	# 4.6 敌人机制
	print("\n▶ Enemy ...")
	TestBase.reset()
	if not TestEnemy.run():
		all_ok = false

	# 4.7 遗物
	print("\n▶ Relics ...")
	TestBase.reset()
	if not TestRelics.run():
		all_ok = false

	# 4.75 手牌
	print("\n▶ Hand ...")
	TestBase.reset()
	if not TestHand.run(self):
		all_ok = false

	# 4.8 丹药
	print("\n▶ Potions ...")
	TestBase.reset()
	if not TestPotions.run(self):
		all_ok = false

	# 5. 战斗流程集成（真实场景，需要 await）
	print("\n▶ BattleIntegration ...")
	TestBase.reset()
	if not await TestBattleIntegration.run(self):
		all_ok = false

	print("\n%s" % "=".repeat(40))
	if all_ok:
		print("  全部测试通过 ✅")
	else:
		print("  存在失败项 ❌")
	print("%s" % "=".repeat(40))

	get_tree().quit(0 if all_ok else 1)
