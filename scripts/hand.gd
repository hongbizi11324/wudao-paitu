class_name Hand
extends Node2D

# ==============================
# 手牌管理组件
# 支持：展开排列、选中浮起、确认出牌、取消选中
# ==============================

# --- 可配置参数 ---
@export_range(1, 15) var max_hand_size: int = 10
@export var spread: float = 450.0
@export var card_width: float = 145.0
@export var card_offset: float = 60.0

# --- 信号 ---
signal hand_full()
signal card_selected(card)   # 确认出牌（第二次点击同一张卡）

# --- 运行时状态 ---
var cards: Array = []
var selected_card = null     # 当前浮起的卡（null = 没有选中）
var _tween: Tween

# 浮起高度
const LIFT_Y: float = -80.0
# 未选中卡的透明度
const DIM_ALPHA: float = 0.6


# 不在这里创建 _tween，_rearrange 里按需创建


# 添加卡到手牌
func add_card(card) -> bool:
	if cards.size() >= max_hand_size:
		hand_full.emit()
		return false
	card.clicked.connect(_on_card_clicked)
	cards.append(card)
	add_child(card)
	_rearrange()
	return true


# 从手牌移除卡
func remove_card(card):
	if not cards.has(card):
		return
	# 如果这张卡正浮起，清除选中状态
	if selected_card == card:
		selected_card = null
	cards.erase(card)
	remove_child(card)
	_rearrange()


# 清空手牌
func clear():
	for c in cards:
		c.queue_free()
	cards.clear()
	selected_card = null
	_rearrange()


# ==============================
# 选中交互
# ==============================

# 卡牌被点击
func _on_card_clicked(card):
	# 如果这张卡已经浮起 → 确认出牌
	if selected_card == card:
		card_selected.emit(card)
		return
	
	# 否则选中这张卡（替换之前的选中）
	_select_card(card)


# 选中某张卡（替换之前的选中）
func _select_card(card):
	var prev = selected_card
	selected_card = card
	
	var tw = create_tween()
	for c in cards:
		if c == card:
			# 新选中的卡：浮起 + 最上层 + 恢复亮度
			c.z_index = 999
			tw.parallel().tween_property(c, "position:y", LIFT_Y, 0.12) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(c, "modulate", Color(1, 1, 1, 1), 0.08)
		elif c == prev:
			# 之前选中的卡：落回原位
			var idx = cards.find(c)
			c.z_index = cards.size() - idx
			tw.parallel().tween_property(c, "position", Vector2(c.original_x, 0), 0.1)
			tw.parallel().tween_property(c, "modulate", Color(1, 1, 1, DIM_ALPHA), 0.08)
		else:
			# 其余卡：变暗
			c.z_index = cards.size() - cards.find(c)
			tw.parallel().tween_property(c, "modulate", Color(1, 1, 1, DIM_ALPHA), 0.08)


# 取消选中（点击空白区域时调用）
func deselect():
	if selected_card == null:
		return
	
	var card = selected_card
	selected_card = null
	
	# 复原动画
	var tw = create_tween()
	for c in cards:
		if c == card:
			# 浮起的卡落回原位
			var idx = cards.find(c)
			var target_x = _get_card_x(idx)
			c.z_index = cards.size() - idx
			tw.parallel().tween_property(c, "position", Vector2(target_x, 0), 0.12) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			# 变暗的卡恢复正常
			tw.parallel().tween_property(c, "modulate", Color(1, 1, 1, 1), 0.1)


# ==============================
# 排列
# ==============================

func _rearrange():
	if cards.size() == 0:
		return
	
	var count = cards.size()
	var total_w = min(count * card_width, spread)
	var start_x = -total_w / 2 + card_offset
	var spacing = total_w / count
	
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	
	for i in range(count):
		var card = cards[i]
		var tx = start_x + i * spacing
		card.z_index = count - i
		card.original_x = tx
		_tween.parallel().tween_property(
			card, "position", Vector2(tx, 0), 0.15
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# 计算第 i 张卡的水平位置
func _get_card_x(index: int) -> float:
	if cards.size() <= 1:
		return 0.0
	var total_w = min(cards.size() * card_width, spread)
	var start_x = -total_w / 2 + card_offset
	var spacing = total_w / cards.size()
	return start_x + index * spacing
