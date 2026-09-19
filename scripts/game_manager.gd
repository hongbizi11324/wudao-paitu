extends Node

# ==============================
# 敌人行为执行器
# 只负责执行敌人逻辑，不管理回合/状态切换
# 回合切换由 TurnManager 状态机统一调度
#
# 双人模式：敌人用自身已播种 RNG 从存活玩家中随机选攻击目标，
# 不再写死只打 P1（旧 bug）
# 支持多段攻击（同一目标连击 intent_times 次）
# ==============================

signal battle_end(won)


## 执行敌人回合（纯函数，不管理回合切换）
## players: 候选目标数组（单人=[P1]，双人=[P1,P2]）
## damage_filter: 可选 (伤害, 目标) -> 修正后伤害（遗物减伤等）
## 返回 true = 有玩家存活，false = 全灭
func execute_enemy_turn(players: Array, enemy, damage_filter: Callable = Callable()) -> bool:
	# 敌人回合开始被动效果（精英/Boss 额外护盾）
	enemy.on_turn_start()

	# 执行当前意图
	var is_attack = enemy.execute_intent(null)

	if is_attack:
		var target = enemy.choose_target(players)
		if target == null:
			return false  # 没有存活目标（防御式处理）
		var times: int = enemy.intent_times if enemy.is_multi_attack() else 1
		var per_hit: int = enemy.get_attack_damage()
		var total := 0
		for i in range(times):
			if target.hp <= 0:
				break
			var hit := per_hit
			if damage_filter.is_valid():
				hit = int(damage_filter.call(per_hit, target))
			total += target.take_damage(hit)
		if times > 1:
			print("敌人多段攻击 %s：%d×%d，共造成 %d 伤害（其 HP 剩余: %d/%d）" % [
				"P2" if target.is_p2 else "P1", per_hit, times, total, target.hp, target.max_hp])
		else:
			print("敌人攻击 %s，造成 %d 伤害（其 HP 剩余: %d/%d）" % [
				"P2" if target.is_p2 else "P1", total, target.hp, target.max_hp])
	else:
		if enemy.intent_type == enemy.IntentType.BUFF:
			print("敌人强化，当前力量 %d" % enemy.strength)
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
