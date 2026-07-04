extends Node2D

var _start_orig_scale: Vector2
var _quit_orig_scale: Vector2
var _continue_btn: Button


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
	
	# 有存档则显示"继续游戏"按钮
	if GameData.has_save():
		_continue_btn = Button.new()
		_continue_btn.text = "▶ 继续游戏"
		_continue_btn.size = Vector2(280, 50)
		_continue_btn.position = Vector2(
			get_viewport().size.x / 2 - 140,
			$BtnStart.position.y + 70
		)
		_continue_btn.pressed.connect(_on_continue)
		add_child(_continue_btn)


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
	# 加载存档 → 进入主场景（自动恢复地图）
	GameData.load_game()
	GameData.is_dual_mode = false
	GameData.loading_save = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")


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
