extends ColorRect

# ==============================
# 卡牌画面组件
# 根节点 ColorRect 控制卡牌尺寸
# FrameImage (TextureRect) 显示牌框 PNG
# TypeOverlay (ColorRect) 半透明类型色
# ==============================

var card_data: CardData
signal clicked()


func setup(data: CardData):
	card_data = data
	_refresh_display()


func _refresh_display():
	if not card_data:
		return
	var data = card_data
	
	# ---- 卡牌名（含门派标识） ----
	var school_tag = ""
	if data.school != "":
		var tag = {"shaolin":"🏯", "wudang":"☯", "xiaoyao":"🦋"}
		school_tag = tag.get(data.school, "") + " "
	$NameLabel.text = school_tag + data.card_name
	$CostLabel.text = "%d" % data.cost
	$DescLabel.text = data.description
	$RetainLabel.visible = data.retain
	
	# ---- 文字描边 ----
	$NameLabel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	$NameLabel.add_theme_constant_override("outline_size", 2)
	$NameLabel.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	$CostLabel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	$CostLabel.add_theme_constant_override("outline_size", 2)
	$DescLabel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	$DescLabel.add_theme_constant_override("outline_size", 1)
	$DescLabel.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	$DescLabel.add_theme_font_size_override("font_size", 11)
	$RetainLabel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	$RetainLabel.add_theme_constant_override("outline_size", 1)
	
	# ---- 卡牌类型色 ----
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


## 用 Lua 预览实际效果，更新描述显示
func update_preview(ctx: Dictionary):
	if not card_data:
		return
	if not LuaRuntime or not LuaRuntime.enabled:
		_refresh_display()
		return
	
	# 把卡牌自身数据合并进 ctx
	var full_ctx = ctx.duplicate()
	full_ctx["card_id"] = card_data.card_id
	full_ctx["cost"] = card_data.cost
	full_ctx["card_type"] = card_data.card_type
	full_ctx["damage"] = card_data.damage
	full_ctx["block"] = card_data.block
	full_ctx["heal"] = card_data.heal
	full_ctx["draw"] = card_data.draw
	full_ctx["energy_gain"] = card_data.energy_gain
	full_ctx["repeat"] = card_data.repeat
	full_ctx["armor_break"] = card_data.armor_break
	full_ctx["school"] = card_data.school
	
	var result = LuaRuntime.preview_card(card_data.card_id, full_ctx)
	if result.is_empty():
		_refresh_display()
		return
	
	# 基础描述
	var desc = card_data.description
	
	# 构建预览数值后缀
	var parts = []
	var dmg = int(result.get("damage", 0))
	var blk = int(result.get("block", 0))
	var heal_amt = int(result.get("heal", 0))
	var draw = int(result.get("draw", 0))
	var eg = int(result.get("energy_gain", 0))
	var rpt = int(result.get("repeat_count", 1))
	
	if dmg > 0:
		var s = "伤害%d" % dmg
		if rpt > 1: s += "×%d" % rpt
		parts.append(s)
	if blk > 0: parts.append("格挡%d" % blk)
	if heal_amt > 0: parts.append("回血%d" % heal_amt)
	if draw > 0: parts.append("抽%d" % draw)
	if eg > 0: parts.append("内力+%d" % eg)
	
	if parts.size() > 0:
		$DescLabel.text = desc + "\n[实际: " + ", ".join(parts) + "]"
	else:
		$DescLabel.text = desc


func _gui_input(event):
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		clicked.emit()


# ==============================
# 对象池支持
# ==============================

# 回收时重置到初始状态
func reset_pooled():
	# 断开所有信号连接，避免重复连接报错
	for c in clicked.get_connections():
		clicked.disconnect(c.callable)
	for c in mouse_entered.get_connections():
		mouse_entered.disconnect(c.callable)
	for c in mouse_exited.get_connections():
		mouse_exited.disconnect(c.callable)
	
	card_data = null
	$NameLabel.text = ""
	$CostLabel.text = ""
	$DescLabel.text = ""
	$RetainLabel.visible = false
	$TypeOverlay.color = Color(1, 1, 1, 0)
