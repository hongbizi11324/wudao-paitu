@tool
class_name CardData
extends Resource

# ==============================
# 卡牌数据
# 数值全部来自 .tres；效果逻辑唯一来源是 lua/cards/*.lua（可热更）
# Lua 不可用时回退 GDScript 通用结算（main._fallback_result）
# ==============================

enum CardType { ATTACK, SKILL, POWER, INNER, MOVEMENT }

@export var card_id: String = ""
@export var card_name: String = "未命名"
@export var card_type: CardType = CardType.ATTACK
@export var cost: int = 1
@export var description: String = ""

# ---- 数值字段（Lua 从 ctx 读取） ----
@export var damage: int = 0
@export var block: int = 0
@export var heal: int = 0
@export var draw: int = 0
@export var repeat: int = 0
@export var retain: bool = false
@export var energy_gain: int = 0
@export var armor_break: int = 0
@export var school: String = ""
