extends SceneTree
# 酒瓶发射器验证(无 Conductor 自由定时):发射口本体不动;弹体下坠 fall_distance 后 3s 消失。
# 用法: godot --headless --path <项目根> --script tools/test_bottle_fall.gd


func _initialize() -> void:
	var emitter := (load("res://src/traps/scenes/trap_bottle.tscn") as PackedScene).instantiate()
	root.add_child(emitter)
	_run(emitter)


func _run(emitter: Node2D) -> void:
	var failures: Array[String] = []
	var bottle: Node2D = null
	# 等发射(最多10秒;无头模式计时与帧率不同步,多留余量)
	for i in range(600):
		await process_frame
		for c in emitter.get_children():
			if c is Area2D:
				bottle = c
				break
		if bottle:
			break
	if bottle == null:
		failures.append("10秒内未发射弹体")
	else:
		var y0 := bottle.position.y
		var fell := 0.0
		for i in range(120):  # 2秒观察下坠
			await process_frame
			if is_instance_valid(bottle):
				fell = maxf(fell, bottle.position.y - y0)
		if fell < 30.0:
			failures.append("弹体下坠不足: %.1fpx(期望40)" % fell)
		# 等消失(3s存活+0.3s淡出,无头留足余量)
		var gone := false
		for i in range(600):
			await process_frame
			if not is_instance_valid(bottle):
				gone = true
				break
		if not gone:
			failures.append("弹体10秒内未消失")
	if emitter.position != Vector2.ZERO:
		failures.append("发射器本体移动了: %s" % emitter.position)

	if failures.is_empty():
		print("[酒瓶发射器] PASS(发射/下坠40px/3s消失/本体不动)")
	else:
		for x in failures:
			print("[酒瓶发射器] FAIL: " + x)
	quit(0 if failures.is_empty() else 1)
