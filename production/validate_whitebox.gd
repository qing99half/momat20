extends SceneTree
# 白盒自动验收脚本(任务1用,非游戏内容):无头模式驱动真实物理,
# 自动按键实测:全速耗时/刹停/跳跃距离与净空/3格缺口落到1格台。
# 运行: godot --headless --path <proj> --script production/validate_whitebox.gd

var scene: Node2D
var player: CharacterBody2D
var phase := 0
var t := 0.0
var accel_t0 := -1.0
var full_speed_t := -1.0
var stop_t0 := -1.0
var stop_x := 0.0
var jump_x := 0.0
var jump_y := 0.0
var peak_y := 0.0
var seen_air := false


func _initialize() -> void:
	var packed: PackedScene = load("res://tests/whitebox_measure.tscn")
	scene = packed.instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	print("== 白盒自动验收开始 ==")


func _physics_process(delta: float) -> bool:
	t += delta
	if t > 20.0:
		print("FAIL: 超时,流程卡住")
		quit(1)
		return true
	match phase:
		0:  # 起步加速到全速
			Input.action_press("ui_right")
			if accel_t0 < 0.0:
				accel_t0 = t
			if full_speed_t < 0.0 and absf(player.velocity.x) >= 89.9:
				full_speed_t = t
				print("全速耗时 %.3fs(目标≈0.10s=6帧)" % (full_speed_t - accel_t0))
			if player.position.x >= 60.0:
				Input.action_release("ui_right")
				stop_t0 = t
				stop_x = player.position.x
				phase = 1
		1:  # 刹停
			if absf(player.velocity.x) < 0.5:
				print("刹停耗时 %.3fs 滑行 %.2fpx(目标0.05s=3帧)" % [t - stop_t0, player.position.x - stop_x])
				phase = 2
		2:  # 重新加速,在 x=104 起跳,跨3格缺口(120~144),落1格台(144~152)
			Input.action_press("ui_right")
			if player.position.x >= 104.0:
				Input.action_press("ui_accept")
				jump_x = player.position.x
				jump_y = player.position.y
				peak_y = player.position.y
				phase = 3
		3:
			Input.action_press("ui_right")
			peak_y = minf(peak_y, player.position.y)
			if not player.is_on_floor():
				seen_air = true
			elif seen_air:
				var dist := player.position.x - jump_x
				var h := jump_y - peak_y
				print("跳跃: 距离 %.1fpx(%.2f格) 净空 %.1fpx(%.2f格)" % [dist, dist / 8.0, h, h / 8.0])
				var ok: bool = player.position.x >= 144.0 and player.position.x <= 152.0 and absf(player.position.y - 144.0) < 1.5
				print("跨过3格缺口并落在1格台(144~152): %s(落点 x=%.1f y=%.1f)" % ["PASS" if ok else "FAIL", player.position.x, player.position.y])
				print("== 白盒自动验收结束 ==")
				phase = 4
				quit(0 if ok else 1)
				return true
	return false
