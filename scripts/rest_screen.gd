extends CanvasLayer

# ==============================
# 休息点
# 选择「调息」或「冥想」
# ==============================

signal closed(next_action: String)  # "heal" or "cultivate"

@onready var overlay = $Overlay
@onready var panel = $Panel
@onready var title_label = $Panel/TitleLabel
@onready var desc_label = $Panel/DescLabel
@onready var heal_btn = $Panel/HealBtn
@onready var cultivate_btn = $Panel/CultivateBtn


func _ready():
	heal_btn.pressed.connect(_on_heal)
	cultivate_btn.pressed.connect(_on_cultivate)
	overlay.gui_input.connect(_on_overlay_clicked)


func open():
	title_label.text = "🧘 休息点"
	desc_label.text = "前方路途艰险，稍作休整再做打算吧。"
	heal_btn.text = "调息  —  恢复 30%% 血量（%d → %d）" % [
		GameData.player_hp, ceili(GameData.player_hp * 1.3)
	]
	cultivate_btn.text = "冥想  —  获得 10 修为 + 10 金币"
	visible = true


func _on_heal():
	closed.emit("heal")
	visible = false


func _on_cultivate():
	closed.emit("cultivate")
	visible = false


func _on_overlay_clicked(event: InputEvent):
	pass  # 必须选一个
