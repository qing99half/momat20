extends CharacterBody2D
# 玩家角色控制器(任务1:蔚蓝手感移植)
# 单位: 像素/秒,1格=8px。碰撞体8×16px(1×2格),底部居中锚点。
# move_and_slide() 无参数(Godot 4.7 写法);CharacterBody2D + 手写 velocity,非 RigidBody2D。
# 实测跳跃数据会在控制台打印(供策划案附录B白盒度量速查表回填)。

# ---- 移动 ----
const MAX_SPEED := 90.0        # 全速(px/s)
const ACCEL := 900.0           # 6帧(0.1s)到全速
const DECEL := 1800.0          # 3帧(0.05s)刹停;转向同率=转向无打滑
const AIR_ACCEL := 900.0       # 空中加速
const AIR_DECEL := 600.0       # 空气摩擦(空中无输入时的减速)

# ---- 跳跃 ----
const GRAVITY := 1400.0
const JUMP_VELOCITY := -265.0  # 净空≈27.8px(3.48格,含顶点滞空增益)
const JUMP_CUT_MULT := 0.5     # 可变跳高:上升中松键,竖直速度砍半
const APEX_THRESHOLD := 40.0   # 顶点滞空:|vy|低于此值重力减半
const APEX_GRAVITY_MULT := 0.5
const MAX_FALL_SPEED := 240.0  # 下落限速

# ---- 宽容机制 ----
const COYOTE_TIME := 0.15      # 土狼时间:离开平台0.15s内仍可跳
const JUMP_BUFFER := 0.1       # 跳跃缓冲:落地前0.1s按跳,落地自动跳
const CORNER_CORRECT_MAX := 6  # 撞角修正:斜角碰撞最大横移(px)

# ---- 动画帧号(占位spritesheet 24帧,帧序见策划案-美术音乐附录) ----
const FRAME_LAND := 20

var _coyote := 0.0
var _buffer := 0.0
var _anim_t := 0.0
var _land_timer := 0.0
var _w_just_pressed := false  # _input 捕获的 W 键按下(跳跃)
var _jump_was_held := false   # 上一帧跳跃键按住状态(可变跳高用)

# 白盒实测记录(跳跃距离/净空)
var _airborne_from_jump := false
var _jump_start := Vector2.ZERO
var _jump_peak_y := 0.0

@onready var sprite: Sprite2D = $Sprite2D


# WASD 输入层(代码级,不动 project.godot;方向键/空格保留兼容)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_W:
			_w_just_pressed = true


func _move_dir() -> float:
	var d := Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_A):
		d -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		d += 1.0
	return clampf(d, -1.0, 1.0)


func _jump_held() -> bool:
	return Input.is_action_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_W)


func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()

	# ---- 竖直:重力 + 顶点滞空 ----
	if not was_on_floor:
		var g := GRAVITY
		if absf(velocity.y) < APEX_THRESHOLD:
			g *= APEX_GRAVITY_MULT
		velocity.y = minf(velocity.y + g * delta, MAX_FALL_SPEED)

	# ---- 水平:6帧全速/3帧刹停/转向无打滑 ----
	var dir := _move_dir()
	if dir != 0.0:
		var a: float = ACCEL if was_on_floor else AIR_ACCEL
		if velocity.x != 0.0 and signf(dir) != signf(velocity.x):
			a = DECEL  # 反向时按刹停率,消灭打滑
		velocity.x = move_toward(velocity.x, dir * MAX_SPEED, a * delta)
	else:
		var d: float = DECEL if was_on_floor else AIR_DECEL
		velocity.x = move_toward(velocity.x, 0.0, d * delta)

	# ---- 土狼时间 / 跳跃缓冲(W/空格均可起跳) ----
	if was_on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	if Input.is_action_just_pressed("ui_accept") or _w_just_pressed:
		_buffer = JUMP_BUFFER
	else:
		_buffer = maxf(_buffer - delta, 0.0)
	_w_just_pressed = false

	# ---- 起跳(缓冲+土狼同时有效才跳) ----
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		_airborne_from_jump = true
		_jump_start = position
		_jump_peak_y = position.y

	# ---- 可变跳高:上升中松开跳跃键(W或空格)砍半 ----
	var held := _jump_held()
	if _jump_was_held and not held and velocity.y < 0.0:
		velocity.y *= JUMP_CUT_MULT
	_jump_was_held = held

	var ascending := velocity.y < 0.0
	move_and_slide()

	# ---- 撞角修正:上升撞天花板时尝试横向挪动到可通行位置 ----
	if ascending and is_on_ceiling():
		_corner_correct()

	# ---- 落地检测 + 白盒实测打印 ----
	var on_floor_now := is_on_floor()
	if on_floor_now and not was_on_floor:
		_land_timer = 0.08
		if _airborne_from_jump:
			_airborne_from_jump = false
			var dist := position.x - _jump_start.x
			var height := _jump_start.y - _jump_peak_y
			print("【白盒实测】跳跃距离 %.1fpx(%.2f格) 净空 %.1fpx(%.2f格)" % [dist, dist / 8.0, height, height / 8.0])
	if _airborne_from_jump:
		_jump_peak_y = minf(_jump_peak_y, position.y)

	_land_timer = maxf(_land_timer - delta, 0.0)
	_anim_t += delta
	_update_sprite(dir, on_floor_now)


func _corner_correct() -> void:
	# 斜角碰撞自动修正:依次尝试向左右横移1~6px,找到上方无阻挡的位置
	var base := global_transform
	for i in range(1, CORNER_CORRECT_MAX + 1):
		for s in [-1.0, 1.0]:
			var candidate := base.translated(Vector2(s * i, 0.0))
			if not test_move(candidate, Vector2(0.0, -1.0)):
				global_position += Vector2(s * i, 0.0)
				return


func _update_sprite(dir: float, on_floor: bool) -> void:
	if dir != 0.0:
		sprite.flip_h = dir < 0.0
	if _land_timer > 0.0:
		sprite.frame = FRAME_LAND  # 落地帧
	elif not on_floor:
		if velocity.y < -10.0:
			sprite.frame = 16  # 跳跃上升
		elif velocity.y < APEX_THRESHOLD:
			sprite.frame = 17  # 顶点
		elif velocity.y < 100.0:
			sprite.frame = 18  # 下落初段
		else:
			sprite.frame = 19  # 下落
	elif absf(velocity.x) > 5.0:
		sprite.frame = 4 + int(_anim_t * 12.0) % 6  # 跑步6帧
	else:
		sprite.frame = int(_anim_t * 4.0) % 4  # 待机4帧
