extends Node

# ==============================
# 局域网联机管理器（自动加载）
# 主机：建服务器，发随机种子
# 客机：连接主机，收随机种子
# 核心：@rpc 同步打牌动作
# ==============================

const DEFAULT_PORT: int = 8080
const MAX_PLAYERS: int = 2
const TIMEOUT_SECONDS: float = 15.0

var is_lan: bool = false
var is_host: bool = false
var shared_seed: int = 0
var p2_peer_id: int = 0

signal game_ready()
signal game_start_ready()
signal player_disconnected()

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
	"""断开连接，释放网络资源"""
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_lan = false
	is_host = false
	p2_peer_id = 0
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


func _on_peer_disconnected(id: int):
	print("[网络] 玩家断开连接 (ID=%d)" % id)
	if p2_peer_id == id:
		p2_peer_id = 0
	player_disconnected.emit()
	cleanup()


# ── 客机接收种子 ──
@rpc("any_peer", "reliable")
func _receive_seed(seed_val: int):
	_stop_timeout()
	shared_seed = seed_val
	seed(seed_val)
	print("[网络] 收到种子=%d" % seed_val)
	game_ready.emit()


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
# RPC 同步函数
# ==============================

# ✅ 参数校验：player_id 只能是 1 或 2
func _valid_player(pid: int) -> bool:
	return pid == 1 or pid == 2

func _valid_card(card_id: String) -> bool:
	return card_id.length() > 0 and card_id.length() < 64


# ==============================
# 客户端 → 主机（请求）
# 客户端发起请求，只有主机处理
# ==============================

# 客机请求出牌
@rpc("any_peer", "reliable")
func request_play(card_id: String, player_id: int):
	if not is_host:
		return  # 只有主机处理
	if not _valid_player(player_id) or not _valid_card(card_id):
		return
	# 主机执行，然后广播
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


# ==============================
# 主机 → 所有节点（广播）
# 主机执行完，广播给所有人执行同样的逻辑
# ==============================

@rpc("authority", "reliable")
func sync_play(card_id: String, player_id: int):
	_safe_call("network_execute_play", [card_id, player_id])


@rpc("authority", "reliable")
func sync_end_turn(player_id: int):
	_safe_call("network_execute_end_turn", [player_id])


func _safe_call(method: String, args: Array):
	var main = get_tree().current_scene
	if main and main.has_method(method):
		main.callv(method, args)


# 地图节点同步
# 主机 → 客机：广播选节点结果（不 call_local，主机已直接执行）
@rpc("authority", "reliable")
func sync_select_node(node_type: int):
	var main = get_tree().current_scene
	if main and main.has_method("network_select_node"):
		main.network_select_node(node_type)


# 客机请求选节点 → 主机执行并广播
@rpc("any_peer", "reliable")
func request_select_node(node_type: int):
	if not is_host:
		return
	var main = get_tree().current_scene
	if main and main.has_method("network_select_node"):
		main.network_select_node(node_type)
	push_snapshot()


# 主机选完角色，同步角色和牌组给客机
@rpc("authority", "reliable")
func sync_start_game(p1_char: String, p2_char: String, p1_deck: Array, p2_deck: Array):
	# 先重置所有数据（new_dual_run 会覆盖 deck 所以后设）
	GameData.new_dual_run()
	# 再覆盖成主机发来的数据
	GameData.selected_character = p1_char
	GameData.selected_character_2 = p2_char
	GameData.player_deck = p1_deck.duplicate()
	GameData.player2_deck = p2_deck.duplicate()
	game_start_ready.emit()


# 主机通知客机：回合变了，执行对应阶段的动作
@rpc("authority", "reliable")
func sync_turn(turn_id: int):
	var main = get_tree().current_scene
	if not main or not main.has_method("network_sync_turn"):
		return
	main.network_sync_turn(turn_id)

# ==============================
# 奖励/地图同步
# ==============================

# 主机 → 客机：开奖励界面
@rpc("authority", "reliable")
func sync_reward_open(options: Array):
	var main = get_tree().current_scene
	if main and main.has_method("network_reward_open"):
		main.network_reward_open(options)

# 主机 → 客机：显示地图
@rpc("authority", "reliable")
func sync_show_map():
	var main = get_tree().current_scene
	if main and main.has_method("network_show_map"):
		main.network_show_map()

# 客机 → 主机：奖励选择完成
@rpc("any_peer", "reliable")
func request_reward_done(card_id: String):
	if not is_host:
		return
	var main = get_tree().current_scene
	if main and main.has_method("network_reward_done"):
		main.network_reward_done(card_id)


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
	print("[主机] 推送快照: turn=%d p1_hand=%d p2_hand=%d" % [snap.get("turn", -1), snap.get("p1_hand_ids", []).size(), snap.get("p2_hand_ids", []).size()])
	rpc("sync_game_state", snap)


@rpc("authority", "reliable")
func sync_game_state(state: Dictionary):
	var main = get_tree().current_scene
	if main and main.has_method("apply_snapshot"):
		main.apply_snapshot(state)
