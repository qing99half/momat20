extends SceneTree
# 传送带惯性测试:离带后逐帧采样空中vx(应恒≈112.5),落地30帧后vx应≈0

func _initialize() -> void:
	var f := FileAccess.open("res://levels/_inertia_test.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"level_id":"_inertia_test","modules":[
		{"id":"conveyor","px":200.0,"py":300.0,"params":{}},
		{"id":"platform_h5","px":300.0,"py":340.0,"params":{"w":5.0,"h":1.0,"style":"platform"}},
		{"id":"spawn","px":150.0,"py":270.0,"params":{}}
	]}))
	f.close()
	var level: Node2D = LevelLoader.build("res://levels/_inertia_test.json")
	root.add_child(level)
	_run(level)

func _run(level: Node2D) -> void:
	var player := level.find_child("Player", true, false)
	var left := false
	var air_samples: Array[float] = []
	var landed := false
	var land_frame := 0
	for i in range(300):
		await physics_frame
		if not left and not player.is_on_floor() and player.position.x > 295.0:
			left = true
		if left and not landed and not player.is_on_floor():
			air_samples.append(player.velocity.x)
		if left and not landed and player.is_on_floor():
			landed = true
			land_frame = i
		if landed and i >= land_frame + 30:
			break
	print("[inertia] 空中vx样本: %s" % str(air_samples))
	var final_vx: float = player.velocity.x
	print("[inertia] 落地30帧后 vx=%.1f (landed=%s)" % [final_vx, landed])
	var ok := landed and air_samples.size() >= 4
	if ok:
		for v in air_samples.slice(2):  # 跳过离带瞬间1-2帧过渡
			if v < 100.0 or v > 130.0:
				ok = false
		ok = ok and absf(final_vx) < 30.0
	print("[inertia] %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
