extends SceneTree
# 编辑器冒烟测试(窗口模式):启动编辑器 → 模拟放置一个平台 → 保存 → 截图 → 退出。
# 用法: godot --path <项目根> --script tools/smoke_editor.gd


func _initialize() -> void:
	var ed := (load("res://src/editor/MapEditor.tscn") as PackedScene).instantiate()
	root.add_child(ed)
	_run(ed)


func _run(ed: Node2D) -> void:
	for i in range(60):
		await process_frame
	# 冷启动自动载入验证:默认关卡 ch1_lv1 有存档,启动后世界应非空
	var autoloaded: bool = ed._world.get_child_count() > 0
	print("[编辑器] 冷启动自动载入=%s (已有模块数=%d)" % [autoloaded, ed._world.get_child_count()])
	ed._clear_level()  # 清场后再验证放置/存档链路
	# 程序化放置:横平台5格 + 摆锤 + 出生点,验证放置/存档链路
	var e_plat := ModuleRegistry.get_entry("platform_h5")
	var e_pend := ModuleRegistry.get_entry("pendulum")
	var e_spawn := ModuleRegistry.get_entry("spawn")
	ed._place_module(e_plat, Vector2(0, 320))
	ed._place_module(e_pend, Vector2(200, 96))
	ed._place_module(e_spawn, Vector2(16, 320))
	ed._level_edit.text = "_editor_smoke"
	ed._save_level()
	for i in range(30):
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("res://tools/smoke_editor.png")
	var saved := FileAccess.file_exists("res://levels/_editor_smoke.json")
	print("[编辑器] 存档写入=%s 模块数=%d" % [saved, ed._world.get_child_count()])
	# 关卡切换验证:ch1_lv2(无存档→空关) → 切回 ch1_lv1(读回85个模块)
	ed._level_edit.text = "ch1_lv2"
	ed._switch_level()
	var switched_empty: bool = ed._world.get_child_count() == 0 and ed._current_level == "ch1_lv2"
	print("[编辑器] 切换到ch1_lv2: 空关=%s 当前关卡=%s" % [switched_empty, ed._current_level])
	ed._level_edit.text = "ch1_lv1"
	ed._switch_level()
	var switched_back: bool = ed._world.get_child_count() > 0 and ed._current_level == "ch1_lv1"
	print("[编辑器] 切回ch1_lv1: 模块数=%d" % ed._world.get_child_count())
	var ok: bool = saved and switched_empty and switched_back and autoloaded
	print("[编辑器] %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
