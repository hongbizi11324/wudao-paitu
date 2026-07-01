extends Node

# ==============================
# 回合管理器
# 负责：敌人回合（执行意图）、胜负判定
# ==============================

enum Turn { PLAYER, ENEMY }

var current_turn: Turn = Turn.PLAYER

signal turn_changed(turn)
signal battle_end(won)


# 开始敌人回合
func start_enemy_turn(player, enemy):
	current_turn = Turn.ENEMY
	turn_changed.emit(current_turn)
	
	# 敌人回合开始被动效果（精英/Boss 额外护盾）
	enemy.on_turn_start()
	
	# 执行当前意图
	var is_attack = enemy.execute_intent(player)
	
	if is_attack:
		# 攻击意图：获取伤害并施加给玩家
		var dmg = enemy.get_attack_damage()
		var actual = player.take_damage(dmg)
		print("敌人攻击，造成 %d 伤害（剩余 HP: %d/%d）" % [actual, player.hp, player.max_hp])
	else:
		print("敌人防御，当前护盾 %d" % enemy.block)
	
	# 检查玩家是否死亡
	if player.hp <= 0:
		battle_end.emit(false)
		return
	
	# 规划下一回合的意图（玩家回合会看到）
	enemy.plan_intent()
	
	# 切回玩家回合
	current_turn = Turn.PLAYER
	turn_changed.emit(current_turn)
	player.refill_energy()
