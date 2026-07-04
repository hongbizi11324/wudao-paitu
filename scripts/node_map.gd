extends CanvasLayer

# ==============================
# 杀戮尖塔风格地图选择
# ==============================

signal node_selected(node_type: int)

# ---- 布局参数 ----
const NODE_SIZE: Vector2 = Vector2(80, 80)
const LAYER_SPACING: int = 140
const NODE_NAMES = {
	0: "普通战斗", 1: "精英战斗", 2: "藏经阁", 3: "休息点", 4: "随机事件"
}

# ---- 节点美术资源 ----
const NODE_TEXTURE_BATTLE_NORMAL = preload("res://assets/images/ui/slices/普通战斗.tres")
const NODE_TEXTURE_BATTLE_ELITE = preload("res://assets/images/ui/slices/精英战斗.tres")
const NODE_TEXTURE_BOSS = preload("res://assets/images/ui/slices/boss战斗.tres")
const NODE_TEXTURE_SHOP = preload("res://assets/images/ui/slices/商店.tres")
const NODE_TEXTURE_REST = preload("res://assets/images/ui/slices/休息处.tres")
const NODE_TEXTURE_EVENT = preload("res://assets/images/ui/slices/随机事件.tres")
const BG_TEX = preload("res://assets/images/backgrounds/背景遮罩.png")

# ---- 节点引用 ----
var _map_nodes: Array = []         # [layer_idx][node_idx] = TextureRect
var _current_layer: int = -1
var _map_content: Control = null
var _map_bg: TextureRect = null
var _scroll: ScrollContainer = null
var _info_label: Label = null
var _title_label: Label = null
var _container: Control = null


func _ready() -> void:
	_build_ui()


func _build_ui():
	# ── 全屏暗色遮罩（挡住 main.tscn） ──
	var overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 1)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# ── 背景图 ──
	_map_bg = TextureRect.new()
	_map_bg.name = "Bg"
	_map_bg.texture = BG_TEX
	_map_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_map_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# ── 滚动内容 ──
	_map_content = Control.new()
	_map_content.name = "MapContent"
	_map_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_content.add_child(_map_bg)

	# ── 滚动容器 ──
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size = Vector2(1200, 625)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var sbg = StyleBoxFlat.new()
	sbg.bg_color = Color(0, 0, 0, 0)
	_scroll.add_theme_stylebox_override("panel", sbg)
	var sbar = StyleBoxFlat.new()
	sbar.bg_color = Color(0.3, 0.2, 0.1, 0.3)
	sbar.corner_radius_top_left = 4
	sbar.corner_radius_bottom_left = 4
	sbar.corner_radius_top_right = 4
	sbar.corner_radius_bottom_right = 4
	_scroll.add_theme_stylebox_override("scroll", sbar)
	_scroll.add_child(_map_content)

	# ── 标签 ──
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.size = Vector2(1200, 34)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_title_label.add_theme_constant_override("outline_size", 1)

	_info_label = Label.new()
	_info_label.name = "Info"
	_info_label.size = Vector2(1200, 22)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75, 0.9))
	_info_label.add_theme_font_size_override("font_size", 13)

	# ── 外层容器 ──
	_container = Control.new()
	_container.name = "Container"
	_container.position = Vector2(40, 10)
	_container.size = Vector2(1200, 700)

	_title_label.position = Vector2(0, 14)
	_info_label.position = Vector2(0, 48)
	_scroll.position = Vector2(0, 75)

	_container.add_child(_title_label)
	_container.add_child(_info_label)
	_container.add_child(_scroll)
	add_child(_container)


func open():
	visible = true
	
	# 退出按钮（角落常显）
	var back_btn = Button.new()
	back_btn.text = "✕"
	back_btn.size = Vector2(36, 36)
	back_btn.position = Vector2(10, 10)
	back_btn.pressed.connect(_on_back_to_menu)
	add_child(back_btn)
	
	if not GameData.map_active:
		GameData.generate_new_act()

	_clear_map()
	_current_layer = GameData.map_current_offset

	var total_layers = GameData.get_layer_count()
	var start_f = GameData.get_map_floor(0)
	var end_f = GameData.get_map_floor(total_layers - 1)

	_title_label.text = "🗺 武道天梯 · 第%d大关" % GameData.map_act_count
	_info_label.text = "修为: %d/%d  金币: %d  %s境 · %d层→%d层" % [
		GameData.cultivation, GameData.cultivation_to_next,
		GameData.gold, GameData.realm_names[GameData.current_realm],
		start_f, end_f
	]

	var cw = 1200.0
	var cm = 80.0
	var cu = cw - cm * 2.0
	var ch = total_layers * LAYER_SPACING + NODE_SIZE.y + 60

	# ── 设置滚动内容大小 ──
	_map_content.custom_minimum_size = Vector2(cw, ch)

	# ── 背景图撑满内容区 ──
	_map_bg.position = Vector2(0, 0)
	_map_bg.size = Vector2(cw, ch)

	# ── 画节点（从下到上） ──
	for li in range(total_layers):
		var nodes = GameData.map_layers[li]
		var yp = ch - li * LAYER_SPACING - NODE_SIZE.y - 20

		for ni in range(nodes.size()):
			var nd = nodes[ni]
			var st = GameData.map_node_states[li][ni]
			var boss = nd.has("is_boss") and nd.is_boss
			var col = nd.get("col", ni)
			var xp = cm + float(col) / float(GameData.MAP_COLUMN_COUNT - 1) * cu
			xp -= NODE_SIZE.x / 2

			var card = _make_node(nd, st, boss, li, ni)
			card.position = Vector2(xp, yp)
			_map_content.add_child(card)

			while _map_nodes.size() <= li:
				_map_nodes.append([])
			_map_nodes[li].append(card)

	# ── 连线 + 发光 ──
	_draw_lines()

	# ── 滚到最下面（起点） ──
	_scroll.scroll_vertical = _map_content.custom_minimum_size.y


func _make_node(nd: Dictionary, st: String, boss: bool, li: int, ni: int) -> TextureRect:
	var nt = nd.type
	var av = st == "available"
	var vs = st == "visited"
	var start = nd.has("is_start") and nd.is_start

	var tex: AtlasTexture
	if boss:            tex = NODE_TEXTURE_BOSS
	elif start:         tex = NODE_TEXTURE_REST
	else:
		match nt:
			GameData.NodeType.BATTLE_NORMAL:   tex = NODE_TEXTURE_BATTLE_NORMAL
			GameData.NodeType.BATTLE_ELITE:    tex = NODE_TEXTURE_BATTLE_ELITE
			GameData.NodeType.SHOP:            tex = NODE_TEXTURE_SHOP
			GameData.NodeType.REST:            tex = NODE_TEXTURE_REST
			GameData.NodeType.EVENT:           tex = NODE_TEXTURE_EVENT
			_:                                 tex = NODE_TEXTURE_BATTLE_NORMAL

	var card = TextureRect.new()
	card.texture = tex
	card.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.size = NODE_SIZE if not boss else Vector2(100, 80)
	card.custom_minimum_size = card.size

	if start or vs:
		card.modulate = Color(0.75, 0.75, 0.75, 0.85)
	elif not av:
		card.modulate = Color(0.9, 0.9, 0.9, 0.95)
	else:
		card.modulate = Color(1, 1, 1, 1)

	if av and not vs:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(_on_click.bind(li, ni, card))
		card.mouse_entered.connect(_on_hover.bind(li, ni, card))
		card.mouse_exited.connect(_on_unhover.bind(card))
	else:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return card


func _on_click(ev: InputEvent, li: int, ni: int, card: TextureRect):
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	get_viewport().set_input_as_handled()

	var nd = GameData.select_map_node(li, ni)
	if nd.is_empty():
		return
	node_selected.emit(nd.type)
	visible = false


func _on_hover(li: int, ni: int, card: TextureRect):
	var nd = GameData.map_layers[li][ni]
	var nt = nd.type
	var boss = nd.has("is_boss") and nd.is_boss
	var fn = GameData.get_map_floor(li)
	card.scale = Vector2(1.15, 1.15)

	var tn = "♛Boss" if boss else NODE_NAMES[nt]
	var desc = ""
	match nt:
		GameData.NodeType.BATTLE_NORMAL: desc = "修为+10  金币+12"
		GameData.NodeType.BATTLE_ELITE:  desc = "修为+20  金币+20  ⚠危险"
		GameData.NodeType.SHOP:          desc = "购买或删除卡牌"
		GameData.NodeType.REST:          desc = "恢复血量或冥想"
		GameData.NodeType.EVENT:         desc = "奇遇或陷阱"
	if boss:
		desc = "镇关Boss！胜者为王"
	_info_label.text = "第%d层 · %s — %s" % [fn, tn, desc]


func _on_unhover(card: TextureRect):
	card.scale = Vector2(1.0, 1.0)
	_info_label.text = "修为: %d/%d  金币: %d  %s境 · 点击选择路线" % [
		GameData.cultivation, GameData.cultivation_to_next,
		GameData.gold, GameData.realm_names[GameData.current_realm]
	]


func _make_ink_line(fp: Vector2, tp: Vector2, act: bool, fl: int, fn: int, tl: int, tn: int) -> Line2D:
	# 用连接坐标做种子，同一条线每次画都一样
	var seed = fl * 1000 + fn * 100 + tl * 10 + tn
	seed = (seed * 9301 + 49297) % 233280
	var rng = RandomNumberGenerator.new()
	rng.seed = seed

	var line = Line2D.new()
	var segs = 6
	var pts: PackedVector2Array = []
	var dir_v = (tp - fp).normalized()
	var perp = Vector2(-dir_v.y, dir_v.x)
	var length = fp.distance_to(tp)

	for i in range(segs + 1):
		var t = float(i) / float(segs)
		var base = fp.lerp(tp, t)
		# 用多个正弦波叠加产生自然抖动
		var wobble = sin(t * PI * 4.6 + rng.randf() * 0.5) * length * 0.025 \
				+ cos(t * PI * 2.3 + rng.randf() * 0.5) * length * 0.015
		pts.append(base + perp * wobble)
	line.points = pts
	line.width = 2.5
	line.default_color = Color(0.15, 0.1, 0.05, 0.7) if act else Color(0.15, 0.1, 0.05, 0.2)
	return line


func _clear_map():
	_map_nodes = []
	for c in _map_content.get_children():
		if c != _map_bg:
			c.queue_free()


func _draw_lines():
	if _map_content == null or GameData.map_connections.is_empty() or _map_nodes.is_empty():
		return

	for conn in GameData.map_connections:
		var fl = conn.from_layer
		var fn = conn.from_node
		var tl = conn.to_layer
		var tn = conn.to_node
		if fl >= _map_nodes.size() or fn >= _map_nodes[fl].size():
			continue
		if tl >= _map_nodes.size() or tn >= _map_nodes[tl].size():
			continue
		var fc = _map_nodes[fl][fn]
		var tc = _map_nodes[tl][tn]
		var fp = fc.position + fc.size / 2
		var tp = tc.position + tc.size / 2
		var fs = GameData.map_node_states[fl][fn]
		var ts = GameData.map_node_states[tl][tn]
		var act = (fs != "locked") and (ts != "locked")
		var line = _make_ink_line(fp, tp, act, fl, fn, tl, tn)
		_map_content.add_child(line)

	# 发光环
	var co = GameData.map_current_offset
	if co >= 0 and co < _map_nodes.size():
		for j in range(_map_nodes[co].size()):
			if GameData.map_node_states[co][j] == "available":
				var card = _map_nodes[co][j]
				var glow = ColorRect.new()
				glow.color = Color(0, 0, 0, 0)
				glow.size = card.size + Vector2(8, 8)
				glow.position = card.position + Vector2(-4, -4)
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
				_map_content.add_child(glow)
				break

func _on_back_to_menu():
func _on_back_to_menu():
	if NetworkManager.is_lan:
		NetworkManager.cleanup()
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
