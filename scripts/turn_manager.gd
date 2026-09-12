class_name TurnManager
extends Node

# ==============================
# 回合状态机
# 单人：PLAYER1 → ENEMY → PLAYER1
# 双人（同屏/联机）：PLAYER1(P1+P2同时) → ENEMY → PLAYER1
#
# 【状态所有权约定】（A1/A2 修复）
# 1. 模式标志的唯一数据源是 GameData.is_dual_mode。本类不持有副本，
#    一律通过 is_dual() 实时查询——副本会在战斗开始后与源头失同步。
# 2. _p1_ended / _p2_ended 是本状态机的内部状态，外部【禁止】直接读写。
#    读取走 has_player_ended(pid)，写入走 mark_player_ended(pid)。
#    所有修改集中在一个入口，才能做校验和留日志。
# ==============================

enum Turn { PLAYER1, PLAYER2, ENEMY }

var current_turn: int = Turn.PLAYER1
var active: bool = false

# 双人模式下，追踪双方是否都点了结束回合（内部状态，禁止外部直接访问）
var _p1_ended: bool = false
var _p2_ended: bool = false

signal turn_started(turn: int)
signal turn_changed(turn: int)


# ==============================
# 模式查询
# ==============================

## 是否双人模式。
## 唯一数据源是 GameData.is_dual_mode —— 不存副本，避免两份数据各自演化。
func is_dual() -> bool:
	return GameData.is_dual_mode


# ==============================
# 生命周期
# ==============================

func start_battle():
	_p1_ended = false
	_p2_ended = false
	current_turn = Turn.PLAYER1
	active = true
	turn_started.emit(current_turn)


# ==============================
# 结束标记：唯一写入口
# ==============================

## 标记某个玩家已结束回合。
## 返回 true 表示双方都已结束、回合已推进到敌人回合。
func mark_player_ended(pid: int) -> bool:
	if pid != 1 and pid != 2:
		push_error("[TurnManager] 非法 player_id: %d（只能是 1 或 2）" % pid)
		return false

	if pid == 1:
		_p1_ended = true
	else:
		_p2_ended = true

	print("[TM] P%d 结束回合 (p1=%s p2=%s)" % [pid, _p1_ended, _p2_ended])

	if _p1_ended and _p2_ended:
		_advance_to_enemy()
		return true
	return false


## 查询某个玩家是否已结束回合
func has_player_ended(pid: int) -> bool:
	if pid == 1:
		return _p1_ended
	if pid == 2:
		return _p2_ended
	push_error("[TurnManager] 非法 player_id: %d（只能是 1 或 2）" % pid)
	return false


## 双方是否都已结束
func both_ended() -> bool:
	return _p1_ended and _p2_ended


## 返回第一个还没结束回合的玩家；都结束了返回 0
func first_unended_player() -> int:
	if not _p1_ended:
		return 1
	if not _p2_ended:
		return 2
	return 0


# ==============================
# 回合推进
# ==============================

func end_player_turn():
	# 双人模式下，还差一方结束是【合法的什么都不做】。
	# 但这个分支必须留日志——静默失败是最难排查的问题。
	if is_dual() and not both_ended():
		print("[TM] end_player_turn 已忽略：双人均未结束 (p1=%s p2=%s)" % [_p1_ended, _p2_ended])
		return
	_advance_to_enemy()


func _advance_to_enemy():
	current_turn = Turn.ENEMY
	_p1_ended = false
	_p2_ended = false
	turn_changed.emit(current_turn)


func end_enemy_turn():
	current_turn = Turn.PLAYER1
	_p1_ended = false
	_p2_ended = false
	turn_changed.emit(current_turn)


# ==============================
# 联机：外部状态注入
# ==============================

## 客机不跑游戏逻辑，但要显示"谁结束了回合"。
## 这是唯一允许从外部写入结束状态的入口，且有明确的语义（网络同步），
## 不像直接改字段那样无法追踪来源。
func apply_network_end_state(p1: bool, p2: bool) -> void:
	_p1_ended = p1
	_p2_ended = p2
