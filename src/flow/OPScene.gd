extends Control

@onready var video: VideoStreamPlayer = $VideoStreamPlayer
@onready var hold_timer: Timer = $HoldTimer

var _skipped := false


func _ready() -> void:
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
	get_tree().change_scene_to_file("res://src/MainGame.tscn")