extends Node

# ==============================
# 敌人行为执行器
# 只负责执行敌人逻辑，不再管理回合/状态切换
# 回合切换由 TurnManager 状态机统一调度
# ==============================

signal battle_end(won)


# 执行敌人回合（纯函数，不管理回合切换）
# 返回 true = 玩家存活，false = 玩家死亡
func execute_enemy_turn(target_player, enemy) -> bool:
	# 敌人回合开始被动效果（精英/Boss 额外护盾）
	enemy.on_turn_start()
	
	# 执行当前意图
	var is_attack = enemy.execute_intent(target_player)
	
	if is_attack:
		var dmg = enemy.get_attack_damage()
		var actual = target_player.take_damage(dmg)
		print("敌人攻击，造成 %d 伤害（剩余 HP: %d/%d）" % [actual, target_player.hp, target_player.max_hp])
	else:
		print("敌人防御，当前护盾 %d" % enemy.block)
	
	# 检查玩家是否死亡
	if target_player.hp <= 0:
		battle_end.emit(false)
		return false
	
	# 规划下一回合的意图
	enemy.plan_intent()
	return true
