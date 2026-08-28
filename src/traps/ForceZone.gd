extends TrapBase
# ForceZone 外力区域:传送带(+x)/账单风(-x),damage=0 不致死。
# 对区域内的 CharacterBody2D 持续施加 config.force 加速度。
# 阵风模式:gust_on>0 时按 吹gust_on秒/停gust_off秒 循环(关4账单风=1.5s吹/2.0s停)。

var _gust_active := true
var _loop_gen := -1  # 自由阵风循环已启动的代际标记(-1=未启动/节拍驱动)


func _on_ready() -> void:
	if config.gust_on > 0.0:
		if config.beat_sync:
			_gust_beat_boot()  # 阵风按拍启停;无音乐时回退自由定时
		else:
			_gust_loop()


func _gust_beat_boot() -> void:
	if not await _wait_conductor():
		_gust_loop()
		return
	# 之后阵风由 _on_beat 按拍驱动,无需循环体


# 阵风对拍(任务3):吹 gust_on 拍 / 停 gust_off 拍,相位用连续拍计数,跨循环不回卷
func _on_beat(n: int) -> void:
	super._on_beat(n)
	if config.gust_on <= 0.0 or not config.beat_sync or not _beat_alive:
		return
	var on_beats := maxi(roundi(config.gust_on / Conductor.SEC_PER_BEAT), 1)
	var off_beats := maxi(roundi(config.gust_off / Conductor.SEC_PER_BEAT), 1)
	_gust_active = _beat_abs % (on_beats + off_beats) < on_beats
	if sprite:
		sprite.modulate = Color.WHITE if _gust_active else Color(1, 1, 1, 0.3)  # 停风期变淡


func _gust_loop() -> void:
	var gen := _gen
	_loop_gen = gen  # 标记:本陷阱走自由定时(死亡重置后按此重排)
	while is_inside_tree() and gen == _gen:
		_gust_active = true
		sprite.modulate = Color.WHITE
		await get_tree().create_timer(config.gust_on).timeout
		if gen != _gen:
			return  # 代际作废:旧循环退出,新循环由 reset_trap 重排
		_gust_active = false
		sprite.modulate = Color(1, 1, 1, 0.3)  # 停风期变淡
		await get_tree().create_timer(config.gust_off).timeout
		if gen != _gen:
			return


func _physics_process(delta: float) -> void:
	if not _gust_active:
		return
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			# 直接位移推动:玩家控制器每帧重写 velocity,加速度叠加会被吃掉/失控,
			# 传送带/风的正确语义是"载着你走",用位置推动。
			body.position += config.push * delta


func reset_trap() -> void:
	var was_free := _loop_gen >= 0  # 先记驱动方式,super 会推进代际
	super.reset_trap()
	_gust_active = true  # 相位归零:回到"吹"态
	if was_free and is_inside_tree():
		_gust_loop()  # 自由定时:旧循环已随代际退出,从"吹"相位重排
	# 节拍驱动:无需循环体,下一拍 _on_beat 按连续拍计数自动校正启停
