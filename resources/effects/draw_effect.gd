@tool
class_name DrawEffect
extends EffectResource
# ==============================
# 抽牌效果
# ==============================

@export var count: int = 1


func execute(ctx: EffectContext) -> void:
	ctx.total_draw += count
