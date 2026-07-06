@tool
extends EditorScript
# ==============================
# 卡牌转换工具
#
# 使用方法：
# 1. 在脚本编辑器中打开此文件
# 2. 按 Ctrl+Shift+X（或点脚本编辑器顶部的「运行」按钮）
# 3. 看底部 Output 面板的输出日志
# ==============================

# 需要转换的卡牌ID列表
const BASIC_CARDS := [
	"strike", "defend", "bash", "double_strike", "triple_stab",
	"flowing_cloud_sword", "iron_shirt", "iron_wall", "golden_bell",
	"light_step", "tactics", "heal", "vigor", "whirlwind",
	"vajra_fist", "sword_energy",
]
# 注意：punch 和 meditate 使用了动态计算函数，暂不自动转换


func _run():
	print("=".repeat(40))
	print("卡牌转换工具 v1 - 开始转换基础卡牌...")
	print("=".repeat(40))
	convert_all()
	print("=".repeat(40))
	print("完成！可以关闭此运行实例了")
	print("=".repeat(40))


# 主入口：转换所有基础卡牌
func convert_all():
	var converted = 0
	for cid in BASIC_CARDS:
		if _convert_card(cid):
			converted += 1
	print("转换完成：共 %d 张卡牌" % converted)


# 转换单个卡牌
func _convert_card(card_id: String) -> bool:
	var path = "res://resources/cards/%s.tres" % card_id
	var card = load(path) as CardData
	if not card:
		push_warning("卡牌 %s 不存在" % card_id)
		return false
	
	# 跳过已有 effects 的
	if card.has_effects():
		print("跳过 %s：已有 effects" % card_id)
		return false
	
	# 根据卡牌类型构建效果数组
	var effects: Array[EffectResource] = []
	
	match card_id:
		# 纯伤害
		"strike", "punch", "bash", "sword_energy":
			effects.append(_make_damage(card.damage))
		
		# 纯格挡
		"defend", "iron_shirt", "iron_wall", "golden_bell":
			effects.append(_make_block(card.block))
		
		# 纯抽牌
		"light_step", "tactics":
			effects.append(_make_draw(card.draw))
		
		# 重复伤害
		"double_strike", "triple_stab":
			effects.append(_make_damage(card.damage, card.repeat))
		
		# 伤害 + 抽牌
		"flowing_cloud_sword", "whirlwind":
			if card.damage > 0:
				effects.append(_make_damage(card.damage))
			if card.draw > 0:
				effects.append(_make_draw(card.draw))
		
		# 伤害 + 格挡
		"vajra_fist":
			if card.damage > 0:
				effects.append(_make_damage(card.damage))
			if card.block > 0:
				effects.append(_make_block(card.block))
		
		# 回血
		"heal":
			effects.append(_make_heal(card.heal))
		
		# 回血 + 抽牌
		"vigor":
			if card.heal > 0:
				effects.append(_make_heal(card.heal))
			if card.draw > 0:
				effects.append(_make_draw(card.draw))
		
		# 内力
		"meditate":
			effects.append(_make_energy(card.energy_gain))
		
		# 复杂卡牌 → 跳过（手动处理）
		_:
			print("跳过 %s：需要手动转换" % card_id)
			return false
	
	if effects.size() == 0:
		return false
	
	# 直接赋值效果数组到卡牌
	card.effects = effects
	
	# 保存回文件
	var err = ResourceSaver.save(card, path)
	if err != OK:
		push_error("保存 %s 失败: %s" % [card_id, error_string(err)])
		return false
	
	print("✅ 已转换 %s (effects=%d)" % [card_id, effects.size()])
	return true


func _make_damage(val: int, repeat_val: int = 0) -> DamageEffect:
	var e = DamageEffect.new()
	e.id = "dmg_%d" % val
	e.damage = val
	e.repeat = repeat_val
	return e

func _make_block(val: int) -> BlockEffect:
	var e = BlockEffect.new()
	e.id = "blk_%d" % val
	e.block = val
	return e

func _make_heal(val: int) -> HealEffect:
	var e = HealEffect.new()
	e.id = "heal_%d" % val
	e.heal = val
	return e

func _make_draw(val: int) -> DrawEffect:
	var e = DrawEffect.new()
	e.id = "draw_%d" % val
	e.count = val
	return e

func _make_energy(val: int) -> EnergyEffect:
	var e = EnergyEffect.new()
	e.id = "eg_%d" % val
	e.amount = val
	return e
