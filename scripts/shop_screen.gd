extends CanvasLayer

# ==============================
# 藏经阁 · 商店
# 买牌 + 删牌（用金币）
# ==============================

signal continue_requested()

const BUY_PRICE: int = 10
const DELETE_PRICE: int = 6

# 商店卡池
var shop_pool = [
	"double_strike", "tactics", "iron_wall", "vigor", "whirlwind",
	"flowing_cloud_sword", "triple_stab", "sword_energy",
	"iron_shirt", "vajra_fist", "golden_bell",
	"bash", "heal",
	# ---- 门派卡 ----
	"sl_fist", "sl_iron", "sl_golden", "sl_arhat", "sl_damo",
	"wd_taiji", "wd_soft", "wd_steps", "wd_heavy", "wd_twoway",
	"xy_beiming", "xy_lingbo", "xy_wuxiang", "xy_zhemel", "xy_bahuang"
]

var shop_cards: Array = []  # 当前展示的3张

@onready var overlay = $Overlay
@onready var panel = $Panel
@onready var title = $Panel/Title
@onready var gold_label = $Panel/GoldLabel
@onready var buy_container = $Panel/BuyContainer
@onready var delete_container = $Panel/DeleteScroll/DeleteContainer
@onready var delete_scroll = $Panel/DeleteScroll
@onready var msg_label = $Panel/MsgLabel
@onready var continue_btn = $Panel/ContinueBtn


func _ready():
	continue_btn.pressed.connect(_on_continue)
	overlay.gui_input.connect(_on_overlay_clicked)


func open():
	_restock()
	_refresh_delete_list()
	msg_label.text = ""
	_update_gold()
	visible = true


func _restock():
	for c in buy_container.get_children():
		c.queue_free()
	shop_cards.clear()
	
	var pool = shop_pool.duplicate()
	pool.shuffle()
	shop_cards = pool.slice(0, 3)
	
	for card_id in shop_cards:
		var data = _load_data(card_id)
		if data == null:
			continue
		
		var card = _make_card_preview(data)
		var can_afford = GameData.gold >= BUY_PRICE
		var price_label = _label("购买 %d金币" % BUY_PRICE, 120, 16, Vector2(8, 180), 11,
			Color(1, 0.85, 0.2, 0.9) if can_afford else Color(0.5, 0.5, 0.5, 0.8))
		card.add_child(price_label)
		card.gui_input.connect(_on_buy_clicked.bind(card_id, card))
		if not can_afford:
			card.modulate = Color(0.5, 0.5, 0.5, 1)
		buy_container.add_child(card)


func _refresh_delete_list():
	for c in delete_container.get_children():
		c.queue_free()
	
	for card_id in GameData.player_deck:
		var data = _load_data(card_id)
		if data == null:
			continue
		
		var card = _make_card_preview(data, true)
		var can_afford = GameData.gold >= DELETE_PRICE
		var price_label = _label("删 %d金币" % DELETE_PRICE, 120, 14, Vector2(6, 130), 10,
			Color(0.9, 0.3, 0.3, 0.9) if can_afford else Color(0.5, 0.5, 0.5, 0.8))
		card.add_child(price_label)
		card.gui_input.connect(_on_delete_clicked.bind(card_id, card))
		if not can_afford:
			card.modulate = Color(0.5, 0.5, 0.5, 1)
		delete_container.add_child(card)


func _on_buy_clicked(event: InputEvent, card_id: String, _node: ColorRect):
	if not (event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not GameData.spend_gold(BUY_PRICE):
		msg_label.text = "金币不足！"
		return
	GameData.add_card(card_id)
	msg_label.text = "购得 %s！" % _load_data(card_id).card_name
	_restock()
	_refresh_delete_list()
	_update_gold()


func _on_delete_clicked(event: InputEvent, card_id: String, _node: ColorRect):
	if not (event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not GameData.spend_gold(DELETE_PRICE):
		msg_label.text = "金币不足！"
		return
	if GameData.remove_card_from_deck(card_id):
		msg_label.text = "已删除"
		_refresh_delete_list()
		_restock()
		_update_gold()


func _update_gold():
	gold_label.text = "金币：%d" % GameData.gold


func _on_continue():
	continue_requested.emit()
	visible = false


func _on_overlay_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_on_continue()


# ---------- 辅助 ----------

func _make_card_preview(data: CardData, small: bool = false) -> ColorRect:
	var card = ColorRect.new()
	var w = 120 if not small else 110
	var h = 200 if not small else 150
	card.custom_minimum_size = Vector2(w, h)
	card.size = Vector2(w, h)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	match data.card_type:
		CardData.CardType.ATTACK:
			card.color = Color(0.3, 0.15, 0.15, 1)
		CardData.CardType.SKILL:
			card.color = Color(0.15, 0.25, 0.3, 1)
		CardData.CardType.POWER:
			card.color = Color(0.2, 0.15, 0.3, 1)
		CardData.CardType.INNER:
			card.color = Color(0.15, 0.3, 0.2, 1)
		CardData.CardType.MOVEMENT:
			card.color = Color(0.3, 0.2, 0.3, 1)
	
	var fs = 12 if not small else 10
	var nx = 6 if not small else 5
	var ny = 8 if not small else 5
	
	var nl = _label(data.card_name, w - 12, 20, Vector2(nx, ny), fs, Color(1, 1, 1, 1))
	card.add_child(nl)
	
	var cl = _label("费:%d" % data.cost, w - 12, 16, Vector2(nx, ny + 24), fs - 1, Color(1, 0.85, 0.2, 1))
	card.add_child(cl)
	
	var dl_h = 60 if not small else 40
	var dl = _label(data.description, w - 12, dl_h, Vector2(nx, ny + 44), fs - 1, Color(0.8, 0.8, 0.9, 1))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(dl)
	
	return card


func _label(text: String, w: float, h: float, pos: Vector2, fs: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.size = Vector2(w, h)
	l.position = pos
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", fs)
	return l


func _load_data(card_id: String) -> CardData:
	return load("res://resources/cards/%s.tres" % card_id) as CardData
