extends Node2D

var _start_orig_scale: Vector2
var _quit_orig_scale: Vector2

func _ready():
	$BtnStart.pressed.connect(_on_start)
	$BtnStart.mouse_entered.connect(_on_start_hover)
	$BtnStart.mouse_exited.connect(_on_start_unhover)
	$TestBtn.pressed.connect(_on_test)
	$QuitBtn.pressed.connect(_on_quit)
	$QuitBtn.mouse_entered.connect(_on_quit_hover)
	$QuitBtn.mouse_exited.connect(_on_quit_unhover)
	
	_start_orig_scale = $BtnStart.scale
	_quit_orig_scale = $QuitBtn.scale


func _on_start_hover():
	var tw = create_tween()
	tw.tween_property($BtnStart, "scale", _start_orig_scale * 1.1, 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_start_unhover():
	var tw = create_tween()
	tw.tween_property($BtnStart, "scale", _start_orig_scale, 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_start():
	get_tree().change_scene_to_file("res://scenes/select_school.tscn")


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


func _on_quit():
	get_tree().quit()
