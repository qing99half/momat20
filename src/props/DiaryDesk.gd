class_name DiaryDesk
extends Area2D
# 关底日记桌(步骤8.4 + 任务10.5):玩家进入触发区 → GameState切Cutscene → 镜头推近笔记本
# (Camera2D.zoom缓动1s)→ 叠化进日记UI(DiaryUI.show_diary) →(仅二章)光片飞入HUD
# (HUD自监听diary_finished,有章节门控) → GameState.advance_level():
#   关内推进=翻页(PageTurn,目标恒定 MainGame.tscn);章级推进=眼睑过场(闭眼→黑屏大字→换场景睁眼)。
# 每关1张,一局只触发一次;UI按组查找(diary_ui/page_turn/eyelid/blackscreen_text),与UI层零硬引用。

const DESK_TEXTURE := preload("res://assets/art/shared/prop_diarydesk.png")  # 真素材 21×14 终尺寸

@export var level_id := "ch1_lv1"
@export var chapter := 1
# 一章=写入演出,日期/正文不落纸(防反转泄底);真实 1993/1996/1997/1999 四篇文案只配在二章四关
@export var diary_date := ""
@export_multiline var diary_text := ""

var _triggered := false


func _ready() -> void:
	collision_layer = 0  # 只做触发,自己不在任何层(与台灯同一约定)
	collision_mask = 1
	var sprite := Sprite2D.new()
	sprite.texture = DESK_TEXTURE
	sprite.position = Vector2(0.0, -7.0)   # 21×14,原点=桌底落地线(底部居中)
	add_child(sprite)
	var hitbox := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(41.0, 34.0)  # 触发区比桌子大一圈,走近即触发
	hitbox.shape = rect
	hitbox.position = Vector2(0.0, -17.0)
	add_child(hitbox)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not (body is CharacterBody2D):
		return
	_triggered = true
	GameState.current = GameState.State.Cutscene
	if body.has_method("set_frozen"):
		body.set_frozen(true)
	if "can_die" in body:
		body.can_die = false  # 演出态显式禁死(附录D):防"关底进演出的同帧碰陷阱"死在日记里
	print("[日记桌] 玩家到达关底,开始日记演出 (%s)" % level_id)
	_play_cutscene(body)


func _play_cutscene(player: Node2D) -> void:
	# 1) 镜头推近笔记本(Camera2D.zoom 缓动,约1秒)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		var zoom_in := create_tween()
		zoom_in.tween_property(cam, "zoom", Vector2(2.0, 2.0), 1.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await zoom_in.finished

	# 2) 叠化进日记UI(淡入在 DiaryUI.show_diary 内部;一章=写入演出,二章=读取演出)
	var diary := get_tree().get_first_node_in_group("diary_ui")
	if diary and diary.has_method("show_diary"):
		diary.show_diary(diary_date, diary_text, chapter)
		await EventBus.diary_finished

	# 3)(仅二章)光片飞入HUD:HUD 自监听 diary_finished 播飞行动画(0.8s),等它落位
	await get_tree().create_timer(1.0).timeout

	# 3.5) 二章末关集齐4片:不翻页不推进,改播开锁演出(任务11.2~11.6;演出末尾自行推进进三章)
	if GameState.unlock_pending:
		var unlock := get_tree().get_first_node_in_group("unlock_cutscene")
		if unlock and unlock.has_method("trigger_unlock_cutscene"):
			unlock.trigger_unlock_cutscene()
		else:
			print("[日记桌] trigger_unlock_cutscene() 未找到 UnlockCutscene 组件,占位跳过")
		return

	GameState.current = GameState.State.Transition
	EventBus.level_completed.emit(level_id)

	# 4) 编辑器试玩:不推进关卡链,翻页回 MainGame 重新装载同一试玩关
	if GameState.editor_level_path != "":
		var editor_turn := get_tree().get_first_node_in_group("page_turn")
		if editor_turn:
			editor_turn.play_turn("res://src/MainGame.tscn")
		return

	# 5) 推进关卡链:关内=翻页;章级=眼睑过场;链走完=收尾占位
	match GameState.advance_level():
		"level":
			var page_turn := get_tree().get_first_node_in_group("page_turn")
			if page_turn:
				page_turn.play_turn("res://src/MainGame.tscn")
		"chapter":
			await _chapter_transition()
		"end":
			print("[日记桌] 关卡链已走完(三章推门→ED 为任务12,待做)")


## 章级过场(任务10.5):眼睑闭眼 → 黑屏大字 → 闭眼态切场景(新场景睁眼开场)。
func _chapter_transition() -> void:
	var eyelid := get_tree().get_first_node_in_group("eyelid")
	var blackscreen := get_tree().get_first_node_in_group("blackscreen_text")
	if eyelid and eyelid.has_method("close_eyes"):
		eyelid.close_eyes(1.0)
		await get_tree().create_timer(1.0).timeout

	if GameState.current_chapter == 2:
		# 一章末:黑屏大字(剧情.md 二章开场原文),逐字浮现+停留共约3.5s
		if blackscreen and blackscreen.has_method("show_text"):
			blackscreen.visible = true
			blackscreen.show_text("我一定要拯救过去的'我'。", false)
			await get_tree().create_timer(3.5).timeout
		# 冲刺解锁:信号发给当前玩家(即将随场景销毁),新章玩家 _ready 按章节自查——双保险
		EventBus.dash_unlocked.emit()
	else:
		# 二章末→三章:正常路径由任务11开锁演出接管(集齐4片走 unlock_pending,到不了这里),保底过场
		print("[日记桌] 章级过场 ch2->ch3(保底路径;正常应走任务11开锁演出)")

	GameState.chapter_intro_pending = true
	get_tree().change_scene_to_file("res://src/MainGame.tscn")
