extends ColorRect
# 幕间黑屏大字:纯黑全屏,白色大字居中,逐字浮现(每字 0.1 秒)。
# 大字"妈妈"等单独一屏时传入 big=true:字号加倍(48→96),同时让音乐立即骤停。

## 普通文案字号(px);大字翻倍为 2 倍。
const BASE_FONT_SIZE := 48

## 每字浮现间隔(秒)。
const CHAR_SECONDS := 0.1

@onready var _label: Label = $Label

var _revealing := false
var _char_index := 0
var _total_chars := 0
var _elapsed := 0.0


func _ready() -> void:
	_label.visible_ratio = 0.0


func show_text(text: String, big: bool) -> void:
	_label.text = text
	_label.visible_ratio = 0.0
	_label.add_theme_font_size_override("font_size", BASE_FONT_SIZE * (2 if big else 1))

	# 「妈妈」等大字单独一屏:音乐立即骤停(见 README.md)。
	if big:
		Conductor.stop_music_immediately()

	_total_chars = text.length()
	_char_index = 0
	_elapsed = 0.0
	_revealing = _total_chars > 0


func _process(delta: float) -> void:
	if not _revealing:
		return

	_elapsed += delta
	# 每满 0.1 秒揭示一字;用 while 处理跳帧。
	while _revealing and _elapsed >= CHAR_SECONDS:
		_elapsed -= CHAR_SECONDS
		_char_index += 1
		_label.visible_ratio = float(_char_index) / float(_total_chars)
		if _char_index >= _total_chars:
			_revealing = false