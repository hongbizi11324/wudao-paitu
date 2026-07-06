@tool
class_name ModifierGainEffect
extends EffectResource
# ==============================
# 门派属性获得效果
# modifier_key: "chan"（禅意）/ "jianyi"（剑意）
# ==============================

@export var modifier_key: String = ""
@export var amount: int = 1


func execute(ctx: EffectContext) -> void:
	if modifier_key == "chan":
		ctx.player.chan += amount
	elif modifier_key == "jianyi":
		ctx.player.jianyi += amount
	else:
		push_warning("ModifierGainEffect: unknown key '%s'" % modifier_key)
