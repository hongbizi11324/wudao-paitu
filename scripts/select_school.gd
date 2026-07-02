extends Node2D

var selected_char_id: String = ""

var chara_nodes = {
	"huiming": "CharaHuiMing",
	"linfeng": "CharaLinFeng",
	"yunzhi": "CharaYunZhi",
	"moyao": "CharaMoYao",
	"xuanweng": "CharaXuanWeng",
	"yexiao": "CharaYeXiao"
}

var passive_descs = {
	"huiming": "【待定】少林系被动",
	"linfeng": "【待定】武当系被动",
	"yunzhi": "【待定】逍遥系被动",
	"moyao": "【待定】通用被动",
	"xuanweng": "【待定】通用被动",
	"yexiao": "【待定】通用被动"
}

func _ready():
	for char_id in chara_nodes:
		var btn = get_node(chara_nodes[char_id])
		btn.pressed.connect(_on_chara_clicked.bind(char_id))
	
	$BackBtn.pressed.connect(_on_back)
	$BackBtn.visible = true


func _on_chara_clicked(char_id: String):
	selected_char_id = char_id
	
	var data = GameData.character_data[char_id]
	$Title.text = data["name"] + " - " + data["title"]
	$Subtitle.text = data["desc"]
	$PassiveLabel.text = "被动能力："
	$DescLabel.text = passive_descs[char_id]
	
	for cid in chara_nodes:
		var btn = get_node(chara_nodes[cid])
		var label = get_node(chara_nodes[cid] + "Label")
		if cid == char_id:
			btn.modulate = Color(1, 1, 1, 1)
			label.modulate = Color(1, 1, 1, 1)
		else:
			btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
			label.modulate = Color(0.5, 0.5, 0.5, 0.7)
	
	GameData.selected_character = char_id
	_show_school_select()


func _show_school_select():
	for cid in chara_nodes:
		get_node(chara_nodes[cid]).visible = false
		get_node(chara_nodes[cid] + "Label").visible = false
	
	$Subtitle.visible = false
	$PassiveLabel.visible = false
	$DescLabel.visible = false
	
	$Title.text = "选择你的门派"
	
	if not has_node("BtnShaolin"):
		var btn_shaolin = Button.new()
		btn_shaolin.name = "BtnShaolin"
		btn_shaolin.position = Vector2(380, 280)
		btn_shaolin.size = Vector2(160, 200)
		btn_shaolin.text = "少林\n\n罗汉拳\n铁布衫"
		btn_shaolin.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
		btn_shaolin.add_theme_font_size_override("font_size", 18)
		btn_shaolin.autowrap_mode = 1
		add_child(btn_shaolin)
		btn_shaolin.pressed.connect(_on_shaolin)
		
		var btn_wudang = Button.new()
		btn_wudang.name = "BtnWudang"
		btn_wudang.position = Vector2(560, 280)
		btn_wudang.size = Vector2(160, 200)
		btn_wudang.text = "武当\n\n太极拳\n柔云剑"
		btn_wudang.add_theme_color_override("font_color", Color(0.6, 0.8, 1, 1))
		btn_wudang.add_theme_font_size_override("font_size", 18)
		btn_wudang.autowrap_mode = 1
		add_child(btn_wudang)
		btn_wudang.pressed.connect(_on_wudang)
		
		var btn_xiaoyao = Button.new()
		btn_xiaoyao.name = "BtnXiaoyao"
		btn_xiaoyao.position = Vector2(740, 280)
		btn_xiaoyao.size = Vector2(160, 200)
		btn_xiaoyao.text = "逍遥\n\n北冥神掌\n凌波微步"
		btn_xiaoyao.add_theme_color_override("font_color", Color(0.7, 0.5, 1, 1))
		btn_xiaoyao.add_theme_font_size_override("font_size", 18)
		btn_xiaoyao.autowrap_mode = 1
		add_child(btn_xiaoyao)
		btn_xiaoyao.pressed.connect(_on_xiaoyao)
	else:
		$BtnShaolin.visible = true
		$BtnWudang.visible = true
		$BtnXiaoyao.visible = true


func start_run(school: String):
	GameData.new_run()
	if selected_char_id != "":
		GameData.selected_character = selected_char_id
	
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
	
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_shaolin():
	start_run("shaolin")

func _on_wudang():
	start_run("wudang")

func _on_xiaoyao():
	start_run("xiaoyao")

func _on_back():
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
