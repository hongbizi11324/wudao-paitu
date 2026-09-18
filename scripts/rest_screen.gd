extends CanvasLayer

# ==============================
# 休息点
# 选择「调息」「冥想」或「强化」
# ==============================

signal closed(next_action: String)  # "heal" / "cultivate"
signal upgrade_requested()          # 打开强化卡牌选择器

@onready var overlay = $Overlay
@onready var panel = $Panel
@onready var title_label = $Panel/TitleLabel
@onready var desc_label = $Panel/DescLabel
@onready var heal_btn = $Panel/HealBtn
@onready var cultivate_btn = $Panel/CultivateBtn
@onready var upgrade_btn = $Panel/UpgradeBtn


func _ready():
	heal_btn.pressed.connect(_on_heal)
	cultivate_btn.pressed.connect(_on_cultivate)
	upgrade_btn.pressed.connect(_on_upgrade)
	overlay.gui_input.connect(_on_overlay_clicked)


## open(interactive)：联机客机传 false（选择权在主机，只展示）
func open(interactive: bool = true):
	title_label.text = "🧘 休息点"
	heal_btn.disabled = not interactive
	cultivate_btn.disabled = not interactive
	upgrade_btn.disabled = not interactive
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
	var up_count := GameData.upgradeable_cards(1).size()
	if GameData.is_dual_mode:
		up_count += GameData.upgradeable_cards(2).size()
	upgrade_btn.text = "强化 — 永久升级一张卡牌（可强化 %d 张）" % up_count
	upgrade_btn.disabled = upgrade_btn.disabled or up_count == 0
	visible = true


func _on_heal():
	closed.emit("heal")
	visible = false


func _on_cultivate():
	closed.emit("cultivate")
	visible = false


func _on_upgrade():
	upgrade_requested.emit()


func _on_overlay_clicked(event: InputEvent):
	pass  # 必须选一个
