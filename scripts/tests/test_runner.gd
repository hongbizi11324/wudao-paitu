@tool
extends EditorScript
# ==============================
# 单元测试运行器
#
# 使用方法：
# 1. 在脚本编辑器中打开此文件
# 2. 按 Ctrl+Shift+X（或点脚本编辑器顶部的「运行」按钮）
# ==============================

func _run():
	print("\n%s" % "=".repeat(40))
	print("  武道牌途 — 单元测试")
	print("  Godot %s" % Engine.get_version_info().get("string", "?"))
	print("%s" % "=".repeat(40))
	
	var all_passed = true
	
	# 效果系统测试
	print("\n▶ 运行效果系统测试...")
	var ok = TestEffects.run()
	if ok:
		print("  ✅ 效果系统测试通过")
	else:
		print("  ❌ 效果系统测试有失败项")
		all_passed = false
	
	print("\n%s" % "=".repeat(40))
	if all_passed:
		print("  全部测试通过! ✅")
	else:
		print("  部分测试失败, 请查看上方详情 ❌")
	print("%s" % "=".repeat(40))
