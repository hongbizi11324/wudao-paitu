class_name Enemy
extends Node

# ==============================
# 敌人
# 楼层递进 + 意图系统 + 护盾
# ==============================

enum FloorType { NORMAL, ELITE, BOSS }
enum IntentType { ATTACK, DEFEND }

var max_hp: int = 40
var hp: int = 40
var block: int = 0
var floor_type: FloorType = FloorType.NORMAL
var base_damage_min: int = 3
var base_damage_max: int = 6
var _rng: RandomNumberGenerator

# 意图系统
var intent_type: IntentType = IntentType.ATTACK
var intent_value: int = 0           # 攻击伤害 或 护盾数值

signal hp_changed(current, max_val)
signal block_changed(current)
signal died()
signal intent_changed(type: int, value: int)


# 旧版 init 保留（兼容旧调用）
func init(hp_val: int = 25):
	max_hp = hp_val
	hp = max_hp
	block = 0
	floor_type = FloorType.NORMAL


# 新版：根据楼层和类型初始化
func init_from_floor(_floor_num: int, ftype: FloorType):
	_rng = RandomNumberGenerator.new()
	# 用楼层+大关做种子，保证两边生成同一只敌人
	_rng.set_seed(_floor_num * 1000 + max(0, GameData.map_act_count))
	floor_type = ftype
	var dmg_range = GameData.get_enemy_damage_range()
	base_damage_min = dmg_range[0]
	base_damage_max = dmg_range[1]
	
	max_hp = GameData.get_enemy_hp()
	hp = max_hp
	block = 0
	
	# 精英：开局自带护盾（15%血量）
	if ftype == FloorType.ELITE:
		block = maxi(3, ceili(max_hp * 0.15))
		block_changed.emit(block)
	
	var type_name = ["普通", "精英", "Boss"][ftype]
	print("【%s战】HP:%d/%d  攻击:%d-%d  格挡:%d" % [type_name, hp, max_hp, base_damage_min, base_damage_max, block])
	
	# 开局规划第一轮意图
	plan_intent()


# ==============================
# 意图系统
# ==============================

# 规划下一回合的意图（敌人回合结束时调用）
func plan_intent():
	# 根据敌人类型决定攻击/防御倾向
	var attack_chance: float = 0.55  # 默认55%攻击
	match floor_type:
		FloorType.ELITE:
			attack_chance = 0.4       # 精英更倾向防御
		FloorType.BOSS:
			var hp_pct = float(hp) / float(max_hp)
			if hp_pct < 0.33:
				attack_chance = 1.0   # Boss第三阶段：必定攻击（狂暴）
			elif hp_pct < 0.66:
				attack_chance = 0.5   # 第二阶段：五五开
			else:
				attack_chance = 0.3   # 第一阶段：更倾向叠盾
	
	if _rng.randf() < attack_chance:
		intent_type = IntentType.ATTACK
		intent_value = _calc_attack_damage()
	else:
		intent_type = IntentType.DEFEND
		intent_value = _calc_defend_amount()
	
	intent_changed.emit(intent_type, intent_value)
	
	var intent_names = ["攻击", "防御"]
	print("敌人意图: %s %d" % [intent_names[intent_type], intent_value])


# 执行当前意图（敌人回合开始时调用）
# 返回 true 表示执行了攻击（game_manager 用来做伤害判定）
func execute_intent(_player: Node) -> bool:
	if intent_type == IntentType.ATTACK:
		return true  # game_manager 会调用 get_attack_damage() 获得伤害值
	else:
		# 防御：获得护盾
		block += intent_value
		block_changed.emit(block)
		print("敌人防御 +%d 护盾（共 %d）" % [intent_value, block])
		return false


# 计算攻击伤害（考虑 Boss 多阶段加成）
func _calc_attack_damage() -> int:
	var base = _rng.randi_range(base_damage_min, base_damage_max)
	
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
