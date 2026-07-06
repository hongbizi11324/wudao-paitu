@tool
class_name SimpleConditionalEffect
extends EffectResource
# ==============================
# 条件分支效果
# 根据某个条件判断执行 then_effects 或 else_effects
#
# condition_type 可选值：
#   hand_le  → 手牌 ≤ N
#   hand_ge  → 手牌 ≥ N  
#   hand_mod_gt → 手牌数比某个值大（灵动版）
#   energy_unused → 本回合未消耗内力
#   last_was_attack → 上一张牌是攻击牌
#   hand_size → 手牌数量满足某个阈值
# ==============================

@export var condition_type: String = ""
@export var condition_params: Dictionary = {}
@export var then_effects: Array[EffectResource] = []
@export var else_effects: Array[EffectResource] = []


func execute(ctx: EffectContext) -> void:
	var met := _check_condition(ctx)
	var effects_to_run = then_effects if met else else_effects
	
	for e in effects_to_run:
		if e:
			e.execute(ctx)


func _check_condition(ctx: EffectContext) -> bool:
	var hand_size = ctx.hand.get_card_count() if ctx.hand and ctx.hand.has_method("get_card_count") else 0
	
	match condition_type:
		"hand_le":
			return hand_size <= condition_params.get("value", 0)
		"hand_ge":
			return hand_size >= condition_params.get("value", 0)
		"energy_unused":
			return ctx.energy_used_this_turn <= 0
		"last_was_attack":
			return ctx.last_played_card_type == CardData.CardType.ATTACK
		"intent_is_attack":
			return ctx.enemy and ctx.enemy.intent_type == 0  # 0 = attack intent
		_:
			push_warning("SimpleConditionalEffect: unknown condition '%s'" % condition_type)
			return false
