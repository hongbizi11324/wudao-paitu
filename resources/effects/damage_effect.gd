@tool
class_name DamageEffect
extends EffectResource
# ==============================
# 伤害效果
# - 支持 repeat（连击/三连刺等多次命中）
# - 支持 armor_break（破甲：额外摧毁护盾）
# ==============================

@export var damage: int = 0
@export var repeat: int = 0    # 0 = 不重复；>0 = 执行 N 次
@export var armor_break: int = 0


func execute(ctx: EffectContext) -> void:
	var times = repeat if repeat > 0 else 1
	var dmg = _apply_modifiers(ctx, damage)
	
	ctx.total_damage += dmg * times
	ctx.total_armor_break += armor_break
	ctx.has_executed_strike = true


func _apply_modifiers(ctx: EffectContext, value: int) -> int:
	# 子类可以重写此方法做动态调整
	return value
