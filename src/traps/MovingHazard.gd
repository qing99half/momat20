extends TrapBase
# MovingHazard 位移轨迹陷阱:config.motion 选择运动模式。
#   0=摆锤:鸡毛掸子,正弦旋转 ±amplitude 度,周期 period 秒(锚点顶部,config.anchor_top=true)
#   1=坠落:酒瓶,待命 period 秒 → 阴影预警 warn_duration → 白闪2帧 → 坠落 fall_distance px

const FALL_SPEED := 400.0  # 坠落速度(px/s)

var _t := 0.0
var _origin := Vector2.ZERO
var _falling := false           # 坠落模式:仅坠落途中致死
var _fall_tween: Tween = null   # 坠落 Tween(死亡重置时 kill)
var _loop_gen := -1             # 自由坠落循环已启动的代际标记(-1=未启动/节拍驱动)


func _on_ready() -> void:
	_origin = position
	if config.motion == 0:
		trap_activated.emit()  # 摆锤开始摆动
	elif config.beat_sync:
		_beat_mode_boot(_fall_loop)  # 酒瓶对拍坠落;无音乐时回退自由定时
	else:
		_fall_loop()


func _dangerous() -> bool:
	if config.motion == 1:
		return config.damage > 0 and _falling
	return super._dangerous()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if config.motion == 0:
		_t += delta
		# 摆锤相位锁定(任务3):直读 Conductor 音频时钟逐帧校正,
		# 使周期整数倍拍上摆锤过中点(rotation=0),漂移超 epsilon 即吸附回拍网格
		var c := Conductor.instance
		if config.beat_sync and c != null and c.state == Conductor.State.PLAYING:
			var p := config.period
			var now := c.get_abs_beat() * Conductor.SEC_PER_BEAT
			var diff := fposmod(_t - now + p * 0.5, p) - p * 0.5
			if absf(diff) > Conductor.EPSILON * Conductor.SEC_PER_BEAT:
				_t -= diff
		rotation = sin(_t * TAU / config.period) * deg_to_rad(config.amplitude)
	elif _falling:
		_poll_hits()  # 坠落速度快,body_entered可能落在落地之后,运动期间轮询兜底


func _fall_loop() -> void:
	var gen := _gen
	_loop_gen = gen  # 标记:本陷阱走自由定时(死亡重置后按此重排)
	while is_inside_tree() and gen == _gen:
		# 待命
		_falling = false
		await get_tree().create_timer(config.period).timeout
		if gen != _gen:
			return  # 代际作废:旧循环退出,新循环由 reset_trap 重排
		await _run_fire_sequence()  # 自由定时:不做落拍等待


# 击发序列·前半(任务3:基类排程调用,trap_activated 由基类在拍点上发射)
func _fire_warn_flash() -> void:
	var gen := _gen
	# 第一层预警:阴影/摇晃(持续 warn_duration)
	play_warning(config.warn_duration)
	await get_tree().create_timer(config.warn_duration).timeout
	if gen != _gen:
		return  # 死亡重置:预警中止,位置/调制已由 reset_trap 复原
	# 第二层:击发前白闪2帧
	await flash_white()


# 击发序列·后半:坠落激活窗口
func _fire_activate() -> void:
	var gen := _gen
	# 坠落(加速下坠)
	_falling = true
	var fall_time := config.fall_distance / FALL_SPEED
	_fall_tween = create_tween()
	_fall_tween.tween_property(self, "position:y", _origin.y + config.fall_distance, fall_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if not await _await_tween(_fall_tween, gen):
		return  # 死亡重置:坠落 Tween 已 kill,位置由 reset_trap 复原
	# 落地后仍保持0.5s致死(碎玻璃茬),再回位(碎裂粒子任务4接)
	await get_tree().create_timer(0.5).timeout
	if gen != _gen:
		return
	_falling = false
	position = _origin


func reset_trap() -> void:
	var was_free := _loop_gen >= 0  # 先记驱动方式,super 会推进代际
	super.reset_trap()
	_t = 0.0        # 摆锤相位归零(回到起始角度)
	rotation = 0.0
	position = _origin
	_falling = false
	if _fall_tween and _fall_tween.is_valid():
		_fall_tween.kill()
	_fall_tween = null
	if config.motion == 1 and was_free and is_inside_tree():
		_fall_loop()  # 自由定时:旧循环已随代际退出,从待命相位重排
