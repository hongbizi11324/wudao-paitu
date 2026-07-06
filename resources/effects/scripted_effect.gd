@tool
class_name ScriptedEffect
extends EffectResource
# ==============================
# 自定义脚本效果（兜底）
# 对不能用数据驱动表达的复杂效果，用 script_id 标记
# main.gd 的执行循环会识别 ScriptedEffect 并调用对应函数
# ==============================

@export var script_id: String = ""


func execute(ctx: EffectContext) -> void:
	# ScriptedEffect 不直接执行逻辑
	# main.gd 的 effect 执行循环会单独分发它
	# 这里只是标记，防止 error
	pass
