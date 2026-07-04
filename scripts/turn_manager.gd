class_name TurnManager
extends Node

# ==============================
# 回合状态机
# 双人热座：P1 → P2 → ENEMY → P1 → ...
# 单人模式：P1 → ENEMY → P1 → ...
# ==============================

enum Turn { PLAYER1, PLAYER2, ENEMY }

var current_turn: int = Turn.PLAYER1 :
	set = set_current_turn
var is_dual: bool = false
var active: bool = false

signal turn_started(turn: int)
signal battle_end(won: bool)


func set_current_turn(value: int):
	current_turn = value


func start_battle(dual: bool):
	"""开始/重新开始战斗"""
	is_dual = dual
	active = true
	_advance_to(Turn.PLAYER1)


# 玩家点击"结束回合"时调用
func end_player_turn():
	if not active or current_turn == Turn.ENEMY:
		return
	
	match current_turn:
		Turn.PLAYER1:
			_advance_to(Turn.PLAYER2 if is_dual else Turn.ENEMY)
		Turn.PLAYER2:
			_advance_to(Turn.ENEMY)


# 敌人执行完毕后调用
func end_enemy_turn():
	if not active or current_turn != Turn.ENEMY:
		return
	_advance_to(Turn.PLAYER1)


func _advance_to(next_turn: int):
	current_turn = next_turn
	turn_started.emit(current_turn)
