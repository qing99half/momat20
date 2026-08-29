extends SceneTree
# 指定关卡冒烟:--script tools/smoke_level.gd -- <level_id> (如 ch1_lv2)
# 装 MainGame → 等 2 秒 → 打印玩家状态 + 截图 tools/smoke_<level_id>.png


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame  # autoload 在 _initialize 之后才挂到 root,等一帧再取
	var args := OS.get_cmdline_user_args()
	var level_id := "ch1_lv1"
	if args.size() > 0:
		level_id = args[0]
	var gs := root.get_node_or_null("/root/GameState")
	if gs:
		gs.set("editor_level_path", "res://levels/%s.json" % level_id)
	else:
		print("[冒烟:%s] WARN: 未找到 GameState,走默认关" % level_id)
	var mg := (load("res://src/MainGame.tscn") as PackedScene).instantiate()
	root.add_child(mg)
	for i in range(120):
		await process_frame
	var player := root.find_child("Player", true, false)
	if player:
		print("[冒烟:%s] 玩家 (%.1f, %.1f) 在地面=%s" % [level_id, player.position.x, player.position.y, player.is_on_floor()])
	else:
		print("[冒烟:%s] FAIL: 未找到玩家" % level_id)
	# 统计贴图命中:带 skin 的陷阱数 / 带贴图的平台数
	var skins := 0
	var texed := 0
	for n in root.find_children("*", "TrapBase", true, false):
		if str(n.get_meta("skin_texture", "")) != "":
			skins += 1
	for n in root.find_children("*", "PlatformModule", true, false):
		if n.tex_path != "":
			texed += 1
	print("[冒烟:%s] 陷阱换皮=%d 平台贴图=%d" % [level_id, skins, texed])
	var img := root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("res://tools/smoke_%s.png" % level_id)
	else:
		print("[冒烟:%s] 无头模式无帧缓冲,跳过截图" % level_id)
	quit(0 if player != null else 1)
