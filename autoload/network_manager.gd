extends Node

# ==============================
# 局域网联机管理器（自动加载）
# 主机：建服务器，发随机种子；跑完整游戏逻辑
# 客机：连接主机，收种子；纯渲染终端，只发输入请求
#
# 请求(客机→主机): request_play / request_end_turn / request_select_node /
#                  request_reward_done / request_rest_done / request_event_done /
#                  request_shop_buy / request_shop_delete / request_shop_done
# 广播(主机→客机): sync_game_state(快照) / sync_select_node / sync_show_map /
#                  sync_reward_open / sync_rest_open / sync_event_open /
#                  sync_shop_open / sync_shop_update
# ==============================

const DEFAULT_PORT: int = 8080
const MAX_PLAYERS: int = 2
const TIMEOUT_SECONDS: float = 15.0

var is_lan: bool = false
var is_host: bool = false
var shared_seed: int = 0
var p2_peer_id: int = 0
var p2_reconnecting: bool = false  # 客机是否正在重连
var host_in_select: bool = false   # 主机是否在选人界面

signal game_ready()
signal game_start_ready()
signal player_disconnected()
signal player_reconnected()

var _timeout_timer: Timer = null


# ==============================
# 主机/客机 建立连接
# ==============================

func host_game(port: int = DEFAULT_PORT) -> bool:
	if is_lan:
		cleanup()

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("建服失败: %d" % err)
		return false

	multiplayer.multiplayer_peer = peer
	is_lan = true
	is_host = true
	shared_seed = randi()

	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("[网络] 主机已开，种子=%d" % shared_seed)
	return true


func join_game(ip: String, port: int = DEFAULT_PORT) -> bool:
	# 防止重复连接
	if is_lan:
		cleanup()

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		push_error("连接失败: %d" % err)
		return false

	multiplayer.multiplayer_peer = peer
	is_lan = true
	is_host = false

	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)

	# ⏱ 连接超时
	_start_timeout()
	return true


func cleanup():
	"""断开连接，释放网络资源，复位会话标记"""
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_lan = false
	is_host = false
	p2_peer_id = 0
	p2_reconnecting = false
	host_in_select = false
	_stop_timeout()
	# 断开所有信号避免重复连接
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	print("[网络] 资源已清理")


# ==============================
# 连接事件
# ==============================

func _on_connected_to_server():
	print("[网络] 已连接服务器，等待种子...")


func _on_peer_connected(id: int):
	p2_peer_id = id
	print("[网络] 玩家已连接 (ID=%d)" % id)
	rpc_id(id, "_receive_seed", shared_seed)

	if is_host and host_in_select:
		# 主机在选人界面：新游戏，通知客机也进选人
		rpc_id(id, "sync_enter_select_school")
	elif is_host and not host_in_select and GameData.has_save():
		# 主机不在选人但有存档：重连场景
		p2_reconnecting = true
		print("[网络] 检测到存档，准备推送重连快照...")
		player_reconnected.emit()


func _on_peer_disconnected(id: int):
	print("[网络] 玩家断开连接 (ID=%d)" % id)
	if p2_peer_id == id:
		p2_peer_id = 0
	if is_host:
		# 主机：不 cleanup，保持服务器开放等重连
		GameData.save_game()
		player_disconnected.emit()
		print("[网络] 主机保持运行，等待客机重连...")
	else:
		# 客机：清理并回主菜单
		cleanup()
		player_disconnected.emit()


# ── 客机接收种子 ──
@rpc("any_peer", "reliable")
func _receive_seed(seed_val: int):
	_stop_timeout()
	shared_seed = seed_val
	seed(seed_val)
	print("[网络] 收到种子=%d" % seed_val)
	game_ready.emit()


# ── 主机通知客机进入选人界面 ──
@rpc("authority", "reliable")
func sync_enter_select_school():
	_find_and_call("network_enter_select_school")


# 主机 → 客机：P1 选完了，轮到 P2 选角色
@rpc("authority", "reliable")
func sync_p2_pick():
	_find_and_call("network_p2_pick")


# 客机 → 主机：P2 选完了
@rpc("any_peer", "reliable")
func request_p2_pick(p2_char: String, p2_school: String):
	if not is_host:
		return
	_find_and_call("network_p2_pick_done", [p2_char, p2_school])


# ── 主机推送重连数据 ──
func send_reconnect_data():
	if not is_host or p2_peer_id == 0:
		return
	p2_reconnecting = false
	# 同步角色和牌组
	rpc_id(p2_peer_id, "sync_start_game",
		GameData.selected_character,
		GameData.selected_character_2,
		GameData.player_deck,
		GameData.player2_deck
	)
	# 等一帧后推送快照（等客机场景加载完成）
	await get_tree().create_timer(0.5).timeout
	push_snapshot()
	print("[网络] 重连快照已推送")


# ==============================
# ⏱ 超时
# ==============================

func _start_timeout():
	_timeout_timer = Timer.new()
	_timeout_timer.wait_time = TIMEOUT_SECONDS
	_timeout_timer.one_shot = true
	_timeout_timer.timeout.connect(_on_timeout)
	add_child(_timeout_timer)
	_timeout_timer.start()


func _stop_timeout():
	if _timeout_timer:
		_timeout_timer.stop()
		_timeout_timer.queue_free()
		_timeout_timer = null


func _on_timeout():
	push_warning("[网络] 连接超时")
	print("[网络] 连接超时，清理资源")
	cleanup()


# ==============================
# 参数校验
# ==============================

func _valid_player(pid: int) -> bool:
	return pid == 1 or pid == 2


func _valid_card(card_id: String) -> bool:
	return card_id.length() > 0 and card_id.length() < 64


# ==============================
# 客户端 → 主机（请求）
# ==============================

# 客机请求出牌
@rpc("any_peer", "reliable")
func request_play(card_id: String, player_id: int):
	if not is_host:
		return  # 只有主机处理
	if not _valid_player(player_id) or not _valid_card(card_id):
		return
	_safe_call("network_execute_play", [card_id, player_id])
	push_snapshot()


# 客机请求结束回合
@rpc("any_peer", "reliable")
func request_end_turn(player_id: int):
	if not is_host:
		return
	if not _valid_player(player_id):
		return
	_safe_call("network_execute_end_turn", [player_id])
	push_snapshot()


# 客机请求选地图节点 → 主机执行并广播
@rpc("any_peer", "reliable")
func request_select_node(node_type: int):
	if not is_host:
		return
	var main = get_tree().current_scene
	if main and main.has_method("network_select_node"):
		main.network_select_node(node_type)
	push_snapshot()


# 客机 → 主机：奖励选择完成
@rpc("any_peer", "reliable")
func request_reward_done(card_id: String):
	if not is_host:
		return
	_safe_call("network_reward_done", [card_id])


# 客机 → 主机：休息点选择完成（现客机不可交互，保留兼容）
@rpc("any_peer", "reliable")
func request_rest_done(next_action: String):
	if not is_host:
		return
	_safe_call("network_rest_done", [next_action])


# 客机 → 主机：事件选择完成
@rpc("any_peer", "reliable")
func request_event_done(event_id: String, action: String):
	if not is_host:
		return
	_safe_call("network_event_done", [event_id, action])


# 客机 → 主机：商店购买
@rpc("any_peer", "reliable")
func request_shop_buy(card_id: String, target_player: int):
	if not is_host:
		return
	if not _valid_card(card_id) or not _valid_player(target_player):
		return
	_safe_call("network_shop_buy", [card_id, target_player])


# 客机 → 主机：商店删牌
@rpc("any_peer", "reliable")
func request_shop_delete(card_id: String, target_player: int):
	if not is_host:
		return
	if not _valid_card(card_id) or not _valid_player(target_player):
		return
	_safe_call("network_shop_delete", [card_id, target_player])


# 客机 → 主机：商店刷新货架
@rpc("any_peer", "reliable")
func request_shop_refresh():
	if not is_host:
		return
	_safe_call("network_shop_refresh", [])


# 客机 → 主机：商店购买遗物
@rpc("any_peer", "reliable")
func request_shop_relic(relic_id: String):
	if not is_host:
		return
	if relic_id.length() == 0 or relic_id.length() > 64:
		return
	_safe_call("network_shop_relic", [relic_id])


# 客机 → 主机：商店逛完
@rpc("any_peer", "reliable")
func request_shop_done():
	if not is_host:
		return
	_safe_call("network_shop_done", [])


# ==============================
# 主机 → 客机（广播）
# ==============================

# 地图节点同步（主机已直接执行，只通知客机）
@rpc("authority", "reliable")
func sync_select_node(node_type: int):
	var main = get_tree().current_scene
	if main and main.has_method("network_select_node"):
		main.network_select_node(node_type)


# 主机选完角色，同步角色和牌组给客机
@rpc("authority", "reliable")
func sync_start_game(p1_char: String, p2_char: String, p1_deck: Array, p2_deck: Array):
	GameData.new_dual_run()
	GameData.selected_character = p1_char
	GameData.selected_character_2 = p2_char
	GameData.player_deck = p1_deck.duplicate()
	GameData.player2_deck = p2_deck.duplicate()
	game_start_ready.emit()


# 奖励界面
@rpc("authority", "reliable")
func sync_reward_open(options: Array):
	_safe_call("network_reward_open", [options])


# 显示地图
@rpc("authority", "reliable")
func sync_show_map():
	_safe_call("network_show_map", [])


# 休息点：同步双方血量与金币后打开
@rpc("authority", "reliable")
func sync_rest_open(p1_hp: int, p2_hp: int, gold: int):
	_safe_call("network_rest_open", [p1_hp, p2_hp, gold])


# 事件：同步事件内容（两端一致，谁先选谁算）
@rpc("authority", "reliable")
func sync_event_open(event_data: Dictionary):
	_safe_call("network_event_open", [event_data])


# 商店：打开时同步库存
@rpc("authority", "reliable")
func sync_shop_open(stock: Array, sold: Array):
	_safe_call("network_shop_open", [stock, sold])


# 商店：购买/删牌后同步库存与金币
@rpc("authority", "reliable")
func sync_shop_update(stock: Array, sold: Array, gold: int):
	_safe_call("network_shop_sync", [stock, sold, gold])


# ==============================
# 状态快照同步
# ==============================

func push_snapshot():
	if not is_host:
		return
	var main = get_tree().current_scene
	if not main or main.scene_file_path != "res://scenes/main.tscn":
		return
	if not main.has_method("apply_snapshot"):
		return
	var snap = GameStateSync.build_snapshot(main)
	print("[主机] 推送快照: turn=%d p1_hand=%d p2_hand=%d gold=%d" % [
		snap.get("turn", -1), snap.get("p1_hand_ids", []).size(),
		snap.get("p2_hand_ids", []).size(), snap.get("gold", 0)])
	rpc("sync_game_state", snap)


@rpc("authority", "reliable")
func sync_game_state(state: Dictionary):
	var main = get_tree().current_scene
	if main and main.has_method("apply_snapshot"):
		main.apply_snapshot(state)


# ==============================
# 场景树方法分派
# ==============================

func _safe_call(method: String, args: Array):
	var main = get_tree().current_scene
	if main and main.has_method(method):
		main.callv(method, args)
	else:
		_find_and_call(method, args)


# 搜索场景树找有指定方法的节点（CanvasLayer 不是 current_scene）
func _find_and_call(method: String, args: Array = []):
	var root = get_tree().root
	_search_and_call(root, method, args)


func _search_and_call(node: Node, method: String, args: Array) -> bool:
	if node.has_method(method):
		node.callv(method, args)
		return true
	for child in node.get_children():
		if _search_and_call(child, method, args):
			return true
	return false
