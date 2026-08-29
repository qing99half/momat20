extends Control
# 二章末关开锁演出(任务11.2~11.6):集齐4枚记忆光片后由日记桌触发(只调 trigger_unlock_cutscene)。
# 流程:定格黑屏+锁共鸣震颤(11.2)→ 笔记本特写浮现+4光片从HUD依次飞入锁扣(11.3)
# → 锁扣发光+咔哒弹开+白光铺满(11.4)→ 黑屏大字"原来,过去的那个'我'是……"(11.5)
# → "妈妈"单独一屏+音乐骤停+呼吸心跳静默4s(11.6)→ 眼睑睁眼过场进三章。
# 素材全为占位:真素材 ui_notebook_close.png / sfx_lock_buzz.ogg(S10)/ sfx_lock_open.ogg(S11)/
# sfx_breath_heartbeat.ogg(S17)到位后换路径即可,白光扩散 shader 暂用白色淡入代替。

const NOTEBOOK_TEXTURE := "res://assets/placeholder/placeholder_ui_notebook_close.png"
const FRAGMENT_TEXTURES := [
	"res://assets/placeholder/placeholder_ui_memory_fragment_1.png",
	"res://assets/placeholder/placeholder_ui_memory_fragment_2.png",
	"res://assets/placeholder/placeholder_ui_memory_fragment_3.png",
	"res://assets/placeholder/placeholder_ui_memory_fragment_4.png",
]
const SFX_BUZZ := "res://assets/audio/sfx_lock_buzz.ogg"          # 锁共鸣低频震颤
const SFX_LOCK := "res://assets/audio/sfx_lock_open.ogg"          # 锁弹开"咔哒"
const SFX_BREATH := "res://assets/audio/sfx_breath_heartbeat.ogg"  # 呼吸+心跳(D-533 绝不砍)

const BLACKOUT_FADE := 0.3     # 11.2 画面定格黑屏淡入
const BUZZ_SECONDS := 0.5      # 11.2 锁共鸣时长
const NOTEBOOK_ZOOM := 0.5     # 11.3 笔记本特写 scale 0.5→1.0
const SHARD_FLIGHT := 0.8      # 11.3 单枚光片飞行时长
const SHARD_STAGGER := 0.2     # 11.3 光片依次起飞间隔
const FLASH_SECONDS := 0.5     # 11.4 白光铺满
const TEXT1_HOLD := 3.5        # 11.5 文案14字×0.1s逐字 + 停留2s
const SILENCE_SECONDS := 4.0   # 11.6 "妈妈"黑屏静默(D-533)

@onready var _blackout: ColorRect = $Blackout
@onready var _notebook: TextureRect = $Notebook
@onready var _flash: ColorRect = $WhiteFlash


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_notebook.texture = load(NOTEBOOK_TEXTURE)


## 任务11 唯一入口。日记桌在 unlock_pending 时调用;演出末尾自行推进关卡链并进三章。
func trigger_unlock_cutscene() -> void:
	print("[开锁演出] 开始(任务11.2~11.6)")
	GameState.unlock_pending = false  # 已消费,防重复触发
	GameState.current = GameState.State.Cutscene
	visible = true
	_notebook.pivot_offset = _notebook.size * 0.5
	_notebook.scale = Vector2(0.5, 0.5)

	# ---- 11.2 短暂静止帧与声音预兆 ----
	_play_sfx(SFX_BUZZ)
	var fade := create_tween()
	fade.tween_property(_blackout, "modulate:a", 1.0, BLACKOUT_FADE)
	await fade.finished
	await get_tree().create_timer(BUZZ_SECONDS).timeout

	# ---- 11.3 笔记本特写 + 4片光依次飞向锁扣 ----
	var zoom := create_tween().set_parallel(true)
	zoom.tween_property(_notebook, "modulate:a", 1.0, 0.3)
	zoom.tween_property(_notebook, "scale", Vector2.ONE, NOTEBOOK_ZOOM) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await zoom.finished

	var lock_pos := get_viewport_rect().size * 0.5  # 锁扣=特写中央(光片汇聚点,D-529)
	var starts := _hud_symbol_centers()
	for i in 4:
		_fly_shard(starts[i], lock_pos, i)
		await get_tree().create_timer(SHARD_STAGGER).timeout
	await get_tree().create_timer(SHARD_FLIGHT).timeout  # 等最后一枚落位

	# ---- 11.4 锁扣发光 + 咔哒 + 白光铺满 ----
	_spawn_lock_burst(lock_pos)
	_play_sfx(SFX_LOCK)
	var flash := create_tween()
	flash.tween_property(_flash, "modulate:a", 1.0, FLASH_SECONDS)
	await flash.finished

	# ---- 11.5/11.6 黑屏大字两连 + 静默 ----
	var blackscreen := get_tree().get_first_node_in_group("blackscreen_text")
	if blackscreen and blackscreen.has_method("show_text"):
		blackscreen.visible = true  # 白色画面被纯黑覆盖("白光闪,黑屏")
		blackscreen.show_text("原来,过去的那个'我'是……", false)
		await get_tree().create_timer(TEXT1_HOLD).timeout
		# "妈妈"单独一屏:字号加倍;big=true 触发 Conductor.stop_music_immediately()(BlackscreenText 内置)
		blackscreen.show_text("妈妈", true)
		_play_sfx(SFX_BREATH)
		await get_tree().create_timer(SILENCE_SECONDS).timeout
	else:
		push_warning("[开锁演出] 未找到 blackscreen_text 组件,黑屏大字段落用计时器占位")
		await get_tree().create_timer(TEXT1_HOLD + SILENCE_SECONDS).timeout

	# ---- 眼睑睁眼过场 → 三章 ----
	# ch3 关卡未搭建前,MainGame 会 push_warning 回退占位场景(任务12 待做)
	GameState.advance_level()  # ch2_lv4 → ch3,返回 "chapter"
	GameState.chapter_intro_pending = true
	get_tree().change_scene_to_file("res://src/MainGame.tscn")


## 4 枚光片的起飞位置=HUD 四枚符号中心;找不到 HUD 时兜底右上角。
func _hud_symbol_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	var hud := get_parent().get_node_or_null("HUD")
	for i in 4:
		var sym: Control = hud.get_node_or_null("Symbols/S%d" % i) if hud else null
		if sym:
			centers.append(sym.global_position + sym.size * 0.5)
		else:
			centers.append(get_viewport_rect().size * Vector2(0.9, 0.1))
	return centers


## 单枚光片飞行:Tween 0.8s ease_out + 粒子轨迹,到达后融入锁扣(消散)。
func _fly_shard(from: Vector2, to: Vector2, index: int) -> void:
	var shard := TextureRect.new()
	shard.texture = load(FRAGMENT_TEXTURES[index])
	shard.size = Vector2(64, 64)
	shard.position = from - shard.size * 0.5
	add_child(shard)

	var trail := GPUParticles2D.new()
	trail.amount = 8
	trail.lifetime = 0.3
	trail.texture = _pixel_texture()
	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 30.0
	trail.process_material = mat
	shard.add_child(trail)

	var tw := create_tween()
	tw.tween_property(shard, "position", to - shard.size * 0.5, SHARD_FLIGHT) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		trail.emitting = false
		shard.queue_free())


## 锁扣发光:一次性粒子爆发。
func _spawn_lock_burst(at: Vector2) -> void:
	var burst := GPUParticles2D.new()
	burst.amount = 32
	burst.lifetime = 0.6
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.texture = _pixel_texture()
	burst.top_level = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 120.0
	mat.initial_velocity_max = 320.0
	mat.gravity = Vector3.ZERO
	mat.damping_min = 60.0
	mat.damping_max = 120.0
	burst.process_material = mat
	add_child(burst)
	burst.global_position = at
	burst.restart()


func _play_sfx(path: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = -6.0
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


func _pixel_texture() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)
