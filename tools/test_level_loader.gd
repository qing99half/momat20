extends SceneTree
# LevelLoader 冒烟测试:造一个 JSON,验证模块/玩家/相机边界都正确装配。
# 用法: godot --headless --path <项目根> --script tools/test_level_loader.gd


func _initialize() -> void:
	var data := {
		"level_id": "_test",
		"modules": [
			{"id": "platform_h5", "px": 0, "py": 160, "params": {"w": 5, "h": 1}},
			{"id": "platform_v2", "px": 1000, "py": 120, "params": {"w": 1, "h": 2}},
			{"id": "pendulum", "px": 500, "py": 40, "params": {}},
			{"id": "lamp", "px": 60, "py": 160, "params": {}},
			{"id": "diary_desk", "px": 1250, "py": 160, "params": {}},
			{"id": "spawn", "px": 80, "py": 160, "params": {}},
		],
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://levels/"))
	var f := FileAccess.open("res://levels/_test.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

	var level := LevelLoader.build("res://levels/_test.json")
	var failures: Array[String] = []

	if level == null:
		failures.append("build 返回 null")
	else:
		root.add_child(level)
		var player := level.find_child("Player", true, false)
		if player == null:
			failures.append("未生成玩家")
		elif player.position != Vector2(80, 160):
			failures.append("玩家出生点错误: %s" % player.position)
		var platforms := 0
		var traps := 0
		for c in level.get_children():
			if c is PlatformModule:
				platforms += 1
			elif c is Area2D:
				traps += 1  # 摆锤+台灯+日记桌
		if platforms != 2:
			failures.append("平台数=%d,期望2" % platforms)
		if traps != 3:
			failures.append("Area2D模块数=%d,期望3" % traps)
		var cam := player.get_node("Camera2D") as Camera2D if player else null
		if cam and cam.limit_right != 2600:
			failures.append("相机右边界应全局固定2600,实得: %d" % cam.limit_right)

	if failures.is_empty():
		print("[装载器] PASS")
	else:
		for x in failures:
			print("[装载器] FAIL: " + x)
	quit(0 if failures.is_empty() else 1)
