# =============================================
# 图集切分辅助工具
# 用法：把 ui2.png 切成多张小图，每张用一个 Sprite2D 显示
# 在 Godot 编辑器里调 region_rect 的 x/y/w/h 就可以了
# =============================================

extends Node2D

# 引用 ui2.png 图集
@onready var atlas = preload("res://assets/images/ui/ui2.png")

# ========== 配置区：在这里填每个小图的坐标 ==========
# 格式：名字 = { pos = Vector2(x, y), size = Vector2(w, h) }
# x = 从左到右的像素位置
# y = 从上到下的像素位置
# w = 宽度
# h = 高度

var slices = {
	# ---- 示例（坐标需要你调）----
	"panel_bg": { pos = Vector2(100, 100), size = Vector2(300, 200) },
	"btn_normal": { pos = Vector2(100, 350), size = Vector2(150, 50) },
	"btn_hover": { pos = Vector2(300, 350), size = Vector2(150, 50) },
	"icon_sword": { pos = Vector2(500, 100), size = Vector2(64, 64) },
	"icon_shield": { pos = Vector2(600, 100), size = Vector2(64, 64) },
	"icon_heart": { pos = Vector2(700, 100), size = Vector2(64, 64) },
	"deco_corner": { pos = Vector2(500, 300), size = Vector2(40, 40) },
}

# ========== 生成节点 ==========

func _ready():
	# 遍历配置，为每个切片创建一个 Sprite2D
	for name in slices:
		var slice = slices[name]
		make_slice(name, slice.pos, slice.size)

# 创建单个切片的 Sprite2D
func make_slice(name: String, pos: Vector2, size: Vector2):
	var spr = Sprite2D.new()
	spr.name = name
	spr.texture = atlas
	spr.region_enabled = true          # 启用区域裁剪
	spr.region_rect = Rect2(pos, size) # 裁剪区域
	spr.position = Vector2(100, 100)   # 临时位置，后面手动拖
	add_child(spr)
	print("创建了 [" + name + "] 位置:(" + str(pos.x) + "," + str(pos.y) + ") 尺寸:" + str(size.x) + "x" + str(size.y))
