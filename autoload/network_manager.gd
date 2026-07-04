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
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("建服失败: %d" % err)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_lan = true
	is_host = true
	shared_seed = randi()
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	print("[网络] 主机已开，种子=%d" % shared_seed)
	return true


func join_game(ip: String, port: int = DEFAULT_PORT) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		push_error("连接失败: %d" % err)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_lan = true
	is_host = false
	
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
	print("[网络] 资源已清理")


# ==============================
# 连接事件
# ==============================

func _on_connected_to_server():
	print("[网络] 已连接服务器，等待种子...")
	_stop_timeout()


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


# P1或P2打牌同步
@rpc("any_peer", "call_local", "reliable")
func sync_play(card_id: String, player_id: int):
	if not _valid_player(player_id) or not _valid_card(card_id):
		push_error("[网络] sync_play 参数非法: pid=%d card=%s" % [player_id, card_id])
		return
	_on_remote_play(card_id, player_id)


# 结束回合同步
@rpc("any_peer", "call_local", "reliable")
func sync_end_turn(player_id: int):
	if not _valid_player(player_id):
		push_error("[网络] sync_end_turn 参数非法: pid=%d" % player_id)
		return
	_on_remote_end_turn(player_id)


func _on_remote_play(card_id: String, player_id: int):
	var main = get_tree().current_scene
	if not main or not main.has_method("network_execute_play"):
		return
	main.network_execute_play(card_id, player_id)


func _on_remote_end_turn(player_id: int):
	var main = get_tree().current_scene
	if not main or not main.has_method("network_execute_end_turn"):
		return
	main.network_execute_end_turn(player_id)


# 地图节点同步
@rpc("authority", "call_local", "reliable")
func sync_select_node(node_type: int):
	var main = get_tree().current_scene
	if main and main.has_method("network_select_node"):
		main.network_select_node(node_type)


# 主机选完角色，同步角色和牌组给客机
@rpc("authority", "reliable")
func sync_start_game(p1_char: String, p2_char: String, p1_deck: Array, p2_deck: Array):
	GameData.selected_character = p1_char
	GameData.selected_character_2 = p2_char
	GameData.player_deck = p1_deck
	GameData.player2_deck = p2_deck
	game_start_ready.emit()


# 主机通知客机：回合变了，执行对应阶段的动作
@rpc("authority", "call_local", "reliable")
func sync_turn(turn_id: int):
	var main = get_tree().current_scene
	if not main or not main.has_method("network_sync_turn"):
		return
	main.network_sync_turn(turn_id)
