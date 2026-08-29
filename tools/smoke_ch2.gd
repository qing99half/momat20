extends SceneTree
# 二章四关装载冒烟:LevelLoader 构建 ch2_lv1~4,验证玩家/日记桌/台灯/相机装配+出生朝向。
# 用法: godot --headless --path <项目根> --script tools/smoke_ch2.gd


func _initialize() -> void:
	var Loader = load("res://src/levels/LevelLoader.gd")
	var failures: Array[String] = []
	for lv in ["ch2_lv1", "ch2_lv2", "ch2_lv3", "ch2_lv4"]:
		var level = Loader.build("res://levels/%s.json" % lv)
		if level == null:
			failures.append("%s: build 返回 null" % lv)
			continue
		root.add_child(level)
		var player = level.find_child("Player", true, false)
		if player == null:
			failures.append("%s: 未生成玩家" % lv)
		else:
			var sp: Sprite2D = player.get_node("Sprite2D")
			if player.position.x > 1300 and not sp.flip_h:
				failures.append("%s: 右半出生未面朝左" % lv)
		var desk = level.find_child("diary_desk*", true, false)
		if desk == null:
			failures.append("%s: 缺日记桌" % lv)
		var conveyors := 0
		var lamps := 0
		for c in level.get_children():
			if c.name.begins_with("conveyor"):
				conveyors += 1
			elif c.name.begins_with("lamp"):
				lamps += 1
		if lamps != 1:
			failures.append("%s: 台灯数=%d,期望1" % [lv, lamps])
		print("[ch2] %s 装配完成: 传送带%d 台灯%d" % [lv, conveyors, lamps])
		level.queue_free()
	if failures.is_empty():
		print("[ch2] PASS")
	else:
		for x in failures:
			print("[ch2] FAIL: " + x)
	quit(0 if failures.is_empty() else 1)
