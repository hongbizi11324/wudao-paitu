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


## open(interactive)：联机客机传 false（选择权在主机，只展示）
func open(interactive: bool = true):
	title_label.text = "🧘 休息点"
	heal_btn.disabled = not interactive
	cultivate_btn.disabled = not interactive
	if GameData.is_dual_mode:
		# 双人模式：调息治疗全队（各恢复30%最大生命）
		desc_label.text = "前方路途艰险，稍作休整再做打算吧。" if interactive \
				else "主机正在选择休整方式..."
		heal_btn.text = "调息 — 全队各恢复30%%最大生命（%d→%d / %d→%d）" % [
			GameData.player_hp, mini(GameData.player_max_hp, GameData.player_hp + ceili(GameData.player_max_hp * 0.3)),
			GameData.player2_hp, mini(GameData.player2_max_hp, GameData.player2_hp + ceili(GameData.player2_max_hp * 0.3)),
		]
	else:
		desc_label.text = "前方路途艰险，稍作休整再做打算吧。" if interactive \
				else "主机正在选择休整方式..."
		heal_btn.text = "调息 — 恢复30%%最大生命（%d → %d）" % [
			GameData.player_hp,
			mini(GameData.player_max_hp, GameData.player_hp + ceili(GameData.player_max_hp * 0.3)),
		]
	cultivate_btn.text = "冥想 — 获得 10 修为 + 10 金币"
	visible = true


func _on_heal():
	closed.emit("heal")
	visible = false


func _on_cultivate():
	closed.emit("cultivate")
	visible = false


func _on_overlay_clicked(event: InputEvent):
	pass  # 必须选一个
