extends Control

@onready var video: VideoStreamPlayer = $VideoStreamPlayer
@onready var hold_timer: Timer = $HoldTimer

var _skipped := false


func _ready() -> void:
	if video.stream == null:
		# OP 视频缺失(ogv 未转码):不卡死,直接进游戏
		push_warning("[OP] 视频流缺失,跳过 OP 直接进游戏")
		_go_to_main()
		return
	video.finished.connect(_on_video_finished)
	hold_timer.timeout.connect(_on_hold_timer_timeout)


func _unhandled_input(event: InputEvent) -> void:
	# 长按任意键 1 秒可跳过：按下开始计时，松开取消
	if event is InputEventKey:
		if event.pressed:
			hold_timer.start()
		else:
			hold_timer.stop()


func _on_video_finished() -> void:
	_go_to_main()


func _on_hold_timer_timeout() -> void:
	_go_to_main()


func _go_to_main() -> void:
	if _skipped:
		return
	_skipped = true
	GameState.reset_run()  # 开新一局:清零关卡链/章节/光片(通关回主菜单后再进,进度不残留)
	get_tree().change_scene_to_file("res://src/MainGame.tscn")