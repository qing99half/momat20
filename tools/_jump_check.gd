extends SceneTree
func _initialize() -> void:
	var mg := (load("res://src/MainGame.tscn") as PackedScene).instantiate()
	root.add_child(mg)
	current_scene = mg
	_run()

func _run() -> void:
	await create_timer(1.5).timeout
	var p = root.find_child("Player", true, false)
	print("[J] frozen=%s cutscene=%s on_floor=%s" % [p.get("_frozen"), p.get("_cutscene"), p.is_on_floor()])
	# 空格跳
	Input.action_press("ui_accept")
	await physics_frame
	Input.action_release("ui_accept")
	for i in range(6): await physics_frame
	print("[J] 空格跳后 vy=%.1f(应<0起跳)" % p.velocity.y)
	await create_timer(1.0).timeout
	# W跳
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_W; ev.pressed = true
	p._input(ev)
	for i in range(6): await physics_frame
	print("[J] W跳后 vy=%.1f" % p.velocity.y)
	quit(0)
