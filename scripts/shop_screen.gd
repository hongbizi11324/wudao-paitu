extends CanvasLayer

# ==============================
# 藏经阁 · 商店
# 买牌 + 删牌（用金币）
#
# 修复记录：
# - 旧版买/删一次就整体刷新进货（等于无限商店），现在已售出的槽位保持"已售罄"
# - 双人模式可选买入/删除哪个玩家的牌组
# - 联机模式下库存由主机生成并同步，客机的购买/删除请求转发主机结算
# ==============================

signal continue_requested()
signal buy_requested(card_id: String, target_player: int)   # 联机客机 → 转发主机
signal delete_requested(card_id: String, target_player: int)

const BUY_PRICE: int = 10
const DELETE_PRICE: int = 6
const STOCK_COUNT: int = 3

var stock: Array = []        # 库存槽位：card_id，"" 表示已售罄
var sold: Array = []         # 各槽位是否已售出
var target_player: int = 1   # 双人模式：当前操作的牌组（1=P1 / 2=P2）

@onready var overlay = $Overlay
@onready var panel = $Panel
@onready var title = $Panel/Title
@onready var gold_label = $Panel/GoldLabel
@onready var buy_container = $Panel/BuyContainer
@onready var delete_container = $Panel/DeleteScroll/DeleteContainer
@onready var delete_scroll = $Panel/DeleteScroll
@onready var msg_label = $Panel/MsgLabel
@onready var continue_btn = $Panel/ContinueBtn

var _target_btn_p1: Button = null
var _target_btn_p2: Button = null


func _ready():
	continue_btn.pressed.connect(_on_continue)
	overlay.gui_input.connect(_on_overlay_clicked)


## open(host_stock, host_sold)：联机客机传主机同步来的库存；单机/主机传空自行生成
func open(host_stock: Array = [], host_sold: Array = []):
	target_player = 1
	if host_stock.size() > 0:
		stock = host_stock.duplicate()
		sold = host_sold.duplicate()
	else:
		_restock()
	_setup_target_toggle()
	_refresh_all()
	msg_label.text = ""
	visible = true


## 联机：主机推送新库存/售罄状态后刷新显示
func refresh_synced(new_stock: Array, new_sold: Array):
	stock = new_stock.duplicate()
	sold = new_sold.duplicate()
	_refresh_all()


# ==============================
# 库存
# ==============================

func _shop_pool() -> Array:
	# 商店卡池 = 通用 + 本队门派（不再出现全门派大杂烩）
	var extra: Array = []
	if GameData.is_dual_mode:
		var s2 = GameData.character_data.get(GameData.selected_character_2, {}).get("school", "")
		if s2 != "":
			extra.append(s2)
	return GameData.get_character_pool("", extra)


func _restock():
	stock = []
	sold = []
	var pool = _shop_pool().duplicate()
	pool.shuffle()
	var picks = pool.slice(0, STOCK_COUNT)
	for i in range(STOCK_COUNT):
		stock.append(picks[i] if i < picks.size() else "")
		sold.append(false)


# ==============================
# 双人模式：牌组切换
# ==============================

func _setup_target_toggle():
	if _target_btn_p1 and is_instance_valid(_target_btn_p1):
		_target_btn_p1.queue_free()
		_target_btn_p1 = null
	if _target_btn_p2 and is_instance_valid(_target_btn_p2):
		_target_btn_p2.queue_free()
		_target_btn_p2 = null
	if not GameData.is_dual_mode:
		return

	_target_btn_p1 = Button.new()
	_target_btn_p1.text = "P1牌组"
	_target_btn_p1.position = Vector2(490, 14)
	_target_btn_p1.size = Vector2(90, 30)
	_target_btn_p1.add_theme_font_size_override("font_size", 13)
	_target_btn_p1.pressed.connect(func(): _set_target(1))
	panel.add_child(_target_btn_p1)

	_target_btn_p2 = Button.new()
	_target_btn_p2.text = "P2牌组"
	_target_btn_p2.position = Vector2(588, 14)
	_target_btn_p2.size = Vector2(90, 30)
	_target_btn_p2.add_theme_font_size_override("font_size", 13)
	_target_btn_p2.pressed.connect(func(): _set_target(2))
	panel.add_child(_target_btn_p2)
	_update_target_buttons()


func _set_target(p: int):
	target_player = p
	_update_target_buttons()
	_refresh_delete_list()
	_toast("当前操作 %s 的牌组" % ("P1" if p == 1 else "P2"))


func _update_target_buttons():
	if _target_btn_p1 and is_instance_valid(_target_btn_p1):
		_target_btn_p1.modulate = Color(1, 0.9, 0.4) if target_player == 1 else Color(0.6, 0.6, 0.6, 0.7)
	if _target_btn_p2 and is_instance_valid(_target_btn_p2):
		_target_btn_p2.modulate = Color(0.6, 0.85, 1) if target_player == 2 else Color(0.6, 0.6, 0.6, 0.7)


# ==============================
# 渲染
# ==============================

func _refresh_all():
	_refresh_buy_list()
	_refresh_delete_list()
	_update_gold()


func _refresh_buy_list():
	for c in buy_container.get_children():
		c.queue_free()

	for i in range(stock.size()):
		var card_id: String = stock[i]
		if card_id == "":
			continue
		var data = _load_data(card_id)
		if data == null:
			continue

		var is_sold = sold[i]
		var card = _make_card_preview(data)
		var can_afford = GameData.gold >= BUY_PRICE and not is_sold
		var price_label = _label(
			("已售罄" if is_sold else "购买 %d金币" % BUY_PRICE), 120, 16,
			Vector2(8, 180), 11,
			Color(0.5, 0.5, 0.5, 0.9) if not can_afford else Color(1, 0.85, 0.2, 0.9))
		card.add_child(price_label)
		card.gui_input.connect(_on_buy_clicked.bind(i))
		if not can_afford:
			card.modulate = Color(0.5, 0.5, 0.5, 1) if not is_sold else Color(0.35, 0.35, 0.35, 0.6)
		buy_container.add_child(card)


func _refresh_delete_list():
	for c in delete_container.get_children():
		c.queue_free()

	var deck: Array = GameData.player_deck if target_player == 1 else GameData.player2_deck
	for card_id in deck:
		var data = _load_data(card_id)
		if data == null:
			continue

		var card = _make_card_preview(data, true)
		var can_afford = GameData.gold >= DELETE_PRICE
		var price_label = _label("删 %d金币" % DELETE_PRICE, 120, 14, Vector2(6, 130), 10,
			Color(0.9, 0.3, 0.3, 0.9) if can_afford else Color(0.5, 0.5, 0.5, 0.8))
		card.add_child(price_label)
		card.gui_input.connect(_on_delete_clicked.bind(card_id))
		if not can_afford:
			card.modulate = Color(0.5, 0.5, 0.5, 1)
		delete_container.add_child(card)


# ==============================
# 交互
# ==============================

func _on_buy_clicked(event: InputEvent, slot_idx: int):
	if not (event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if slot_idx >= stock.size() or sold[slot_idx]:
		return
	var card_id: String = stock[slot_idx]

	# 联机客机：请求转发给主机结算，主机广播后刷新本地
	if NetworkManager.is_lan and not NetworkManager.is_host:
		buy_requested.emit(card_id, target_player)
		return

	if not GameData.spend_gold(BUY_PRICE):
		_toast("金币不足！")
		return
	_apply_buy(card_id, target_player)
	sold[slot_idx] = true
	_refresh_all()


func _apply_buy(card_id: String, p: int):
	if p == 2:
		GameData.add_card_to_player2(card_id)
	else:
		GameData.add_card(card_id)
	_toast("购得 %s！（%s牌组）" % [_load_data(card_id).card_name, "P2" if p == 2 else "P1"])


func _on_delete_clicked(event: InputEvent, card_id: String):
	if not (event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT):
		return

	# 联机客机：转发主机
	if NetworkManager.is_lan and not NetworkManager.is_host:
		delete_requested.emit(card_id, target_player)
		return

	if not GameData.spend_gold(DELETE_PRICE):
		_toast("金币不足！")
		return
	if _apply_delete(card_id, target_player):
		_toast("已删除 %s" % _load_data(card_id).card_name)
		_refresh_delete_list()
		_refresh_buy_list()
		_update_gold()


func _apply_delete(card_id: String, p: int) -> bool:
	if p == 2:
		return GameData.remove_card_from_player2_deck(card_id)
	return GameData.remove_card_from_deck(card_id)


## 联机：主机代客机结算购买（扣钱由调用方完成），标记槽位售罄并刷新
func apply_remote_buy(card_id: String, p: int) -> void:
	for i in range(stock.size()):
		if stock[i] == card_id and not sold[i]:
			sold[i] = true
			break
	_apply_buy(card_id, p)
	_refresh_all()


## 联机：主机代客机结算删牌
func apply_remote_delete(card_id: String, p: int) -> void:
	_apply_delete(card_id, p)
	_refresh_all()


func _update_gold():
	gold_label.text = "金币：%d" % GameData.gold


func _on_continue():
	continue_requested.emit()
	visible = false


func _on_overlay_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_on_continue()


func _toast(msg: String):
	msg_label.text = msg


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
