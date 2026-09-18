class_name CardPreviewFactory
# ==============================
# 卡牌预览块工厂
# 统一的"卡面"绘制（名称/费用/描述/类型配色），供各界面复用，
# 避免每个界面各写一份绘制代码造成样式漂移。
#
# 返回一个可点击的 ColorRect；调用方负责连接 gui_input 与添加额外标签。
# ==============================

const TYPE_COLORS := {
	CardData.CardType.ATTACK: Color(0.3, 0.15, 0.15, 1),
	CardData.CardType.SKILL: Color(0.15, 0.25, 0.3, 1),
	CardData.CardType.POWER: Color(0.2, 0.15, 0.3, 1),
	CardData.CardType.INNER: Color(0.15, 0.3, 0.2, 1),
	CardData.CardType.MOVEMENT: Color(0.3, 0.2, 0.3, 1),
}


## 生成卡面块。w/h 为尺寸；font_scale 缩放字号（小卡传 0.85）
static func make(card_id: String, w: float = 120.0, h: float = 200.0, font_scale: float = 1.0) -> ColorRect:
	var data := GameData.load_card(card_id)
	var card := ColorRect.new()
	card.custom_minimum_size = Vector2(w, h)
	card.size = Vector2(w, h)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if data == null:
		card.color = Color(0.2, 0.2, 0.2, 1)
		card.add_child(label("缺失:%s" % card_id, w - 12, 20, Vector2(6, 8), 11, Color(1, 0.4, 0.4, 1)))
		return card

	card.color = TYPE_COLORS.get(data.card_type, Color(0.2, 0.2, 0.2, 1))
	card.set_meta("card_id", card_id)

	var fs := int(round(12 * font_scale))
	var nx := 6.0
	var ny := 6.0

	# 名称（强化卡带 "+" 用金色）
	var name_color := Color(1, 0.85, 0.35, 1) if GameData.is_upgraded(card_id) else Color(1, 1, 1, 1)
	card.add_child(label(data.card_name, w - 12, 20, Vector2(nx, ny), fs, name_color))

	# 费用
	card.add_child(label("费:%d" % data.cost, w - 12, 16, Vector2(nx, ny + 22), fs - 1, Color(1, 0.85, 0.2, 1)))

	# 描述
	var desc := label(data.description, w - 12, h * 0.42, Vector2(nx, ny + 42), fs - 1, Color(0.82, 0.82, 0.92, 1))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(desc)

	return card


static func label(text: String, w: float, h: float, pos: Vector2, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.size = Vector2(w, h)
	l.position = pos
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", fs)
	return l
