extends Node2D
# 游戏主入口(步骤8.3/8.4):把当前关卡装进 SubViewport(走 LUT 后处理),
# UI 层在窗口空间挂 HUD(场景已带)+ 日记UI + 翻页转场。
# 换关:改 START_LEVEL 或后续接关卡管理器。

const START_LEVEL := preload("res://src/levels/level_ch1_lv1.tscn")
const LEVEL_CH3 := preload("res://src/levels/level_ch3.tscn")  # 三章=演出关(任务12),独立场景不走 JSON
const DIARY_UI := preload("res://src/ui/DiaryUI.tscn")
const PAGE_TURN := preload("res://src/ui/PageTurn.tscn")
const EYELID := preload("res://src/ui/EyelidTransition.tscn")
const BLACKSCREEN := preload("res://src/ui/BlackscreenText.tscn")
const UNLOCK := preload("res://src/ui/UnlockCutscene.tscn")


func _ready() -> void:
	# GameView 精灵显示离屏 SubViewport 的纹理;尺寸/位置/缩放全由 _fit_game_layer 手动管理
	$GameView.texture = $GameLayer/SubViewport.get_texture()
	$GameView.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 像素风最近邻放大
	_fit_game_layer()
	get_viewport().size_changed.connect(_fit_game_layer)

	# 关卡来源:编辑器试玩 > 关卡链 JSON(任务10.5,按 GameState 当前索引拼路径)> 默认场景
	var level: Node2D
	var json_path := GameState.editor_level_path
	if json_path != "":
		# 编辑器试玩:按文件名同步章节(HUD 门控/冲刺解锁据此判定),不动关卡链进度
		GameState.sync_chapter_from_level_id(json_path.get_file().get_basename())
	else:
		var chain_id := GameState.current_level_id()
		if chain_id == "ch3":
			# 三章相遇(任务12):演出关,独立场景特判加载,不走地图编辑器 JSON
			GameState.current_chapter = 3
			level = LEVEL_CH3.instantiate()
		else:
			var chain_path := "res://levels/%s.json" % chain_id
			if FileAccess.file_exists(chain_path):
				json_path = chain_path
			elif GameState.current_level_index > 0:
				# 链上关卡 JSON 未搭建:不静默回退第1关,先报警再占位
				push_warning("[MainGame] %s 不存在,回退默认场景(该关待搭建)" % chain_path)
	if level == null:
		if json_path != "":
			level = LevelLoader.build(json_path)
		else:
			level = START_LEVEL.instantiate()
	$GameLayer/SubViewport.add_child(level)
	# 关卡必须画在 BackBufferCopy 之前,LUT 才采得到画面
	$GameLayer/SubViewport.move_child(level, 0)
	# Conductor 已随关卡入树(_ready 已跑完),启动音乐+节拍
	var conductor := level.find_child("Conductor", false, false) as Conductor
	if conductor and conductor.has_meta("autoplay_track"):
		var track: String = conductor.get_meta("autoplay_track")
		conductor.play(track)
		# 音乐循环:按音频实际时长设循环点(120BPM=0.5s/拍),播完自动回卷重放——
		# 节拍信号因此不断供,对拍陷阱(酒瓶/摆锤/冲压/声波)不会随音乐结束停摆
		var stream: AudioStream = load(track)
		if stream and stream.get_length() > 0.0:
			conductor.set_loop(0.0, stream.get_length() / Conductor.SEC_PER_BEAT)

	var diary := DIARY_UI.instantiate()  # _ready 内自加组 diary_ui
	$UILayer.add_child(diary)

	var page_turn := PAGE_TURN.instantiate()
	page_turn.add_to_group("page_turn")
	$UILayer.add_child(page_turn)

	# 章级过场组件(任务10.5):黑屏大字 + 眼睑,DiaryDesk 按组查找,与 UI 层零硬引用
	# 顺序铁律(2026-08-30 修复):眼睑必须先加、黑屏大字后加——后加者画在上层;
	# 反序时闭眼黑幕会压住黑屏大字,字在播但玩家看不见(ch1→ch2 转场文字"没做"的真相之二)
	var eyelid := EYELID.instantiate()
	eyelid.add_to_group("eyelid")
	$UILayer.add_child(eyelid)

	var blackscreen := BLACKSCREEN.instantiate()
	blackscreen.visible = false  # 场景默认可见,这里先藏起来,章级过场时才亮
	blackscreen.add_to_group("blackscreen_text")
	$UILayer.add_child(blackscreen)

	# 二章末关开锁演出(任务11.2~11.6),日记桌按组查找
	var unlock := UNLOCK.instantiate()
	unlock.add_to_group("unlock_cutscene")
	$UILayer.add_child(unlock)

	# 章级过场后半场:DiaryDesk 闭眼状态下切场景,这里第一眼就是闭着的,再睁开进新章
	if GameState.chapter_intro_pending:
		GameState.chapter_intro_pending = false
		eyelid.set_closed()
		eyelid.open_eyes(1.0)
		# 二章首关:睁眼后播冲刺赠予演出(任务9 play_dash_gift_cutscene 由本处调用)
		if GameState.current_chapter == 2:
			_play_dash_gift_after_intro(level)

	# 一章关底黑屏直转的后半场(2026-08-30):新场景第一眼全黑,0.5s 淡入关卡
	if GameState.fade_from_black_pending:
		GameState.fade_from_black_pending = false
		var fade_layer := CanvasLayer.new()
		fade_layer.layer = 100
		var black := ColorRect.new()
		black.color = Color.BLACK
		black.set_anchors_preset(Control.PRESET_FULL_RECT)
		black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_layer.add_child(black)
		add_child(fade_layer)
		var fade_in := create_tween()
		fade_in.tween_property(black, "modulate:a", 0.0, 0.5)
		fade_in.tween_callback(fade_layer.queue_free)

	# 冲刺=二章专属(2026-08-30 陈洒指令):一章不解锁不弹提示;
	# 唯一弹窗=二章首关赠予演出(上方 chapter_intro_pending 分支)。


## 等睁眼结束(1.0s)再触发赠予演出;玩家由 LevelLoader 建在关卡根下。
func _play_dash_gift_after_intro(level: Node2D) -> void:
	await get_tree().create_timer(1.0).timeout
	for child in level.get_children():
		if child is CharacterBody2D and child.has_method("play_dash_gift_cutscene"):
			child.play_dash_gift_cutscene()
			return
	push_warning("[MainGame] 二章首关未找到玩家,赠予演出跳过")


# 游戏层恒以 640×360 渲染(20px格,单屏=32格宽×18格高=整关高度,开局即见关卡顶)。
# 方案A:保宽高比的小数缩放——窗口内最大16:9矩形铺满,黑边只剩宽高比差异(细边);
# 整数倍分辨率(720p×2/1080p×3/2K×4)依然像素完美;F11 无边框真全屏吃满物理分辨率(见 _unhandled_input)。
# 注意:SubViewportContainer.stretch=true 会把 SubViewport 本身改尺寸(相机视野随之变形),
# 小数缩放必须走 stretch=false + 容器 scale(纯纹理放大,视口恒为640×360)。
func _fit_game_layer() -> void:
	var ws := get_viewport_rect().size
	var s := minf(ws.x / 640.0, ws.y / 360.0)
	$GameView.scale = Vector2(s, s)
	$GameView.position = ((ws - Vector2(640.0, 360.0) * s) / 2.0).floor()


# F3:开关碰撞箱可视化(验收陷阱判定/美术对齐用)
# F11:无边框真全屏切换(方案C;1080p 屏=精确3×铺满,最大化窗口的标题栏/任务栏余量也消掉)
# Esc:编辑器试玩模式下返回编辑器
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			get_tree().debug_collisions_hint = not get_tree().debug_collisions_hint
			print("[调试] 碰撞箱显示: %s" % ("开" if get_tree().debug_collisions_hint else "关"))
		elif event.keycode == KEY_F11:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
			print("[调试] 全屏: %s" % ("开" if w.mode == Window.MODE_FULLSCREEN else "关"))
		elif event.keycode == KEY_ESCAPE and GameState.editor_level_path != "":
			GameState.current = GameState.State.Gameplay
			get_tree().change_scene_to_file("res://src/editor/MapEditor.tscn")
