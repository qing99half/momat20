extends Node2D
# 陷阱长廊(任务2逐个验收):12个陷阱各一个摊位,玩家从左走到右逐个经过。
# 死亡反馈可见:红闪 + 退回本摊位起点(正式死亡重生=任务4)。
# 自动验收模式:命令行加 `-- --trap-auto-test`,逐陷阱断言真实影响后退出。
#
# 影响断言:
#   致死(尖刺×4/摆锤/酒瓶/冲压/滴液/声波) → player_died
#   传送带 → 站立时被向右推;  账单风 → 被向左推
#   腐心平台 → 踩上1s碎裂,玩家坠落

const GROUND_Y := 144
# 各摊位起点(手动模式死亡回退点)
const CHECKPOINTS := [16.0, 270.0, 384.0, 432.0, 512.0, 592.0, 676.0, 752.0, 856.0]

const LABELS := [
	["陷阱长廊:逐个经过,验证每种影响", Vector2(8, 14)],
	["1搓衣板", Vector2(52, 100)], ["2零件", Vector2(104, 100)],
	["3荆棘", Vector2(152, 100)], ["4玻璃渣", Vector2(196, 100)],
	["5传送带(站上去被右推)", Vector2(252, 100)],
	["6账单风(向左推)", Vector2(352, 100)],
	["7摆锤", Vector2(424, 60)], ["8酒瓶", Vector2(504, 60)],
	["9冲压机", Vector2(584, 60)],
	["10腐心平台(踩上1s碎裂)", Vector2(644, 100)],
	["11巨心滴液", Vector2(736, 60)], ["12啼哭声波", Vector2(816, 60)],
]

var _auto := false
var _deaths := 0
var _t := 0.0
var _phase := 0
var _phase_t := 0.0
var _phase_x := 0.0

@onready var player: CharacterBody2D = $Player
@onready var cam: Camera2D = $Camera2D


func _ready() -> void:
	_auto = "--trap-auto-test" in OS.get_cmdline_user_args()
	# 地板:腐心平台处留坑(664~696)
	_make_platform(0, 664, GROUND_Y, 36)
	_make_platform(696, 420, GROUND_Y, 36)
	_make_platform(-8, 8, 0, 180)
	_make_platform(1108, 8, 0, 180)
	EventBus.player_died.connect(_on_player_died)
	print("陷阱长廊:12个陷阱摊位,致死陷阱碰到=红闪+回退;自动模式加 `-- --trap-auto-test`")


func _on_player_died() -> void:
	_deaths += 1
	print("[长廊] player_died #%d (x=%.1f)" % [_deaths, player.position.x])
	if not _auto:
		# 可见反馈:红闪 + 退回本摊位起点
		var sp: Sprite2D = player.get_node("Sprite2D")
		sp.modulate = Color(2.5, 0.4, 0.4)
		create_tween().tween_property(sp, "modulate", Color.WHITE, 0.4)
		var cp: float = CHECKPOINTS[0]
		for c in CHECKPOINTS:
			if c < player.position.x - 4.0:
				cp = c
		_teleport(cp, GROUND_Y)


func _teleport(x: float, y: float = GROUND_Y) -> void:
	player.position = Vector2(x, y)
	player.velocity = Vector2.ZERO


func _process(_delta: float) -> void:
	cam.position = Vector2(clampf(player.position.x, 160.0, 960.0), 90.0)
	if player.position.y > 200.0:  # 摔进腐心平台的坑
		_teleport(660.0)


# ---- 自动验收状态机 ----

func _physics_process(delta: float) -> void:
	if not _auto:
		return
	_t += delta
	_phase_t += delta
	if _t > 60.0:
		_fail("总超时60s")
	match _phase:
		0:  # 依次踩 4 条尖刺
			Input.action_press("ui_right")
			if _deaths >= 4:
				Input.action_release("ui_right")
				_pass("尖刺带×4(搓衣板/零件/荆棘/玻璃渣)全部致死")
				_teleport(270.0)
				_next(0.7)
		1:  # 传送带:站立不动应被右推
			if _phase_t >= 0.7:
				var dx := player.position.x - 270.0
				if dx > 8.0:
					_pass("传送带:站立被右推 %.1fpx" % dx)
					_teleport(384.0)
					_next(4.2)
				else:
					_fail("传送带推力不足 dx=%.1f" % dx)
		2:  # 账单风:应被向左推出风区
			if player.position.x < 384.0 - 6.0:
				_pass("账单风:被向左推 %.1fpx" % (384.0 - player.position.x))
				_teleport(432.0)
				_next(3.5)
			elif _phase_t >= 4.2:
				_fail("账单风无推力")
		3:  # 摆锤
			if _deaths >= 5:
				_pass("摆锤:扫中致死")
				_teleport(520.0)
				_next(4.5)
			elif _phase_t >= 3.5:
				_fail("摆锤未命中")
		4:  # 酒瓶坠落
			if _deaths >= 6:
				_pass("酒瓶:坠落途中致死")
				_teleport(600.0)
				_next(4.5)
			elif _phase_t >= 4.5:
				_fail("酒瓶未命中")
		5:  # 冲压机
			if _deaths >= 7:
				_pass("冲压机:下砸致死")
				_teleport(680.0, 137.0)
				_next(4.0)
			elif _phase_t >= 4.5:
				_fail("冲压机未命中")
		6:  # 腐心平台:踩上1s碎裂,玩家坠落
			if player.position.y > 152.0:
				_pass("腐心平台:踩后碎裂,玩家坠落")
				_teleport(760.0)
				_next(5.0)
			elif _phase_t >= 4.0:
				_fail("腐心平台未碎裂")
		7:  # 巨心滴液
			if _deaths >= 8:
				_pass("巨心滴液:液滴坠落致死")
				_teleport(856.0)
				_next(4.0)
			elif _phase_t >= 5.0:
				_fail("滴液未命中")
		8:  # 啼哭声波
			if _deaths >= 9:
				_pass("啼哭声波:声波环扩散致死")
				print("== 长廊自动验收全部 PASS(12/12) ==")
				get_tree().quit(0)
			elif _phase_t >= 4.0:
				_fail("声波未命中")


func _next(timeout: float) -> void:
	_phase += 1
	_phase_t = 0.0


func _pass(msg: String) -> void:
	print("  PASS 摊位%d: %s" % [_phase + 1, msg])


func _fail(msg: String) -> void:
	print("== 长廊自动验收 FAIL 摊位%d: %s ==" % [_phase + 1, msg])
	get_tree().quit(1)


func _make_platform(x: float, w: float, top: float, h: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x + w / 2.0, top + h / 2.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	body.add_child(shape)
	var vis := ColorRect.new()
	vis.color = Color(0.30, 0.69, 0.31, 1.0)
	vis.position = Vector2(-w / 2.0, -h / 2.0)
	vis.size = Vector2(w, h)
	body.add_child(vis)
	add_child(body)


func _draw() -> void:
	var faint := Color(1, 1, 1, 0.07)
	for x in range(0, 1113, 8):
		draw_line(Vector2(x, 0), Vector2(x, 180), faint)
	for y in range(0, 181, 8):
		draw_line(Vector2(0, y), Vector2(1112, y), faint)
	var font: Font = ThemeDB.fallback_font
	for label in LABELS:
		draw_string(font, label[1], label[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.85))
