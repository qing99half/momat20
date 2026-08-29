extends SceneTree

func _initialize() -> void:
	var level: Node2D = LevelLoader.build("res://levels/ch1_lv2.json")
	root.add_child(level)
	var cam := Camera2D.new()
	cam.position = Vector2(320, 180)
	root.add_child(cam)
	cam.make_current()
	_run(level)

func _run(level: Node2D) -> void:
	for i in range(60):
		await process_frame
	var bg := level.find_child("ParallaxBackground", true, false)
	if bg:
		print("[iso] ParallaxBackground 在树内=%s visible=%s layer=%d" % [bg.is_inside_tree(), bg.visible, bg.layer])
		var far := bg.find_child("Far", true, false)
		if far:
			print("[iso] Far层 子节点=%d mirroring=%s" % [far.get_child_count(), far.motion_mirroring])
	else:
		print("[iso] FAIL: 关卡内无 ParallaxBackground")
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://tools/_smoke_bg2.png")
	quit(0)
