extends Node2D
# 游戏主入口(步骤8.3/8.4):把当前关卡装进 SubViewport(走 LUT 后处理),
# UI 层在窗口空间挂 HUD(场景已带)+ 日记UI + 翻页转场。
# 换关:改 START_LEVEL 或后续接关卡管理器。

const START_LEVEL := preload("res://src/levels/level_ch1_lv1.tscn")
const DEFAULT_LEVEL_JSON := "res://levels/ch1_lv1.json"
const DIARY_UI := preload("res://src/ui/DiaryUI.tscn")
const PAGE_TURN := preload("res://src/ui/PageTurn.tscn")


func _ready() -> void:
	# GameLayer 是 Control 但父节点是 Node2D,锚点不生效——显式铺满窗口并跟随窗口变化(含全屏)。
	_fit_game_layer()
	get_viewport().size_changed.connect(_fit_game_layer)

	# 关卡来源:编辑器试玩 > 已保存的JSON关卡 > 默认场景
	var level: Node2D
	var json_path := GameState.editor_level_path
	if json_path == "" and FileAccess.file_exists(DEFAULT_LEVEL_JSON):
		json_path = DEFAULT_LEVEL_JSON
	if json_path != "":
		level = LevelLoader.build(json_path)
	else:
		level = START_LEVEL.instantiate()
	$GameLayer/SubViewport.add_child(level)
	# 关卡必须画在 BackBufferCopy 之前,LUT 才采得到画面
	$GameLayer/SubViewport.move_child(level, 0)

	var diary := DIARY_UI.instantiate()  # _ready 内自加组 diary_ui
	$UILayer.add_child(diary)

	var page_turn := PAGE_TURN.instantiate()
	page_turn.add_to_group("page_turn")
	$UILayer.add_child(page_turn)


# 游戏层恒以 320×180 渲染、整数倍放大(窗口1280×720→4倍,全屏1920×1080→6倍)。
# SubViewportContainer.stretch 会把视口改成 容器尺寸/stretch_shrink,故 shrink=窗口/320。
func _fit_game_layer() -> void:
	var ws := get_viewport_rect().size
	$GameLayer.size = ws
	$GameLayer.stretch_shrink = maxi(int(ws.x) / 320, 1)


# F3:开关碰撞箱可视化(验收陷阱判定/美术对齐用)
# Esc:编辑器试玩模式下返回编辑器
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			get_tree().debug_collisions_hint = not get_tree().debug_collisions_hint
			print("[调试] 碰撞箱显示: %s" % ("开" if get_tree().debug_collisions_hint else "关"))
		elif event.keycode == KEY_ESCAPE and GameState.editor_level_path != "":
			GameState.current = GameState.State.Gameplay
			get_tree().change_scene_to_file("res://src/editor/MapEditor.tscn")
