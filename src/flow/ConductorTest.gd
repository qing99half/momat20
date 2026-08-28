extends Node
# 任务3 验收自测场景(F6 运行,或命令行跑):
#   播放真 120BPM 节拍器 placeholder_M1.wav,钢琴/环境/节奏三轨挂同一份流。
#   控制台应每 0.5s 打印一次 beat(0,1,2...),拍号连续无跳变。
# 自动化验收脚本(无需按键):
#   t≈2.3s 暂停 → t≈4.3s 恢复(验证拍号接上不跳)
#   循环区间 [0,8) 拍,4s 一圈(验证循环点边界事件不重复/不漏)
#   t=14s 自动退出。
# 手动按键:空格=暂停/恢复  L=开/关循环  Q=停止  1/2/3=钢琴/环境/节奏分轨开关(D-401)

const M1 := "res://assets/placeholder/placeholder_M1.wav"
const LOOP_END := 8.0          # 测试用短循环:8 拍 = 4s 一圈
const QUIT_AT := 14.0

var _conductor: Conductor
var _elapsed := 0.0
var _paused_done := false
var _resumed_done := false


func _ready() -> void:
	EventBus.beat.connect(_on_beat)
	_conductor = Conductor.new()
	_conductor.name = "Conductor"
	add_child(_conductor)
	_conductor.play(M1, M1, M1)
	_conductor.set_loop(0.0, LOOP_END)
	print("[Test] 开始:120BPM,每 0.5s 应打印一次 beat;循环 [0,%.0f) 拍" % LOOP_END)


func _process(delta: float) -> void:
	_elapsed += delta
	if not _paused_done and _elapsed >= 2.3:
		_paused_done = true
		_conductor.pause_music()
		print("[Test] >>> 暂停于 beat %.3f,2 秒内不应再有 beat 打印" % _conductor.get_current_beat())
	elif not _resumed_done and _elapsed >= 4.3:
		_resumed_done = true
		_conductor.resume_music()
		print("[Test] >>> 恢复,拍号应从上面暂停值续走、不跳变")
	elif _elapsed >= QUIT_AT:
		print("[Test] 结束。检查:①每拍一行 ②暂停期无打印 ③恢复后接上前值 ④循环只到 beat %d 且回卷后从 0 重来" % (int(LOOP_END) - 1))
		get_tree().quit()


func _on_beat(n: int) -> void:
	print("[Test] EventBus.beat -> %d" % n)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE:
			if _conductor.state == Conductor.State.PLAYING:
				_conductor.pause_music()
				print("[Test] >>> 手动暂停于 beat %.3f" % _conductor.get_current_beat())
			elif _conductor.state == Conductor.State.PAUSED:
				_conductor.resume_music()
				print("[Test] >>> 手动恢复")
		KEY_L:
			if _conductor.is_looping_enabled():
				_conductor.clear_loop()
				print("[Test] >>> 循环关")
			else:
				_conductor.set_loop(0.0, LOOP_END)
				print("[Test] >>> 循环开 [0,%.0f)" % LOOP_END)
		KEY_Q:
			_conductor.stop_music_immediately()
			print("[Test] >>> 停止")
		KEY_1:
			_conductor.set_track_enabled(Conductor.Track.PIANO, not _conductor.is_track_enabled(Conductor.Track.PIANO))
		KEY_2:
			_conductor.set_track_enabled(Conductor.Track.AMBIENT, not _conductor.is_track_enabled(Conductor.Track.AMBIENT))
		KEY_3:
			_conductor.set_track_enabled(Conductor.Track.RHYTHM, not _conductor.is_track_enabled(Conductor.Track.RHYTHM))
