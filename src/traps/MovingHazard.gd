extends TrapBase
# MovingHazard 位移轨迹陷阱:config.motion 选择运动模式。
#   0=摆锤:鸡毛掸子,正弦旋转 ±amplitude 度,周期 period 秒(锚点顶部,config.anchor_top=true)
#   1=坠落:酒瓶,待命 period 秒 → 阴影预警 warn_duration → 白闪2帧 → 坠落 fall_distance px

const FALL_SPEED := 400.0  # 坠落速度(px/s)

var _t := 0.0
var _origin := Vector2.ZERO
var _falling := false  # 坠落模式:仅坠落途中致死


func _on_ready() -> void:
	_origin = position
	if config.motion == 0:
		trap_activated.emit()  # 摆锤开始摆动
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
		rotation = sin(_t * TAU / config.period) * deg_to_rad(config.amplitude)
	elif _falling:
		_poll_hits()  # 坠落速度快,body_entered可能落在落地之后,运动期间轮询兜底


func _fall_loop() -> void:
	while is_inside_tree():
		# 待命
		_falling = false
		await get_tree().create_timer(config.period).timeout
		# 第一层预警:阴影/摇晃(持续 warn_duration)
		play_warning(config.warn_duration)
		await get_tree().create_timer(config.warn_duration).timeout
		# 第二层:击发前白闪2帧
		await flash_white()
		# 坠落(加速下坠)
		_falling = true
		trap_activated.emit()
		var fall_time := config.fall_distance / FALL_SPEED
		var tween := create_tween()
		tween.tween_property(self, "position:y", _origin.y + config.fall_distance, fall_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tween.finished
		# 落地后仍保持0.5s致死(碎玻璃茬),再回位(碎裂粒子任务4接)
		await get_tree().create_timer(0.5).timeout
		_falling = false
		position = _origin


func reset_trap() -> void:
	super.reset_trap()
	_t = 0.0
	rotation = 0.0
	position = _origin
	_falling = false
