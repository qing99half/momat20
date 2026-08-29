extends SceneTree
# 一章关底新流程冒烟测试(无头,2026-08-30 需求变更):
# 传送玩家到日记桌 → 镜头推近(1s) → 不弹日记UI、不广播 diary_finished、不收光片
# → 黑屏覆盖(0.4s) → 直接推进到 ch1_lv2(翻页不介入),新场景从黑淡入。
# 用法: godot --headless --path <项目根> --script tools/test_diary_flow.gd
# 注意:--script 模式下 autoload 不可编译期直引,一律 root.get_node 动态获取。

var _diary_seen_visible := false
var _diary_finished_seen := false
var _desk_triggered := false


func _initialize() -> void:
	var mg := (load("res://src/MainGame.tscn") as PackedScene).instantiate()
	root.add_child(mg)
	current_scene = mg  # 让 change_scene_to_file 正确销毁旧场景(贴近真实运行)
	_run()


func _run() -> void:
	await process_frame
	await process_frame

	var event_bus := root.get_node_or_null("/root/EventBus")
	var game_state := root.get_node_or_null("/root/GameState")
	var player := root.find_child("Player", true, false) as CharacterBody2D
	var desk := root.find_child("diary_desk_*", true, false) as Area2D  # LevelLoader 命名: <id>_<x>_<y>
	if event_bus == null or game_state == null or player == null or desk == null:
		print("[test] FAIL: 节点未找到(EventBus=%s, GameState=%s, Player=%s, DiaryDesk=%s)" % [event_bus, game_state, player, desk])
		quit(1)
		return
	event_bus.diary_finished.connect(func(): _diary_finished_seen = true)

	# 传送到日记桌触发区(ch1_lv1 日记桌 px=2500,py=320;触发区 41×34 比桌大一圈)
	player.global_position = Vector2(2480, 300)

	var advanced := false
	for i in range(6000):  # 无头模式帧耗时不可控,按关卡链索引轮询
		await process_frame
		if is_instance_valid(desk) and desk._triggered:
			_desk_triggered = true
		var diary := root.find_child("DiaryUI", true, false) as Control
		if diary and diary.visible:
			_diary_seen_visible = true
		if game_state.current_level_index >= 1:
			advanced = true
			break

	# 再等若干帧:让新场景 _ready 消费 fade_from_black_pending 并淡入
	for j in range(120):
		await process_frame

	print("[test] 桌面已触发: %s" % _desk_triggered)
	print("[test] 日记UI弹出过(一章应为 false): %s" % _diary_seen_visible)
	print("[test] diary_finished 广播过(一章应为 false): %s" % _diary_finished_seen)
	print("[test] 已推进到下一关(index=1=ch1_lv2): %s" % advanced)
	print("[test] 新场景淡入标记已消费(应为 false): %s" % game_state.fade_from_black_pending)
	var ok: bool = _desk_triggered and not _diary_seen_visible and not _diary_finished_seen \
		and advanced and not game_state.fade_from_black_pending
	print("[test] 结果: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
