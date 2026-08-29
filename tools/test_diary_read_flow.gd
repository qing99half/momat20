extends SceneTree
# 二章关底读取演出全链路冒烟测试(无头,2026-08-30):
# 强制关卡链到 ch2_lv1 → 传送玩家到日记桌 → 期望:弹日记UI(日期 1999年11月2日 先行)
# → 正文加速 → diary_finished → 光片飞入 HUD → 翻页推进到 ch2_lv2(index=5)。
# 一章黑屏分支不得触发(GameState.current_chapter=2)。
# 用法: godot --headless --path <项目根> --script tools/test_diary_read_flow.gd

var _diary_seen_visible := false
var _diary_finished_seen := false
var _date_text_seen := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame  # 等 autoload 入树(_initialize 阶段还不存在)
	var game_state := root.get_node_or_null("/root/GameState")
	if game_state == null:
		print("[test] FAIL: autoload GameState 未找到")
		quit(1)
		return
	# 在装场景前把关卡链拨到 ch2_lv1(index=4,章=2)
	game_state.current_level_index = 4
	game_state.current_chapter = 2
	var mg := (load("res://src/MainGame.tscn") as PackedScene).instantiate()
	root.add_child(mg)
	current_scene = mg
	await process_frame
	await process_frame

	var event_bus := root.get_node_or_null("/root/EventBus")
	var player := root.find_child("Player", true, false) as CharacterBody2D
	var desk := root.find_child("diary_desk_*", true, false) as Area2D
	if event_bus == null or game_state == null or player == null or desk == null:
		print("[test] FAIL: 节点未找到(EventBus=%s, GameState=%s, Player=%s, desk=%s)" % [event_bus, game_state, player, desk])
		quit(1)
		return
	event_bus.diary_finished.connect(func(): _diary_finished_seen = true)

	# 传送到日记桌触发区(ch2_lv1 日记桌 px=2500,py=320)
	player.global_position = Vector2(2480, 300)

	var hud: Control = null
	var collected := 0
	var skipped := false
	for i in range(6000):
		await process_frame
		if i % 600 == 0:
			print("[test] 轮询中 i=%d level_index=%d desk_triggered=%s" % [i, game_state.current_level_index, desk._triggered])
		var diary := root.find_child("DiaryUI", true, false) as Control
		if diary and diary.visible:
			_diary_seen_visible = true
			if _date_text_seen == "" and diary.date_label.visible_ratio > 0.0:
				_date_text_seen = diary.date_label.text
			# 正文阶段一到就按键加速(长文案 229 字,不加速要打 8 秒)
			if diary._phase == 1 and not skipped:
				skipped = true
				diary._skip_body()
		if hud == null:
			hud = root.find_child("HUD", true, false)
		elif hud._collected > collected:
			collected = hud._collected
		if game_state.current_level_index >= 5:
			break

	print("[test] 日记UI弹出过(二章应为 true): %s" % _diary_seen_visible)
	print("[test] 日期先行内容(应=1999年11月2日): %s" % _date_text_seen)
	print("[test] diary_finished 已广播: %s" % _diary_finished_seen)
	print("[test] HUD 已收集光片(应=1): %d" % collected)
	print("[test] 已推进到 ch2_lv2(index=5): %s" % (game_state.current_level_index >= 5))
	var ok: bool = _diary_seen_visible and _date_text_seen == "1999年11月2日" \
		and _diary_finished_seen and collected == 1 and game_state.current_level_index == 5
	print("[test] 结果: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
