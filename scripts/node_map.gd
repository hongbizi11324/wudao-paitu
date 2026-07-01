extends CanvasLayer

# ==============================
# 杀戮尖塔风格地图选择
# ==============================

signal node_selected(node_type: int)

# ---- 布局参数 ----
const NODE_SIZE: Vector2 = Vector2(56, 56)
const LAYER_SPACING: int = 95    # 层间距
const TOP_OFFSET: int = 75       # 顶部标题区高度
const NODE_COLORS = {
	0: Color(0.7, 0.2, 0.2, 1.0),    # BATTLE_NORMAL - 红
	1: Color(0.9, 0.15, 0.15, 1.0),  # BATTLE_ELITE - 亮红
	2: Color(0.15, 0.4, 0.65, 1.0),  # SHOP - 蓝
	3: Color(0.15, 0.55, 0.25, 1.0), # REST - 绿
	4: Color(0.55, 0.35, 0.15, 1.0), # EVENT - 橙
}
const NODE_ICONS = {
	0: "🗡",  # BATTLE_NORMAL
	1: "⚔",  # BATTLE_ELITE
	2: "商",  # SHOP
	3: "休",  # REST
	4: "?",  # EVENT
}
const NODE_NAMES = {
	0: "普通战斗", 1: "精英战斗", 2: "藏经阁", 3: "休息点", 4: "随机事件"
}
const BOSS_COLOR: Color = Color(0.8, 0.2, 0.05, 1.0)

# ---- 节点引用 ----
var _map_nodes: Array = []        # 二维数组: [layer_idx][node_idx] = ColorRect
var _hovered_node: Array = []     # [layer, node] 当前悬停的节点
var _current_layer: int = -1      # 当前层偏移
var _panel: Panel = null
var _info_label: Label = null
var _title_label: Label = null
var _draw_control: Control = null


func _ready() -> void:
	_build_ui()


func _build_ui():
	# 遮罩
	var overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	
	# 绘制控制区（画连线用）
	_draw_control = Control.new()
	_draw_control.name = "MapCanvas"
	_draw_control.anchor_right = 1.0
	_draw_control.anchor_bottom = 1.0
	_draw_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_control)
	
	# 主面板
	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.position = Vector2(40, 10)
	_panel.size = Vector2(1200, 700)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.10, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.2, 0.1, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	
	# 标题
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.position = Vector2(0, 14)
	_title_label.size = Vector2(1200, 34)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_title_label.add_theme_constant_override("outline_size", 1)
	_panel.add_child(_title_label)
	
	# 信息栏
	_info_label = Label.new()
	_info_label.name = "InfoLabel"
	_info_label.position = Vector2(0, 48)
	_info_label.size = Vector2(1200, 22)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75, 0.9))
	_info_label.add_theme_font_size_override("font_size", 13)
	_panel.add_child(_info_label)


func open():
	visible = true
	if not GameData.map_active:
		GameData.generate_new_act()
	
	_clear_map()
	_current_layer = GameData.map_current_offset
	
	var total_layers = GameData.get_layer_count()
	var start_floor = GameData.map_act_count * 6 + 2
	var end_floor = start_floor + total_layers - 1
	
	_title_label.text = "🗺 武道天梯 · 第%d大关" % GameData.map_act_count
	_info_label.text = "修为: %d/%d  金币: %d  %s境 · %d层→%d层" % [
		GameData.cultivation, GameData.cultivation_to_next,
		GameData.gold, GameData.realm_names[GameData.current_realm],
		start_floor, end_floor
	]
	
	# 计算每一层节点的 X 位置（居中）
	var panel_w = _panel.size.x
	var panel_h = _panel.size.y
	
	# 画节点
	for layer_idx in range(total_layers):
		var nodes = GameData.map_layers[layer_idx]
		var node_count = nodes.size()
		var start_x = (panel_w - node_count * (NODE_SIZE.x + 20)) / 2
		var y_pos = TOP_OFFSET + 15 + layer_idx * LAYER_SPACING
		
		# 楼层标签
		var floor_num = GameData.get_map_floor(layer_idx)
		var floor_label = Label.new()
		floor_label.text = "第%d层" % floor_num
		floor_label.position = Vector2(15, y_pos + 8)
		floor_label.size = Vector2(70, 20)
		floor_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7, 0.8))
		floor_label.add_theme_font_size_override("font_size", 11)
		_panel.add_child(floor_label)
		
		# 楼层类型徽标
		var ft = GameData._calc_floor_type(floor_num)
		var ft_label = Label.new()
		match ft:
			GameData.FloorType.BOSS:
				ft_label.text = "♛Boss"
				ft_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.1, 0.9))
			GameData.FloorType.ELITE:
				ft_label.text = "⚔精英"
				ft_label.add_theme_color_override("font_color", Color(0.85, 0.4, 0.4, 0.7))
			_:
				ft_label.text = ""
		ft_label.position = Vector2(15, y_pos + 26)
		ft_label.size = Vector2(70, 16)
		ft_label.add_theme_font_size_override("font_size", 10)
		_panel.add_child(ft_label)
		
		for node_idx in range(node_count):
			var node_data = nodes[node_idx]
			var state = GameData.map_node_states[layer_idx][node_idx]
			var is_boss = node_data.has("is_boss") and node_data.is_boss
			
			var x_pos = start_x + node_idx * (NODE_SIZE.x + 16)
			if node_count == 1:
				x_pos = (panel_w - NODE_SIZE.x) / 2  # Boss节点居中
			
			var card = _create_node_ui(node_data, state, is_boss, layer_idx, node_idx)
			card.position = Vector2(x_pos, y_pos)
			_panel.add_child(card)
			
			# 存引用
			while _map_nodes.size() <= layer_idx:
				_map_nodes.append([])
			_map_nodes[layer_idx].append(card)
	
	# 画连线 + 发光环
	_draw_lines()


func _create_node_ui(node_data: Dictionary, state: String, is_boss: bool, layer: int, node_idx: int) -> ColorRect:
	var ntype = node_data.type
	var is_available = (state == "available")
	var is_visited = (state == "visited")
	var is_current = (layer == _current_layer and is_available)
	
	# 主节点
	var card = ColorRect.new()
	card.size = NODE_SIZE if not is_boss else Vector2(80, 56)
	card.custom_minimum_size = card.size
	
	# 颜色
	if is_visited:
		card.color = Color(0.2, 0.2, 0.25, 0.5)  # 已访问变灰
	elif is_boss and is_available:
		card.color = BOSS_COLOR
	elif is_available:
		card.color = NODE_COLORS[ntype]
	else:
		card.color = Color(0.12, 0.12, 0.16, 0.8)  # 锁定变暗
	
	# 圆角
	var style = StyleBoxFlat.new()
	style.bg_color = card.color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	
	if is_current:
		style.border_color = Color(1, 0.85, 0.2, 1.0)
	elif is_available:
		style.border_color = Color(0.4, 0.4, 0.45, 0.8)
	else:
		style.border_color = Color(0.15, 0.15, 0.2, 0.6)
	
	card.add_theme_stylebox_override("panel", style)
	
	# 图标/文字
	var icon = Label.new()
	if is_boss:
		icon.text = "♛"
	elif is_visited:
		icon.text = "✓"
	else:
		icon.text = NODE_ICONS[ntype] if ntype in NODE_ICONS else "?"
	
	icon.size = card.size
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 22 if not is_boss else 28)
	
	if is_visited:
		icon.add_theme_color_override("font_color", Color(0.3, 0.35, 0.3, 0.7))
	elif is_available:
		icon.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	else:
		icon.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3, 0.5))
	
	icon.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	icon.add_theme_constant_override("outline_size", 1)
	card.add_child(icon)
	
	# 点击/悬停（仅 available 节点可交互）
	if is_available and not is_visited:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		card.gui_input.connect(_on_node_clicked.bind(layer, node_idx, card))
		card.mouse_entered.connect(_on_node_hover.bind(layer, node_idx, card))
		card.mouse_exited.connect(_on_node_unhover.bind(card))
	else:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	return card


func _on_node_clicked(event: InputEvent, layer: int, node_idx: int, card: ColorRect):
	if not (event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT):
		return
	get_viewport().set_input_as_handled()
	
	var node_data = GameData.select_map_node(layer, node_idx)
	if node_data.is_empty():
		return
	
	var ntype = node_data.type
	
	# 如果是 Boss 节点也标记为 BATTLE_ELITE 类型
	node_selected.emit(ntype)
	visible = false


func _on_node_hover(layer: int, node_idx: int, card: ColorRect):
	var node_data = GameData.map_layers[layer][node_idx]
	var ntype = node_data.type
	var is_boss = node_data.has("is_boss") and node_data.is_boss
	var floor_num = GameData.get_map_floor(layer)
	
	# 悬停放大
	card.scale = Vector2(1.15, 1.15)
	
	# 显示节点详情
	var type_name = "♛Boss" if is_boss else NODE_NAMES[ntype]
	var desc = ""
	match ntype:
		GameData.NodeType.BATTLE_NORMAL:
			desc = "修为+10  金币+12"
		GameData.NodeType.BATTLE_ELITE:
			desc = "修为+20  金币+20  ⚠危险"
		GameData.NodeType.SHOP:
			desc = "购买或删除卡牌"
		GameData.NodeType.REST:
			desc = "恢复血量或冥想"
		GameData.NodeType.EVENT:
			desc = "奇遇或陷阱"
	if is_boss:
		desc = "镇关Boss！胜者为王"
	
	_info_label.text = "第%d层 · %s — %s" % [floor_num, type_name, desc]


func _on_node_unhover(card: ColorRect):
	card.scale = Vector2(1.0, 1.0)
	# 恢复信息栏
	_info_label.text = "修为: %d/%d  金币: %d  %s境 · 点击选择路线" % [
		GameData.cultivation, GameData.cultivation_to_next,
		GameData.gold, GameData.realm_names[GameData.current_realm]
	]


func _clear_map():
	_map_nodes = []
	for c in _panel.get_children():
		# 保留永久标签（标题和信息），只清理动态创建的节点
		if c != _title_label and c != _info_label:
			c.queue_free()
	# 清理画布上的连线+光晕
	for c in _draw_control.get_children():
		c.queue_free()


func _draw_lines():
	# 在 _draw_control 上画节点间连线
	if _draw_control == null or GameData.map_connections.is_empty() or _map_nodes.is_empty():
		return
	
	var panel_pos = _panel.position
	
	for conn in GameData.map_connections:
		var fl = conn.from_layer
		var fn = conn.from_node
		var tl = conn.to_layer
		var tn = conn.to_node
		
		if fl >= _map_nodes.size() or fn >= _map_nodes[fl].size():
			continue
		if tl >= _map_nodes.size() or tn >= _map_nodes[tl].size():
			continue
		
		var from_card = _map_nodes[fl][fn]
		var to_card = _map_nodes[tl][tn]
		
		var from_pos = from_card.position + from_card.size / 2 + panel_pos
		var to_pos = to_card.position + to_card.size / 2 + panel_pos
		
		var from_state = GameData.map_node_states[fl][fn]
		var to_state = GameData.map_node_states[tl][tn]
		var is_active = (from_state != "locked") and (to_state != "locked")
		
		var line = Line2D.new()
		line.points = [from_pos, to_pos]
		line.width = 2.0
		if is_active:
			line.default_color = Color(0.45, 0.35, 0.2, 0.6)
		else:
			line.default_color = Color(0.15, 0.12, 0.08, 0.25)
		_draw_control.add_child(line)
	
	# 当前可选节点加发光环
	var cur_offset = GameData.map_current_offset
	if cur_offset >= 0 and cur_offset < _map_nodes.size():
		for j in range(_map_nodes[cur_offset].size()):
			if GameData.map_node_states[cur_offset][j] == "available":
				var card = _map_nodes[cur_offset][j]
				var glow = ColorRect.new()
				glow.size = card.size + Vector2(8, 8)
				glow.position = card.position + Vector2(-4, -4) + panel_pos
				var gs = StyleBoxFlat.new()
				gs.bg_color = Color(0, 0, 0, 0)
				gs.border_width_left = 2
				gs.border_width_top = 2
				gs.border_width_right = 2
				gs.border_width_bottom = 2
				gs.border_color = Color(1, 0.85, 0.2, 0.4)
				gs.corner_radius_top_left = 10
				gs.corner_radius_top_right = 10
				gs.corner_radius_bottom_right = 10
				gs.corner_radius_bottom_left = 10
				glow.add_theme_stylebox_override("panel", gs)
				glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_draw_control.add_child(glow)
				break
