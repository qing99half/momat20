extends SceneTree
# 游戏冒烟测试(窗口模式):装载 MainGame → 等 2 秒 → 截图 + 打印玩家状态。
# 用法: godot --path <项目根> --script tools/smoke_game.gd


func _initialize() -> void:
	var mg := (load("res://src/MainGame.tscn") as PackedScene).instantiate()
	root.add_child(mg)
	_run()


func _run() -> void:
	for i in range(120):
		await process_frame
	var player := root.find_child("Player", true, false)
	if player:
		print("[冒烟] 玩家位置: (%.1f, %.1f) 在地面=%s" % [player.position.x, player.position.y, player.is_on_floor()])
	else:
		print("[冒烟] FAIL: 未找到玩家")
	# 动态访问 Conductor,避免 --script 入口静态编译其依赖链(autoload 未注册)
	var conductor := root.find_child("Conductor", true, false)
	var looping: bool = false
	if conductor:
		looping = conductor.is_looping_enabled()
		print("[冒烟] 音乐状态值=%s 循环已开=%s" % [conductor.get("state"), looping])
	else:
		print("[冒烟] FAIL: 未找到 Conductor")
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://tools/smoke_game.png")
	print("[冒烟] 截图已存 tools/smoke_game.png")
	quit(0 if player != null and conductor != null and looping else 1)
