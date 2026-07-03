class_name Player
extends Node

# ==============================
# 玩家
# 管理内力、血量、格挡
# ==============================

var max_hp: int = 60
var hp: int = 60

# 内力系统
var max_energy: int = 3          # 内力上限（基础 + 存储）
var energy: int = 3              # 当前内力
var energy_per_turn: int = 3     # 每回合恢复的基础内力（= 当前境界内力上限）
const ENERGY_STORAGE_MAX: int = 2  # 最多存 2 点内力到下回合

var block: int = 0

# ========== 门派系统 ==========
var chan: int = 0            # 少林·禅意
var jianyi: int = 0          # 武当·剑意

# POWER 激活标记
var power_damo: bool = false    # 达摩一苇
var power_twoway: bool = false  # 太极两仪
var power_bahuang: bool = false # 八荒六合

# 逍遥·凌波微步折扣
var next_card_discount: int = 0

# 太极两仪：首次受击标记（每回合重置）
var first_hit_this_turn: bool = true

signal energy_changed(current, max_val)
signal hp_changed(current, max_val)
signal block_changed(current)
signal died()


# 初始化（每场战斗开始调用）
func init(use_p2_hp: bool = false):
	# 重置门派变量
	chan = 0
	jianyi = 0
	power_damo = false
	power_twoway = false
	power_bahuang = false
	next_card_discount = 0
	first_hit_this_turn = true
	
	# 从 GameData 读取跨战斗血量
	if use_p2_hp:
		max_hp = GameData.player2_max_hp
		hp = GameData.player2_hp
	else:
		max_hp = GameData.player_max_hp
		hp = GameData.player_hp
	block = 0
	# 从 GameData 读取当前境界的内力上限
	energy_per_turn = GameData.max_energy_per_realm
	max_energy = energy_per_turn + ENERGY_STORAGE_MAX
	energy = energy_per_turn
	energy_changed.emit(energy, max_energy)
	hp_changed.emit(hp, max_hp)
	block_changed.emit(0)


# 每回合回复内力（带存储机制）
func refill_energy():
	block = 0
	# 上回合没用完的内力最多存 2 点到下回合
	var stored = min(energy, ENERGY_STORAGE_MAX)
	energy = min(energy_per_turn + stored, energy_per_turn + ENERGY_STORAGE_MAX)
	energy_changed.emit(energy, max_energy)
	block_changed.emit(0)


# 消耗内力（带门派折扣）
func spend_energy(amount: int) -> bool:
	var actual = amount
	# 凌波微步折扣
	if next_card_discount > 0:
		actual = max(0, amount - next_card_discount)
		next_card_discount = 0
	if energy < actual:
		return false
	energy -= actual
	energy_changed.emit(energy, max_energy)
	return true


# 获得内力（调息等卡牌效果）
func gain_energy(amount: int):
	energy = min(energy + amount, max_energy)
	energy_changed.emit(energy, max_energy)


# 加格挡
func add_block(amount: int):
	block += amount
	block_changed.emit(block)


# 受伤害（格挡先吸收，含太极两仪触发）
func take_damage(amount: int) -> int:
	var dmg = max(0, amount - block)
	if block > 0:
		block = max(0, block - amount)
		block_changed.emit(block)
	hp -= dmg
	# 同步回 GameData
	GameData.player_hp = hp
	hp_changed.emit(hp, max_hp)
	
	# 太极两仪：每回合首次受击触发
	if power_twoway and first_hit_this_turn and dmg > 0:
		first_hit_this_turn = false
		jianyi += 2
		hp = min(max_hp, hp + 2)
		GameData.player_hp = hp
		hp_changed.emit(hp, max_hp)
		print("太极两仪触发：剑意+2，回复2HP")
	
	if hp <= 0:
		died.emit()
	return dmg


# 回血
func heal(amount: int):
	hp = min(max_hp, hp + amount)
	# 同步回 GameData
	GameData.player_hp = hp
	hp_changed.emit(hp, max_hp)
