class_name Conductor
extends Node
# Conductor 节拍器(任务3,H16~24)。只发 EventBus 已有信号,不新增 autoload。
#
# 结构:_ready() 内挂 3 个同步 AudioStreamPlayer(钢琴=主音轨 / 环境 / 节奏),
#   M1/M2 三分轨同起点同长度,四关靠开关分轨调浓度(D-401)——只调音量,不改播放位置。
# 拍数:beat = (钢琴轨.get_playback_position() + offset) * BPM / 60.0
# 节拍事件:每拍发射 EventBus.beat(beat_number),陷阱订阅该信号,
#   按配置的 active_beats / cooldown_beats 激活/休眠。
# 状态机:STOPPED / PLAYING / PAUSED / LOOPING。
#
# 硬约束:BPM=120.0(精确浮点);周期陷阱 period ∈ {1.0,1.5,2.0,2.5,3.0} 秒(=0.5s 一拍);
#         beat 比较 epsilon=0.05;循环点边界事件不重复/不漏触发。

enum State { STOPPED, PLAYING, PAUSED, LOOPING }
enum Track { PIANO, AMBIENT, RHYTHM }

const BPM := 120.0                                      # 精确浮点,写死
const SEC_PER_BEAT := 60.0 / BPM                        # 0.5s = 一拍
const EPSILON := 0.05                                   # beat 浮点比较容差
const VALID_PERIODS: Array[float] = [1.0, 1.5, 2.0, 2.5, 3.0]  # 周期陷阱合法 period(秒)
const MUTE_DB := -80.0                                  # 分轨"关"=静音,播放位置不动保持同步

@export var offset := 0.0                               # 校准偏移(秒),并入 beat 公式
@export var debug_print := true                         # 验收①:控制台每拍打印

var state: State = State.STOPPED

# 当前活动实例(静态注册表,非 autoload):陷阱对拍时直读音频时钟。
# play() 注册,stop_music() 注销;任意时刻至多一个在跑。
static var instance: Conductor = null

var _piano: AudioStreamPlayer                           # 主音轨:beat 只从它算
var _ambient: AudioStreamPlayer
var _rhythm: AudioStreamPlayer

var _last_emitted := -1                                 # 已发射的最后一拍(整数拍号)
var _paused_beat := 0.0                                 # 暂停时保存的拍数,恢复时校验不跳变
var _beats_enabled := true                              # false=音乐继续但节拍事件停发(任务4死亡流程用)

var _loop_enabled := false
var _loop_start_beat := 0.0
var _loop_end_beat := 0.0
var _abs_base := 0.0                                    # 绝对拍基数:每次循环回卷累加,跨循环不回卷


func _ready() -> void:
	_piano = AudioStreamPlayer.new()
	_piano.name = "PianoPlayer"
	_ambient = AudioStreamPlayer.new()
	_ambient.name = "AmbientPlayer"
	_rhythm = AudioStreamPlayer.new()
	_rhythm.name = "RhythmPlayer"
	add_child(_piano)
	add_child(_ambient)
	add_child(_rhythm)


func _process(_delta: float) -> void:
	if state != State.PLAYING:
		return
	if not _piano.playing:
		state = State.STOPPED  # 非循环时播完自然停止
		return
	var beat_f := get_current_beat()
	# 循环点:beat 回卷时先结算旧循环剩余事件,再重置
	if _loop_enabled and beat_f >= _loop_end_beat - EPSILON:
		_settle_and_rewind()
		return
	_emit_beats_up_to(beat_f)


# ---- 播放控制 ----

# 入口与策划案一致:Conductor.play(M1音频路径, 环境轨, 节奏轨)。
# 三分轨同帧同起点播放,保持同步;空路径=该轨不挂流。
func play(piano_path: String, ambient_path := "", rhythm_path := "", from_beat := 0.0) -> void:
	var piano_stream: AudioStream = load(piano_path)
	if piano_stream == null:
		push_error("Conductor: 主音轨加载失败 " + piano_path)
		return
	_piano.stream = piano_stream
	_ambient.stream = load(ambient_path) if ambient_path != "" else null
	_rhythm.stream = load(rhythm_path) if rhythm_path != "" else null
	var start_sec := maxf(from_beat * SEC_PER_BEAT - offset, 0.0)
	for p in _players():
		p.stream_paused = false
		if p.stream != null:
			p.play(start_sec)
		else:
			p.stop()
	_last_emitted = floori(from_beat + EPSILON) - 1
	_beats_enabled = true
	_abs_base = from_beat
	instance = self
	state = State.PLAYING


func pause_music() -> void:
	if state != State.PLAYING:
		return
	_paused_beat = get_current_beat()  # 暂停时保存 beat
	for p in _players():
		p.stream_paused = true  # stream_paused 保留播放位置,三轨一起冻结
	state = State.PAUSED


func resume_music() -> void:
	if state != State.PAUSED:
		return
	for p in _players():
		p.stream_paused = false
	state = State.PLAYING
	# 播放位置被保留,拍号从 _paused_beat 续走;_last_emitted 不动,不跳变
	var resumed := get_current_beat()
	if absf(resumed - _paused_beat) > EPSILON:
		push_warning("Conductor: 恢复时拍数漂移 %.3f -> %.3f" % [_paused_beat, resumed])


# 任务4死亡流程用:音乐继续,节拍事件不触发。拍号照常推进,恢复时不补发不跳变。
func stop_beats() -> void:
	_beats_enabled = false


func start_beats() -> void:
	_beats_enabled = true


func stop_music() -> void:
	for p in _players():
		p.stop()
	_last_emitted = -1
	if instance == self:
		instance = null
	state = State.STOPPED


# 任务11.6 用:音乐立即静音(直接 AudioStreamPlayer.stop())
func stop_music_immediately() -> void:
	stop_music()


# ---- 循环点 ----

# 循环区间 [start_beat, end_beat):end_beat 边界拍归新循环,保证边界事件不重复/不漏。
func set_loop(start_beat: float, end_beat: float) -> void:
	if end_beat <= start_beat:
		push_error("Conductor: 循环区间非法 %.2f ~ %.2f" % [start_beat, end_beat])
		return
	_loop_start_beat = start_beat
	_loop_end_beat = end_beat
	_loop_enabled = true


func clear_loop() -> void:
	_loop_enabled = false


func is_looping_enabled() -> bool:
	return _loop_enabled


# ---- 分轨浓度(D-401):只调音量,不改播放位置 ----

func set_track_enabled(track: Track, enabled: bool) -> void:
	_track_player(track).volume_db = 0.0 if enabled else MUTE_DB


func set_track_volume(track: Track, db: float) -> void:
	_track_player(track).volume_db = db


func is_track_enabled(track: Track) -> bool:
	return _track_player(track).volume_db > MUTE_DB


# ---- 查询 ----

func get_current_beat() -> float:
	if _piano.stream == null:
		return 0.0
	return (_piano.get_playback_position() + offset) * BPM / 60.0


# 绝对拍(跨循环不回卷的连续时钟):陷阱对拍排程用它,不受 beat 信号回卷影响
func get_abs_beat() -> float:
	if _loop_enabled:
		return _abs_base + (get_current_beat() - _loop_start_beat)
	return get_current_beat()


# 周期陷阱 period 校验:必须 ∈ {1.0,1.5,2.0,2.5,3.0} 秒
static func is_valid_period(p: float) -> bool:
	for v in VALID_PERIODS:
		if absf(p - v) <= EPSILON:
			return true
	return false


# ---- 内部 ----

func _players() -> Array[AudioStreamPlayer]:
	return [_piano, _ambient, _rhythm]


func _track_player(track: Track) -> AudioStreamPlayer:
	match track:
		Track.PIANO:
			return _piano
		Track.AMBIENT:
			return _ambient
		Track.RHYTHM:
			return _rhythm
	return _piano


# 把拍号推进到 beat_f(含 epsilon 容差),跨几拍补几拍,不漏触发
func _emit_beats_up_to(beat_f: float) -> void:
	var target := floori(beat_f + EPSILON)
	while _last_emitted < target:
		_last_emitted += 1
		if _beats_enabled:
			EventBus.beat.emit(_last_emitted)
		if debug_print:
			print("[Conductor] beat %d (t=%.3fs)" % [_last_emitted, _piano.get_playback_position()])


# beat 回卷:先结算旧循环剩余拍,再三轨同步 seek 回循环起点并重置拍号
func _settle_and_rewind() -> void:
	state = State.LOOPING
	# 1) 结算旧循环剩余事件:最后一拍 = loop_end 的前一整拍(边界拍归新循环,防重复)
	var last_in_loop := ceili(_loop_end_beat - EPSILON) - 1
	_emit_beats_up_to(float(last_in_loop))
	# 2) 重置:三轨同步 seek 回循环起点(只改播放位置,音量不动)
	var start_sec := maxf(_loop_start_beat * SEC_PER_BEAT - offset, 0.0)
	for p in _players():
		if p.stream != null:
			p.seek(start_sec)
	# 3) 拍号回卷:新循环从起点第一拍重新发射,边界拍不丢
	_last_emitted = floori(_loop_start_beat + EPSILON) - 1
	_abs_base += _loop_end_beat - _loop_start_beat  # 绝对拍时钟连续推进,陷阱排程不受回卷影响
	if debug_print:
		print("[Conductor] 循环回卷 -> beat %.1f 重来" % _loop_start_beat)
	state = State.PLAYING
