class_name TurnManager
extends Node

# ==============================
# 回合状态机
# 单人：PLAYER1 → ENEMY → PLAYER1
# 双人（同屏/联机）：PLAYER1(P1+P2同时) → ENEMY → PLAYER1
# ==============================

enum Turn { PLAYER1, PLAYER2, ENEMY }

var current_turn: int = Turn.PLAYER1
var active: bool = false
var is_dual_mode: bool = false

# 双人模式下，追踪双方是否都点了结束回合
var p1_ended: bool = false
var p2_ended: bool = false

signal turn_started(turn: int)
signal turn_changed(turn: int)


func start_battle(dual: bool = false):
	is_dual_mode = dual
	p1_ended = false
	p2_ended = false
	current_turn = Turn.PLAYER1
	active = true
	turn_started.emit(current_turn)


func end_player_turn():
	if is_dual_mode:
		if p1_ended and p2_ended:
			current_turn = Turn.ENEMY
			p1_ended = false
			p2_ended = false
			turn_changed.emit(current_turn)
	else:
		current_turn = Turn.ENEMY
		turn_changed.emit(current_turn)


func end_enemy_turn():
	current_turn = Turn.PLAYER1
	p1_ended = false
	p2_ended = false
	turn_changed.emit(current_turn)
