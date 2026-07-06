@tool
class_name ModifierConsumeEffect
extends EffectResource
# ==============================
# 消耗门派属性获得加成
# 例如：罗汉伏魔 → 消耗所有禅意，每层+4伤害
# 金钟罩 → 消耗所有禅意，每层+3格挡
# ==============================

@export var modifier_key: String = ""   # "chan" / "jianyi"
@export var bonus_per_consumed: int = 0  # 每层加成值
@export var bonus_target: String = "damage"  # "damage" / "block" / "heal"
@export var base_value: int = 0  # 消耗前的基础值


func execute(ctx: EffectContext) -> void:
	var current: int = 0
	if modifier_key == "chan":
		current = ctx.player.chan
		ctx.player.chan = 0
	elif modifier_key == "jianyi":
		current = ctx.player.jianyi
		ctx.player.jianyi = 0
	else:
		push_warning("ModifierConsumeEffect: unknown key '%s'" % modifier_key)
		return
	
	var bonus = current * bonus_per_consumed
	var total = base_value + bonus
	
	match bonus_target:
		"damage":
			ctx.total_damage += total
		"block":
			ctx.total_block += total
		"heal":
			ctx.total_heal += total
		_:
			push_warning("ModifierConsumeEffect: unknown target '%s'" % bonus_target)
