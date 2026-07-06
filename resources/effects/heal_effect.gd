@tool
class_name HealEffect
extends EffectResource
# ==============================
# 回复效果
# ==============================

@export var heal: int = 0


func execute(ctx: EffectContext) -> void:
	ctx.total_heal += heal
