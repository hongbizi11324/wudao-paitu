@tool
class_name ApplyPowerEffect
extends EffectResource
# ==============================
# 激活核心功法（POWER）效果
# power_key 对应 player.gd 中的 power_ 变量
# 可选值：damo / twoway / bahuang / longxiang / xiaoyaoyou
# ==============================

@export var power_key: String = ""


func execute(ctx: EffectContext) -> void:
	var p = ctx.player
	match power_key:
		"damo":
			p.power_damo = true
		"twoway":
			p.power_twoway = true
		"bahuang":
			p.power_bahuang = true
		"longxiang":
			p.power_longxiang = true
		"xiaoyaoyou":
			p.power_xiaoyaoyou = true
			p.hand_limit_mod = 2  # 逍遥游 +2手牌上限
		_:
			push_warning("ApplyPowerEffect: unknown power_key '%s'" % power_key)
