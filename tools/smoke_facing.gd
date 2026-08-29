extends SceneTree
# 朝向验证:玩家钉在出生点(避开关卡缺口/陷阱),分别按住→和←各 1 秒截图。
# 用法: godot --path <项目根> --script tools/smoke_facing.gd


func _initialize() -> void:
	var mg := (load("res://src/MainGame.tscn") as PackedScene).instantiate()
	root.add_child(mg)
	_run()


func _crop_save(player: Node2D, path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	# 游戏层 640×360 整数倍×2 铺满 1280×720:屏幕坐标 = 游戏坐标×2
	var cx := int(player.position.x * 2.0)
	var cy := int(player.position.y * 2.0)
	var r := Rect2i(maxi(cx - 120, 0), maxi(cy - 140, 0), 240, 180)
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(r).save_png(path)


func _run() -> void:
	for i in range(30):
		await process_frame
	var player := root.find_child("Player", true, false)
	if player == null:
		print("[朝向] FAIL: 未找到玩家")
		quit(1)
		return
	var pin: Vector2 = player.position
	Input.action_press("ui_right")
	for i in range(60):
		player.position = pin
		player.velocity = Vector2.ZERO
		await process_frame
	Input.action_release("ui_right")
	_crop_save(player, "res://tools/_facing_right.png")
	print("[朝向] 向右: flip_h=%s frame=%d" % [player.get_node("Sprite2D").flip_h, player.get_node("Sprite2D").frame])
	Input.action_press("ui_left")
	for i in range(60):
		player.position = pin
		player.velocity = Vector2.ZERO
		await process_frame
	Input.action_release("ui_left")
	_crop_save(player, "res://tools/_facing_left.png")
	print("[朝向] 向左: flip_h=%s frame=%d" % [player.get_node("Sprite2D").flip_h, player.get_node("Sprite2D").frame])
	print("[朝向] 截图: tools/_facing_right.png / tools/_facing_left.png")
	quit(0)
