@tool
class_name CompositeEffect
extends EffectResource
# ==============================
# 复合效果 —— 顺序执行多个子效果
# 大部分卡牌都包一层这个，比如：
# "造成5点伤害，抽1张牌" = Composite([Damage(5), Draw(1)])
# ==============================

@export var effects: Array[EffectResource] = []


func execute(ctx: EffectContext) -> void:
	for e in effects:
		if e:
			e.execute(ctx)


# 辅助：快速构造（在编辑器里直接用 export 数组就行）
func add_effect(e: EffectResource) -> void:
	effects.append(e)
