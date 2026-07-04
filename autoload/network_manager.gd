extends Node

# ==============================
# 局域网联机管理器（自动加载）
# 主机：建服务器，发随机种子
# 客机：连接主机，收随机种子
# 核心：@rpc 同步打牌动作
# ==============================

var is_lan: bool = false      # 是否局域网模式
var is_host: bool = false     # 是否是主机（服务器）
var shared_seed: int = 0      # 共享随机种子
var p2_peer_id: int = 0       # P2的连接ID（主机端用）

signal game_ready()           # 种子同步完毕，可以进游戏了


# ---- 主机：开房间 ----
func host_game(port: int = 8080) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, 2)  # 最多2人
	if err != OK:
		push_error("建服失败: %d" % err)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_lan = true
	is_host = true
	shared_seed = randi()  # 生成随机种子
	multiplayer.peer_connected.connect(_on_peer_connected)
	print("[网络] 主机已开，种子=%d" % shared_seed)
	return true


# ---- 客机：加入房间 ----
func join_game(ip: String, port: int = 8080) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		push_error("连接失败: %d" % err)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_lan = true
	is_host = false
	# 连接成功后等服务器发种子
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	return true


func _on_connected_to_server():
	print("[网络] 已连接服务器，等待种子...")


func _on_peer_connected(id: int):
	p2_peer_id = id
	print("[网络] 玩家已连接 (ID=%d)" % id)
	# 给客机发种子
	rpc_id(id, "_receive_seed", shared_seed)


# ── 客机接收种子 ──
@rpc("any_peer", "reliable")
func _receive_seed(seed_val: int):
	shared_seed = seed_val
	seed(seed_val)  # 设置Godot全局随机种子
	print("[网络] 收到种子=%d" % seed_val)
	game_ready.emit()


# ==============================
# RPC 同步函数
# 打牌/结束回合，call_local保证两边都执行
# ==============================

# P1或P2打牌同步
@rpc("any_peer", "call_local", "reliable")
func sync_play(card_id: String, player_id: int):
	_on_remote_play(card_id, player_id)


# 结束回合同步
@rpc("any_peer", "call_local", "reliable")
func sync_end_turn(player_id: int):
	_on_remote_end_turn(player_id)


# 执行打牌（在两边都运行）
# 从 main.gd 中找到对应手牌执行
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
