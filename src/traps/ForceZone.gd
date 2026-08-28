extends TrapBase
# ForceZone 外力区域:传送带(+x)/账单风(-x),damage=0 不致死。
# 对区域内的 CharacterBody2D 持续施加 config.force 加速度。
# 阵风模式:gust_on>0 时按 吹gust_on秒/停gust_off秒 循环(关4账单风=1.5s吹/2.0s停)。

var _gust_active := true


func _on_ready() -> void:
	if config.gust_on > 0.0:
		_gust_loop()


func _gust_loop() -> void:
	while is_inside_tree():
		_gust_active = true
		sprite.modulate = Color.WHITE
		await get_tree().create_timer(config.gust_on).timeout
		_gust_active = false
		sprite.modulate = Color(1, 1, 1, 0.3)  # 停风期变淡
		await get_tree().create_timer(config.gust_off).timeout


func _physics_process(delta: float) -> void:
	if not _gust_active:
		return
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			# 直接位移推动:玩家控制器每帧重写 velocity,加速度叠加会被吃掉/失控,
			# 传送带/风的正确语义是"载着你走",用位置推动。
			body.position += config.push * delta


func reset_trap() -> void:
	super.reset_trap()
	_gust_active = true
