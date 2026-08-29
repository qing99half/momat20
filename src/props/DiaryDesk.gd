class_name DiaryDesk
extends Area2D
# 关底日记桌(步骤8.4 + 任务10.5):玩家进入触发区 → GameState切Cutscene → 镜头推近笔记本
# (Camera2D.zoom缓动1s)→ 一章:不展示日记,聚焦完成不停顿直接黑屏覆盖→跳转下一关(2026-08-30 变更);
# 二章:叠化进日记UI(DiaryUI.show_diary)→光片飞入HUD(HUD自监听diary_finished,有章节门控)。
# 推进=GameState.advance_level():一章关内=黑屏直转(新场景淡入);二章关内=翻页(PageTurn);
# 章级推进=眼睑过场(闭眼→黑屏大字→换场景睁眼)。
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

	# 章判定以 GameState.current_chapter 为准(autoload 由 MainGame/编辑器试玩同步,恒正确;
	# 若只看 chapter 导出值,二章关卡 params 漏配 chapter=2 时会错走一章黑屏分支,日记永不展示)
	var ch: int = GameState.current_chapter

	# 2) 一章(2026-08-30 需求变更):不展示日记内容——聚焦完成后不停顿,直接黑屏覆盖→跳转下一关
	if ch == 1:
		await _black_cover_advance()
		return

	# 3) 二章:叠化进日记UI(读取演出:日期先行逐字,打完前禁跳;正文可加速)
	#    文案来源:编辑器 params 优先;为空时回退 assets/data/diary_texts.json(四篇正式长文案,1999/1997/1996/1993)
	if ch >= 2 and diary_text.is_empty():
		_load_diary_text_fallback()
	var diary := get_tree().get_first_node_in_group("diary_ui")
	if diary and diary.has_method("show_diary"):
		diary.show_diary(diary_date, diary_text, ch)
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

	# 4) 编辑器试玩(2026-08-30 变更):不再重载同一关——
	#    试玩关在关卡链内且下一关 JSON 已搭建 → 翻页接着试玩下一关(可连试二章四关);
	#    链尾/下一关未搭建 → 翻页回编辑器。
	if GameState.editor_level_path != "":
		var cur_id := GameState.editor_level_path.get_file().get_basename()
		var idx := GameState.LEVEL_CHAIN.find(cur_id)
		var next_id := ""
		if idx >= 0 and idx + 1 < GameState.LEVEL_CHAIN.size():
			var candidate := "res://levels/%s.json" % GameState.LEVEL_CHAIN[idx + 1]
			if FileAccess.file_exists(candidate):
				next_id = GameState.LEVEL_CHAIN[idx + 1]
		if next_id != "":
			GameState.editor_level_path = "res://levels/%s.json" % next_id
			GameState.sync_chapter_from_level_id(next_id)
			print("[日记桌] 试玩推进 -> %s" % next_id)
			var editor_turn := get_tree().get_first_node_in_group("page_turn")
			if editor_turn:
				editor_turn.play_turn("res://src/MainGame.tscn")
		else:
			print("[日记桌] 试玩已到链尾(%s),返回编辑器" % cur_id)
			GameState.current = GameState.State.Gameplay
			get_tree().change_scene_to_file("res://src/editor/MapEditor.tscn")
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


## 一章关底新流程(2026-08-30):不展示日记内容,聚焦完成后不停顿——
## 黑屏全覆盖(0.4s)→ 推进关卡链 → 直接切场景;新场景第一眼全黑,由 MainGame 淡入(0.5s)。
## 章末(ch1_lv4)黑屏后继续走原章级过场(黑屏大字"我一定要拯救过去的'我'。"→眼睑睁眼进二章)。
func _black_cover_advance() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100  # 压过游戏层与 UI 层
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.modulate.a = 0.0
	layer.add_child(black)
	var host: Node = get_tree().current_scene
	if host == null:
		host = owner  # 无头测试/试玩旁路(current_scene 为空):挂关卡根,随关卡销毁
	if host == null:
		host = get_tree().root
	host.add_child(layer)
	var fade := create_tween()
	fade.tween_property(black, "modulate:a", 1.0, 0.4)
	await fade.finished

	GameState.current = GameState.State.Transition
	EventBus.level_completed.emit(level_id)

	# 编辑器试玩:不推进关卡链,黑屏后回 MainGame 重载同一试玩关
	if GameState.editor_level_path != "":
		GameState.fade_from_black_pending = true
		get_tree().change_scene_to_file("res://src/MainGame.tscn")
		return

	match GameState.advance_level():
		"level":
			GameState.fade_from_black_pending = true
			get_tree().change_scene_to_file("res://src/MainGame.tscn")
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


## 二章日记文案回退(2026-08-30):编辑器 params 未配 diary_text 时,按关卡 id 查
## assets/data/diary_texts.json(四篇正式长文案;倒序:ch2_lv1=1999 … ch2_lv4=1993)。
## 仍为空则报警占位,不静默演空白日记(防反转证据丢失)。
func _load_diary_text_fallback() -> void:
	const TEXTS_PATH := "res://assets/data/diary_texts.json"
	if not FileAccess.file_exists(TEXTS_PATH):
		push_warning("[日记桌] %s 不存在,二章日记无文案回退" % TEXTS_PATH)
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXTS_PATH))
	if not (data is Dictionary):
		push_warning("[日记桌] diary_texts.json 解析失败")
		return
	# 依次试:导出 level_id → GameState 当前关(编辑器试玩旁路时导出值可能是默认 ch1_lv1)
	for key in [level_id, GameState.current_level_id()]:
		var entry: Variant = data.get(key)
		if entry is Dictionary:
			diary_date = str(entry.get("date", ""))
			diary_text = str(entry.get("text", ""))
			print("[日记桌] 文案回退命中 %s(%s)" % [key, diary_date])
			return
	push_warning("[日记桌] 未找到 %s 的二章日记文案,演出将只有日期" % level_id)
