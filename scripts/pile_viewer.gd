extends CanvasLayer

# ==============================
# 牌堆查看器（模态弹窗）
# 查看牌库/弃牌堆里的所有卡牌
# ==============================

# 缓存卡牌数据，不用反复读文件
var _card_data_cache: Dictionary = {}

@onready var overlay = $Overlay
@onready var panel = $Panel
@onready var title_label = $Panel/TitleLabel
@onready var card_container = $Panel/ScrollContainer/CardContainer
@onready var close_btn = $Panel/CloseBtn


func _ready():
	close_btn.pressed.connect(_on_close)
	overlay.gui_input.connect(_on_overlay_clicked)
	# 给卡片网格加间距
	card_container.add_theme_constant_override("hseparation", 12)
	card_container.add_theme_constant_override("vseparation", 12)


# 打开查看器
# pile: 卡牌 ID 数组 (如 ["strike", "defend", ...])
# title: 标题文字 (如 "弃牌堆" / "牌库")
func open(pile: Array, title: String):
	title_label.text = "%s (%d张)" % [title, len(pile)]
	
	# 清空旧的卡牌显示
	_clear_cards()
	
	# 遍历牌堆，逐张显示
	for card_id in pile:
		var data = _load_card_data(card_id)
		if data == null:
			continue
		_add_card_preview(data)
	
	# 显示弹窗
	visible = true


func _on_close():
	_close()


# 点击遮罩也关闭
func _on_overlay_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_close()


func _close():
	visible = false


# 加载卡牌数据（带缓存）
func _load_card_data(card_id: String) -> CardData:
	if _card_data_cache.has(card_id):
		return _card_data_cache[card_id]
	
	var path = "res://resources/cards/%s.tres" % card_id
	var data = load(path) as CardData
	if data:
		_card_data_cache[card_id] = data
	return data


# 清空所有卡牌预览
func _clear_cards():
	for child in card_container.get_children():
		child.queue_free()


# 添加一张卡牌预览到网格
func _add_card_preview(data: CardData):
	# 用 ColorRect 做一张小卡牌预览
	var preview = ColorRect.new()
	# ★ custom_minimum_size 告诉 Container 这个孩子需要多大空间
	preview.custom_minimum_size = Vector2(110, 160)
	preview.size = Vector2(110, 160)
	
	# 根据类型换颜色
	match data.card_type:
		CardData.CardType.ATTACK:
			preview.color = Color(0.3, 0.15, 0.15, 1)
		CardData.CardType.SKILL:
			preview.color = Color(0.15, 0.25, 0.3, 1)
		CardData.CardType.POWER:
			preview.color = Color(0.2, 0.15, 0.3, 1)
		CardData.CardType.INNER:
			preview.color = Color(0.15, 0.3, 0.2, 1)
		CardData.CardType.MOVEMENT:
			preview.color = Color(0.3, 0.2, 0.3, 1)
	
	# 卡牌名
	var name_label = _make_label(data.card_name, 100, 22, Vector2(5, 6), 12, Color(1, 1, 1, 1))
	preview.add_child(name_label)
	
	# 费用
	var cost_label = _make_label("费: %d" % data.cost, 100, 18, Vector2(5, 34), 11, Color(1, 0.85, 0.2, 1))
	preview.add_child(cost_label)
	
	# 描述
	var desc_label = _make_label(data.description, 100, 75, Vector2(5, 58), 11, Color(0.8, 0.8, 0.9, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_child(desc_label)
	
	card_container.add_child(preview)


# 辅助函数：创建一个带样式的 Label
func _make_label(text: String, w: float, h: float, pos: Vector2, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.size = Vector2(w, h)
	label.position = pos
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label
