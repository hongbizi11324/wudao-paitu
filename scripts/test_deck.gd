extends CanvasLayer

# ==============================
# 测试模式 · 自选10张牌
# ==============================

const MAX_SELECT: int = 10

# 所有可选卡牌
var all_cards = [
	"punch", "meditate", "light_step",
	"double_strike", "tactics", "iron_wall", "vigor", "whirlwind",
	"flowing_cloud_sword", "triple_stab", "sword_energy",
	"iron_shirt", "vajra_fist", "golden_bell",
	"strike", "defend", "bash", "heal",
	# ---- 门派卡 ----
	"sl_fist", "sl_iron", "sl_golden", "sl_arhat", "sl_damo",
	"wd_taiji", "wd_soft", "wd_steps", "wd_heavy", "wd_twoway",
	"xy_beiming", "xy_lingbo", "xy_wuxiang", "xy_zhemel", "xy_bahuang"
]

var selected: Array = []

@onready var panel = $Panel
@onready var title = $Panel/Title
@onready var grid = $Panel/ScrollContainer/Grid
@onready var count_label = $Panel/CountLabel
@onready var start_btn = $Panel/StartBtn
@onready var back_btn = $Panel/BackBtn


func _ready():
	back_btn.pressed.connect(_on_back)
	start_btn.pressed.connect(_on_start)
	start_btn.disabled = true
	_load_cards()


func _load_cards():
	for card_id in all_cards:
		var data = _load_data(card_id)
		if data == null:
			continue
		
		var card = ColorRect.new()
		card.custom_minimum_size = Vector2(110, 155)
		card.size = Vector2(110, 155)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.set_meta("card_id", card_id)
		
		# 颜色
		match data.card_type:
			CardData.CardType.ATTACK:
				card.color = Color(0.35, 0.18, 0.18, 1)
			CardData.CardType.SKILL:
				card.color = Color(0.18, 0.28, 0.35, 1)
			CardData.CardType.POWER:
				card.color = Color(0.22, 0.18, 0.35, 1)
			CardData.CardType.INNER:
				card.color = Color(0.18, 0.35, 0.22, 1)
			CardData.CardType.MOVEMENT:
				card.color = Color(0.35, 0.22, 0.35, 1)
		
		# 标签
		var nl = _label(data.card_name, 100, 20, Vector2(5, 5), 11, Color(1,1,1,1))
		card.add_child(nl)
		var cl = _label("费:%d" % data.cost, 100, 16, Vector2(5, 28), 10, Color(1,0.85,0.2,1))
		card.add_child(cl)
		var dl = _label(data.description, 100, 60, Vector2(5, 48), 10, Color(0.8,0.8,0.9,1))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(dl)
		
		card.gui_input.connect(_on_card_clicked.bind(card))
		grid.add_child(card)


func _on_card_clicked(event: InputEvent, card: ColorRect):
	if not (event is InputEventMouseButton and event.pressed):
		return
	
	var card_id: String = card.get_meta("card_id")
	
	if selected.has(card_id):
		# 取消选中
		selected.erase(card_id)
		card.modulate = Color(0.7, 0.7, 0.7, 1)
		card.scale = Vector2(1, 1)
	else:
		if selected.size() >= MAX_SELECT:
			return  # 已满
		# 选中
		selected.append(card_id)
		card.modulate = Color(1, 1, 1, 1)
		card.scale = Vector2(1.05, 1.05)
	
	_update_ui()


func _update_ui():
	count_label.text = "已选 %d / %d" % [selected.size(), MAX_SELECT]
	start_btn.disabled = selected.size() != MAX_SELECT


func _on_start():
	if selected.size() != MAX_SELECT:
		return
	# 写入 GameData 并开战
	GameData.new_run_custom(selected.duplicate())
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back():
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _load_data(card_id: String) -> CardData:
	return load("res://resources/cards/%s.tres" % card_id) as CardData


func _label(text: String, w: float, h: float, pos: Vector2, fs: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.size = Vector2(w, h)
	l.position = pos
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", fs)
	return l
