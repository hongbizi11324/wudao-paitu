class_name BattleFX
extends CanvasLayer

# ====================================================================
# BattleFX — 战斗表现层（纯 GDScript + Tween，不依赖外部素材）
#
# 职责：伤害/格挡/回血/内力飘字、受击闪白、屏幕闪红、节点抖动、
#       卡牌打出飞行动画、POWER/回合横幅（排队显示）。
#
# 定位：只做「表现」，不碰任何游戏状态。由 main.gd 在数值变化后调用。
# CardExecutor 保持纯逻辑，与表现层完全解耦。
# ====================================================================

var _banner_queue: Array = []
var _banner_busy: bool = false
var _flash_rect: ColorRect = null

const FONT_SIZE: int = 22
const OUTLINE_COLOR: Color = Color(0, 0, 0, 0.9)

# 颜色约定
const COLOR_DAMAGE: Color = Color(1.0, 0.30, 0.25, 1.0)     # 红：伤害
const COLOR_ARMOR_BREAK: Color = Color(1.0, 0.55, 0.2, 1.0) # 橙：破甲
const COLOR_BLOCK: Color = Color(0.45, 0.65, 1.0, 1.0)      # 蓝：格挡
const COLOR_HEAL: Color = Color(0.4, 1.0, 0.55, 1.0)        # 绿：回血
const COLOR_ENERGY: Color = Color(1.0, 0.85, 0.3, 1.0)      # 黄：内力
const COLOR_CHAN: Color = Color(1.0, 0.75, 0.4, 1.0)        # 禅意
const COLOR_JIANYI: Color = Color(0.6, 0.8, 1.0, 1.0)       # 剑意
const COLOR_INFO: Color = Color(0.85, 0.85, 0.95, 1.0)      # 白：信息
const COLOR_VICTORY: Color = Color(1.0, 0.85, 0.3, 1.0)     # 金：胜利/横幅


func _ready() -> void:
	layer = 60  # 高于所有游戏 UI


# ====================================================================
# 飘字
# ====================================================================

func float_text(pos: Vector2, text: String, color: Color = COLOR_INFO, font_size: int = FONT_SIZE) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 3)
	label.position = pos - Vector2(30, 10)
	label.z_index = 100
	add_child(label)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 48.0, 0.9) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(label.queue_free)


## 伤害飘字（大号）
func damage_text(pos: Vector2, amount: int, armor_broken: bool = false) -> void:
	float_text(pos, "-%d" % amount,
		COLOR_ARMOR_BREAK if armor_broken else COLOR_DAMAGE, 26)


# ====================================================================
# 受击反馈
# ====================================================================

## 目标闪白/闪红（modulate 高亮后恢复，保存原值）
func flash(node: CanvasItem, color: Color = Color(1.6, 1.6, 1.6, 1.0), duration: float = 0.16) -> void:
	if not is_instance_valid(node):
		return
	var orig: Color = node.modulate
	node.modulate = color
	var tw := create_tween()
	tw.tween_property(node, "modulate", orig, duration)


## 节点抖动（攻击/受击通用；Node2D 与 Control 均可，用鸭子类型）
func shake(node, intensity: float = 7.0, duration: float = 0.28) -> void:
	if not is_instance_valid(node):
		return
	var orig: Vector2 = node.position
	var tw := create_tween()
	var steps := 6
	for i in range(steps):
		tw.tween_property(node, "position",
			orig + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)),
			duration / float(steps))
	tw.tween_property(node, "position", orig, duration / float(steps))


## 全屏闪色（玩家受击时闪红）
func screen_flash(color: Color = Color(1, 0, 0), alpha: float = 0.22, duration: float = 0.3) -> void:
	if _flash_rect == null:
		_flash_rect = ColorRect.new()
		_flash_rect.color = Color(1, 0, 0, 0)
		_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_rect.z_index = 90
		add_child(_flash_rect)
	_flash_rect.color = Color(color.r, color.g, color.b, alpha)
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, duration)


# ====================================================================
# 卡牌打出飞行
# ====================================================================

## 从手牌位置飞出一张幻影卡到目标位置
func card_flight(from: Vector2, to: Vector2, data: CardData = null) -> void:
	var card_scene: PackedScene = load("res://scenes/card.tscn")
	if card_scene == null:
		return
	var card: ColorRect = card_scene.instantiate()
	# 手牌幻影：跳过 setup（避免读 .tres），直接铺类型色
	card.size = Vector2(90, 135)
	card.color = Color(0.95, 0.85, 0.5, 0.85)
	add_child(card)
	card.global_position = from - card.size / 2.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "global_position", to - card.size / 2.0, 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "rotation", deg_to_rad(12.0), 0.24)
	tw.tween_property(card, "scale", Vector2(0.55, 0.55), 0.24)
	tw.tween_property(card, "modulate:a", 0.5, 0.24)
	tw.chain().tween_callback(card.queue_free)


# ====================================================================
# 横幅（POWER 激活 / 回合切换 / 突破），同屏排队
# ====================================================================

func show_banner(text: String, subtitle: String = "", color: Color = COLOR_VICTORY) -> void:
	_banner_queue.append([text, subtitle, color])
	if not _banner_busy:
		_process_banner()


func _process_banner() -> void:
	if _banner_queue.is_empty():
		_banner_busy = false
		return
	_banner_busy = true
	var item: Array = _banner_queue.pop_front()
	var text: String = item[0]
	var subtitle: String = item[1]
	var color: Color = item[2]

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(420, 92)
	panel.position = Vector2((viewport_size.x - 420) / 2.0, viewport_size.y * 0.2)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.09, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var title := Label.new()
	title.text = text
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.offset_top = 10
	title.offset_bottom = 56
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", color)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 3)
	panel.add_child(title)

	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.anchor_right = 1.0
		sub.anchor_bottom = 1.0
		sub.offset_top = 48
		sub.offset_bottom = 82
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 16)
		sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 0.95))
		panel.add_child(sub)

	# 动画：上滑淡入 → 停留 → 上滑淡出
	panel.modulate.a = 0.0
	panel.position.y += 36.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.16)
	tw.parallel().tween_property(panel, "position:y", panel.position.y - 36.0, 0.16)
	tw.tween_interval(0.75)
	tw.tween_property(panel, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(panel, "position:y", panel.position.y - 30.0, 0.22)
	tw.tween_callback(panel.queue_free)
	tw.tween_callback(_process_banner)


# ====================================================================
# 胜利战斗统计面板
# ====================================================================

func show_stats_panel(stats: Dictionary) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(320, 196)
	panel.position = Vector2((viewport_size.x - 320) / 2.0, viewport_size.y * 0.40)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.09, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_VICTORY
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var title := Label.new()
	title.text = "—— 战 报 ——"
	title.anchor_right = 1.0
	title.offset_top = 8
	title.offset_bottom = 36
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", COLOR_VICTORY)
	panel.add_child(title)

	var lines: Array = [
		["战斗回合", "%d" % int(stats.get("turns", 0))],
		["打出卡牌", "%d 张" % int(stats.get("cards", 0))],
		["造成伤害", "%d" % int(stats.get("damage", 0))],
		["最大单次", "%d" % int(stats.get("max_hit", 0))],
		["获得格挡", "%d" % int(stats.get("block", 0))],
	]
	var y := 42
	for row in lines:
		var name_l := Label.new()
		name_l.text = str(row[0])
		name_l.position = Vector2(30, y)
		name_l.size = Vector2(130, 24)
		name_l.add_theme_font_size_override("font_size", 15)
		name_l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.88, 1))
		panel.add_child(name_l)

		var val_l := Label.new()
		val_l.text = str(row[1])
		val_l.position = Vector2(170, y)
		val_l.size = Vector2(120, 24)
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_l.add_theme_font_size_override("font_size", 15)
		val_l.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 1))
		panel.add_child(val_l)
		y += 28

	# 淡入停留淡出
	panel.modulate.a = 0.0
	var tw2 := create_tween()
	tw2.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw2.tween_interval(2.0)
	tw2.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw2.tween_callback(panel.queue_free)
