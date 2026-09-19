class_name PotionEffects
extends RefCounted

# ====================================================================
# PotionEffects — 丹药使用效果
#
# 丹药定义在 GameData.POTIONS；使用后消耗，战斗内每回合最多 1 个。
# 全部为静态方法，便于单元测试；由 main.gd 在玩家点击丹药时调用。
# ====================================================================


## 使用一枚丹药。返回 true 表示使用成功（已消耗）。
## ctx: {player, enemy, track, executor} —— executor 为 CardExecutor（抽牌用）
static func use(potion_id: String, ctx: Dictionary) -> bool:
	var player: Player = ctx.get("player")
	var enemy: Enemy = ctx.get("enemy")
	var track: Dictionary = ctx.get("track", {})
	var ex = ctx.get("executor")
	if player == null:
		return false
	if not GameData.POTIONS.has(potion_id):
		return false

	match potion_id:
		"small_pill":
			player.heal(15)
			print("【丹药·小还丹】回复15生命")
		"focus_powder":
			player.gain_energy(2)
			print("【丹药·凝神散】内力+2")
		"vajra_pill":
			player.add_block(12)
			print("【丹药·金刚丹】格挡+12")
		"swift_powder":
			if ex:
				ex.draw_cards(2)
			print("【丹药·疾风散】抽2张")
		"fire_wine":
			# 本回合所有攻击牌 +4（由 RelicEffects 之外的本回合标记生效）
			track["potion_attack_bonus"] = int(track.get("potion_attack_bonus", 0)) + 4
			print("【丹药·烈火酒】本回合攻击牌伤害+4")
		"awaken_wine":
			if ex:
				ex.draw_cards(3)
			player.gain_energy(1)
			print("【丹药·醒神酒】抽3张，内力+1")
		"melt_powder":
			if enemy:
				enemy.take_damage(8, 25)
			print("【丹药·化功散】破甲25 + 8伤害")
		"golden_pill":
			player.max_energy += 2
			player.energy_per_turn += 2
			player.energy = player.max_energy
			player.energy_changed.emit(player.energy, player.max_energy)
			print("【丹药·九转金丹】内力上限+2并回满")
		_:
			return false
	return true


## 丹药使用后的额外伤害加成（烈火酒），在出牌清单生成后调用
static func apply_attack_bonus(result: Dictionary, data: CardData, track: Dictionary) -> void:
	if result.is_empty():
		return
	var bonus: int = int(track.get("potion_attack_bonus", 0))
	if bonus > 0 and data.card_type == CardData.CardType.ATTACK:
		result["damage"] = int(result.get("damage", 0)) + bonus
