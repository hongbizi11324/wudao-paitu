@tool
class_name EffectContext
extends RefCounted
# ==============================
# 效果执行上下文
# 当一张卡牌被使用，所有效果共享同一个 EffectContext
# 效果之间通过 ctx 沟通（比如 DamageEffect 写入 damage，
# 后面的 CompositeEffect 可以用这个值做条件判断）
# ==============================

# ---- 引用（由 main.gd 传入） ----
var player: Player
var enemy: Enemy
var hand: Node2D
var draw_pile: Array
var discard_pile: Array
var card_data: CardData  # 正在执行的卡牌

# ---- 回合状态（拷贝自 main.gd 的变量） ----
var last_played_card_id: String = ""
var last_played_card_type: int = -1
var skill_played_this_turn: int = 0
var energy_used_this_turn: int = 0
var next_card_discount: int = 0
var next_two_cards_discount: bool = false
var consecutive_discount_used: int = 0
var first_hit_this_turn: bool = true

# ---- 效果执行结果（各 effect 写入，最后统一应用） ----
var total_damage: int = 0
var total_block: int = 0
var total_heal: int = 0
var total_draw: int = 0
var total_energy: int = 0
var total_armor_break: int = 0
var is_consumed: bool = false
var wait_for_reply: bool = false  # 需要等待玩家选牌等操作
var has_executed_strike: bool = false  # 攻击效果是否已发生（用于判断）


func reset():
	total_damage = 0
	total_block = 0
	total_heal = 0
	total_draw = 0
	total_energy = 0
	total_armor_break = 0
	is_consumed = false
	wait_for_reply = false
	has_executed_strike = false
