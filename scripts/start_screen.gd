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
	_build_volume_ui()


## 音量设置（音乐/音效独立滑块，代码创建避免改场景）
func _build_volume_ui():
	var title := Label.new()
	title.text = "── 设 置 ──"
	title.position = Vector2(20, 452)
	title.size = Vector2(140, 20)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.8))
	add_child(title)

	var mk_row := func(label_text: String, y: float, getter: Callable, setter: Callable):
		var lb := Label.new()
		lb.text = label_text
		lb.position = Vector2(20, y)
		lb.size = Vector2(110, 18)
		lb.add_theme_font_size_override("font_size", 12)
		lb.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85, 0.9))
		add_child(lb)

		var sd := HSlider.new()
		sd.position = Vector2(128, y)
		sd.size = Vector2(100, 18)
		sd.min_value = 0.0
		sd.max_value = 100.0
		sd.step = 5.0
		sd.value = float(getter.call()) * 100.0
		sd.value_changed.connect(func(v: float): setter.call(v / 100.0))
		sd.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_child(sd)

	mk_row.call("音乐音量", 478, func(): return BgmManager.music_volume,
		func(v): BgmManager.set_music_volume(v))
	mk_row.call("音效音量", 502, func(): return BgmManager.sfx_volume,
		func(v): BgmManager.set_sfx_volume(v))


func _on_start_hover():
	var tw = create_tween()
	tw.tween_property($BtnStart, "scale", _start_orig_scale * 1.1, 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_start_unhover():
	var tw = create_tween()
	tw.tween_property($BtnStart, "scale", _start_orig_scale, 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_start():
	GameData.start_run(false)
	if GameData.has_save():
		GameData.delete_save()
	get_tree().change_scene_to_file("res://scenes/select_school.tscn")

func _on_dual():
	GameData.start_run(true)
	if GameData.has_save():
		GameData.delete_save()
	get_tree().change_scene_to_file("res://scenes/select_school.tscn")

func _on_continue():
	if not GameData.has_save():
		_toast("没有旧存档")
		return

	if not GameData.load_game():
		_toast("存档读取失败")
		return

	# 模式标志由存档恢复，不再硬编码成单人（A4）
	GameData.start_run(GameData.is_dual_mode, true)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

	if NetworkManager.is_host and not NetworkManager.p2_peer_id:
		_toast("等待P2重连...")

func _on_host():
	if NetworkManager.host_game():
		GameData.start_run(true)
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
	# 只有重连场景才需要 loading_save 标记
	GameData.start_run(true, NetworkManager.p2_reconnecting)
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
	# 测试牌组走单人口径，必须显式重置模式。
	# 原先这里漏设，玩过双人之后点进来，is_dual_mode 会残留 true（A3）
	GameData.start_run(false)
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
	GameData.start_run(true)
	get_tree().change_scene_to_file("res://scenes/select_school.tscn")
