class_name RelicEffects
extends RefCounted

# ====================================================================
# RelicEffects — 遗物效果钩子（静态方法）
#
# 遗物定义在 GameData.RELICS（名称/描述/稀有度），效果在这里按 id 分派。
# 所有钩子都是纯"读遗物列表 + 改玩家状态"的逻辑，便于单元测试。
#
# 钩子调用时机（main.gd 调用）：
#   on_battle_start  — 战斗初始化完成后
#   on_turn_start    — 每个玩家回合开始（回能/抽牌之后）
#   on_turn_end      — 玩家回合结束（弃牌前）
#   modify_card_result — 出牌清单生成后、执行前（修正伤害/格挡/破甲）
#   on_damage_taken  — 玩家受击结算前（减伤）
#   on_battle_end    — 战斗胜利后（额外收益）
# ====================================================================


## 战斗开始：一次性加成
static func on_battle_start(player: Player, is_first_turn_draw: bool = true) -> Dictionary:
	var out := {"extra_draw": 0, "energy_bonus": 0}
	if GameData.has_relic("iron_bracer"):
		player.add_block(5)
	if GameData.has_relic("qi_furnace"):
		# 本场战斗内力上限 +1（同时补满当回合）
		player.max_energy += 1
		player.energy_per_turn += 1
		player.gain_energy(1)
		out["energy_bonus"] = 1
	if GameData.has_relic("wind_boots") and is_first_turn_draw:
		out["extra_draw"] = 2
	return out


## 每回合开始：持续型加成
static func on_turn_start(player: Player, track: Dictionary) -> Dictionary:
	var out := {"extra_draw": 0}
	if GameData.has_relic("prayer_beads"):
		player.chan += 1
	if GameData.has_relic("snake_gall") and player.hp < player.max_hp * 0.5:
		player.add_block(3)
	if GameData.has_relic("dragon_vein") and not bool(track.get("took_damage_last_turn", false)):
		out["extra_draw"] = 1
	# 回合级标记：本回合尚未打出攻击牌 / 尚未受伤
	track["first_attack_used"] = false
	track["took_damage_this_turn"] = false
	return out


## 回合结束：结算型
static func on_turn_end(player: Player) -> void:
	if GameData.has_relic("turtle_charm") and player.block >= 10:
		player.heal(2)
		print("【遗物·龟息符】格挡%d → 回复2生命" % player.block)


## 出牌结算前修正清单（伤害/格挡/破甲）
static func modify_card_result(result: Dictionary, data: CardData, player: Player, track: Dictionary) -> void:
	if result.is_empty():
		return
	var is_attack: bool = data.card_type == CardData.CardType.ATTACK
	var is_skill: bool = data.card_type == CardData.CardType.SKILL

	# 破军令：攻击牌伤害 +1
	if is_attack and GameData.has_relic("war_token"):
		result["damage"] = int(result.get("damage", 0)) + 1

	# 铁布衫秘卷：技能牌格挡 +2
	if is_skill and GameData.has_relic("iron_manual"):
		result["block"] = int(result.get("block", 0)) + 2

	# 剑穗 / 罗汉拳谱：每回合第一张攻击牌
	if is_attack and not bool(track.get("first_attack_used", false)):
		track["first_attack_used"] = true
		if GameData.has_relic("sword_tassel"):
			result["damage"] = int(result.get("damage", 0)) + 4
			print("【遗物·剑穗】本回合首张攻击 +4 伤害")
		if GameData.has_relic("arhat_manual"):
			result["armor_break"] = int(result.get("armor_break", 0)) + 5
			print("【遗物·罗汉拳谱】本回合首张攻击 破甲+5")


## 受击前减伤（返回修正后的伤害）
static func modify_incoming_damage(amount: int, track: Dictionary) -> int:
	var dmg := amount
	if GameData.has_relic("heart_mirror") and not bool(track.get("mirror_used_this_turn", false)):
		track["mirror_used_this_turn"] = true
		dmg = maxi(0, dmg - 2)
		print("【遗物·护心镜】本回合首次受击 -2 伤害")
	return dmg


## 战斗胜利后的额外收益
static func on_battle_end(player: Player) -> Dictionary:
	var out := {"gold": 0, "cultivation": 0}
	if GameData.has_relic("coin_sword"):
		out["gold"] += 10
	if GameData.has_relic("meditation_cushion"):
		out["cultivation"] += 5
	if GameData.has_relic("blood_jade"):
		player.heal(6)
		print("【遗物·血玉】战斗胜利回复6生命")
	return out


## 遗物栏显示文本（名称列表）
static func display_names() -> Array:
	var out: Array = []
	for rid in GameData.player_relics:
		out.append(GameData.relic_name(rid))
	return out
