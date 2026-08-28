extends Control

## 硬性约束：整段文字(日期+正文)总计 5 秒打完。
const TOTAL_TYPE_SECONDS := 5.0

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


func _ready() -> void:
	# 【临时·视觉检验用】运行即触发,检验完成后删除此行
	show_diary("1993年", "窗外的雨下了整整一夜。我把今天发生的事，一笔一笔写进这页纸里。等很多年以后，再回来看看。", 1)


func show_diary(date: String, text: String, chapter: int) -> void:
	_date_text = date
	_body_text = text

	date_label.text = date
	body_text.text = text
	date_label.visible_ratio = 0.0
	body_text.visible_ratio = 0.0
	skip_hint.visible = true

	_phase = PHASE_DATE
	_char_index = 0
	_elapsed = 0.0
	# 每字间隔 = 总时长 / 总字数，保证「日期 + 正文」合计恰好 5 秒
	_char_interval = TOTAL_TYPE_SECONDS / float(max(_date_text.length() + _body_text.length(), 1))
	visible = true


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