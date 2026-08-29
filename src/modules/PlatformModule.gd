class_name PlatformModule
extends StaticBody2D
# 平台模块(地图编辑器):规格=横向1~5格×1格高 / 纵向1格宽×2~3格高。
# 原点=左上角,按格吸附(1格=8px)。白盒期为色块;换美术时只换 _build_visual。

const CELL := 8.0
const COLOR_FILL := Color(0.34, 0.36, 0.44)     # 平台面
const COLOR_TOP := Color(0.55, 0.58, 0.68)      # 顶面高光(读得出"可站")

var w_cells := 3
var h_cells := 1


func set_cells(w: int, h: int) -> void:
	w_cells = clampi(w, 1, 5)
	h_cells = clampi(h, 1, 3)
	if is_node_ready():
		_rebuild()


func _ready() -> void:
	collision_layer = 1  # 约定:角色Layer=1,平台与角色同层供站立
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var size := Vector2(w_cells * CELL, h_cells * CELL)
	# 碰撞:整矩形(白盒期美术即碰撞,换美术后按附录E再收)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	add_child(shape)
	# 视觉:底色 + 顶面高光条
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	body.color = COLOR_FILL
	add_child(body)
	var top := Polygon2D.new()
	top.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, 2.0), Vector2(0, 2.0)])
	top.color = COLOR_TOP
	add_child(top)
