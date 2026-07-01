extends CanvasLayer

# ==============================
# 随机事件弹窗
# 显示事件描述 + 选项按钮
# ==============================

signal closed(event_id: String, action: String)

@onready var overlay = $Overlay
@onready var panel = $Panel
@onready var title_label = $Panel/TitleLabel
@onready var desc_label = $Panel/DescLabel
@onready var option_a = $Panel/OptionA
@onready var option_b = $Panel/OptionB


func _ready():
	option_a.pressed.connect(_on_option_a)
	option_b.pressed.connect(_on_option_b)
	overlay.gui_input.connect(_on_overlay_clicked)


func open(event_data: Dictionary):
	title_label.text = "❓ %s" % event_data.title
	desc_label.text = event_data.desc
	option_a.text = event_data.options[0].text
	option_b.text = event_data.options[1].text
	set_meta("event_id", event_data.id)
	set_meta("action_a", event_data.options[0].action)
	set_meta("action_b", event_data.options[1].action)
	visible = true


func _on_option_a():
	closed.emit(get_meta("event_id"), get_meta("action_a"))
	visible = false


func _on_option_b():
	closed.emit(get_meta("event_id"), get_meta("action_b"))
	visible = false


func _on_overlay_clicked(event: InputEvent):
	pass
