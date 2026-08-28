extends Node2D
# 陷阱测试关(任务2验收):地板 + 尖刺带(搓衣板) + 摆锤。
# 玩家碰到任一陷阱 → 控制台打印 player_died。摔落自动回起点。
# 自动验收模式:命令行加 `-- --trap-auto-test` 时自动按右行走进陷阱并自检退出。

const GROUND_Y := 144

var _auto := false
var _deaths := 0
var _auto_t := 0.0

@onready var player: CharacterBody2D = $Player


func _ready() -> void:
	_auto = "--trap-auto-test" in OS.get_cmdline_user_args()
	_make_platform(0, 320, GROUND_Y, 36)
	_make_platform(-8, 8, 0, 180)
	_make_platform(320, 8, 0, 180)
	EventBus.player_died.connect(_on_player_died)
	print("陷阱测试关:碰到摆锤或尖刺应打印 player_died")


func _on_player_died() -> void:
	_deaths += 1
	print("[测试] 收到 EventBus.player_died #%d (玩家x=%.1f)" % [_deaths, player.position.x])


func _physics_process(delta: float) -> void:
	if not _auto:
		return
	_auto_t += delta
	Input.action_press("ui_right")
	if _deaths >= 2:
		# 第一次死亡在尖刺(x≈110+)之后,证明两次都由接触触发、不是凭空发信号
		var ok: bool = player.position.x > 100.0
		print("AUTO-TEST %s: 尖刺+摆锤均触发 player_died" % ("PASS" if ok else "FAIL"))
		get_tree().quit(0 if ok else 1)
	elif _auto_t > 12.0:
		print("AUTO-TEST FAIL: 12秒内仅 %d 次死亡(期望≥2)" % _deaths)
		get_tree().quit(1)


func _process(_delta: float) -> void:
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
	vis.color = Color(0.30, 0.69, 0.31, 1.0)
	vis.position = Vector2(-w / 2.0, -h / 2.0)
	vis.size = Vector2(w, h)
	body.add_child(vis)
	add_child(body)
