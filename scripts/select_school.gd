extends CanvasLayer

# ==============================
# 角色选择界面（杀戮尖塔风格）
# 全屏立绘背景 + 底部头像栏
# ==============================

var hero_ids := ["yunzhi", "linfeng", "yexiao", "moyao", "huiming", "xuanweng"]
var current_index := 0
var _pick_count: int = 0  # 双人选择计数: 0=未选, 1=P1, 2=P2
var _p1_school: String = ""  # P1选的门派

var passive_descs = {
	"huiming": "【少林·禅意】每获得1层禅意，回复1点生命",
	"linfeng": "【武当·剑意】每消耗1层剑意，造成1点额外伤害",
	"yunzhi": "【逍遥·奇策】每回合第一次出牌，费用-1",
	"moyao": "【待定】",
	"xuanweng": "【待定】",
	"yexiao": "【待定】"
}

var story_texts = {
	"huiming": "自幼出家少林，精研佛法与武学。\n以禅入武，以武证禅。",
	"linfeng": "自幼在山林中长大，与飞禽走兽为伍，\n从自然剑法中领悟了独特的武学之道。",
	"yunzhi": "逍遥派传人，云游四方，随性而为。\n看似散漫不羁，实则深藏不露。",
	"moyao": "墨门最后的传人，精通机关术与暗器。\n性格冷静，做事讲究效率。",
	"xuanweng": "隐居深山的奇人，精通奇门遁甲之术。\n看似疯癫，实则大智若愚。",
	"yexiao": "江湖上独来独往的浪客，出手狠辣。\n没人知道他的过去，只知道他很强。"
}

var school_names = {
	"shaolin": "少林", "wudang": "武当",
	"xiaoyao": "逍遥", "": "通用"
}


func _ready():
	_bind_avatars()
	_pick_count = 0
	show_hero(current_index)
	
	if GameData.is_dual_mode:
		$InfoPanel/CharName.text = "玩家1选择角色"
	
	$BottomBar/BackBtn.pressed.connect(_on_back)
	$BottomBar/ConfirmBtn.pressed.connect(_on_confirm)


# ==============================
# 绑定手动放置的头像
# ==============================

func _bind_avatars():
	var container = $BottomBar/AvatarContainer
	for i in range(container.get_child_count()):
		if i >= hero_ids.size():
			break
		var child = container.get_child(i)
		child.mouse_filter = 1
		child.gui_input.connect(_on_avatar_gui.bind(i))
		child.mouse_entered.connect(_on_avatar_enter.bind(i))
		child.mouse_exited.connect(_on_avatar_exit.bind(i))


func _on_avatar_gui(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_hero(index)


func _on_avatar_enter(index: int):
	var child = $BottomBar/AvatarContainer.get_child(index)
	if child and index != current_index:
		child.modulate = Color(0.7, 0.7, 0.7, 0.8)


func _on_avatar_exit(index: int):
	var child = $BottomBar/AvatarContainer.get_child(index)
	if child:
		if index == current_index:
			child.modulate = Color(1, 1, 1, 1)
		else:
			child.modulate = Color(0.5, 0.5, 0.5, 0.6)


# ==============================
# 显示角色（只切换可见性）
# ==============================

func show_hero(index: int):
	if index < 0 or index >= hero_ids.size():
		return
	
	current_index = index
	var hid = hero_ids[index]
	var data = GameData.character_data[hid]
	
	# 切换全屏立绘：隐藏所有，显示选中的
	for hid2 in hero_ids:
		var node = $PortraitContainer.get_node_or_null(hid2 + "_bg")
		if node:
			node.visible = (hid2 == hid)
	
	# 头像高亮
	var container = $BottomBar/AvatarContainer
	for i in range(container.get_child_count()):
		var child = container.get_child(i)
		if i == index:
			child.modulate = Color(1, 1, 1, 1)
		else:
			child.modulate = Color(0.5, 0.5, 0.5, 0.6)
	
	# 信息面板
	$InfoPanel/CharName.text = data.get("name", "")
	$InfoPanel/CharTitle.text = data.get("title", "")
	$InfoPanel/PassiveDesc.text = passive_descs.get(hid, "待定")
	$InfoPanel/StoryDesc.text = story_texts.get(hid, "")
	
	# 🐛 双人模式：仅 P1 选人时写 GameData.selected_character
	# _pick_count == 0 表示 P1 正在选，>=1 表示 P2 选择阶段
	if _pick_count == 0:
		GameData.selected_character = hid


# ==============================
# 确认
# ==============================

func _on_confirm():
	var hid = hero_ids[current_index]
	var data = GameData.character_data[hid]
	var school = data.get("school", "")
	
	if _pick_count == 0:
		# ── 玩家1选角色 ──
		GameData.selected_character = hid
		_pick_count = 1
		if school != "":
			_p1_school = school
			_after_p1_pick()
		else:
			_show_school_picker()
	elif _pick_count == 1 and GameData.is_dual_mode:
		# ── 玩家2选角色 ──
		GameData.selected_character_2 = hid
		_pick_count = 2
		if school != "":
			_start_dual_run(school)
		else:
			_show_school_picker()
	else:
		# ── 单人确认 ──
		GameData.selected_character = hid
		start_run(school)


func _show_school_picker():
	var old = get_node_or_null("SchoolPicker")
	if old:
		old.queue_free()
	
	var picker = Panel.new()
	picker.name = "SchoolPicker"
	picker.offset_left = 340
	picker.offset_top = 200
	picker.offset_right = 940
	picker.offset_bottom = 520
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.45, 0.35, 0.2, 1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	picker.add_theme_stylebox_override("panel", style)
	add_child(picker)
	
	var title = Label.new()
	title.text = "选择你的门派"
	title.position = Vector2(0, 30)
	title.size = Vector2(600, 40)
	title.horizontal_alignment = 1
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.4, 1))
	title.add_theme_font_size_override("font_size", 22)
	picker.add_child(title)
	
	var schools = ["shaolin", "wudang", "xiaoyao"]
	var school_info = {
		"shaolin": {"name": "少林", "desc": "罗汉拳 · 铁布衫", "color": Color(1, 0.85, 0.3, 1)},
		"wudang":  {"name": "武当", "desc": "太极拳 · 柔云剑", "color": Color(0.6, 0.8, 1, 1)},
		"xiaoyao": {"name": "逍遥", "desc": "北冥神掌 · 凌波微步", "color": Color(0.7, 0.5, 1, 1)}
	}
	
	var i = 0
	for sk in schools:
		var info = school_info[sk]
		var btn = Button.new()
		btn.position = Vector2(80, 100 + i * 100)
		btn.size = Vector2(440, 80)
		btn.text = "%s\n%s" % [info["name"], info["desc"]]
		btn.add_theme_color_override("font_color", info["color"])
		btn.add_theme_font_size_override("font_size", 18)
		btn.autowrap_mode = 1
		btn.pressed.connect(_on_pick_school.bind(sk, picker))
		picker.add_child(btn)
		i += 1


func _on_pick_school(school: String, picker: Panel):
	picker.queue_free()
	if _pick_count == 1:
		_p1_school = school
		if GameData.is_dual_mode:
			_after_p1_pick()
		else:
			start_run(school)
	elif _pick_count == 2:
		_start_dual_run(school)
	else:
		start_run(school)


func _after_p1_pick():
	"""P1选完角色+门派，界面切到P2选择"""
	if GameData.is_dual_mode:
		$InfoPanel/CharName.text = "玩家2选择角色"
		$InfoPanel/PassiveDesc.text = "请选择第二位角色"
		$InfoPanel/StoryDesc.text = ""
		var saved = GameData.selected_character
		current_index = 0
		show_hero(0)
		GameData.selected_character = saved
	else:
		start_run(_p1_school)


func _start_dual_run(school_p2: String):
	"""双人：两人都选完，开战"""
	GameData.new_dual_run()
	
	# 局域网：通知客机进游戏
	if NetworkManager.is_lan and NetworkManager.is_host:
		NetworkManager.rpc("sync_start_game")
	
	# 玩家1的门派牌
	match _p1_school:
		"shaolin":
			GameData.add_card("sl_fist"); GameData.add_card("sl_iron")
		"wudang":
			GameData.add_card("wd_taiji"); GameData.add_card("wd_soft")
		"xiaoyao":
			GameData.add_card("xy_beiming"); GameData.add_card("xy_lingbo")
	
	# 玩家2的门派牌
	match school_p2:
		"shaolin":
			GameData.add_card_to_player2("sl_fist"); GameData.add_card_to_player2("sl_iron")
		"wudang":
			GameData.add_card_to_player2("wd_taiji"); GameData.add_card_to_player2("wd_soft")
		"xiaoyao":
			GameData.add_card_to_player2("xy_beiming"); GameData.add_card_to_player2("xy_lingbo")
	
	# 启动双人战斗场景
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func start_run(school: String):
	GameData.new_run()
	GameData.selected_character = hero_ids[current_index]
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


func _on_back():
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
