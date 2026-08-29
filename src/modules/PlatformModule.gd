class_name PlatformModule
extends StaticBody2D
# 平台/地面模块(地图编辑器):
#   平台 platform = 横向1~5格×¼格厚(20×5) / 纵向¼格厚×2~3格高(5×h格)(悬浮薄板,可站)
#   地面 ground   = 横向1~5格×4格高(实心方块,从落脚点一直填到画面底)
# 原点=左上角,按格吸附(1格=20px)。白盒期为色块;换美术时只换 _rebuild 视觉部分。

const CELL := 20.0
const PLAT_THICK := 5.0  # 平台厚度=¼格(策划定:20×5薄板,地面不受影响)
# 平台:冷灰,顶面高光(读得出"悬浮可站")
const PLAT_FILL := Color(0.34, 0.36, 0.44)
const PLAT_TOP := Color(0.55, 0.58, 0.68)
# 地面:暖褐实心,顶面土黄(读得出"踏实的地")
const GROUND_FILL := Color(0.30, 0.24, 0.19)
const GROUND_TOP := Color(0.48, 0.40, 0.30)

var w_cells := 3
var h_cells := 1
var style := "platform"  # "platform" | "ground"


func configure(w: int, h: int, p_style: String = "platform") -> void:
	style = p_style
	w_cells = clampi(w, 1, 5)
	h_cells = clampi(h, 1, 4)
	if is_node_ready():
		_rebuild()


func set_cells(w: int, h: int) -> void:
	configure(w, h, style)


func _ready() -> void:
	collision_layer = 1  # 约定:角色Layer=1,平台与地面同层供站立
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var size := Vector2(w_cells * CELL, h_cells * CELL)
	if style == "platform":
		if h_cells == 1:
			size.y = PLAT_THICK  # 横平台:半格厚薄板
		elif w_cells == 1:
			size.x = PLAT_THICK  # 竖平台:半格厚薄板
	# 碰撞:整矩形(白盒期美术即碰撞,换美术后按附录E再收)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	add_child(shape)
	# 视觉:底色 + 顶面条(平台=高光,地面=土层)
	var fill := GROUND_FILL if style == "ground" else PLAT_FILL
	var top_color := GROUND_TOP if style == "ground" else PLAT_TOP
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	body.color = fill
	add_child(body)
	var top_h := 5.0 if style == "ground" else 2.0  # 薄板高光条2px(板才5px厚,5px条会铺满)
	var top := Polygon2D.new()
	top.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, top_h), Vector2(0, top_h)])
	top.color = top_color
	add_child(top)
