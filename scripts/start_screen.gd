extends Node2D

var _start_orig_scale: Vector2
var _quit_orig_scale: Vector2
@onready var _continue_btn: Button = $ContinueBtn


func _ready():
	$BtnStart.pressed.connect(_on_start)
	$BtnStart.mouse_entered.connect(_on_start_hover)
	$BtnStart.mouse_exited.connect(_on_start_unhover)
	$TestBtn.pressed.connect(_on_test)
	$DualBtn.pressed.connect(_on_dual)
	$DualBtn.mouse_entered.connect(_on_dual_hover)
	$DualBtn.mouse_exited.connect(_on_dual_unhover)
	$MusicBtn.pressed.connect(_on_music_toggle)
	$QuitBtn.pressed.connect(_on_quit)
	$QuitBtn.mouse_entered.connect(_on_quit_hover)
	$QuitBtn.mouse_exited.connect(_on_quit_unhover)
	
	_start_orig_scale = $BtnStart.scale
	_quit_orig_scale = $QuitBtn.scale
	_update_music_btn()
	
	_continue_btn.pressed.connect(_on_continue)
	$HostBtn.pressed.connect(_on_host)
	$JoinBtn.pressed.connect(_on_join)


func _on_start_hover():
	var tw = create_tween()
	tw.tween_property($BtnStart, "scale", _start_orig_scale * 1.1, 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_start_unhover():
	var tw = create_tween()
	tw.tween_property($BtnStart, "scale", _start_orig_scale, 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_start():
	GameData.is_dual_mode = false
	if GameData.has_save():
		GameData.delete_save()
	get_tree().change_scene_to_file("res://scenes/select_school.tscn")

func _on_dual():
	GameData.is_dual_mode = true
	if GameData.has_save():
		GameData.delete_save()
	get_tree().change_scene_to_file("res://scenes/select_school.tscn")

func _on_continue():
	if not GameData.has_save():
		_toast("没有旧存档")
		return
	
	if NetworkManager.is_host and not NetworkManager.p2_peer_id:
		GameData.load_game()
		GameData.is_dual_mode = true
		GameData.loading_save = true
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		_toast("等待P2重连...")
		return
	
	GameData.load_game()
	GameData.is_dual_mode = false
	GameData.loading_save = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_host():
	if NetworkManager.host_game():
		GameData.is_dual_mode = true
		GameData.new_dual_run()
		NetworkManager.host_in_select = true
		get_tree().change_scene_to_file("res://scenes/select_school.tscn")

func _on_join():
	var ip = $IpEdit.text.strip_edges()
	if ip.is_empty():
		_toast("请输入主机IP地址")
		return
	if NetworkManager.join_game(ip):
		if not NetworkManager.game_ready.is_connected(_on_network_ready):
			NetworkManager.game_ready.connect(_on_network_ready)
		_toast("正在连接...")

func _on_network_ready():
	_toast("已连接，等待主机会话...")
	if not NetworkManager.game_start_ready.is_connected(_on_game_start):
		NetworkManager.game_start_ready.connect(_on_game_start)

func _on_game_start():
	GameData.is_dual_mode = true
	# 只有重连场景才设 loading_save
	if NetworkManager.p2_reconnecting:
		GameData.loading_save = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _toast(msg: String):
	var toast = Label.new()
	toast.text = msg
	toast.add_theme_font_size_override("font_size", 18)
	toast.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	toast.position = Vector2(500, 500)
	add_child(toast)
	var tw = create_tween()
	tw.tween_property(toast, "modulate", Color(1,1,1,0), 1.5).set_delay(0.8)
	tw.finished.connect(toast.queue_free)

func _on_test():
	get_tree().change_scene_to_file("res://scenes/test_deck.tscn")

func _on_quit_hover():
	var tw = create_tween()
	tw.tween_property($QuitBtn, "scale", _quit_orig_scale * 1.1, 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_quit_unhover():
	var tw = create_tween()
	tw.tween_property($QuitBtn, "scale", _quit_orig_scale, 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_dual_hover():
	var tw = create_tween()
	tw.tween_property($DualBtn, "scale", Vector2(1.05, 1.05), 0.1)

func _on_dual_unhover():
	var tw = create_tween()
	tw.tween_property($DualBtn, "scale", Vector2(1, 1), 0.08)

func _on_music_toggle():
	BgmManager.toggle()
	_update_music_btn()

func _update_music_btn():
	$MusicBtn.text = "🔊" if BgmManager.is_enabled else "🔇"

func _on_quit():
	get_tree().quit()

# RPC回调：主机通知客机进入选人界面
func network_enter_select_school():
	GameData.is_dual_mode = true
	get_tree().change_scene_to_file("res://scenes/select_school.tscn")
