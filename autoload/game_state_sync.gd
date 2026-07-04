extends Node

# 构建当前游戏状态快照（只含客机渲染需要的数据）
static func build_snapshot(main_node: Node) -> Dictionary:
	var tm = main_node.turn_manager
	var turn_val = tm.current_turn if tm and tm.active else -1
	
	var snap = {
		"turn": turn_val,
		"active_player": main_node._active_player,
		"p1_hp": main_node.player1.hp,
		"p1_max_hp": main_node.player1.max_hp,
		"p1_block": main_node.player1.block,
		"p1_energy": main_node.player1.energy,
		"p1_hand_ids": [],
		"p1_draw_count": main_node.draw_pile.size(),
		"p1_discard_count": main_node.discard_pile.size(),
		"p2_hp": main_node.player2.hp if main_node.player2 else 0,
		"p2_max_hp": main_node.player2.max_hp if main_node.player2 else 1,
		"p2_block": main_node.player2.block if main_node.player2 else 0,
		"p2_energy": main_node.player2.energy if main_node.player2 else 0,
		"p2_hand_ids": [],
		"p2_draw_count": main_node.draw_pile_p2.size() if main_node.draw_pile_p2 else 0,
		"p2_discard_count": main_node.discard_pile_p2.size() if main_node.discard_pile_p2 else 0,
		"enemy_hp": 0, "enemy_max_hp": 1, "enemy_block": 0,
		"enemy_exists": false, "enemy_intent_type": -1, "enemy_intent_val": 0,
		"floor": GameData.current_floor, "game_over": main_node.game_over,
		"is_dual": GameData.is_dual_mode
	}
	
	for c in main_node.hand1.cards:
		snap["p1_hand_ids"].append(c.card_data.card_id)
	if main_node.hand2:
		for c in main_node.hand2.cards:
			snap["p2_hand_ids"].append(c.card_data.card_id)
	
	var e = main_node.get_node_or_null("Enemy")
	if e and is_instance_valid(e):
		snap["enemy_exists"] = true
		snap["enemy_hp"] = e.hp; snap["enemy_max_hp"] = e.max_hp; snap["enemy_block"] = e.block
		snap["enemy_intent_type"] = e.intent_type; snap["enemy_intent_val"] = e.intent_value
	
	return snap
