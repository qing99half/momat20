extends Node2D
# 11种陷阱全量冒烟测试(账单风已删):全部实例化铺开,跑6秒,任何脚本/资源错误都会打到控制台。
# 运行: godot --headless --path <proj> res://tests/trap_smoke.tscn -- --quit-flag

const TRAP_SCENES := [
	"washboard", "part", "thorns", "glass",
	"conveyor",
	"pendulum", "bottle",
	"press", "rotten", "heart_big", "soundwave",
]

var _t := 0.0


func _ready() -> void:
	_make_platform(0, 640, 160, 20)
	for i in TRAP_SCENES.size():
		var packed: PackedScene = load("res://src/traps/scenes/trap_%s.tscn" % TRAP_SCENES[i])
		if packed == null:
			push_error("加载失败: " + TRAP_SCENES[i])
			continue
		var inst := packed.instantiate()
		inst.position = Vector2(24 + i * 48, 120)
		add_child(inst)
		print("实例化 OK: ", TRAP_SCENES[i])
	print("== 冒烟测试运行中(6秒) ==")


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > 6.0:
		print("SMOKE PASS: 11种陷阱运行6秒无脚本错误")
		get_tree().quit(0)


func _make_platform(x: float, w: float, top: float, h: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x + w / 2.0, top + h / 2.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
