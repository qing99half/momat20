extends Control
# 二章HUD:右上角4枚记忆光片符号。◇=未获得(半透明),◆=已获得。
# 日记读完(EventBus.diary_finished)时,光片从屏幕中央飞入对应符号并点亮。

## 光片获得音效"叮"(占位 S9;真素材 sfx_light_shard.ogg 到位后替换)。
const FRAGMENT_SFX := "res://assets/placeholder/placeholder_S9.wav"

## 光片飞行时长(秒),照任务写死。
const FLIGHT_SECONDS := 0.8

## 符号常驻透明度(未获得与已获得都半透明)。
const IDLE_ALPHA := 0.4

## 每枚光片的占位素材(真素材 ui_memory_fragment_1~4.png 到位后替换)。
const FRAGMENT_TEXTURES := [
	"res://assets/placeholder/placeholder_ui_memory_fragment_1.png",
	"res://assets/placeholder/placeholder_ui_memory_fragment_2.png",
	"res://assets/placeholder/placeholder_ui_memory_fragment_3.png",
	"res://assets/placeholder/placeholder_ui_memory_fragment_4.png",
]

@onready var _symbols: Array[Label] = [$Symbols/S0, $Symbols/S1, $Symbols/S2, $Symbols/S3]

var _collected := 0
var _sfx: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_sfx = AudioStreamPlayer.new()
	_sfx.stream = load(FRAGMENT_SFX)
	add_child(_sfx)

	for s in _symbols:
		s.text = "◇"
		s.modulate.a = IDLE_ALPHA

	EventBus.diary_finished.connect(_on_diary_finished)


func _on_diary_finished() -> void:
	collect_fragment()


## 点亮下一枚未点亮的符号,并播放光片飞行动画。
func collect_fragment() -> void:
	if _collected >= _symbols.size():
		return
	var target := _symbols[_collected]
	_collected += 1
	_fly_fragment(target)


## 光片从屏幕中央飞向目标符号,0.8s ease_out,到达后点亮。
func _fly_fragment(target: Label) -> void:
	var shard := TextureRect.new()
	shard.texture = load(FRAGMENT_TEXTURES[_collected - 1])
	shard.size = Vector2(64, 64)
	# 起点:屏幕中央(笔记本位置)。
	shard.position = size * 0.5 - shard.size * 0.5
	add_child(shard)

	var end := target.global_position + target.size * 0.5 - shard.size * 0.5
	var tw := create_tween()
	tw.tween_property(shard, "position", end, FLIGHT_SECONDS)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_shard_arrive.bind(target, shard))


func _on_shard_arrive(target: Label, shard: TextureRect) -> void:
	shard.queue_free()
	target.text = "◆"
	_play_ding()
	_flash(target)


## 获得瞬间:符号高亮闪烁后回到半透明实心态。
func _flash(target: Label) -> void:
	target.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(target, "modulate:a", IDLE_ALPHA, 0.15)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(target, "modulate:a", 1.0, 0.15)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(target, "modulate:a", IDLE_ALPHA, 0.15)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_ding() -> void:
	if _sfx:
		_sfx.play()
