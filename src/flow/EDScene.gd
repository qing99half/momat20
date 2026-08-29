extends Control
# ED 视频(H36~44 接入):不可跳过(策划流程表:ED 不可跳)。播完 → 开发者的话 → 主菜单。
# ogv 缺失时黑屏文字占位 3s 后进开发者的话(图片序列保底的精神,先不卡死)。


func _ready() -> void:
	var video := $VideoStreamPlayer as VideoStreamPlayer
	if video.stream == null:
		push_warning("[ED] 视频流缺失,黑屏占位 3s")
		$FallbackLabel.visible = true
		await get_tree().create_timer(3.0).timeout
		_go_next()
		return
	video.finished.connect(_go_next)
	video.play()


func _go_next() -> void:
	get_tree().change_scene_to_file("res://src/flow/DevWordsScene.tscn")
