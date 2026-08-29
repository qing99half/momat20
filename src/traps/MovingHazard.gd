extends TrapBase
# MovingHazard 位移轨迹陷阱:config.motion 选择运动模式。
#   0=摆锤:鸡毛掸子,正弦旋转 ±amplitude 度,周期 period 秒(锚点顶部,config.anchor_top=true)
#   1=酒瓶发射器:本体固定在发射口不动,周期性向下发射酒瓶弹体;
#     弹体加速下坠 fall_distance px,全程致死,掉落 3s 后消失(BottleProjectile)。

const FALL_SPEED := 1000.0      # 弹体坠落速度(px/s)
const BOTTLE_LIFETIME := 3.0   # 弹体掉落后存活(秒),到期淡出消失

var _t := 0.0


func _on_ready() -> void:
	if config.motion == 0:
		trap_activated.emit()  # 摆锤开始摆动
	elif config.beat_sync:
		_beat_mode_boot(_free_fire_loop)  # 有 Conductor 对拍击发;无音乐回退自由定时
	else:
		_free_fire_loop()


func _dangerous() -> bool:
	# 发射器本体不致死,致死的是弹体(BottleProjectile 自带判定)
	if config.motion == 1:
		return false
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


# 无 Conductor 时的自由击发循环(与 _fall_loop 旧职责相同,但本体不动)
func _free_fire_loop() -> void:
	var gen := _gen
	while is_inside_tree() and gen == _gen:
		await get_tree().create_timer(config.period).timeout
		if gen != _gen:
			return
		await _run_fire_sequence()  # 自由定时:不做落拍等待


# 击发序列·前半(任务3:基类排程调用,trap_activated 由基类在拍点上发射)
func _fire_warn_flash() -> void:
	var gen := _gen
	# 第一层预警:发射口明暗脉冲/摇晃(持续 warn_duration)
	play_warning(config.warn_duration)
	await get_tree().create_timer(config.warn_duration).timeout
	if gen != _gen:
		return
	# 第二层:击发前白闪2帧
	await flash_white()


# 击发序列·后半:发射一枚酒瓶弹体(本体位置不动,编辑器看到的位置=游戏里的发射口)
func _fire_activate() -> void:
	if config.motion != 1:
		return
	var bottle := BottleProjectile.new()
	bottle.setup(config)
	add_child(bottle)  # 挂发射器下,随发射器一起被关卡管理;死亡时由 player_died 自清
	bottle.launch(config.fall_distance, FALL_SPEED, BOTTLE_LIFETIME)


func reset_trap() -> void:
	super.reset_trap()
	_t = 0.0        # 摆锤相位归零(回到起始角度)
	rotation = 0.0
	# 自由定时模式由基类代际推进自动作废旧循环;本陷阱死亡重排在 _beat_fire_enabled 分支已由基类处理
	if config.motion == 1 and not _beat_fire_enabled and is_inside_tree():
		_free_fire_loop()  # 自由定时:旧循环已随代际退出,从待命相位重排


# ---- 酒瓶弹体 ----
class BottleProjectile:
	extends Area2D
	# 发射器射出的酒瓶:加速下坠,全程致死(含落地静置期),存活 bottle_lifetime 秒后淡出消失。

	var _config: TrapConfig
	var _hit_cd := 0.0

	func setup(cfg: TrapConfig) -> void:
		_config = cfg
		collision_layer = 2  # 约定:角色Layer=1,陷阱Layer=2
		collision_mask = 1
		var sprite := Sprite2D.new()
		sprite.texture = cfg.texture
		add_child(sprite)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		# 与 TrapBase 同一硬约束:致死判定体四边各内缩2px(擦尖不死)
		rect.size = Vector2(maxf(cfg.hitbox_size.x - 10.0, 5.0), maxf(cfg.hitbox_size.y - 10.0, 5.0))
		shape.shape = rect
		add_child(shape)
		body_entered.connect(_on_body_entered)
		EventBus.player_died.connect(_on_player_died)

	func launch(fall_px: float, speed: float, lifetime: float) -> void:
		# 加速下坠(重力感)
		var tween := create_tween()
		tween.tween_property(self, "position:y", position.y + fall_px, fall_px / speed) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# 存活倒计时 → 淡出消失
		var life := get_tree().create_timer(lifetime)
		life.timeout.connect(_fade_out)

	func _physics_process(delta: float) -> void:
		_hit_cd = maxf(_hit_cd - delta, 0.0)
		# 高速下坠可能一帧穿过 body_entered,运动期间轮询兜底(与 TrapBase 同一策略)
		if _hit_cd <= 0.0:
			for body in get_overlapping_bodies():
				if body is CharacterBody2D:
					_on_body_entered(body)

	func _on_body_entered(body: Node2D) -> void:
		if _hit_cd > 0.0 or not (body is CharacterBody2D):
			return
		_hit_cd = 0.5
		if body.has_method("receive_hazard"):
			body.receive_hazard(_config.knockback, _config.source_id)
		else:
			EventBus.player_died.emit()

	func _fade_out() -> void:
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)

	func _on_player_died() -> void:
		queue_free()  # 死亡重生:清空场景内所有飞行/静置弹体
