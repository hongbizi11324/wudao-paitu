class_name TestBase
# ==============================
# 测试基类：断言工具与统计
# 用法：Godot 场景模式（tests/test_boot.tscn）或编辑器 Ctrl+Shift+X 运行 test_runner
# ==============================

static var passed: int = 0
static var failed: int = 0
static var errors: Array[String] = []


static func reset():
	passed = 0
	failed = 0
	errors.clear()


static func describe(name: String):
	print("\n  📋 %s" % name)


static func assert_eq(got, expected, msg: String = "") -> bool:
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


static func assert_true(cond: bool, msg: String = "") -> bool:
	if cond:
		passed += 1
		return true
	failed += 1
	var full = "  ❌ %s" % (msg if msg else "预期为 true")
	errors.append(full)
	print(full)
	return false


static func assert_false(cond: bool, msg: String = "") -> bool:
	return assert_true(not cond, msg)


static func print_summary() -> bool:
	print("\n%s" % "=".repeat(40))
	print("  ✅ 通过: %d" % passed)
	print("  ❌ 失败: %d" % failed)
	if errors.size() > 0:
		print("  ———— 失败详情 ————")
		for e in errors:
			print(e)
	print("%s" % "=".repeat(40))
	return failed == 0


# ==============================
# 测试对象构造助手
# ==============================

static func make_player(cid: String = "") -> Player:
	var p := Player.new()
	p.character_id = cid
	p.max_hp = 60
	p.hp = 60
	p.max_energy = 5
	p.energy = 3
	return p


static func make_enemy() -> Enemy:
	var e := Enemy.new()
	e.max_hp = 40
	e.hp = 40
	return e


static func make_hand(parent: Node) -> Hand:
	var h := Hand.new()
	parent.add_child(h)
	return h


static func make_card(parent: Node, card_id: String) -> Node:
	var data: CardData = load("res://resources/cards/%s.tres" % card_id)
	var scene: PackedScene = load("res://scenes/card.tscn")
	var card = CardPool.acquire(scene)
	card.setup(data)
	return card


static func free_node(n):
	if n and is_instance_valid(n):
		n.free()
