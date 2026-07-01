extends CanvasLayer

# ==============================
# 战斗胜利奖励弹窗
# 显示3张卡牌供玩家选择1张
# ==============================

signal card_chosen(card_id: String)
signal skipped()

@onready var overlay = $Overlay
@onready var panel = $Panel
@onready var title_label = $Panel/TitleLabel
@onready var card_container = $Panel/CardContainer
@onready var skip_btn = $Panel/SkipBtn


func _ready():
	skip_btn.pressed.connect(_on_skip)
	overlay.gui_input.connect(_on_overlay_clicked)


# 打开奖励弹窗
# options: 3 个 card_id 的数组
func open(options: Array):
	title_label.text = "选择一张奖励卡牌"
	
	# 清空旧的
	for c in card_container.get_children():
		c.queue_free()
	
	# 放入3张候选卡
	for card_id in options:
		_add_card_option(card_id)
	
	visible = true


# 添加一张可选卡牌
func _add_card_option(card_id: String):
	var data = _load_card_data(card_id)
	if data == null:
		return
	
	var preview = ColorRect.new()
	preview.custom_minimum_size = Vector2(140, 200)
	preview.size = Vector2(140, 200)
	preview.mouse_filter = 1  # STOP — 可点击
	preview.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# 卡牌颜色
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
	
	# 标签
	var name_label = _make_label(data.card_name, 130, 24, Vector2(5, 8), 13, Color(1, 1, 1, 1))
	preview.add_child(name_label)
	
	var cost_label = _make_label("费: %d" % data.cost, 130, 20, Vector2(5, 36), 12, Color(1, 0.85, 0.2, 1))
	preview.add_child(cost_label)
	
	var desc_label = _make_label(data.description, 130, 90, Vector2(5, 62), 11, Color(0.8, 0.8, 0.9, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_child(desc_label)
	
	# 点击 → 选中这张卡
	preview.gui_input.connect(_on_card_clicked.bind(card_id))
	
	# 悬停效果
	preview.mouse_entered.connect(_on_card_hover.bind(preview))
	preview.mouse_exited.connect(_on_card_unhover.bind(preview))
	
	card_container.add_child(preview)


# 点击卡牌
func _on_card_clicked(event: InputEvent, card_id: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		card_chosen.emit(card_id)
		visible = false


# 悬停高亮
func _on_card_hover(preview: ColorRect):
	preview.modulate = Color(1.15, 1.15, 1.15, 1)


func _on_card_unhover(preview: ColorRect):
	preview.modulate = Color(1, 1, 1, 1)


func _on_skip():
	skipped.emit()
	visible = false


func _on_overlay_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_on_skip()


func _load_card_data(card_id: String) -> CardData:
	var path = "res://resources/cards/%s.tres" % card_id
	return load(path) as CardData


func _make_label(text: String, w: float, h: float, pos: Vector2, font_size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.size = Vector2(w, h)
	label.position = pos
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label
