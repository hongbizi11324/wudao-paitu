extends Node2D

func _ready():
	$BtnShaolin.pressed.connect(_on_shaolin)
	$BtnWudang.pressed.connect(_on_wudang)
	$BtnXiaoyao.pressed.connect(_on_xiaoyao)
	$BackBtn.pressed.connect(_on_back)


func start_run(school: String):
	GameData.new_run()
	# 添加门派起始牌
	match school:
		"shaolin":
			GameData.add_card("sl_fist")
			GameData.add_card("sl_iron")
		"wudang":
			GameData.add_card("wd_taiji")
			GameData.add_card("wd_soft")
		"xiaoyao":
			GameData.add_card("xy_beiming")
			GameData.add_card("xy_lingbo")
	# 生成地图并跳到地图选路
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_shaolin():
	start_run("shaolin")

func _on_wudang():
	start_run("wudang")

func _on_xiaoyao():
	start_run("xiaoyao")

func _on_back():
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
