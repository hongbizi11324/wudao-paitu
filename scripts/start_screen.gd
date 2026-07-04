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
	
	# "继续游戏"按钮
	_continue_btn.pressed.connect(_on_continue)
	
	# 局域网按钮
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
		# 显示提示
		var toast = Label.new()
		toast.text = "没有旧存档"
		toast.add_theme_font_size_override("font_size", 24)
		toast.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		toast.position = Vector2(540, 500)
		add_child(toast)
		var tw = create_tween()
		tw.tween_property(toast, "modulate", Color(1,1,1,0), 1.5).set_delay(1.0)
		tw.finished.connect(toast.queue_free)
		return
	
	# 加载存档 → 进入主场景（自动恢复地图）
	GameData.load_game()
	GameData.is_dual_mode = false
	GameData.loading_save = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_host():
	# 局域网主机
	if NetworkManager.host_game():
		GameData.is_dual_mode = true
		GameData.new_dual_run()
		get_tree().change_scene_to_file("res://scenes/select_school.tscn")


func _on_join():
	# 局域网加入
	var ip = $IpEdit.text.strip_edges()
	if ip.is_empty():
		_toast("请输入主机IP地址")
		return
	if NetworkManager.join_game(ip):
		# 连上后等种子同步
		NetworkManager.game_ready.connect(_on_network_ready)
		_toast("正在连接...")


func _on_network_ready():
	# 种子同步完成，进游戏
	GameData.is_dual_mode = true
	GameData.new_dual_run()
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
