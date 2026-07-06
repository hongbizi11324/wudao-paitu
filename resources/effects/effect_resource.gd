@tool
class_name EffectResource
extends Resource
# ==============================
# 效果基类 — 所有效果的父类
# 每个效果 = .tres 资源文件，可被多个卡牌复用
# ==============================

enum TargetType { ENEMY, SELF, ALL_ENEMIES, ALL }

@export var id: String = ""       # 唯一标识（用于调试和关联）
@export var description: String = ""
@export var target: TargetType = TargetType.ENEMY


# 效果执行入口 —— 子类必须重写
func execute(ctx: EffectContext) -> void:
	push_error("EffectResource.execute() called on base class! id=%s" % id)
