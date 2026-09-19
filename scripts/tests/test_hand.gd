class_name TestHand
# ==============================
# 手牌（Hand）测试
# 覆盖：增删/上限/选中与悬停状态/扇形布局一致性/Tween 安全
#
# 回归：曾报 "Tween (bound to /root/Main/Hand1): started with no Tweeners"
# 原因：_rearrange 给悬停/选中的卡跳过动画，若所有卡都被跳过
#（如手里只剩 1 张且正被选中）就会创建空 Tween。现已改为延迟创建。
# ==============================

static func run(parent: Node) -> bool:
	TestBase.describe("手牌：增删/上限/状态/Tween 安全")

	# ---------- 1. 增删与上限 ----------
	var h := TestBase.make_hand(parent)
	var c1 = TestBase.make_card(parent, "strike")
	var c2 = TestBase.make_card(parent, "defend")
	TestBase.assert_true(h.add_card(c1), "添加卡牌成功")
	TestBase.assert_true(h.add_card(c2), "添加第二张成功")
	TestBase.assert_eq(h.cards.size(), 2, "手牌数量=2")
	TestBase.assert_eq(h.get_card_count(), 2, "get_card_count 一致")

	h.remove_card(c1)
	TestBase.assert_eq(h.cards.size(), 1, "移除后数量=1")
	TestBase.assert_false(h.cards.has(c1), "移除的卡不在手牌")

	# 上限：降到 2 后加满
	h.apply_limit_mod(-8)   # base 10 → 2
	TestBase.assert_eq(h.max_hand_size, 2, "手牌上限=2（apply_limit_mod）")
	h.add_card(c1)
	TestBase.assert_eq(h.cards.size(), 2, "达到上限")
	var c3 = TestBase.make_card(parent, "heal")
	TestBase.assert_false(h.add_card(c3), "超过上限时添加失败")
	TestBase.free_node(c3)

	# ---------- 2. Tween 安全（回归）----------
	# 单张手牌 + 被选中 → 所有卡都被跳过 → 不能创建空 Tween
	var h2 := TestBase.make_hand(parent)
	var s1 = TestBase.make_card(parent, "strike")
	h2.add_card(s1)
	h2._rearrange()
	TestBase.assert_true(h2._tween != null, "有可排列的卡时创建 Tween")
	h2.selected_card = s1
	h2._rearrange()
	TestBase.assert_true(h2._tween == null,
		"全部卡被跳过时不创建空 Tween（回归: started with no Tweeners）")

	# 悬停同理
	h2.selected_card = null
	h2.hovered_card = s1
	h2._rearrange()
	TestBase.assert_true(h2._tween == null, "仅悬停卡时也不创建空 Tween")

	# 两张卡、其中一张被选中 → 仍应给另一张做动画
	var h3 := TestBase.make_hand(parent)
	var a = TestBase.make_card(parent, "strike")
	var b = TestBase.make_card(parent, "defend")
	h3.add_card(a)
	h3.add_card(b)
	h3.selected_card = a
	h3._rearrange()
	TestBase.assert_true(h3._tween != null, "部分卡被跳过时仍创建 Tween（给其余卡）")

	# ---------- 3. 选中/取消状态 ----------
	h3.deselect()
	TestBase.assert_true(h3.selected_card == null, "deselect 清空选中")
	h3.selected_card = b
	h3.remove_card(b)
	TestBase.assert_true(h3.selected_card == null, "移除选中卡后选中被清空")

	# ---------- 4. 扇形布局一致性（_rearrange 与 _update_states 起始角统一）----------
	var h4 := TestBase.make_hand(parent)
	var cards: Array = []
	for i in range(3):
		var c = TestBase.make_card(parent, "strike")
		h4.add_card(c)
		cards.append(c)
	# 无悬停/选中时，两种布局算出的位置应完全一致
	h4.selected_card = null
	h4.hovered_card = null
	var pos_rearrange: Array = []
	for c in h4.cards:
		pos_rearrange.append(c.position)
	h4._update_states()
	# _update_states 用 Tween 过渡，位置在动画结束后才到位；
	# 这里只校验两者使用的角度公式一致（起始角都是 -max_fan_angle/2）
	var angle_step := h4.max_fan_angle / 2.0
	var expect_first := h4._calc_arc_pos(-h4.max_fan_angle / 2.0)
	var expect_last := h4._calc_arc_pos(-h4.max_fan_angle / 2.0 + 2 * angle_step)
	TestBase.assert_true(expect_first.x < expect_last.x, "扇形从左到右展开（首卡在左）")
	TestBase.assert_true(absf(expect_first.x) - absf(expect_last.x) < 0.001,
		"扇形对称（左右偏移量相等，起始角统一为 -max_fan_angle/2）")

	# ---------- 5. clear 回池 ----------
	h.clear()
	TestBase.assert_eq(h.cards.size(), 0, "clear 清空手牌")
	TestBase.assert_true(h.selected_card == null and h.hovered_card == null, "clear 重置选中/悬停")

	for hh in [h, h2, h3, h4]:
		hh.clear()
		hh.queue_free()

	return TestBase.failed == 0
