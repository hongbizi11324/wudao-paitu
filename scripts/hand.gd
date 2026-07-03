class_name Hand
extends Node2D

# ==============================
# 手牌管理 · 圆弧扇形布局 (Slay the Spire Style)
# 每张卡牌围绕虚拟圆心旋转排列，形成扇面
# ==============================

# --- 可调参数（在编辑器Inspector中调整） ---

@export_range(1, 20) var max_hand_size: int = 10     # 手牌上限，超过触发 hand_full
@export var card_width: float = 120.0                # 卡牌宽度（影响间距计算）
@export var arc_radius: float = 500.0                # 扇形半径（越大弧越平）450左右
@export var max_fan_angle: float = 30.0              # 扇形总角度（度），60°=适中
@export var hover_lift: float = -80.0                # 悬停/选中时上浮高度（负=向上）

# --- 信号 ---

signal hand_full()              # 手牌满了，抽牌会失败
signal card_selected(card)      # 确认出牌（第二次点击同一张卡）

# --- 运行时数据 ---

var cards: Array = []           # 当前手牌列表，按索引从左到右排列
var hovered_card = null         # 当前鼠标悬停的卡（null=无）
var selected_card = null        # 当前选中的卡（鼠标点击锁定，null=无）
var _tween: Tween               # 排列动画控制器

# --- 常量 ---

const DIM_ALPHA: float = 0.7    # 非活跃卡牌的透明系数


# ==============================
# 卡牌增删
# ==============================

func add_card(card) -> bool:
	"""添加一张卡到手牌。返回 true 表示成功。"""
	if cards.size() >= max_hand_size:
		hand_full.emit()
		return false
	# 连接悬停信号（避免重复连接）
	if not card.mouse_entered.is_connected(_on_hover_start):
		card.mouse_entered.connect(_on_hover_start.bind(card))
		card.mouse_exited.connect(_on_hover_end.bind(card))
	card.clicked.connect(_on_card_clicked.bind(card))
	cards.append(card)
	add_child(card)
	_rearrange()
	return true


func remove_card(card):
	"""从手牌移除一张卡（打出/销毁时调用）。"""
	if not cards.has(card):
		return
	cards.erase(card)
	if selected_card == card: selected_card = null
	if hovered_card == card: hovered_card = null
	remove_child(card)
	_rearrange()


func clear():
	"""清空所有手牌。"""
	for c in cards:
		c.queue_free()
	cards.clear()
	selected_card = null
	hovered_card = null


# ==============================
# 扇形排列算法
# ==============================

func _rearrange():
	"""重新排列所有卡牌到扇形位置。"""
	var count = cards.size()
	if count == 0: return

	if _tween: _tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var angle_step = 0.0
	if count > 1: angle_step = max_fan_angle / (count - 1)    # 相邻卡牌的角度间隔
	var start_angle = -max_fan_angle / 1.5                    # 最左边卡牌的角度

	for i in range(count):
		var card = cards[i]
		var angle = start_angle + i * angle_step              # 当前卡牌在圆弧上的角度
		var pos = _calc_arc_pos(angle)                        # 按圆周位置计算 (x,y)
		var rot = deg_to_rad(angle)                           # 卡牌旋转弧度

		card.z_index = i                                      # 右牌盖左牌
		if card != hovered_card and card != selected_card:    # 悬停/选中的卡不受排列影响
			_tween.tween_property(card, "position", pos, 0.2)
			_tween.tween_property(card, "rotation", rot, 0.2)
			_tween.tween_property(card, "scale", Vector2.ONE, 0.2)
			card.modulate.a = DIM_ALPHA if (hovered_card or selected_card) else 1.0


func _calc_arc_pos(angle_deg: float) -> Vector2:
	"""
	计算卡牌在圆弧上的位置。
	圆心在屏幕下方虚拟位置，中心卡（角度0）正好在原点上。
	"""
	var rad = deg_to_rad(angle_deg)
	return Vector2(arc_radius * sin(rad), -arc_radius * cos(rad) + arc_radius)


# ==============================
# 悬停 + 选中交互
# ==============================

func _on_hover_start(card):
	"""鼠标进入卡牌区域：高亮，不上浮。"""
	hovered_card = card
	_update_states()


func _on_hover_end(card):
	"""鼠标离开卡牌区域：所有牌恢复。"""
	if hovered_card == card:
		hovered_card = null
		_update_states()


func _on_card_clicked(card):
	"""
	卡牌点击逻辑：
	- 第一次点击 → 选中（抬起 + 回正）
	- 第二次点击同一张 → 确认出牌
	"""
	if selected_card == card:
		card_selected.emit(card)
	else:
		selected_card = card
		hovered_card = null
		_update_states()


func _update_states():
	"""
	刷新所有卡牌的视觉状态：
	- 选中的卡 → 上浮 + 回正 + 放大 + 最前层
	- 悬停仅变亮
	- 其余卡 → 回到扇形位置 + 变暗
	"""
	var count = cards.size()
	if count == 0: return

	if _tween: _tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var angle_step = 0.0
	if count > 1: angle_step = max_fan_angle / (count - 1)
	var start_angle = -max_fan_angle / 2.0

	for i in range(count):
		var card = cards[i]
		var angle = start_angle + i * angle_step
		var base = _calc_arc_pos(angle)
		var is_sel = card == selected_card
		var is_hover = card == hovered_card

		card.modulate.a = 1.0 if (is_hover or is_sel) else DIM_ALPHA
		card.z_index = 100 if is_sel else i

		if is_sel:
			_tween.tween_property(card, "position", base + Vector2(0, hover_lift), 0.15)
			_tween.tween_property(card, "rotation", 0.0, 0.15)
			_tween.tween_property(card, "scale", Vector2(1.15, 1.15), 0.15)
		else:
			_tween.tween_property(card, "position", base, 0.15)
			_tween.tween_property(card, "rotation", deg_to_rad(angle), 0.15)
			_tween.tween_property(card, "scale", Vector2.ONE, 0.15)


func deselect():
	"""取消选中（回合结束、切换场景等）。"""
	selected_card = null
	_update_states()


func get_card_count() -> int:
	return cards.size()
