extends SceneTree
# 二章日记文案回退链路冒烟测试(无头,2026-08-30):
# 不依赖 ch2 关卡是否建好——直接实例化 DiaryDesk,验证按 level_id / GameState 当前关
# 从 assets/data/diary_texts.json 取到正确的日期与长文案(倒序:lv1=1999/lv2=1997/lv3=1996/lv4=1993)。
# 用法: godot --headless --path <项目根> --script tools/test_diary_texts_fallback.gd

const CASES := {
	"ch2_lv1": "1999年11月2日",
	"ch2_lv2": "1997年5月2日",
	"ch2_lv3": "1996年10月3日",
	"ch2_lv4": "1993年6月12日",
}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame  # 等 autoload 入树
	var game_state := root.get_node_or_null("/root/GameState")
	var desk_scene := load("res://src/props/DiaryDesk.tscn") as PackedScene
	var ok := true

	for level_id in CASES:
		var desk := desk_scene.instantiate()
		root.add_child(desk)
		desk.level_id = level_id
		desk._load_diary_text_fallback()
		var expect: String = CASES[level_id]
		var hit: bool = desk.diary_date == expect and desk.diary_text.length() > 150
		print("[test] %s -> 日期 '%s'(应='%s'),正文 %d 字: %s" % [level_id, desk.diary_date, expect, desk.diary_text.length(), hit])
		ok = ok and hit
		desk.queue_free()

	# GameState 当前关兜底:level_id 为默认 ch1_lv1(编辑器 params 未配)时,按 current_level_id 命中
	game_state.current_level_index = 4  # ch2_lv1
	var desk2 := desk_scene.instantiate()
	root.add_child(desk2)
	desk2._load_diary_text_fallback()
	var ok2: bool = desk2.diary_date == "1999年11月2日"
	print("[test] 默认 level_id + GameState=ch2_lv1 -> '%s': %s" % [desk2.diary_date, ok2])
	ok = ok and ok2

	print("[test] 结果: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
