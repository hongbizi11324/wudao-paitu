class_name CardData
extends Resource

enum CardType { ATTACK, SKILL, POWER, INNER, MOVEMENT }

@export var card_id: String = ""
@export var card_name: String = "未命名"
@export var card_type: CardType = CardType.ATTACK
@export var cost: int = 1
@export var description: String = ""
@export var damage: int = 0
@export var block: int = 0
@export var heal: int = 0
@export var draw: int = 0     # 抽牌数
@export var repeat: int = 0   # 重复次数（0=不重复，>0 则效果执行 N 次）
@export var retain: bool = false  # 保留：回合结束时不弃掉
@export var energy_gain: int = 0  # 获得内力数（调息等内功）
@export var armor_break: int = 0   # 破甲：额外摧毁敌人护盾值
@export var school: String = ""        # 门派标识："shaolin" / "wudang" / "xiaoyao"，空为通用
