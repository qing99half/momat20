extends Node2D
# 三章相遇(任务12.2~12.5):演出关,不走地图编辑器 JSON(MainGame 特判加载本场景)。
# 12.4 二段式:阶段一按住←背景才滚(松键0.3s缓出,阻-09方案A),两人原地走;
# 滚到头进阶段二:背景停滚,两人真实位移相向而行;
# 12.5 门前相距<=1格继续按←→双人并肩推门→M3停→V1童声→白光铺满→ED占位。

# ---- 12.4 滚屏参数 ----
const SCROLL_SPEED := 100.0   # 虚拟滚屏速度:2267/100≈22.7s滚完(策划阶段一20~25s)
const SCROLL_MAX := 2267.0    # 滚到头:远景0.3×2267≈680px,2000px长图右缘恰对齐屏幕右缘=长图展示完
const FAR_SCALE := 0.3        # 远景系数(策划)
const MID_SCALE := 0.5        # 中景系数(策划)
const SCROLL_EASE := 0.3      # 松键缓出时长(秒)
const MID_TILES := 4          # 中景1000px×4块:总滚0.5×2267≈1133px,全程盖住屏幕

# ---- 12.5 相遇/推门 ----
const DOOR_X := 1000.0        # 门中心X=50格
const MEET_GAP := 24.0        # 两人停靠间距(门两侧各12px)
const DOOR_HALF := "res://assets/art/ch3/prop_ch3_door_halfopen.png"
const DOOR_OPEN_DEG := -30.0  # 门半开旋转约30°(绕左铰链向左内开)

# ---- 素材(真素材优先,占位兜底) ----
const GROUND_REAL := "res://assets/art/ch3/ground_ch3_5w_real.png"    # 左半=母亲侧(写实灰调)
const GROUND_DREAM := "res://assets/art/ch3/ground_ch3_5w_dream.png"  # 右半=女儿侧(梦核彩色)
const BGM_M3 := "res://assets/audio/bgm_m3_a.ogg"
const BGM_M3_PH := "res://assets/placeholder/placeholder_M3.wav"
# V1 童声在 ED 视频音轨里(ed.ogv),此处不单独引用
const SFX_DOOR := "res://assets/audio/sfx_door_push.ogg"
const SFX_STEPS := "res://assets/audio/sfx_footsteps_ch3.ogg"

var _scroll := 0.0
var _scroll_vel := 0.0
var _phase := 1
var _push_started := false
var _step_t := 0.0  # 脚步声步频计时(0.35s/步)

# 注:_player/_mother 故意用 = (Variant 动态派发):Player.gd 无 class_name,
# 用 := 会推断成 Node 基类,访问 chapter3_mode/door_x 等脚本属性编译报错。
@onready var _player = $Player
@onready var _mother = $Mother
@onready var _far := $Background/Far as Sprite2D
@onready var _mid := $Background/Mid as Sprite2D
@onready var _door := $Door as Sprite2D
var _mid_tiles: Array[Sprite2D] = []
var _bgm: AudioStreamPlayer
var _steps: AudioStreamPlayer


func _ready() -> void:
	# 12.2:玩家三章模式;阶段一位置锁定(原地走);自带相机停用——三章镜头固定(场景 Camera2D)
	_player.chapter3_mode = true
	_player.ch3_walk_locked = true
	(_player.get_node("Camera2D") as Camera2D).enabled = false
	(_player.get_node("Sprite2D") as Sprite2D).flip_h = true  # 女儿在右侧向左走,面朝左
	# 12.3:母亲门位置(回望判定用)
	_mother.door_x = DOOR_X
	# 中景平铺 MID_TILES 块(0~4000px)
	_mid_tiles.append(_mid)
	for i in range(1, MID_TILES):
		var t := _mid.duplicate() as Sprite2D
		_mid.get_parent().add_child(t)
		_mid_tiles.append(t)
	_ground_skin()
	_bgm = _make_audio(BGM_M3, BGM_M3_PH, 0.0, true, true)
	_steps = _make_audio(SFX_STEPS, "", -6.0, false, false)  # 0.1s 单步样本,禁止循环(循环=10Hz 嗡鸣);由 _process 按步频触发


## 地面换皮:左半写实(母亲侧)/右半梦核(女儿侧),5w条带(100×80)各10块;缺素材则保留白盒色块
func _ground_skin() -> void:
	for style in ["real", "dream"]:
		var path := GROUND_REAL if style == "real" else GROUND_DREAM
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		for i in 10:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.position = Vector2((i if style == "real" else i + 10) * 100.0, 0.0)
			$Ground.add_child(s)


func _make_audio(real: String, ph: String, vol: float, loop: bool, autoplay: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var path := real if ResourceLoader.exists(real) else ph
	if path != "" and ResourceLoader.exists(path):
		p.stream = load(path)
		if loop:
			if p.stream is AudioStreamOggVorbis:
				p.stream.loop = true
			elif p.stream is AudioStreamWAV:
				p.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	p.volume_db = vol
	add_child(p)
	if autoplay and p.stream:
		p.play()
	return p


func _play_sfx(path: String, vol: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = vol
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


func _process(delta: float) -> void:
	if _push_started:
		return
	var left := Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A)
	if _phase == 1:
		# 阶段一:只有按住←背景才滚,松键0.3s缓出(阻-09:输入因果0.5s内可确认,防判死机)
		var target := SCROLL_SPEED if left else 0.0
		_scroll_vel = move_toward(_scroll_vel, target, SCROLL_SPEED / SCROLL_EASE * delta)
		_scroll = minf(_scroll + _scroll_vel * delta, SCROLL_MAX)
		_far.position.x = -_scroll * FAR_SCALE
		for i in _mid_tiles.size():
			_mid_tiles[i].position.x = i * 1000.0 - _scroll * MID_SCALE
		if _scroll >= SCROLL_MAX:
			_phase = 2
			_player.ch3_walk_locked = false
			_mother.walk_in_place = false
			_mother.walking = true
			print("[三章] 背景滚到头→阶段二:两人真实位移相向而行")
	else:
		# 阶段二:背景停滚;母亲到门左12px停等(切回望帧),女儿被夹在门右12px
		_mother.walking = _mother.global_position.x < DOOR_X - MEET_GAP / 2.0
		if _player.global_position.x < DOOR_X + MEET_GAP / 2.0:
			_player.global_position.x = DOOR_X + MEET_GAP / 2.0
		# 门前相遇:继续按←触发双人推门(12.5)——这次←同时完成"靠近她"和"推门"
		if left and _player.global_position.x - _mother.global_position.x <= MEET_GAP + 1.0:
			_start_push()
	# 脚步声:任一方在走即按步频触发(0.1s 单步样本;50px/s 慢走≈0.35s/步,循环播放会变 10Hz 嗡鸣)
	if _steps and _steps.stream:
		if left or _mother.walking:
			_step_t -= delta
			if _step_t <= 0.0:
				_steps.play()
				_step_t = 0.35
		else:
			_step_t = 0.0  # 停走重置,下一步立即出声


func _start_push() -> void:
	_push_started = true
	if _steps:
		_steps.playing = false
	print("[三章] 门前相遇→双人并肩推门(12.5)")
	# 母女并肩定格推门帧(两个sprite靠在一起,手在同一位置=双人并肩推门,中-26)
	_player.global_position.x = DOOR_X + 10.0
	_player.ch3_push_pose()
	_mother.global_position.x = DOOR_X - 10.0
	_mother.push_pose()
	# 门:换半开图,绕左铰链(x=970)旋转约30°
	if ResourceLoader.exists(DOOR_HALF):
		_door.texture = load(DOOR_HALF)
	_door.position = Vector2(970.0, 280.0)
	_door.offset = Vector2(30.0, 0.0)
	var door_tw := create_tween()
	door_tw.tween_property(_door, "rotation_degrees", DOOR_OPEN_DEG, 0.3)
	_play_sfx(SFX_DOOR, -6.0)
	# M3推至最高(B终止式)→推门瞬间全静音
	if _bgm:
		_bgm.stop()
	# V1 童声由 ED 视频自带音轨承接(ed.ogv 开场即白光+清唱,与白光转场无缝衔接,
	# 不再单独播 vocal_v1.ogg——避免场景切换时腰斩音轨/与视频音轨双重播放)
	print("停M3,ED视频接V1")
	# 白光0.5s铺满(ColorRect占位;真白光扩散shader到位后替换)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var white := ColorRect.new()
	white.color = Color.WHITE
	white.size = Vector2(640.0, 360.0)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white.modulate.a = 0.0
	layer.add_child(white)
	var flash := create_tween()
	flash.tween_property(white, "modulate:a", 1.0, 0.5)
	await flash.finished
	# 白光满屏 → ED视频(不可跳过)→ 开发者的话 → 主菜单(H36~44 接入完成)
	get_tree().change_scene_to_file("res://src/flow/EDScene.tscn")
