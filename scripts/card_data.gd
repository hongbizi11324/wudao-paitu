@tool
class_name CardData
extends Resource

enum CardType { ATTACK, SKILL, POWER, INNER, MOVEMENT }

@export var card_id: String = ""
@export var card_name: String = "未命名"
@export var card_type: CardType = CardType.ATTACK
@export var cost: int = 1
@export var description: String = ""

# ---- 旧版字段（兼容，方便快速编辑） ----
@export var damage: int = 0
@export var block: int = 0
@export var heal: int = 0
@export var draw: int = 0
@export var repeat: int = 0
@export var retain: bool = false
@export var energy_gain: int = 0
@export var armor_break: int = 0
@export var school: String = ""

# ---- 新版效果系统（优先使用） ----
# effects 数组不为空时，使用效果系统执行
# 为空时回退到旧版字段模式
@export var effects: Array[EffectResource] = []


# 是否已迁移到效果系统
func has_effects() -> bool:
	return effects.size() > 0
