extends Node2D

# ==============================
# 游戏主控
# 开局、出牌、回合、UI 更新
# ==============================

var deck_config = [
	"strike", "strike", "defend",
	"bash", "heal",
	"strike", "defend"
]

@onready var hand = $Hand
@onready var player = $Player
@onready var enemy = $Enemy
@onready var gm = $GameManager

@onready var energy_label = $EnergyLabel
@onready var hp_label = $HPLabel
@onready var block_label = $BlockLabel
@onready var enemy_hp_label = $EnemyHPLabel
@onready var end_turn_btn = $EndTurnBtn
@onready var turn_label = $TurnLabel


func _ready():
	# 调试：最简单的测试
	var test = ColorRect.new()
	test.size = Vector2(100, 100)
	test.color = Color(1, 0, 0, 1)
	test.position = Vector2(100, 100)
	add_child(test)
	print("_ready 执行了！")
	
	# ---- 创建卡牌 ----
	var card_scene = load("res://scenes/card.tscn")
	if card_scene == null:
		print("错误：无法加载卡牌场景！")
		return
	print("卡牌场景加载成功，开始创建牌组...")
	
	for id in deck_config:
		var path = "res://resources/cards/%s.tres" % id
		var data = load(path)
		if data == null:
			print("错误：无法加载卡牌数据 %s" % path)
			continue
		var card = card_scene.instantiate()
		card.setup(data)
		hand.add_card(card)
	
	print("卡牌创建完毕，手牌数量：%d" % hand.cards.size())
	
	# ---- 初始化 ----
	player.init()
	enemy.init(40)
	
	# ---- 连接信号 ----
	hand.card_selected.connect(_on_card_confirmed)
	player.energy_changed.connect(_on_energy_changed)
	player.hp_changed.connect(_on_hp_changed)
	player.block_changed.connect(_on_block_changed)
	enemy.hp_changed.connect(_on_enemy_hp_changed)
	gm.battle_end.connect(_on_battle_end)
	
	# ---- 更新 UI ----
	_update_all_ui()
	turn_label.text = "你的回合"
	print("游戏初始化完成")


func _on_card_confirmed(card):
	if not player.spend_energy(card.card_data.cost):
		print("能量不够！")
		return
	gm.play_card(card.card_data, card, player, enemy, hand)


func _on_end_turn():
	if hand.selected_card != null:
		hand.deselect()
	end_turn_btn.disabled = true
	turn_label.text = "敌人回合"
	gm.start_enemy_turn(player, enemy)
	_update_all_ui()
	end_turn_btn.disabled = false
	turn_label.text = "你的回合"


func _on_battle_end(won):
	end_turn_btn.disabled = true
	turn_label.text = "胜利！" if won else "败北..."


func _update_all_ui():
	_on_energy_changed(player.energy, player.max_energy)
	_on_hp_changed(player.hp, player.max_hp)
	_on_block_changed(player.block)
	_on_enemy_hp_changed(enemy.hp, enemy.max_hp)

func _on_energy_changed(cur, max_val):
	energy_label.text = "能量 %d/%d" % [cur, max_val]

func _on_hp_changed(cur, max_val):
	hp_label.text = "HP %d/%d" % [cur, max_val]

func _on_block_changed(cur):
	block_label.text = "格挡 %d" % cur if cur > 0 else ""

func _on_enemy_hp_changed(cur, max_val):
	enemy_hp_label.text = "敌人 HP %d/%d" % [cur, max_val]
