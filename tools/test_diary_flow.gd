extends SceneTree
# 步骤8.4 日记演出集成冒烟测试(无头):
# 把玩家传送到日记桌旁,验证 触发→镜头推近→日记UI→光片飞入→(无下一关)交还控制 全链路。
# 用法: godot --headless --path <项目根> --script tools/test_diary_flow.gd
# 注意:--script 模式下 autoload 不可编译期直引,一律 root.get_node 动态获取。

var _diary_seen_visible := false
var _diary_finished_seen := false


func _initialize() -> void:
	var mg := (load("res://src/MainGame.tscn") as PackedScene).instantiate()
	root.add_child(mg)
	_run()


func _run() -> void:
	await process_frame
	await process_frame

	var event_bus := root.get_node_or_null("/root/EventBus")
	var game_state := root.get_node_or_null("/root/GameState")
	var diary := root.find_child("DiaryUI", true, false) as Control
	var hud := root.find_child("HUD", true, false)
	var player := root.find_child("Player", true, false) as CharacterBody2D
	var desk := root.find_child("DiaryDesk", true, false) as Area2D
	if event_bus == null or game_state == null:
		print("[test] FAIL: autoload 未找到(EventBus=%s, GameState=%s)" % [event_bus, game_state])
		quit(1)
		return
	event_bus.diary_finished.connect(func(): _diary_finished_seen = true)

	# 传送到日记桌触发区(X=125 落地线)
	player.global_position = Vector2(990, 136)

	var state_now: int = game_state.current
	for i in range(6000):  # 无头模式帧耗时不可控,按状态轮询:回到 Gameplay 即演出走完
		await process_frame
		if diary and diary.visible:
			_diary_seen_visible = true
		state_now = game_state.current
		if desk._triggered and _diary_finished_seen and state_now == 0:
			break
	print("[test] 桌面已触发: %s" % desk._triggered)
	print("[test] 日记UI弹出过: %s" % _diary_seen_visible)
	print("[test] diary_finished 已广播: %s" % _diary_finished_seen)
	print("[test] HUD 已收集光片: %d" % hud._collected)
	print("[test] 结束时 GameState(0=Gameplay 表示已交还控制): %d" % state_now)
	var ok: bool = desk._triggered and _diary_seen_visible and _diary_finished_seen \
		and hud._collected == 1 and state_now == 0
	print("[test] 结果: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
