extends CanvasLayer

# ==============================
# 卡牌选择器（通用弹窗）
# 用于「强化」等需要从牌组里挑一张卡的场景。
# 牌面绘制走 CardPreviewFactory，与其它界面保持一致。
# ==============================

signal card_picked(card_id: String)
signal cancelled()

@onready var overlay = $Overlay
@onready var panel = $Panel
@onready var title_label = $Panel/TitleLabel
@onready var grid = $Panel/ScrollContainer/Grid
@onready var hint_label = $Panel/HintLabel
@onready var cancel_btn = $Panel/CancelBtn


func _ready():
	cancel_btn.pressed.connect(_on_cancel)
	overlay.gui_input.connect(_on_overlay_clicked)


## open(card_ids, title)：展示可选的卡牌（空数组会提示无可选项）
func open(card_ids: Array, title: String = "选择一张卡牌"):
	title_label.text = title
	_clear()
	for cid in card_ids:
		var card := CardPreviewFactory.make(cid, 120, 190, 1.0)
		card.gui_input.connect(_on_card_clicked.bind(cid))
		grid.add_child(card)
	hint_label.text = "共 %d 张可选" % card_ids.size() if card_ids.size() > 0 else "没有可选的卡牌"
	visible = true


func _clear():
	for c in grid.get_children():
		c.queue_free()


func _on_card_clicked(event: InputEvent, card_id: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		visible = false
		card_picked.emit(card_id)


func _on_cancel():
	visible = false
	cancelled.emit()


func _on_overlay_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		_on_cancel()
