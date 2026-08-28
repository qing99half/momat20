extends TrapBase
# TimedHazard 周期激活陷阱:config.timed_mode 选择模式。
#   0=冲压机:周期 period,摇晃预警 warn_duration → 白闪2帧 → 下砸 amplitude px,激活 active_duration
#   1=腐心平台:可站立(自带 StaticBody2D),踩上 crumble_delay 秒后碎裂,respawn_delay 秒后重生(不致死)
#   2=巨心滴液:收缩预警 → 白闪 → 滴液坠落 fall_distance px(坠落途中致死)
#   3=啼哭声波:摇晃预警 → 白闪 → 声波环从中心扩散(扩散途中致死)
# 统一节奏:持续态预警(≥0.5s) → 击发前白闪(2帧) → 激活窗口 → 冷却。

var _active := false
var _stand_body: StaticBody2D = null
var _stand_shape: CollisionShape2D = null
var _droplet: Sprite2D = null
var _crumbled := false
var _crumbling := false
var _loop_gen := -1  # 自由周期循环已启动的代际标记(-1=未启动/节拍驱动)


func _on_ready() -> void:
	match config.timed_mode:
		1:
			_build_stand_surface()
		2:
			_build_droplet()
	if config.timed_mode != 1:
		if config.beat_sync:
			_beat_mode_boot(_cycle_loop)  # 对拍击发;无音乐时回退自由定时
		else:
			_cycle_loop()


func _dangerous() -> bool:
	if config.timed_mode == 1:
		return false  # 腐心平台本身不致死,危险来自踩空
	return config.damage > 0 and _active


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _active:
		_poll_hits()  # 下砸/滴液/声波扩散运动快,body_entered 可能错过,激活期轮询兜底


# ---- 模式1:腐心平台 ----

func _build_stand_surface() -> void:
	_stand_body = StaticBody2D.new()
	_stand_body.collision_layer = 1  # 玩家 mask=1 可站立
	_stand_body.collision_mask = 0
	_stand_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = config.hitbox_size  # 站立面不内缩,与贴图同大
	_stand_shape.shape = rect
	_stand_body.add_child(_stand_shape)
	add_child(_stand_body)
	# 触发区上移1px:站立时玩家脚底与台面同线(零深度不触发),上移保证稳定重叠
	hitbox.position = Vector2(0.0, -1.0)
	_hitbox_base_pos = hitbox.position


func _on_body_entered(body: Node2D) -> void:
	super._on_body_entered(body)
	if config.timed_mode == 1 and body is CharacterBody2D and not _crumbling and not _crumbled:
		_crumble_loop()


func _crumble_loop() -> void:
	var gen := _gen  # 代际守卫:死亡重置后中止,平台状态由 reset_trap 复原
	_crumbling = true
	# 踩上后的碎裂预警:摇晃 crumble_delay 秒(持续态预警)
	play_warning_shake(config.crumble_delay)
	await get_tree().create_timer(config.crumble_delay).timeout
	if gen != _gen:
		return
	# 碎裂
	_crumbled = true
	_crumbling = false
	sprite.visible = false
	_stand_shape.set_deferred("disabled", true)
	monitoring = false
	await get_tree().create_timer(config.respawn_delay).timeout
	if gen != _gen:
		return
	# 重生
	_crumbled = false
	sprite.visible = true
	_stand_shape.set_deferred("disabled", false)
	monitoring = true


# ---- 模式2:巨心滴液 ----

func _build_droplet() -> void:
	_droplet = Sprite2D.new()
	_droplet.texture = config.droplet_texture
	_droplet.visible = false
	add_child(_droplet)


# ---- 周期循环(模式 0/2/3) ----

func _cycle_loop() -> void:
	var gen := _gen
	_loop_gen = gen  # 标记:本陷阱走自由定时(死亡重置后按此重排)
	while is_inside_tree() and gen == _gen:
		var flash_time := maxi(config.flash_frames, 1) / 60.0
		var active_time := _active_window()
		var idle := maxf(config.period - config.warn_duration - flash_time - active_time, 0.1)
		await get_tree().create_timer(idle).timeout
		if gen != _gen:
			return  # 代际作废:旧循环退出,新循环由 reset_trap 重排
		await _run_fire_sequence()  # 自由定时:不做落拍等待


# 击发序列·前半(任务3:基类排程调用,trap_activated 由基类在拍点上发射)
func _fire_warn_flash() -> void:
	var gen := _gen
	# 第一层:持续态预警
	_do_warning()
	await get_tree().create_timer(config.warn_duration).timeout
	if gen != _gen:
		return  # 死亡重置:预警中止,位置/缩放/调制已由 reset_trap 复原
	# 第二层:击发前白闪
	await flash_white()


# 击发序列·后半:激活窗口
func _fire_activate() -> void:
	await _activate_once()


func _active_window() -> float:
	if config.timed_mode == 2:
		return config.fall_distance / 400.0
	if config.timed_mode == 3:
		return 0.8
	return config.active_duration


func _do_warning() -> void:
	match config.timed_mode:
		0:  # 冲压机:蒸汽预警(占位=摇晃,真蒸汽粒子待素材)
			play_warning_shake(config.warn_duration)
		2:  # 巨心:收缩预警
			var tween := create_tween()
			tween.tween_property(sprite, "scale", Vector2(0.85, 0.85), config.warn_duration)
			tween.tween_property(sprite, "scale", Vector2.ONE, 0.1)
		3:  # 啼哭声波:摇篮摇晃预警
			play_warning_shake(config.warn_duration)


func _activate_once() -> void:
	var gen := _gen  # 代际守卫:死亡重置后中止,后续属性写入一律作废
	match config.timed_mode:
		0:  # 冲压下砸
			_active = true
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(sprite, "position:y", _sprite_base_pos.y + config.amplitude, 0.08)
			tween.tween_property(hitbox, "position:y", _hitbox_base_pos.y + config.amplitude, 0.08)
			if not await _await_tween(tween, gen):
				return
			await get_tree().create_timer(config.active_duration).timeout
			if gen != _gen:
				return
			var back := create_tween()
			back.set_parallel(true)
			back.tween_property(sprite, "position:y", _sprite_base_pos.y, 0.15)
			back.tween_property(hitbox, "position:y", _hitbox_base_pos.y, 0.15)
			if not await _await_tween(back, gen):
				return
			_active = false
		2:  # 滴液坠落(判定体缩放到液滴尺寸,不用巨心的大判定)
			_active = true
			_droplet.visible = true
			_droplet.position = Vector2(0.0, config.hitbox_size.y / 2.0)
			var drop_scale := (config.droplet_size - HITBOX_INSET * 2.0) / maxf(config.hitbox_size.x - HITBOX_INSET * 2.0, 1.0)
			hitbox.scale = Vector2(drop_scale, drop_scale)
			var hitbox_start := _droplet.position
			hitbox.position = hitbox_start
			var fall_time := config.fall_distance / 400.0
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(_droplet, "position:y", hitbox_start.y + config.fall_distance, fall_time) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(hitbox, "position:y", hitbox_start.y + config.fall_distance, fall_time) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			if not await _await_tween(tween, gen):
				return
			_droplet.visible = false
			hitbox.scale = Vector2.ONE
			hitbox.position = _hitbox_base_pos
			_active = false
		3:  # 声波环扩散
			_active = true
			sprite.scale = Vector2(0.3, 0.3)
			hitbox.scale = Vector2(0.3, 0.3)
			var target := config.amplitude / (config.hitbox_size.x / 2.0)
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(sprite, "scale", Vector2(target, target), 0.8)
			tween.tween_property(hitbox, "scale", Vector2(target, target), 0.8)
			if not await _await_tween(tween, gen):
				return
			sprite.scale = Vector2.ONE
			hitbox.scale = Vector2.ONE
			_active = false


func reset_trap() -> void:
	var was_free := _loop_gen >= 0  # 先记驱动方式,super 会推进代际
	super.reset_trap()
	_active = false
	if _droplet:
		_droplet.visible = false
	if config.timed_mode == 1 and (_crumbled or _crumbling):
		_crumbled = false
		_crumbling = false
		sprite.visible = true
		_stand_shape.set_deferred("disabled", false)
		monitoring = true
	elif config.timed_mode != 1 and was_free and is_inside_tree():
		_cycle_loop()  # 自由定时:旧循环已随代际退出,从待机相位重排
