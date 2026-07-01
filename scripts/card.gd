extends ColorRect

# ==============================
# 卡牌画面组件
# 根节点 ColorRect 控制卡牌尺寸
# FrameImage (TextureRect) 显示牌框 PNG
# TypeOverlay (ColorRect) 半透明类型色
# ==============================

var card_data: CardData
var original_x: float  # 在 Hand 中排列时的 X 位置

signal clicked(card)


func setup(data: CardData):
	card_data = data
	
	# ---- 卡牌名（含门派标识） ----
	var school_tag = ""
	if data.school != "":
		var tag = {"shaolin":"🏯", "wudang":"☯", "xiaoyao":"🦋"}
		school_tag = tag.get(data.school, "") + " "
	$NameLabel.text = school_tag + data.card_name
	$CostLabel.text = "%d" % data.cost
	$DescLabel.text = data.description
	$RetainLabel.visible = data.retain
	
	# ---- 文字描边（保证在任何底图上都清晰） ----
	# 卡牌名：白字 + 黑描边
	$NameLabel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	$NameLabel.add_theme_constant_override("outline_size", 2)
	$NameLabel.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	
	# 费用：金字 + 黑描边
	$CostLabel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	$CostLabel.add_theme_constant_override("outline_size", 2)
	
	# 描述：亮白字 + 细描边 + 稍大字号
	$DescLabel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	$DescLabel.add_theme_constant_override("outline_size", 1)
	$DescLabel.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	$DescLabel.add_theme_font_size_override("font_size", 11)
	
	# 保留标签：黄字 + 描边
	$RetainLabel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	$RetainLabel.add_theme_constant_override("outline_size", 1)
	
	# ---- 卡牌类型色（半透明叠加在牌框图上） ----
	match data.card_type:
		CardData.CardType.ATTACK:
			$TypeOverlay.color = Color(0.3, 0.15, 0.15, 0.2)
		CardData.CardType.SKILL:
			$TypeOverlay.color = Color(0.15, 0.25, 0.3, 0.2)
		CardData.CardType.POWER:
			$TypeOverlay.color = Color(0.2, 0.15, 0.3, 0.2)
		CardData.CardType.INNER:
			$TypeOverlay.color = Color(0.15, 0.3, 0.2, 0.2)
		CardData.CardType.MOVEMENT:
			$TypeOverlay.color = Color(0.3, 0.2, 0.3, 0.2)


func _gui_input(event):
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		clicked.emit(self)
