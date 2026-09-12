extends Node

# ==============================
# 敌人行为执行器
# 只负责执行敌人逻辑，不管理回合/状态切换
# 回合切换由 TurnManager 状态机统一调度
#
# 双人模式：敌人用自身已播种 RNG 从存活玩家中随机选攻击目标，
# 不再写死只打 P1（旧 bug）
# ==============================

signal battle_end(won)


## 执行敌人回合（纯函数，不管理回合切换）
## players: 候选目标数组（单人=[P1]，双人=[P1,P2]）
## 返回 true = 有玩家存活，false = 全灭
func execute_enemy_turn(players: Array, enemy) -> bool:
	# 敌人回合开始被动效果（精英/Boss 额外护盾）
	enemy.on_turn_start()

	# 执行当前意图
	var is_attack = enemy.execute_intent(null)

	if is_attack:
		var target = enemy.choose_target(players)
		if target == null:
			return false  # 没有存活目标（不该发生，防御式处理）
		var dmg = enemy.get_attack_damage()
		var actual = target.take_damage(dmg)
		print("敌人攻击 %s，造成 %d 伤害（其 HP 剩余: %d/%d）" % [
			"P2" if target.is_p2 else "P1", actual, target.hp, target.max_hp])
	else:
		print("敌人防御，当前护盾 %d" % enemy.block)

	# 检查是否全灭
	var any_alive = false
	for p in players:
		if p and is_instance_valid(p) and p.hp > 0:
			any_alive = true
			break
	if not any_alive:
		battle_end.emit(false)
		return false

	# 规划下一回合的意图
	enemy.plan_intent()
	return true
