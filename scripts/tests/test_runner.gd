@tool
extends EditorScript
# ==============================
# 单元测试运行器（编辑器模式）
# 在脚本编辑器打开本文件按 Ctrl+Shift+X 运行；
# 无头环境请用：godot --headless --path . res://tests/test_boot.tscn
# ==============================

func _run():
	print("\n%s" % "=".repeat(40))
	print("  武道牌途 — 单元测试")
	print("  Godot %s" % Engine.get_version_info().get("string", "?"))
	print("%s" % "=".repeat(40))

	TestBase.reset()
	var all_passed := true

	print("\n▶ 回合状态机测试...")
	TestBase.reset()
	if not TestTurnManager.run():
		all_passed = false

	print("\n▶ 全局数据与地图测试...")
	TestBase.reset()
	if not TestGameData.run():
		all_passed = false

	print("\n▶ 出牌结算器测试...")
	TestBase.reset()
	var tmp_parent := Node.new()
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.root.add_child(tmp_parent)
	if not TestCardExecutor.run(tmp_parent):
		all_passed = false
	if tree:
		tmp_parent.queue_free()

	print("\n▶ Lua 卡牌效果测试...")
	TestBase.reset()
	if not TestLuaCards.run():
		all_passed = false

	print("\n%s" % "=".repeat(40))
	if all_passed:
		print("  全部测试通过! ✅")
	else:
		print("  部分测试失败, 请查看上方详情 ❌")
	print("%s" % "=".repeat(40))
