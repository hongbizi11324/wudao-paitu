extends Node

# ==============================================
# LuaRuntime — Lua 热更桥接层
# 管理 LuaState 生命周期，提供卡牌效果调用和热重载接口
# ==============================================

signal lua_reloaded(file_path: String)
signal lua_error(error_msg: String)

var _lua: LuaState
var _loaded_files: Dictionary = {}
var _ready_flag: bool = false
var _auto_reload: bool = true
var _check_interval: float = 1.0
var _timer: float = 0.0

var enabled: bool = true

# Lua 脚本路径
const CARDS_LUA_PATH = "res://lua/cards.lua"
const ENEMY_AI_LUA_PATH = "res://lua/enemy_ai.lua"
const BATTLE_LUA_PATH = "res://lua/battle.lua"

# 宿主回调（由 main.gd 设置）
var host: Node = null


func _ready() -> void:
	_init_lua_state()
	_load_cards_script()
	_load_enemy_ai_script()
	_load_battle_script()
	_ready_flag = true
	print("[LuaRuntime] 初始化完成（自动热更: 每%.0f秒检测，Ctrl+R 手动触发）" % _check_interval)


func _process(delta: float) -> void:
	if not _auto_reload or not _ready_flag:
		return
	_timer += delta
	if _timer >= _check_interval:
		_timer = 0.0
		check_and_reload()


func _init_lua_state() -> void:
	_lua = LuaState.new()
	_lua.open_libraries()
	_setup_godot_bindings()


func _setup_godot_bindings() -> void:
	# ---- 基础数值查询 ----
	_lua.globals["gd_get_damage_bonus"] = func(): return GameData.get_damage_bonus()
	_lua.globals["gd_get_block_bonus"] = func(): return GameData.get_block_bonus()
	_lua.globals["gd_get_punch_damage"] = func(): return GameData.get_punch_damage()
	_lua.globals["gd_get_meditate_gain"] = func(): return GameData.get_meditate_gain()

	# ---- 玩家状态操作 ----
	_lua.globals["gd_player_heal"] = func(amount): if host and host.player: host.player.heal(amount)
	_lua.globals["gd_player_add_block"] = func(amount): if host and host.player: host.player.add_block(amount)
	_lua.globals["gd_player_gain_energy"] = func(amount): if host and host.player: host.player.gain_energy(amount)
	_lua.globals["gd_player_chan_plus"] = func(amount): if host and host.player: host.player.chan += amount
	_lua.globals["gd_player_chan_reset"] = func(): if host and host.player: host.player.chan = 0
	_lua.globals["gd_player_jianyi_plus"] = func(amount): if host and host.player: host.player.jianyi += amount
	_lua.globals["gd_player_jianyi_minus"] = func(amount): if host and host.player: host.player.jianyi = max(0, host.player.jianyi - amount)
	_lua.globals["gd_player_set_next_discount"] = func(amount): if host and host.player: host.player.next_card_discount = amount

	# ---- 敌人状态操作 ----
	_lua.globals["gd_enemy_take_damage"] = func(dmg, armor_break): if host and host.enemy: host.enemy.take_damage(dmg, armor_break)
	_lua.globals["gd_enemy_hp"] = func(): return host.enemy.hp if host and host.enemy else 0
	_lua.globals["gd_enemy_max_hp"] = func(): return host.enemy.max_hp if host and host.enemy else 1
	_lua.globals["gd_enemy_block"] = func(): return host.enemy.block if host and host.enemy else 0
	_lua.globals["gd_enemy_intent_type"] = func(): return host.enemy.intent_type if host and host.enemy else 0
	_lua.globals["gd_enemy_intent_value"] = func(): return host.enemy.intent_value if host and host.enemy else 0

	# ---- 手牌操作 ----
	_lua.globals["gd_hand_size"] = func(): return host.hand.cards.size() if host and host.hand else 0
	_lua.globals["gd_hand_card_ids"] = func():
		var ids = []
		if host and host.hand:
			for c in host.hand.cards:
				ids.append(c.card_data.card_id)
		return ids
	_lua.globals["gd_discard_card_by_index"] = func(idx):
		if not host or not host.hand: return
		if idx < 0 or idx >= host.hand.cards.size(): return
		var c = host.hand.cards[idx]
		var dc = host.discard_pile_p2 if host._active_player == 2 else host.discard_pile
		dc.append(c.card_data.card_id)
		host.hand.remove_card(c)
		host.CardPool.release(c)
	_lua.globals["gd_add_card_to_hand"] = func(card_id):
		if not host: return
		var path = "res://resources/cards/%s.tres" % card_id
		var data = load(path)
		if not data: return
		var cscene = load("res://scenes/card.tscn")
		var new_card = host.CardPool.acquire(cscene)
		new_card.setup(data)
		if not host.hand.add_card(new_card):
			host.CardPool.release(new_card)
			var dc = host.discard_pile_p2 if host._active_player == 2 else host.discard_pile
			dc.append(card_id)

	# ---- 牌堆操作 ----
	_lua.globals["gd_draw_pile_size"] = func():
		if not host: return 0
		var dp = host.draw_pile_p2 if host._active_player == 2 else host.draw_pile
		return dp.size()
	_lua.globals["gd_discard_pile_ids"] = func():
		var ids = []
		if not host: return ids
		var dc = host.discard_pile_p2 if host._active_player == 2 else host.discard_pile
		for id in dc: ids.append(id)
		return ids
	_lua.globals["gd_move_card_to_draw_pile"] = func(idx):
		if not host or not host.hand: return
		if idx < 0 or idx >= host.hand.cards.size(): return
		var c = host.hand.cards[idx]
		var dp = host.draw_pile_p2 if host._active_player == 2 else host.draw_pile
		dp.append(c.card_data.card_id)
		host.hand.remove_card(c)
		host.CardPool.release(c)
	_lua.globals["gd_draw_cards"] = func(count):
		if not host: return
		var dp = host.draw_pile_p2 if host._active_player == 2 else host.draw_pile
		var dc = host.discard_pile_p2 if host._active_player == 2 else host.discard_pile
		host._switch_draw(host.hand, dp, dc, count)

	# ---- 内力操作 ----
	_lua.globals["gd_player_spend_energy"] = func(amount):
		if not host or not host.player: return
		host.player.energy = max(0, host.player.energy - amount)
		host.energy_used_this_turn += amount
		host.player.energy_changed.emit(host.player.energy, host.player.max_energy)
	_lua.globals["gd_player_energy"] = func(): return host.player.energy if host and host.player else 0
	_lua.globals["gd_player_max_energy"] = func(): return host.player.max_energy if host and host.player else 0

	# ---- 游戏状态查询 ----
	_lua.globals["gd_game_data"] = func(key):
		match key:
			"current_floor": return GameData.current_floor
			"is_dual_mode": return GameData.is_dual_mode
			"max_energy_per_realm": return GameData.max_energy_per_realm
			"player_hp": return GameData.player_hp
			"player_max_hp": return GameData.player_max_hp
		return null

	# ---- POWER 标记 ----
	_lua.globals["gd_set_power"] = func(power_name, value):
		if not host or not host.player: return
		match power_name:
			"damo": host.player.power_damo = value
			"twoway": host.player.power_twoway = value
			"bahuang": host.player.power_bahuang = value
			"longxiang": host.player.power_longxiang = value
			"xiaoyaoyou": host.player.power_xiaoyaoyou = value
	_lua.globals["gd_get_power"] = func(power_name):
		if not host or not host.player: return false
		match power_name:
			"damo": return host.player.power_damo
			"twoway": return host.player.power_twoway
			"bahuang": return host.player.power_bahuang
			"longxiang": return host.player.power_longxiang
			"xiaoyaoyou": return host.player.power_xiaoyaoyou
		return false

	# ---- UI 刷新 ----
	_lua.globals["gd_update_ui"] = func():
		if host:
			host._update_deck_ui()
			host._update_sect_ui()
	_lua.globals["gd_print"] = func(msg): print(msg)


# ==============================================
# 文件加载
# ==============================================

func _load_cards_script() -> void:
	var result = _lua.do_file(CARDS_LUA_PATH)
	if result is LuaError:
		_report_error(CARDS_LUA_PATH, result)
	else:
		_track_file(CARDS_LUA_PATH)
		print("[LuaRuntime] cards.lua 加载成功")


func _load_enemy_ai_script() -> void:
	if not FileAccess.file_exists(ProjectSettings.globalize_path(ENEMY_AI_LUA_PATH)):
		return
	var result = _lua.do_file(ENEMY_AI_LUA_PATH)
	if result is LuaError:
		_report_error(ENEMY_AI_LUA_PATH, result)
	else:
		_track_file(ENEMY_AI_LUA_PATH)
		print("[LuaRuntime] enemy_ai.lua 加载成功")


func _load_battle_script() -> void:
	if not FileAccess.file_exists(ProjectSettings.globalize_path(BATTLE_LUA_PATH)):
		return
	var result = _lua.do_file(BATTLE_LUA_PATH)
	if result is LuaError:
		_report_error(BATTLE_LUA_PATH, result)
	else:
		_track_file(BATTLE_LUA_PATH)
		print("[LuaRuntime] battle.lua 加载成功")


func _report_error(file_path: String, result) -> void:
	var msg = "[LuaRuntime] 加载 %s 失败: %s" % [file_path, str(result)]
	push_error(msg)
	lua_error.emit(msg)
	enabled = false


func _track_file(file_path: String) -> void:
	var abs_path = ProjectSettings.globalize_path(file_path)
	_loaded_files[file_path] = FileAccess.get_modified_time(abs_path)


# ==============================================
# 热重载
# ==============================================

func reload(file_path: String = CARDS_LUA_PATH) -> void:
	print("[LuaRuntime] 正在重载 %s ..." % file_path)
	var result = _lua.do_file(file_path)
	if result is LuaError:
		var msg = "[LuaRuntime] 重载失败: %s" % str(result)
		push_error(msg)
		lua_error.emit(msg)
	else:
		_track_file(file_path)
		lua_reloaded.emit(file_path)
		print("[LuaRuntime] 重载成功: %s" % file_path)


func check_and_reload() -> void:
	for file_path in _loaded_files.keys():
		var abs_path = ProjectSettings.globalize_path(file_path)
		if not FileAccess.file_exists(abs_path):
			continue
		var mtime = FileAccess.get_modified_time(abs_path)
		if mtime != _loaded_files[file_path]:
			reload(file_path)


# ==============================================
# 卡牌效果执行
# ==============================================

func execute_card(card_id: String, ctx: Dictionary) -> Dictionary:
	if not enabled or not _ready_flag:
		return {}

	var card_effects = _lua.globals["CardEffects"]
	if card_effects == null:
		return {}
	if card_effects is LuaError:
		return {}

	var func_ref = card_effects[card_id]
	if func_ref == null:
		return {}

	_lua.globals["_call_ctx"] = ctx

	var lua_func = _lua.load_string("return CardEffects['" + card_id + "'](_G._call_ctx)")
	if lua_func is LuaError:
		push_error("[LuaRuntime] load_string 出错: %s" % str(lua_func))
		return {}

	var result = lua_func.invoke()
	if result is LuaError:
		push_error("[LuaRuntime] 执行卡牌 %s 出错: %s" % [card_id, str(result)])
		return {}

	if result is Dictionary:
		return result

	return {}


## 预览卡牌效果（不执行副作用，只返回计算结果用于显示）
func preview_card(card_id: String, ctx: Dictionary) -> Dictionary:
	return execute_card(card_id, ctx)


# ==============================================
# 敌人 AI 执行
# ==============================================

func enemy_plan_intent(ctx: Dictionary) -> Dictionary:
	if not enabled or not _ready_flag:
		return {}
	var enemy_ai = _lua.globals["EnemyAI"]
	if enemy_ai == null:
		return {}

	_lua.globals["_enemy_ctx"] = ctx
	var lua_func = _lua.load_string("return EnemyAI.plan_intent(_G._enemy_ctx)")
	if lua_func is LuaError:
		push_error("[LuaRuntime] enemy plan_intent load 出错: %s" % str(lua_func))
		return {}

	var result = lua_func.invoke()
	if result is LuaError:
		push_error("[LuaRuntime] enemy plan_intent 出错: %s" % str(result))
		return {}

	if result is Dictionary:
		return result
	return {}


func enemy_execute_intent(ctx: Dictionary) -> Dictionary:
	if not enabled or not _ready_flag:
		return {}
	var enemy_ai = _lua.globals["EnemyAI"]
	if enemy_ai == null:
		return {}

	_lua.globals["_enemy_ctx"] = ctx
	var lua_func = _lua.load_string("return EnemyAI.execute_intent(_G._enemy_ctx)")
	if lua_func is LuaError:
		return {}

	var result = lua_func.invoke()
	if result is LuaError:
		push_error("[LuaRuntime] enemy execute_intent 出错: %s" % str(result))
		return {}

	if result is Dictionary:
		return result
	return {}


# ==============================================
# POWER/回合逻辑执行
# ==============================================

func battle_trigger_powers(ctx: Dictionary) -> void:
	if not enabled or not _ready_flag:
		return
	var battle = _lua.globals["Battle"]
	if battle == null:
		return

	_lua.globals["_battle_ctx"] = ctx
	var lua_func = _lua.load_string("return Battle.trigger_powers(_G._battle_ctx)")
	if lua_func is LuaError:
		return
	var result = lua_func.invoke()
	if result is LuaError:
		push_error("[LuaRuntime] battle trigger_powers 出错: %s" % str(result))


func battle_on_turn_start(ctx: Dictionary) -> Dictionary:
	if not enabled or not _ready_flag:
		return {}
	var battle = _lua.globals["Battle"]
	if battle == null:
		return {}

	_lua.globals["_battle_ctx"] = ctx
	var lua_func = _lua.load_string("return Battle.on_turn_start(_G._battle_ctx)")
	if lua_func is LuaError:
		return {}
	var result = lua_func.invoke()
	if result is LuaError:
		push_error("[LuaRuntime] battle on_turn_start 出错: %s" % str(result))
		return {}
	if result is Dictionary:
		return result
	return {}


# ==============================================
# 输入处理
# ==============================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and event.ctrl_pressed:
			reload()
			get_viewport().set_input_as_handled()
