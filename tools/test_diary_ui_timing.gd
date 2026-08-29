extends SceneTree
# DiaryUI 打字节奏冒烟测试(无头,2026-08-30 文案方案):
# ① 长文案(1993 篇,190+字)触底 0.035s/字;② 短文案(约47字)仍 5 秒均分;③ 超短文案上限 0.12s;
# ④ 日期阶段无跳过提示,进正文瞬间提示变为"按任意键加速",按键直接显示全文并广播 diary_finished。
# 用法: godot --headless --path <项目根> --script tools/test_diary_ui_timing.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	var diary := (load("res://src/ui/DiaryUI.tscn") as PackedScene).instantiate()
	root.add_child(diary)
	await process_frame
	await process_frame

	var texts: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://assets/data/diary_texts.json"))

	# ---- ① 长文案触底 0.035 ----
	var long_entry: Dictionary = texts["ch2_lv4"]
	diary.show_diary(long_entry["date"], long_entry["text"], 2)
	var total_chars: int = (long_entry["date"] as String).length() + (long_entry["text"] as String).length()
	var ok1: bool = is_equal_approx(diary._char_interval, 0.035)
	print("[test] ① 长文案 %d 字,间隔=%.4f(应=0.035): %s" % [total_chars, diary._char_interval, ok1])

	# 等到正文阶段,检查加速提示,然后按键加速(等价 _unhandled_input 路径)
	var hint_ok := false
	var t0 := Time.get_ticks_msec()
	while diary._phase != 2 and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
		if diary._phase == 1 and not hint_ok:
			hint_ok = diary.skip_hint.visible and diary.skip_hint.text == "按任意键加速"
			print("[test] ④ 进正文瞬间提示='按任意键加速'且可见: %s" % hint_ok)
			diary._skip_body()  # 模拟按键加速
	var finished1: bool = diary._phase == 2 and not diary.visible
	print("[test] ① 加速后全文显示并关闭: %s" % finished1)

	# ---- ② 短文案仍按 5 秒均分 ----
	var short_text := "爸又喝了酒。七点钟开始的，先是碗，然后是门。我跪在搓衣板上数地砖，数到四十三，他就停了。"  # 47字
	var short_date := "1993年6月12日"
	diary.show_diary(short_date, short_text, 2)
	var expect2: float = 5.0 / float(short_date.length() + short_text.length())
	var ok2: bool = absf(diary._char_interval - expect2) < 0.001
	print("[test] ② 短文案 %d 字,间隔=%.4f(应≈%.4f): %s" % [short_date.length() + short_text.length(), diary._char_interval, expect2, ok2])
	diary._finish()  # 直接收尾,不等逐字

	# ---- ③ 超短文案上限 0.12 ----
	diary.show_diary("1993", "短", 2)
	var ok3: bool = is_equal_approx(diary._char_interval, 0.12)
	print("[test] ③ 超短文案 5 字,间隔=%.4f(应=0.12): %s" % [diary._char_interval, ok3])

	# ---- 日期阶段提示隐藏 ----
	diary.show_diary(long_entry["date"], long_entry["text"], 2)
	var ok4: bool = not diary.skip_hint.visible
	print("[test] ④ 日期阶段跳过提示隐藏(D-505): %s" % ok4)

	var ok: bool = ok1 and finished1 and hint_ok and ok2 and ok3 and ok4
	print("[test] 结果: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
