extends SceneTree
# 酒瓶坠落验证(无 Conductor 自由定时回退):6秒内酒瓶应离开原点下落。
# 用法: godot --headless --path <项目根> --script tools/test_bottle_fall.gd


func _initialize() -> void:
	var b := (load("res://src/traps/scenes/trap_bottle.tscn") as PackedScene).instantiate()
	root.add_child(b)
	_run(b)


func _run(b: Node2D) -> void:
	var y0 := b.position.y
	var fell := false
	for i in range(360):  # 6秒:待命2s → 预警0.8s → 坠落
		await process_frame
		if b.position.y > y0 + 1.0:
			fell = true
	print("[酒瓶] 6秒内发生坠落=%s" % fell)
	print("[酒瓶] %s" % ("PASS" if fell else "FAIL"))
	quit(0 if fell else 1)
