class_name DiaryDesk
extends Area2D
# 关底日记桌(步骤8.4):玩家进入触发区 → GameState切Cutscene → 镜头推近笔记本(Camera2D.zoom缓动1s)
# → 叠化进日记UI(DiaryUI.show_diary) → 日记结束光片飞入HUD(HUD自监听diary_finished)
# → 翻页转场(PageTurn) → 下一关。
# 每关1张,一局只触发一次;UI按组查找(diary_ui/page_turn),与UI层零硬引用。

const DESK_TEXTURE := preload("res://assets/placeholder/placeholder_prop_diary_desk.png")

@export var level_id := "ch1_lv1"
@export var diary_date := "1993年6月12日"
@export_multiline var diary_text := "他又摔了酒瓶。我抱着你躲在厨房，数着墙上的裂纹等天亮。等你长大，妈妈带你离开这里。"
@export var chapter := 1
@export var next_scene_path := ""  # 翻页目标场景;空=留在本关(单关验收用)

var _triggered := false


func _ready() -> void:
	collision_layer = 0  # 只做触发,自己不在任何层(与台灯同一约定)
	collision_mask = 1
	var sprite := Sprite2D.new()
	sprite.texture = DESK_TEXTURE
	sprite.position = Vector2(0.0, -40.0)  # 120×80贴图,原点=桌面落地线(底部居中)
	add_child(sprite)
	var hitbox := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(140.0, 100.0)  # 触发区比桌子大一圈,走近即触发
	hitbox.shape = rect
	hitbox.position = Vector2(0.0, -50.0)
	add_child(hitbox)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not (body is CharacterBody2D):
		return
	_triggered = true
	GameState.current = GameState.State.Cutscene
	if body.has_method("set_frozen"):
		body.set_frozen(true)
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

	# 2) 叠化进日记UI(淡入在 DiaryUI.show_diary 内部;打字机5s,可跳)
	var diary := get_tree().get_first_node_in_group("diary_ui")
	if diary and diary.has_method("show_diary"):
		diary.show_diary(diary_date, diary_text, chapter)
		await EventBus.diary_finished

	# 3) 光片飞入HUD:HUD 自监听 diary_finished 播飞行动画(0.8s),等它落位
	await get_tree().create_timer(1.0).timeout

	# 4) 翻页转场 → 下一关
	GameState.current = GameState.State.Transition
	EventBus.level_completed.emit(level_id)
	var page_turn := get_tree().get_first_node_in_group("page_turn")
	if page_turn and not next_scene_path.is_empty():
		page_turn.play_turn(next_scene_path)
	else:
		# 单关验收:暂无下一关,镜头拉回并交还控制
		if cam:
			var zoom_out := create_tween()
			zoom_out.tween_property(cam, "zoom", Vector2.ONE, 0.6) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await zoom_out.finished
		if player.has_method("set_frozen"):
			player.set_frozen(false)
		GameState.current = GameState.State.Gameplay
		print("[日记桌] 日记演出结束(next_scene_path 为空,留在本关)")
