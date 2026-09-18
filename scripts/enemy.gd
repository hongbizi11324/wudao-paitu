class_name Enemy
extends Node

# ==============================
# 敌人
# 楼层递进 + 意图系统 + 护盾 + 力量成长
#
# 意图类型：
#   ATTACK       单次攻击
#   MULTI_ATTACK 多段攻击（连击 intent_times 次）
#   DEFEND       叠盾
#   BUFF         力量成长（永久 +strength，之后每次攻击都加成）
#
# 目标选择：双人模式下从存活玩家中用已播种 RNG 随机选一个
# （host 权威执行，客机通过快照看到结果，天然同步）
# ==============================

enum FloorType { NORMAL, ELITE, BOSS }
enum IntentType { ATTACK, DEFEND, MULTI_ATTACK, BUFF }

var max_hp: int = 40
var hp: int = 40
var block: int = 0
var floor_type: FloorType = FloorType.NORMAL
var base_damage_min: int = 3
var base_damage_max: int = 6
var strength: int = 0          # 力量：每次攻击的额外伤害（BUFF 累积）
var _rng: RandomNumberGenerator

# 意图系统
var intent_type: IntentType = IntentType.ATTACK
var intent_value: int = 0           # 攻击伤害 / 护盾数值 / 力量增量
var intent_times: int = 1           # 多段攻击的段数

signal hp_changed(current, max_val)
signal block_changed(current)
signal died()
signal intent_changed(type: int, value: int)


## 新版：根据楼层和类型初始化。
## 双人模式 HP ×1.5（两人输出接近翻倍，避免合作模式变成无双割草）
func init_from_floor(_floor_num: int, ftype: FloorType):
	_rng = RandomNumberGenerator.new()
	# 用楼层+大关做种子，保证重连/重试时生成同一只敌人
	_rng.set_seed(_floor_num * 1000 + max(0, GameData.map_act_count))
	floor_type = ftype
	strength = 0
	var dmg_range = GameData.get_enemy_damage_range()
	base_damage_min = dmg_range[0]
	base_damage_max = dmg_range[1]

	max_hp = GameData.get_enemy_hp()
	if GameData.is_dual_mode:
		max_hp = ceili(max_hp * 1.5)
	hp = max_hp
	block = 0

	# 精英：开局自带护盾（15%血量）
	if ftype == FloorType.ELITE:
		block = maxi(3, ceili(max_hp * 0.15))
		block_changed.emit(block)

	var type_name = ["普通", "精英", "Boss"][ftype]
	print("【%s战】HP:%d/%d  攻击:%d-%d  格挡:%d%s" % [
		type_name, hp, max_hp, base_damage_min, base_damage_max, block,
		" (双人缩放×1.5)" if GameData.is_dual_mode else ""])

	# 开局规划第一轮意图
	plan_intent()


# ==============================
# 目标选择
# ==============================

## 从存活的玩家里随机选一个攻击目标（用已播种 RNG，主机权威、可复现）
func choose_target(players: Array) -> Node:
	var alive: Array = []
	for p in players:
		if p and is_instance_valid(p) and p.hp > 0:
			alive.append(p)
	if alive.is_empty():
		return null
	if alive.size() == 1:
		return alive[0]
	return alive[_rng.randi_range(0, alive.size() - 1)]


# ==============================
# 意图系统
# ==============================

# 规划下一回合的意图（敌人回合结束时调用）
func plan_intent():
	intent_times = 1

	var roll: float = _rng.randf()
	match floor_type:
		FloorType.NORMAL:
			# 普通：70% 攻击（含多段）/ 30% 防御
			if roll < 0.45:
				_set_attack()
			elif roll < 0.70:
				_set_multi_attack(2)
			else:
				_set_defend()
		FloorType.ELITE:
			# 精英：多段攻击 + 力量成长
			if roll < 0.35:
				_set_attack()
			elif roll < 0.65:
				_set_multi_attack(2)
			elif roll < 0.85:
				_set_defend()
			else:
				_set_buff(2)
		FloorType.BOSS:
			var hp_pct := float(hp) / float(max_hp)
			if hp_pct < 0.33:
				# 第三阶段：狂暴，高频多段
				if roll < 0.55:
					_set_multi_attack(3)
				else:
					_set_attack()
			elif hp_pct < 0.66:
				# 第二阶段：力量成长 + 多段
				if roll < 0.30:
					_set_buff(3)
				elif roll < 0.65:
					_set_multi_attack(2)
				else:
					_set_attack()
			else:
				# 第一阶段：叠盾蓄力
				if roll < 0.35:
					_set_defend()
				elif roll < 0.55:
					_set_buff(2)
				elif roll < 0.80:
					_set_attack()
				else:
					_set_multi_attack(2)

	intent_changed.emit(intent_type, intent_value)

	var intent_names = ["攻击", "防御", "多段攻击", "强化"]
	var extra := ""
	if intent_type == IntentType.MULTI_ATTACK:
		extra = "×%d" % intent_times
	elif intent_type == IntentType.BUFF:
		extra = " 力量+%d" % intent_value
	print("敌人意图: %s %d%s" % [intent_names[int(intent_type)], intent_value, extra])


func _set_attack():
	intent_type = IntentType.ATTACK
	intent_value = _calc_attack_damage()


func _set_multi_attack(times: int):
	intent_type = IntentType.MULTI_ATTACK
	intent_times = times
	# 多段单次伤害 = 单次伤害的 55%（总伤害略高于单次，但被格挡多次吸收）
	intent_value = maxi(1, ceili(_calc_attack_damage() * 0.55))


func _set_defend():
	intent_type = IntentType.DEFEND
	intent_value = _calc_defend_amount()


func _set_buff(amount: int):
	intent_type = IntentType.BUFF
	intent_value = amount


# 执行当前意图（敌人回合开始时调用）
# 返回 true 表示执行了攻击（game_manager 用来做伤害判定）
func execute_intent(_player: Node) -> bool:
	match intent_type:
		IntentType.ATTACK, IntentType.MULTI_ATTACK:
			return true
		IntentType.DEFEND:
			block += intent_value
			block_changed.emit(block)
			print("敌人防御 +%d 护盾（共 %d）" % [intent_value, block])
			return false
		IntentType.BUFF:
			strength += intent_value
			print("敌人强化：力量 +%d（当前力量 %d）" % [intent_value, strength])
			return false
	return false


# 计算攻击伤害（含力量加成 + Boss 多阶段加成）
func _calc_attack_damage() -> int:
	var base = _rng.randi_range(base_damage_min, base_damage_max) + strength

	if floor_type == FloorType.BOSS:
		var hp_pct = float(hp) / float(max_hp)
		if hp_pct < 0.33:
			return ceili(base * 2.0)   # 第三阶段：2x
		elif hp_pct < 0.66:
			return ceili(base * 1.5)   # 第二阶段：1.5x

	return base


# 计算防御护盾值
func _calc_defend_amount() -> int:
	var base_shield = maxi(3, ceili(max_hp * 0.06))
	match floor_type:
		FloorType.ELITE:
			base_shield = ceili(base_shield * 1.5)  # 精英护盾更多
		FloorType.BOSS:
			base_shield = ceili(base_shield * 2.0)  # Boss 护盾翻倍
	return base_shield


# 获取当前意图的攻击伤害（供 game_manager 用作实际伤害）
func get_attack_damage() -> int:
	return intent_value


# 是否为多段攻击（game_manager 决定是否连击）
func is_multi_attack() -> bool:
	return intent_type == IntentType.MULTI_ATTACK


# ==============================
# 伤害与护盾
# ==============================

# 受伤害（格挡先吸收）
func take_damage(amount: int, armor_break: int = 0) -> int:
	var remaining = amount

	# 破甲：先摧毁护盾（即便超过护盾量）
	if armor_break > 0 and block > 0:
		var broken = min(block, armor_break)
		block -= broken
		block_changed.emit(block)
		print("破甲摧毁 %d 护盾" % broken)

	# 格挡吸收伤害
	if block > 0:
		var blocked = min(block, remaining)
		block -= blocked
		remaining -= blocked
		block_changed.emit(block)

	var actual_dmg = min(remaining, hp)
	hp -= actual_dmg
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		died.emit()
	return amount


# 回合开始钩子（game_manager 调用）
# 护盾先清零，精英和 Boss 再获得额外护盾
func on_turn_start():
	# 护盾每回合重置
	block = 0
	block_changed.emit(block)

	match floor_type:
		FloorType.ELITE:
			block += ceili(max_hp * 0.04)
			block_changed.emit(block)

		FloorType.BOSS:
			var hp_pct = float(hp) / float(max_hp)
			if hp_pct < 0.33:
				block += ceili(max_hp * 0.06)
				block_changed.emit(block)
