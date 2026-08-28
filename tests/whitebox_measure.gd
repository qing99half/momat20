extends Node2D
# 白盒度量关(任务1):8×8格子网格 + 度量标注 + 验证平台组。
# 1格=8px,地面顶线 y=144,全程 y∈[0,180] 与正式游戏 320×180 视野一致。
# 平台布局(单位px, [x起点, 宽, 顶线y, 高]):
#   起点台 → 3格缺口(24px) → 1格台 → 连续小平台(2格台×3,2格缝)
#   → 4格缺口(最宽安全缺口) → 4格间距 → 5格间距 → 3格高台
#   → 撞角测试浮块(底边=地面上3格) → 斜坡 → 终点台

const GRID := 8
const GROUND_Y := 144

const PLATFORMS := [
	[0, 120, 144, 36],      # 起点平台
	[144, 8, 144, 36],      # 1格台(跳跃落点精度验证)
	[168, 16, 144, 36],     # 连续小平台 1
	[200, 16, 144, 36],     # 连续小平台 2
	[232, 16, 144, 36],     # 连续小平台 3
	[280, 80, 144, 36],     # 4格缺口(248~280)后
	[392, 16, 144, 36],     # 4格间距(360~392)
	[448, 96, 144, 36],     # 5格间距(408~448)后
	[560, 64, 120, 8],      # 3格高台(顶线120=地面-24px)
	[640, 250, 144, 36],    # 落地 + 撞角测试地面
	[760, 32, 104, 16],     # 撞角测试浮块(底边y=120=地面上3格)
	[1020, 252, 144, 36],   # 终点平台
	[-8, 8, 0, 180],        # 左墙
	[1272, 8, 0, 180],      # 右墙
]

const LABELS := [
	["白盒度量关  1格=8px  A/D移动 W或空格跳跃", Vector2(8, 14)],
	["红线=跳跃上限3.5格(28px)", Vector2(8, 116)],
	["3格缺口(24px)", Vector2(96, 100)],
	["1格台", Vector2(136, 62)],
	["连续小平台", Vector2(160, 100)],
	["4格缺口(最宽安全)", Vector2(228, 100)],
	["4格间距", Vector2(350, 62)],
	["5格间距", Vector2(402, 100)],
	["高台+3格", Vector2(546, 100)],
	["撞角测试(跳上浮块边缘)", Vector2(690, 86)],
	["斜坡", Vector2(924, 100)],
	["终点", Vector2(1040, 100)],
]

@onready var player: CharacterBody2D = $Player
@onready var cam: Camera2D = $Camera2D


func _ready() -> void:
	for p in PLATFORMS:
		_make_platform(p[0], p[1], p[2], p[3])
	# 斜坡:x 890~994 从地面(y≈144)爬升到 y≈115(中心942,132,长108,倾角-13.5°)
	_make_slope(942.0, 132.0, 108.0, -13.5)


func _process(_delta: float) -> void:
	# 摄像机水平跟随,垂直锁定(与任务5.4规则一致)
	cam.position = Vector2(clampf(player.position.x, 160.0, 1120.0), 90.0)
	# 摔出场地 → 回起点重试(白盒循环测试用)
	if player.position.y > 200.0:
		player.position = Vector2(16.0, GROUND_Y)
		player.velocity = Vector2.ZERO


func _make_platform(x: float, w: float, top: float, h: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x + w / 2.0, top + h / 2.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	body.add_child(shape)
	var vis := ColorRect.new()
	vis.color = Color(0.30, 0.69, 0.31, 1.0)  # 亮绿 #4CAF50,对齐 placeholder_tile_platform
	vis.position = Vector2(-w / 2.0, -h / 2.0)
	vis.size = Vector2(w, h)
	body.add_child(vis)
	add_child(body)


func _make_slope(cx: float, cy: float, length: float, deg: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(cx, cy)
	body.rotation_degrees = deg
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, 8.0)
	shape.shape = rect
	body.add_child(shape)
	var vis := ColorRect.new()
	vis.color = Color(0.24, 0.55, 0.25, 1.0)
	vis.position = Vector2(-length / 2.0, -4.0)
	vis.size = Vector2(length, 8.0)
	body.add_child(vis)
	add_child(body)


func _draw() -> void:
	# 8×8 格子网格(每5格加粗)
	var faint := Color(1, 1, 1, 0.07)
	var strong := Color(1, 1, 1, 0.18)
	for x in range(0, 1281, GRID):
		draw_line(Vector2(x, 0), Vector2(x, 180), strong if x % 40 == 0 else faint)
	for y in range(0, 181, GRID):
		draw_line(Vector2(0, y), Vector2(1280, y), strong if y % 40 == 0 else faint)
	# 跳跃高度标注线(3.5格=28px,顶线y=116)
	draw_line(Vector2(0, 116), Vector2(160, 116), Color(1, 0.2, 0.2, 0.9), 1.0)
	# 文字标注
	var font: Font = ThemeDB.fallback_font
	for label in LABELS:
		draw_string(font, label[1], label[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.85))
