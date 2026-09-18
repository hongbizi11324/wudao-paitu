class_name Player
extends Node

# ==============================
# 玩家数据
# 管理 HP / 内力 / 格挡 / 门派资源 / 角色被动
#
# 双人模式下 is_p2 = true 时，持久血量读写 GameData.player2_*，
# 不再无条件写 player_hp（旧 bug：P2 掉血会覆盖 P1 的存档血量）
# ==============================

var max_hp: int = 60
var hp: int = 60

# 内力系统
var max_energy: int = 3          # 内力上限（基础 + 存储）
var energy: int = 3              # 当前内力
var energy_per_turn: int = 3     # 每回合恢复的基础内力（= 当前境界内力上限）
const ENERGY_STORAGE_MAX: int = 2  # 最多存 2 点内力到下回合

var block: int = 0

# ========== 门派资源 ==========
var chan: int = 0            # 少林·禅意
var jianyi: int = 0          # 武当·剑意

# POWER 激活标记
var power_damo: bool = false      # 达摩一苇
var power_twoway: bool = false    # 太极两仪
var power_bahuang: bool = false   # 八荒六合
var power_longxiang: bool = false # 龙象般若
var power_xiaoyaoyou: bool = false # 逍遥游
var power_bodhi: bool = false     # 菩提心（每回合 禅意+1 格挡+1）

# ========== 角色与被动 ==========
var is_p2: bool = false
var character_id: String = ""    # 选中的角色ID（决定被动）

# ========== 折扣 / 回合标记 ==========
var next_card_discount: int = 0      # 凌波微步：下一张牌费用减免
var attack_discounted: bool = false  # 逍遥游 POWER：攻击/内力牌永久 -1 费
var hand_limit_mod: int = 0          # 逍遥游：手牌上限增量（由 main 应用到 Hand）
var first_hit_this_turn: bool = true  # 太极两仪：每回合首次受击标记
var passive_block_used: bool = false  # 玄翁被动：每回合首次受击标记

signal energy_changed(current, max_val)
signal hp_changed(current, max_val)
signal block_changed(current)
signal died()


## 初始化（每场战斗开始调用）。use_p2_hp = true 表示这是 P2。
func init(use_p2_hp: bool = false):
	is_p2 = use_p2_hp
	if use_p2_hp:
		character_id = GameData.selected_character_2
	else:
		character_id = GameData.selected_character

	# 重置门派变量与 POWER
	chan = 0
	jianyi = 0
	power_damo = false
	power_twoway = false
	power_bahuang = false
	power_longxiang = false
	power_xiaoyaoyou = false
	power_bodhi = false
	next_card_discount = 0
	attack_discounted = false
	hand_limit_mod = 0
	first_hit_this_turn = true
	passive_block_used = false

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


## 每回合开始：回能 + 清格挡 + 重置回合级标记。
## 回合级标记的复位收敛在这一个入口，不再散落在 POWER 触发里。
func refill_energy():
	block = 0
	first_hit_this_turn = true
	passive_block_used = false
	# 上回合没用完的内力最多存 2 点到下回合
	var stored = min(energy, ENERGY_STORAGE_MAX)
	energy = min(energy_per_turn + stored, energy_per_turn + ENERGY_STORAGE_MAX)
	energy_changed.emit(energy, max_energy)
	block_changed.emit(0)


## 消耗内力。折扣计算不在这里——费用在 main._calc_card_cost 统一算清后
## 才调用本方法；失败（内力不足）时任何折扣都不该被吞掉。
func spend_energy(amount: int) -> bool:
	if energy < amount:
		return false
	energy -= amount
	energy_changed.emit(energy, max_energy)
	return true


## 获得内力（调息等卡牌效果）
func gain_energy(amount: int):
	energy = min(energy + amount, max_energy)
	energy_changed.emit(energy, max_energy)


## 加格挡
func add_block(amount: int):
	block += amount
	block_changed.emit(block)


## 受伤害（格挡先吸收，含太极两仪 / 玄翁被动）
func take_damage(amount: int) -> int:
	# 玄翁被动【奇门遁甲】：每回合首次受击前，格挡 +2
	if character_id == "xuanweng" and not passive_block_used:
		passive_block_used = true
		block += 2
		block_changed.emit(block)
		print("【被动·奇门遁甲】格挡+2")

	var dmg = max(0, amount - block)
	if block > 0:
		block = max(0, block - amount)
		block_changed.emit(block)
	hp -= dmg
	_sync_hp()

	# 太极两仪：每回合首次受击触发
	if power_twoway and first_hit_this_turn and dmg > 0:
		first_hit_this_turn = false
		jianyi += 2
		hp = min(max_hp, hp + 2)
		_sync_hp()
		print("太极两仪触发：剑意+2，回复2HP")

	if hp <= 0:
		died.emit()
	return dmg


## 回血
func heal(amount: int):
	hp = min(max_hp, hp + amount)
	_sync_hp()


## 血量变化后同步到 GameData（区分 P1/P2，修复旧 bug）
func _sync_hp():
	hp_changed.emit(hp, max_hp)
	if is_p2:
		GameData.player2_hp = hp
	else:
		GameData.player_hp = hp
