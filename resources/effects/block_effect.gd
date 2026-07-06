@tool
class_name BlockEffect
extends EffectResource
# ==============================
# 格挡效果
# ==============================

@export var block: int = 0


func execute(ctx: EffectContext) -> void:
	ctx.total_block += block
