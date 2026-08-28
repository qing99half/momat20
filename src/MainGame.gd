extends Node2D
# 游戏主入口(步骤8.3/8.4):把当前关卡装进 SubViewport(走 LUT 后处理),
# UI 层在窗口空间挂 HUD(场景已带)+ 日记UI + 翻页转场。
# 换关:改 START_LEVEL 或后续接关卡管理器。

const START_LEVEL := preload("res://src/levels/level_ch1_lv1.tscn")
const DIARY_UI := preload("res://src/ui/DiaryUI.tscn")
const PAGE_TURN := preload("res://src/ui/PageTurn.tscn")


func _ready() -> void:
	var level := START_LEVEL.instantiate()
	$GameLayer/SubViewport.add_child(level)
	# 关卡必须画在 BackBufferCopy 之前,LUT 才采得到画面
	$GameLayer/SubViewport.move_child(level, 0)

	var diary := DIARY_UI.instantiate()  # _ready 内自加组 diary_ui
	$UILayer.add_child(diary)

	var page_turn := PAGE_TURN.instantiate()
	page_turn.add_to_group("page_turn")
	$UILayer.add_child(page_turn)
