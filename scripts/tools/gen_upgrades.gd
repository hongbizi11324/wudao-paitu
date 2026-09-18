extends Node
# ==============================
# 升级卡生成器（工具，可重复运行）
#
# 运行：godot --headless --path . res://tools/gen_upgrades.tscn
#
# 为 resources/cards/ 下每张基础卡生成 "<id>_plus.tres"（card_id = "<id>+"）。
# 升级规则：强化「主效果」一项，避免多字段同时膨胀：
#   伤害  +max(2, 35%)
#   格挡  +max(2, 35%)
#   回血  +max(1, 35%)
#   抽牌  +1
#   内力  +1
#   以上皆无（纯 POWER）→ 费用 -1
# ==============================

const CARDS_DIR := "res://resources/cards"


func _ready():
	var dir := DirAccess.open(CARDS_DIR)
	if dir == null:
		push_error("无法打开 %s" % CARDS_DIR)
		get_tree().quit(1)
		return

	var generated := 0
	var skipped := 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres") and not fname.ends_with("_plus.tres"):
			var card_id := fname.trim_suffix(".tres")
			if _generate(card_id):
				generated += 1
			else:
				skipped += 1
		fname = dir.get_next()
	dir.list_dir_end()

	print("[升级卡生成] 完成：生成 %d 张，跳过 %d 张" % [generated, skipped])
	get_tree().quit(0)


func _generate(base_id: String) -> bool:
	var base: CardData = load("%s/%s.tres" % [CARDS_DIR, base_id])
	if base == null:
		return false

	var up := CardData.new()
	up.card_id = base_id + "+"
	up.card_name = base.card_name + "+"
	up.card_type = base.card_type
	up.cost = base.cost
	up.description = base.description
	up.damage = base.damage
	up.block = base.block
	up.heal = base.heal
	up.draw = base.draw
	up.repeat = base.repeat
	up.retain = base.retain
	up.energy_gain = base.energy_gain
	up.armor_break = base.armor_break
	up.school = base.school

	# 选主效果（价值评分最高的那一项）并强化
	var scores := {
		"damage": base.damage * 1.0,
		"block": base.block * 1.0,
		"heal": base.heal * 1.2,
		"draw": base.draw * 5.0,
		"energy_gain": base.energy_gain * 6.0,
	}
	var best := ""
	var best_score := 0.0
	for k in scores:
		if scores[k] > best_score:
			best_score = scores[k]
			best = k

	match best:
		"damage":
			up.damage = base.damage + maxi(2, int(round(base.damage * 0.35)))
		"block":
			up.block = base.block + maxi(2, int(round(base.block * 0.35)))
		"heal":
			up.heal = base.heal + maxi(1, int(round(base.heal * 0.35)))
		"draw":
			up.draw = base.draw + 1
		"energy_gain":
			up.energy_gain = base.energy_gain + 1
		_:
			# 纯 POWER（无数值）：费用 -1
			up.cost = maxi(0, base.cost - 1)

	# 描述附加升级标记
	up.description = base.description + "\n[强化]"

	var path := "%s/%s_plus.tres" % [CARDS_DIR, base_id]
	var err := ResourceSaver.save(up, path)
	if err != OK:
		push_error("保存 %s 失败: %s" % [path, error_string(err)])
		return false
	return true
