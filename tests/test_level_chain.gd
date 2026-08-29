extends Node
# 任务10.5 + 11.1(修正版)验收测试:关卡链推进序列 / 章节推算 / add_fragment 开锁条件 / 章节同步。
# 运行:godot --headless --path <项目根> res://tests/test_level_chain.tscn

func _ready() -> void:
	var ok := true

	# 1) 链推进序列:lv1→2→3→4 关内翻页,lv4→ch2_lv1 章级,…,ch2_lv4→ch3 章级,末端 end
	var expect: Array[String] = ["level", "level", "level", "chapter", "level", "level", "level", "chapter"]
	for i in expect.size():
		var r: String = GameState.advance_level()
		if r != expect[i]:
			ok = false
			printerr("[测试] advance_level 第%d步: 期望 %s 实得 %s" % [i + 1, expect[i], r])
	if GameState.current_level_id() != "ch3" or GameState.current_chapter != 3:
		ok = false
		printerr("[测试] 链末端状态错误: %s ch%d" % [GameState.current_level_id(), GameState.current_chapter])
	if GameState.advance_level() != "end":
		ok = false
		printerr("[测试] 链末端应返回 end")

	# 2) add_fragment(任务11.1):一章集齐不触发开锁;二章末关集齐才触发
	GameState.current_level_index = 3  # ch1_lv4
	GameState.current_chapter = 1
	GameState.collected_fragments = 3
	GameState.unlock_pending = false
	if GameState.add_fragment():
		ok = false
		printerr("[测试] ch1_lv4 集齐4片不应触发开锁")
	GameState.current_level_index = 7  # ch2_lv4
	GameState.current_chapter = 2
	GameState.collected_fragments = 3
	if not GameState.add_fragment() or not GameState.unlock_pending:
		ok = false
		printerr("[测试] ch2_lv4 集齐4片应置 unlock_pending 并返回 true")

	# 3) 编辑器试玩旁路的章节同步
	GameState.sync_chapter_from_level_id("ch2_lv3")
	if GameState.current_chapter != 2:
		ok = false
		printerr("[测试] sync_chapter ch2 失败")
	GameState.sync_chapter_from_level_id("ch1_lv2")
	if GameState.current_chapter != 1:
		ok = false
		printerr("[测试] sync_chapter ch1 失败")

	print("[测试] 任务10.5/11.1: %s" % ("全部通过" if ok else "有失败项"))
	get_tree().quit(0 if ok else 1)
