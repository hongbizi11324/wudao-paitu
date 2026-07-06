@tool
class_name EnergyEffect
extends EffectResource
# ==============================
# 内力效果（获得或消耗）
# ==============================

enum EnergyMode { GAIN, SPEND }

@export var amount: int = 1
@export var mode: EnergyMode = EnergyMode.GAIN


func execute(ctx: EffectContext) -> void:
	ctx.total_energy += amount if mode == EnergyMode.GAIN else -amount
