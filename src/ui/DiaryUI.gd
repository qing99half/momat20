extends Control

## 打字节奏(2026-08-30 文案方案):5 秒均分仍是基准,但间隔钳制在 [0.035, 0.12] 秒——
## 短文案(约47字)仍按 5 秒打完;长文案(200+字)触底 0.035 秒/字保可读性(约 6.7~7.4 秒)。
const TOTAL_TYPE_SECONDS := 5.0
const MIN_CHAR_INTERVAL := 0.035  # 可读性下限:低于此值文字变滚屏,无法阅读
const MAX_CHAR_INTERVAL := 0.12   # 超短文案不慢于原有节奏

## 一章:字迹模糊(正文压半透明模拟)+笔尖沙沙(S7);二章:逐字清晰+纸页摩挲(S6)。
## 音效约定:打字期间循环、打完即停(0.035s/字的逐字触发会连成蜂鸣,故用循环音,文案方案第三节认可此口径)。
const PEN_SFX := "res://assets/audio/sfx_pen_writing.ogg"
const PAPER_SFX := "res://assets/audio/sfx_diary_open.ogg"
const BLUR_ALPHA := 0.45

@onready var date_label: Label = $DateLabel
@onready var body_text: RichTextLabel = $BodyText
@onready var skip_hint: Label = $SkipHint

## 阶段: 0 = 日期逐字, 1 = 正文逐字, 2 = 完成
const PHASE_DATE := 0
const PHASE_BODY := 1
const PHASE_DONE := 2

var _phase := PHASE_DONE
var _char_index := 0
var _elapsed := 0.0
## 每个字符的打字间隔(秒)，在 show_diary() 里按总字数均分得出。
var _char_interval := 0.05

var _date_text := ""
var _body_text := ""

var _sfx: AudioStreamPlayer


func _ready() -> void:
	add_to_group("diary_ui")  # 日记桌(DiaryDesk)按组查找,零硬引用
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -6.0
	add_child(_sfx)


## 章节音效:打字期间循环,打完即停。
func _play_sfx(path: String) -> void:
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		stream.loop = true  # ogg 真素材:打字期间循环,打完即停
	_sfx.stream = stream
	_sfx.play()


func show_diary(date: String, text: String, chapter: int) -> void:
	_date_text = date
	_body_text = text

	date_label.text = date
	body_text.text = text
	date_label.visible_ratio = 0.0
	body_text.visible_ratio = 0.0
	skip_hint.visible = false  # 日期阶段不可跳过(D-505),不显示提示;进正文阶段才亮"按任意键加速"

	# 章节差异:一章字迹模糊+笔尖沙沙;二章逐字清晰+纸页摩挲(日期先行=日期阶段恒在最前)
	if chapter >= 2:
		body_text.modulate = Color.WHITE
		_play_sfx(PAPER_SFX)
	else:
		body_text.modulate = Color(1.0, 1.0, 1.0, BLUR_ALPHA)
		_play_sfx(PEN_SFX)

	_phase = PHASE_DATE
	_char_index = 0
	_elapsed = 0.0
	# 每字间隔 = 总时长 / 总字数,钳制在 [MIN, MAX]:短文案仍 5 秒打完,长文案触底 0.035s/字
	_char_interval = clampf(TOTAL_TYPE_SECONDS / float(max(_date_text.length() + _body_text.length(), 1)),
			MIN_CHAR_INTERVAL, MAX_CHAR_INTERVAL)
	visible = true
	# 叠化进入(步骤8.4:黑场→日记,约0.5s淡入)
	modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.5)


func _process(delta: float) -> void:
	if not visible or _phase == PHASE_DONE:
		return

	# 累计时间，每满一个字符间隔揭示一字；用 while 处理跳帧，严格保证总共 5 秒
	_elapsed += delta
	while _phase != PHASE_DONE and _elapsed >= _char_interval:
		_elapsed -= _char_interval
		_reveal_one_char()

	_update_skip_hint()


## 揭示下一个字符(日期 → 正文顺序)。
func _reveal_one_char() -> void:
	if _phase == PHASE_DATE:
		_char_index += 1
		date_label.visible_ratio = float(_char_index) / float(max(_date_text.length(), 1))
		if _char_index >= _date_text.length():
			_phase = PHASE_BODY
			_char_index = 0
			# 日期打完的瞬间亮出加速提示(文案方案:此时才允许按键,提示呼吸闪烁维持原逻辑)
			skip_hint.text = "按任意键加速"
			skip_hint.visible = true
	elif _phase == PHASE_BODY:
		_char_index += 1
		body_text.visible_ratio = float(_char_index) / float(max(_body_text.length(), 1))
		if _char_index >= _body_text.length():
			_phase = PHASE_DONE

	if _phase == PHASE_DONE:
		_finish()


func _finish() -> void:
	_phase = PHASE_DONE
	skip_hint.visible = false
	_sfx.stop()
	# 日记关闭:广播 diary_finished,由 HUD 监听后触发光片飞入。
	visible = false
	EventBus.diary_finished.emit()


func _update_skip_hint() -> void:
	if not skip_hint.visible:
		return
	var t := Time.get_ticks_msec() / 1000.0
	# 日期阶段半透明固定；正文阶段呼吸闪烁
	if _phase == PHASE_BODY:
		skip_hint.modulate.a = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * 3.0))
	else:
		skip_hint.modulate.a = 0.6


func _unhandled_input(event: InputEvent) -> void:
	# 日期打完前禁止跳过(D-505)；仅在正文阶段允许按键加速
	if _phase != PHASE_BODY:
		return
	if event is InputEventKey and event.pressed:
		_skip_body()


func _skip_body() -> void:
	body_text.visible_ratio = 1.0
	_finish()
