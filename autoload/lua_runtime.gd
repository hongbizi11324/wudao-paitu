extends Node

# ==============================================
# LuaRuntime — Lua 热更桥接层（Command Pattern 版）
#
# 架构约定（与旧版的本质区别）：
#   Lua 是纯函数——只读 ctx、返回「结果清单」，不写任何游戏状态。
#   GDScript 拿到清单后由 CardExecutor 原子执行。
#   - Lua 报错 → 清单没返回 → 什么都不执行 → 无需快照/回滚/沙箱
#   - 无需 gd_* 写回调、无需 host 全局注入（旧 bug：host 从未绑定恒为 nil）
#   - 预览与出牌共用同一份纯函数，预览天然无副作用
#
# 模块化：cards/basic|shaolin|wudang|xiaoyao|yunzhi.lua 按序加载，
# 各自向全局 CardEffects 表注册卡牌函数；battle.lua 提供 POWER 触发。
# ==============================================

signal lua_reloaded(file_path: String)
signal lua_error(error_msg: String)

var _lua: LuaState
var _loaded_files: Dictionary = {}   # res路径 -> mtime
var _ready_flag: bool = false
var _auto_reload: bool = true
var _check_interval: float = 1.0
var _timer: float = 0.0
var _func_cache: Dictionary = {}     # card_id -> 编译好的 LuaFunction（TODO P5）

var enabled: bool = true

# Lua 模块（按加载顺序；cards 聚合后再加载战斗逻辑）
const CARD_MODULES: Array = [
	"res://lua/cards/basic.lua",
	"res://lua/cards/shaolin.lua",
	"res://lua/cards/wudang.lua",
	"res://lua/cards/xiaoyao.lua",
	"res://lua/cards/yunzhi.lua",
]
const BATTLE_LUA_PATH: String = "res://lua/battle.lua"


func _ready() -> void:
	_init_lua_state()
	var ok := true
	for path in CARD_MODULES:
		if not _load_file(path):
			ok = false
	if not _load_file(BATTLE_LUA_PATH):
		ok = false
	if ok:
		_ready_flag = true
		print("[LuaRuntime] 初始化完成：%d 个卡牌模块 + battle.lua（自动热更: 每%.0f秒检测，Ctrl+R 手动触发）" % [
			CARD_MODULES.size(), _check_interval])
	else:
		push_error("[LuaRuntime] 初始化失败，卡牌逻辑回退 GDScript 基础结算")


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


# ==============================================
# 文件加载
# ==============================================

func _load_file(file_path: String) -> bool:
	if not FileAccess.file_exists(ProjectSettings.globalize_path(file_path)):
		_report_error(file_path, "文件不存在")
		return false
	var result = _lua.do_file(file_path)
	if result is LuaError:
		_report_error(file_path, result)
		return false
	_track_file(file_path)
	print("[LuaRuntime] 已加载 %s" % file_path)
	return true


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

## 全量热重载：按依赖顺序重新执行所有模块，清空函数编译缓存。
## 某个模块失败时保留已加载的旧函数（热更容错），并发出错误信号。
func reload() -> void:
	print("[LuaRuntime] 正在热重载所有 Lua 模块 ...")
	var failed: Array = []
	for path in CARD_MODULES:
		var result = _lua.do_file(path)
		if result is LuaError:
			failed.append(path)
			push_error("[LuaRuntime] 重载失败 %s: %s" % [path, str(result)])
			lua_error.emit("[LuaRuntime] 重载失败 %s: %s" % [path, str(result)])
		else:
			_track_file(path)
	var b_result = _lua.do_file(BATTLE_LUA_PATH)
	if b_result is LuaError:
		failed.append(BATTLE_LUA_PATH)
	else:
		_track_file(BATTLE_LUA_PATH)

	_func_cache.clear()
	if failed.is_empty():
		lua_reloaded.emit("all")
		print("[LuaRuntime] 热重载成功")
	else:
		print("[LuaRuntime] 热重载完成（%d 个模块失败，保留旧逻辑）" % failed.size())


func check_and_reload() -> void:
	for file_path in _loaded_files.keys():
		var abs_path = ProjectSettings.globalize_path(file_path)
		if not FileAccess.file_exists(abs_path):
			continue
		var mtime = FileAccess.get_modified_time(abs_path)
		if mtime != _loaded_files[file_path]:
			reload()
			return


# ==============================================
# 卡牌效果计算（纯函数：Lua 只算不写）
# ==============================================

## 计算 card_id 的效果清单。ctx 由 GDScript 打包（含全部所需只读数据）。
## execute 与 preview 共用本函数——Lua 无副作用，预览即真值。
func execute_card(card_id: String, ctx: Dictionary) -> Dictionary:
	if not enabled or not _ready_flag:
		return {}

	var card_effects = _lua.globals["CardEffects"]
	if card_effects == null or card_effects is LuaError:
		return {}
	if card_effects[card_id] == null:
		return {}

	var lua_func = _func_cache.get(card_id)
	if lua_func == null:
		var compiled = _lua.load_string("return CardEffects['" + card_id + "'](_G._call_ctx)")
		if compiled is LuaError:
			push_error("[LuaRuntime] 编译 %s 出错: %s" % [card_id, str(compiled)])
			return {}
		_func_cache[card_id] = compiled
		lua_func = compiled

	_lua.globals["_call_ctx"] = ctx
	var result = lua_func.invoke()
	if result is LuaError:
		push_error("[LuaRuntime] 执行卡牌 %s 出错: %s" % [card_id, str(result)])
		return {}

	return result if result is Dictionary else {}


## 旧接口兼容别名：预览 = 执行（纯函数化后两者完全一致）
func preview_card(card_id: String, ctx: Dictionary) -> Dictionary:
	return execute_card(card_id, ctx)


# ==============================================
# POWER/回合逻辑（同样返回清单，由宿主执行）
# ==============================================

## 每回合开始触发当前玩家的 POWER。返回触发清单。
func battle_trigger_powers(ctx: Dictionary) -> Dictionary:
	if not enabled or not _ready_flag:
		return {}
	var battle = _lua.globals["Battle"]
	if battle == null or battle is LuaError:
		return {}

	var lua_func = _func_cache.get("__battle_powers")
	if lua_func == null:
		var compiled = _lua.load_string("return Battle.trigger_powers(_G._battle_ctx)")
		if compiled is LuaError:
			return {}
		_func_cache["__battle_powers"] = compiled
		lua_func = compiled

	_lua.globals["_battle_ctx"] = ctx
	var result = lua_func.invoke()
	if result is LuaError:
		push_error("[LuaRuntime] battle trigger_powers 出错: %s" % str(result))
		return {}
	return result if result is Dictionary else {}


# ==============================================
# 输入处理
# ==============================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and event.ctrl_pressed:
			reload()
			get_viewport().set_input_as_handled()
