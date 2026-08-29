extends Control
# 翻页转场:纸页从屏幕右侧外向左横扫,遮满全屏(扫到一半)时切换场景,扫完后销毁自身。

## 翻页音效(S8 真素材)。
const PAGE_TURN_SFX := "res://assets/audio/sfx_page_turn.ogg"

## 纸页横扫总时长(秒)。
const SWEEP_SECONDS := 0.8

@onready var _page: TextureRect = $Page

var _tween: Tween
var _pending_scene := ""
var _sfx: AudioStreamPlayer
var _switch_timer: Timer


func _ready() -> void:
	# 闲置时整页隐藏:停靠在屏幕右缘外时窗口变宽会露馅(深色页片右条),直接不画最稳
	_page.visible = false

	_sfx = AudioStreamPlayer.new()
	_sfx.stream = load(PAGE_TURN_SFX)
	_sfx.volume_db = -6.0
	add_child(_sfx)

	_switch_timer = Timer.new()
	_switch_timer.one_shot = true
	_switch_timer.timeout.connect(_on_switch_scene)
	add_child(_switch_timer)


func play_turn(next_scene_path: String) -> void:
	_pending_scene = next_scene_path
	_page.position.x = _screen_width()
	_page.visible = true  # 演出开始才显示(闲置恒隐藏)

	_sfx.play()

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	# 从屏幕右侧外横扫到左侧外,全程线性。
	_tween.tween_property(_page, "position:x", -_screen_width(), SWEEP_SECONDS)\
		.set_trans(Tween.TRANS_LINEAR)
	_tween.tween_callback(queue_free)

	# 扫到一半(纸页遮满全屏)时切换场景。
	_switch_timer.start(SWEEP_SECONDS / 2.0)


func _screen_width() -> float:
	return get_viewport_rect().size.x


func _on_switch_scene() -> void:
	if _pending_scene.is_empty():
		return
	get_tree().change_scene_to_file(_pending_scene)
	_pending_scene = ""