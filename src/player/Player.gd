extends CharacterBody2D
# 玩家角色控制器(任务1:蔚蓝手感移植)
# 单位: 像素/秒,1格=20px。碰撞体20×20px(1×1格,主角=格基准),底部居中锚点。
# move_and_slide() 无参数(Godot 4.7 写法);CharacterBody2D + 手写 velocity,非 RigidBody2D。
# 实测跳跃数据会在控制台打印(供策划案附录B白盒度量速查表回填)。

# ---- 移动 ----
const MAX_SPEED := 225.0        # 全速(px/s)
const ACCEL := 2250.0           # 6帧(0.1s)到全速
const DECEL := 4500.0          # 3帧(0.05s)刹停;转向同率=转向无打滑
const AIR_ACCEL := 2250.0       # 空中加速
const AIR_DECEL := 1500.0       # 空气摩擦(空中无输入时的减速)

# ---- 跳跃 ----
const GRAVITY := 3500.0
const JUMP_VELOCITY := -662.5  # 净空≈70px(3.48格,格数不变,含顶点滞空增益)
const JUMP_CUT_MULT := 0.5     # 可变跳高:上升中松键,竖直速度砍半
const APEX_THRESHOLD := 100.0   # 顶点滞空:|vy|低于此值重力减半
const APEX_GRAVITY_MULT := 0.5
const MAX_FALL_SPEED := 600.0  # 下落限速

# ---- 宽容机制 ----
const COYOTE_TIME := 0.15      # 土狼时间:离开平台0.15s内仍可跳
const JUMP_BUFFER := 0.1       # 跳跃缓冲:落地前0.1s按跳,落地自动跳
const CORNER_CORRECT_MAX := 15  # 撞角修正:斜角碰撞最大横移(px)

# ---- 动画帧号(占位spritesheet 24帧,帧序见策划案-美术音乐附录) ----
const FRAME_LAND := 20
const FRAME_DASH := 21  # 冲刺帧

# ---- 冲刺(任务9,20px格体系:3格=60px;旧8px提示词的24px/48px作废) ----
const DASH_DISTANCE := 60.0      # 冲刺距离:精确3格=60px
const DASH_DURATION := 0.15      # 锁方向时间(秒)
const DASH_SPEED := DASH_DISTANCE / DASH_DURATION  # =400px/s
const DASH_COOLDOWN := 1.0       # 冷却(秒)
const DASH_BUFFER := 0.1         # 输入缓冲:离地前几帧按F转空中冲刺(跳冲组合必需)
const HITSTOP_SCALE := 0.1       # 顿帧强度(提示词写 Time.time_scale,Godot 4.7 正确 API=Engine.time_scale)
const HITSTOP_SECONDS := 0.067   # 顿帧时长:4帧@60fps
const AFTERIMAGE_INTERVAL := 0.05  # 残影间隔(秒)
const AFTERIMAGE_ALPHA := 0.5    # 残影初始透明度
const AFTERIMAGE_DECAY := 0.75   # 残影 alpha 逐帧递减系数
const SHAKE_PX := 2.0            # 微屏震幅度(px)

var _coyote := 0.0
var _buffer := 0.0
var _anim_t := 0.0
var _land_timer := 0.0
var _w_just_pressed := false  # _input 捕获的 W 键按下(跳跃)
var _jump_was_held := false   # 上一帧跳跃键按住状态(可变跳高用)

# ---- 冲刺状态 ----
@export var dash_unlocked := false  # 二章赠予演出解锁(EventBus.dash_unlocked);白盒测试可在编辑器勾选
var _dash_time := 0.0          # 剩余锁方向时间
var _dash_dir := 1.0
var _dash_cooldown := 0.0
var _dash_buffer := 0.0
var _air_dash_used := false    # 空中限一次,落地重置
var _shift_just_pressed := false
var _dash_key_was_pressed := false  # 轮询边沿检测:冲刺三键位上一帧状态
var _w_key_was_pressed := false     # 轮询边沿检测:W 跳上一帧状态
var _afterimage_t := 0.0
var _ghost_alpha := AFTERIMAGE_ALPHA
var _cutscene := false         # 赠予演出中:屏蔽输入但保持物理运行(演示冲刺)
var _gift_running := false
var _dash_popup: CanvasLayer

# 传送带惯性已回滚(2026-08-30 陈洒指令):离带不保持带速,带上推动=纯位移,无加速无惯性。

# 白盒实测记录(跳跃距离/净空)
var _airborne_from_jump := false
var _jump_start := Vector2.ZERO
var _jump_peak_y := 0.0

# ---- 死亡与重生(任务4) ----
# 无生命值/无死亡计数/无Game Over;触陷阱=碎裂粒子 + 1s后台灯旁聚合重生。
# 无无敌帧系统(D-537):仅重生后 0.5s 内 can_die=false,防"重生瞬间与陷阱相位重叠即死"连死循环。
const RESPAWN_DELAY := 1.0       # 死亡→重生等待(秒)
const RESPAWN_PROTECT := 0.5     # 重生保护窗(秒,防连死,非无敌帧)
const KILL_Y := 400.0  # 锚视野底360+40(单屏=整关高18格)                        # 坠落死亡线:掉出世界(坑底)即死,回最近台灯
const SHATTER_LIFETIME := 0.8    # 碎裂粒子寿命(秒)
const SHATTER_GRAVITY := 750.0   # 碎裂粒子重力(px/s²)
const SHATTER_SPEED_MIN := 500.0 # 碎裂粒子初速下限(px/s)
const SHATTER_SPEED_MAX := 1000.0 # 碎裂粒子初速上限(px/s)

var can_die := true                  # 死亡期间/重生保护窗内=false(防连续触发)
var _frozen := false                 # 死亡流程中冻结输入与移动
var _checkpoint_pos := Vector2.ZERO  # 最近台灯位置(默认=出生点)
var _checkpoint_flip := false        # 经过台灯时的朝向
var _shatter: GPUParticles2D         # 碎裂:像素方块向四周飞散
var _gather: GPUParticles2D          # 重生:碎裂倒放=向中心聚合
var _sfx_death: AudioStreamPlayer    # S4 死亡碎裂音
var _sfx_rebirth: AudioStreamPlayer  # S13 重生上行单音
var _sfx_jump: AudioStreamPlayer     # S1 跳跃
var _sfx_land: AudioStreamPlayer     # S2 落地
var _sfx_dash: AudioStreamPlayer     # S3 冲刺

@onready var sprite: Sprite2D = $Sprite2D


# WASD 输入层(代码级,不动 project.godot;方向键/空格保留兼容)
func _input(event: InputEvent) -> void:
	if _frozen:
		return  # 死亡流程中冻结输入
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_W:
			_w_just_pressed = true
		elif event.physical_keycode == KEY_F or event.physical_keycode == KEY_SHIFT:
			_shift_just_pressed = true  # 冲刺(任务9):F/Shift/鼠标右键三键位;中文输入法吃字母和Shift时右键兜底
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_shift_just_pressed = true  # 右键冲刺:IME 永不拦截,中文输入法环境保底键位


func _move_dir() -> float:
	var d := Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_A):
		d -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		d += 1.0
	return clampf(d, -1.0, 1.0)


func _jump_held() -> bool:
	return Input.is_action_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_W)


# 轮询边沿检测(2026-08-30 修复):游戏画面在 SubViewport 里用 GameView 精灵显示,
# SubViewport 不包 SubViewportContainer 时收不到窗口输入事件,_input 永不触发,
# 冲刺三键位(F/Shift/右键)和 W 跳曾因此全部失灵;改为物理帧轮询全局输入状态。
# _input 保留:直跑 Player 场景(无 SubViewport)时仍作兜底,幂等。
func _poll_input_edges() -> void:
	var dash_now := Input.is_physical_key_pressed(KEY_F) or Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if dash_now and not _dash_key_was_pressed and not _frozen:
		_shift_just_pressed = true
	_dash_key_was_pressed = dash_now
	var w_now := Input.is_physical_key_pressed(KEY_W)
	if w_now and not _w_key_was_pressed and not _frozen:
		_w_just_pressed = true
	_w_key_was_pressed = w_now


func _physics_process(delta: float) -> void:
	_poll_input_edges()
	if _frozen:
		return  # 死亡流程中冻结移动(粒子/计时走协程,不吃物理帧)
	var was_on_floor := is_on_floor()

	# ---- 冲刺状态机(任务9):计时/触发;冲刺中=水平瞬发+锁方向+无重力 ----
	var dashing := _tick_dash(delta, was_on_floor)

	# ---- 竖直:重力 + 顶点滞空 ----
	if dashing:
		velocity.x = _dash_dir * DASH_SPEED
		velocity.y = 0.0
		_afterimage_t -= delta
		if _afterimage_t <= 0.0:
			_afterimage_t = AFTERIMAGE_INTERVAL
			_spawn_afterimage()
	elif not was_on_floor:
		var g := GRAVITY
		if absf(velocity.y) < APEX_THRESHOLD:
			g *= APEX_GRAVITY_MULT
		velocity.y = minf(velocity.y + g * delta, MAX_FALL_SPEED)

	# ---- 水平:6帧全速/3帧刹停/转向无打滑(冲刺锁方向/演出屏蔽输入时跳过) ----
	var dir := 0.0 if (dashing or _cutscene) else _move_dir()
	if not dashing:
		if dir != 0.0:
			var a: float = ACCEL if was_on_floor else AIR_ACCEL
			if velocity.x != 0.0 and signf(dir) != signf(velocity.x):
				a = DECEL  # 反向时按刹停率,消灭打滑
			velocity.x = move_toward(velocity.x, dir * MAX_SPEED, a * delta)
		else:
			var d: float = DECEL if was_on_floor else AIR_DECEL
			velocity.x = move_toward(velocity.x, 0.0, d * delta)

	# ---- 土狼时间 / 跳跃缓冲(W/空格均可起跳;冲刺与演出中不刷新跳跃缓冲) ----
	if was_on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	if not dashing and not _cutscene and (Input.is_action_just_pressed("ui_accept") or _w_just_pressed):
		_buffer = JUMP_BUFFER
	else:
		_buffer = maxf(_buffer - delta, 0.0)
	_w_just_pressed = false

	# ---- 起跳(缓冲+土狼同时有效才跳;冲刺/演出中禁止) ----
	if not dashing and not _cutscene and _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		_airborne_from_jump = true
		_jump_start = position
		_jump_peak_y = position.y
		_sfx_jump.play()

	# ---- 可变跳高:上升中松开跳跃键(W或空格)砍半 ----
	var held := _jump_held()
	if _jump_was_held and not held and velocity.y < 0.0:
		velocity.y *= JUMP_CUT_MULT
	_jump_was_held = held

	var ascending := velocity.y < 0.0
	move_and_slide()

	# ---- 坠落死亡:掉出世界(坑底)即死,回最近台灯;世界外无地板,不死会无限下坠卡死 ----
	if can_die and position.y > KILL_Y:
		print("[玩家] 坠入深渊 -> player_died")
		receive_hazard(Vector2.ZERO, &"pit")
		return

	# ---- 撞角修正:上升撞天花板时尝试横向挪动到可通行位置 ----
	if ascending and is_on_ceiling():
		_corner_correct()

	# ---- 落地检测 + 白盒实测打印 ----
	var on_floor_now := is_on_floor()
	if on_floor_now and not was_on_floor:
		_land_timer = 0.08
		_sfx_land.play()
		if _airborne_from_jump:
			_airborne_from_jump = false
			var dist := position.x - _jump_start.x
			var height := _jump_start.y - _jump_peak_y
			print("【白盒实测】跳跃距离 %.1fpx(%.2f格) 净空 %.1fpx(%.2f格)" % [dist, dist / 20.0, height, height / 20.0])
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
	if _dash_time > 0.0:
		sprite.frame = FRAME_DASH  # 冲刺帧(锁方向,朝向在 _start_dash 已设定)
		return
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


# ---- 死亡与重生(任务4) ----

func _ready() -> void:
	# 出生点=默认检查点(台灯①被经过后覆盖为台灯位置)
	_checkpoint_pos = global_position
	_checkpoint_flip = sprite.flip_h
	_build_death_fx()
	# 冲刺开局即解锁(2026-08-30 用户反馈:按 Shift 无反应——原设计为二章赠予,但二章关卡未建,
	# 能力前置;章级过场的 dash_unlocked 信号保留兜底,赠予演出仍在二章首关播放)
	dash_unlocked = true
	EventBus.dash_unlocked.connect(_on_dash_unlocked)


func _on_dash_unlocked() -> void:
	dash_unlocked = true
	print("[玩家] 冲刺已解锁(任务9)")


func _build_death_fx() -> void:
	var pixel := _pixel_texture()
	# 碎裂:8×8px 像素方块向四周飞散(初速200~400,重力300,寿命0.8s)
	_shatter = GPUParticles2D.new()
	_shatter.amount = 24
	_shatter.lifetime = SHATTER_LIFETIME
	_shatter.one_shot = true
	_shatter.explosiveness = 1.0
	_shatter.texture = pixel
	_shatter.top_level = true  # 粒子不随玩家传送挪走
	_shatter.visibility_rect = Rect2(-200.0, -200.0, 400.0, 400.0)
	var shatter_mat := ParticleProcessMaterial.new()
	shatter_mat.direction = Vector3(0.0, -1.0, 0.0)
	shatter_mat.spread = 180.0  # 向四周全向飞散
	shatter_mat.initial_velocity_min = SHATTER_SPEED_MIN
	shatter_mat.initial_velocity_max = SHATTER_SPEED_MAX
	shatter_mat.gravity = Vector3(0.0, SHATTER_GRAVITY, 0.0)
	_shatter.process_material = shatter_mat
	add_child(_shatter)
	# 逆聚:碎裂倒放——环带上生成,径向速度为负=向中心收拢
	_gather = GPUParticles2D.new()
	_gather.amount = 24
	_gather.lifetime = 0.5
	_gather.one_shot = true
	_gather.explosiveness = 1.0
	_gather.texture = pixel
	_gather.top_level = true
	_gather.visibility_rect = Rect2(-200.0, -200.0, 400.0, 400.0)
	var gather_mat := ParticleProcessMaterial.new()
	gather_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	gather_mat.emission_sphere_radius = 24.0
	gather_mat.radial_velocity_min = -220.0  # 负径向速度=向中心聚合
	gather_mat.radial_velocity_max = -140.0
	gather_mat.gravity = Vector3.ZERO
	gather_mat.damping_min = 60.0  # 收拢时减速,避免穿过中心甩出去
	gather_mat.damping_max = 120.0
	_gather.process_material = gather_mat
	add_child(_gather)
	# 音效(S1=跳跃,S2=落地,S3=冲刺,S4=死亡碎裂,S13=重生上行单音;统一 -6dB=BGM 的一半)
	_sfx_death = AudioStreamPlayer.new()
	_sfx_death.stream = load("res://assets/audio/sfx_death.ogg")
	_sfx_death.volume_db = -6.0
	add_child(_sfx_death)
	_sfx_rebirth = AudioStreamPlayer.new()
	_sfx_rebirth.stream = load("res://assets/audio/sfx_rebirth.ogg")
	_sfx_rebirth.volume_db = -6.0
	add_child(_sfx_rebirth)
	_sfx_jump = AudioStreamPlayer.new()
	_sfx_jump.stream = load("res://assets/audio/sfx_jump.ogg")
	_sfx_jump.volume_db = -6.0
	add_child(_sfx_jump)
	_sfx_land = AudioStreamPlayer.new()
	_sfx_land.stream = load("res://assets/audio/sfx_land.ogg")
	_sfx_land.volume_db = -6.0
	add_child(_sfx_land)
	_sfx_dash = AudioStreamPlayer.new()
	_sfx_dash.stream = load("res://assets/audio/sfx_dash.ogg")
	_sfx_dash.volume_db = -6.0
	add_child(_sfx_dash)


func _pixel_texture() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)  # 8×8px 方块
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


# 台灯调用:保存检查点(位置+朝向)
func set_checkpoint(pos: Vector2, facing_left: bool) -> void:
	_checkpoint_pos = pos
	_checkpoint_flip = facing_left


# 过场调用(步骤8.4 日记演出):冻结/解冻输入与移动。与死亡流程共用 _frozen,互不嵌套。
func set_frozen(frozen: bool) -> void:
	_frozen = frozen
	if frozen:
		velocity = Vector2.ZERO
		_w_just_pressed = false
		_dash_time = 0.0      # 打断冲刺,防冻结结束后残留锁方向速度
		_dash_buffer = 0.0
		_shift_just_pressed = false


# 陷阱统一入口(TrapBase._try_hit 调用)。knockback 在即死系统下不生效(D-537 已删受伤态)。
func receive_hazard(_knockback: Vector2, _source_id: StringName) -> void:
	if not can_die:
		return  # 死亡期间/重生保护窗内不再触发(防连死)
	can_die = false
	EventBus.player_died.emit()  # 步骤1;陷阱监听此信号自重置(步骤5同步完成)
	_die_and_respawn()


func _die_and_respawn() -> void:
	# 步骤2:冻结输入,播放碎裂粒子
	_frozen = true
	velocity = Vector2.ZERO
	_dash_time = 0.0       # 死亡打断冲刺;冲刺无伤害豁免(D-537),冲死同判
	_dash_buffer = 0.0
	_air_dash_used = false
	_shatter.global_position = global_position + Vector2(0.0, -8.0)  # 身体中心
	_shatter.restart()
	_sfx_death.play()
	# 步骤3:玩家 sprite 隐藏
	sprite.visible = false
	# 步骤4:停止 Conductor 逻辑拍(音乐继续,节拍事件不触发)
	_set_conductor_beats(false)
	# 步骤5:重置所有陷阱——由步骤1的 player_died 信号驱动,各陷阱 reset_trap() 已同步执行
	# 步骤6:等待1秒
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	# 步骤7:传送回最近检查点(台灯位置+朝向)
	global_position = _checkpoint_pos
	velocity = Vector2.ZERO
	sprite.flip_h = _checkpoint_flip
	# 步骤8:碎裂粒子倒放=重生聚合
	_gather.global_position = _checkpoint_pos + Vector2(0.0, -8.0)
	_gather.restart()
	_sfx_rebirth.play()
	# 步骤9:玩家 sprite 显示,恢复输入;节拍事件恢复
	sprite.visible = true
	_set_conductor_beats(true)
	_frozen = false
	# 重生保护窗:0.5s 内 can_die=false(防相位重叠连死,非无敌帧)
	await get_tree().create_timer(RESPAWN_PROTECT).timeout
	can_die = true


# Conductor 非 autoload,关卡里才有;找不到(测试场景没挂)就跳过,不报错
func _set_conductor_beats(enabled: bool) -> void:
	var c := Conductor.instance
	if c == null:
		return
	if enabled:
		c.start_beats()
	else:
		c.stop_beats()


# ---- 冲刺(任务9) ----

# 每帧调用:计时/触发判定。返回 true=本帧处于冲刺(锁方向锁速度,常规移动跳跃跳过)。
func _tick_dash(delta: float, on_floor: bool) -> bool:
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_dash_buffer = maxf(_dash_buffer - delta, 0.0)
	if _shift_just_pressed:
		_shift_just_pressed = false
		_dash_buffer = DASH_BUFFER
	if on_floor:
		_air_dash_used = false  # 落地重置空中冲刺次数
	if _dash_time > 0.0:
		_dash_time = maxf(_dash_time - delta, 0.0)
		if _dash_time <= 0.0:
			velocity.x = _dash_dir * MAX_SPEED  # 0.15s到点,交还控制(保留跑速动量)
		return true
	# 触发:解锁+缓冲+冷却就绪
	if not dash_unlocked or _dash_buffer <= 0.0 or _dash_cooldown > 0.0:
		return false
	if not on_floor:
		if _air_dash_used:
			return false  # 空中限一次
		_start_dash(true)
		return true
	# 地面:有 pending 跳跃(_buffer>0=刚按跳)时不发动,等离地后转空中冲刺(输入缓冲0.1s,跳冲组合必需)
	if _buffer > 0.0:
		return false
	_start_dash(false)
	return true


func _start_dash(air: bool) -> void:
	_dash_buffer = 0.0
	_dash_cooldown = DASH_COOLDOWN
	_dash_time = DASH_DURATION
	_air_dash_used = air
	_afterimage_t = 0.0  # 首帧立即出残影
	_ghost_alpha = AFTERIMAGE_ALPHA
	var dir := 0.0 if _cutscene else _move_dir()
	if dir == 0.0:
		dir = -1.0 if sprite.flip_h else 1.0  # 无输入时按当前朝向冲
	_dash_dir = dir
	sprite.flip_h = dir < 0.0
	sprite.frame = FRAME_DASH
	velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
	_hitstop()
	_camera_shake()
	_sfx_dash.play()
	# 冲刺照常判定死亡、无伤害豁免(D-537):can_die 全程不动,陷阱命中=即死


# 顿帧:4帧(约0.067s)time_scale=0.1。提示词写 Time.time_scale,Godot 4.7 正确 API=Engine.time_scale。
func _hitstop() -> void:
	Engine.time_scale = HITSTOP_SCALE
	await get_tree().create_timer(HITSTOP_SECONDS, true, false, true).timeout  # ignore_time_scale:按真实时间恢复
	Engine.time_scale = 1.0


# 微屏震:Camera2D.offset 随机抖动约0.15s后归零。
func _camera_shake() -> void:
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tw := create_tween()
	for i in 3:
		tw.tween_property(cam, "offset", Vector2(randf_range(-SHAKE_PX, SHAKE_PX), randf_range(-SHAKE_PX, SHAKE_PX)), 0.03)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.06)


# 残影拖尾:复制当前 sprite 帧为独立 Sprite2D,alpha 递减淡出(4~6帧,间隔0.05s)。
func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.hframes = sprite.hframes
	ghost.vframes = sprite.vframes
	ghost.frame = sprite.frame
	ghost.flip_h = sprite.flip_h
	ghost.top_level = true
	ghost.global_position = sprite.global_position
	ghost.modulate = Color(1.0, 1.0, 1.0, _ghost_alpha)
	_ghost_alpha = maxf(_ghost_alpha * AFTERIMAGE_DECAY, 0.1)
	add_child(ghost)
	var tw := create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)


# ---- 二章开场赠予演出(任务9,约2s+弹窗2s) ----
# 由章节过场(任务10.5)在二章首关睁眼后调用;白盒验收在 dash_test 场景按 G 触发。
func play_dash_gift_cutscene() -> void:
	if _gift_running:
		return
	_gift_running = true
	_cutscene = true  # 屏蔽输入但保持物理(演示冲刺要走物理帧)
	velocity = Vector2.ZERO
	# 1) 女儿脚下亮起冲刺残影特效
	for i in 4:
		_spawn_afterimage()
		await get_tree().create_timer(0.15).timeout
	# 2) 身体前倾自动演示一小段冲刺位移(真实走冲刺状态机=与玩家操作手感一致)
	dash_unlocked = true
	_start_dash(false)
	await get_tree().create_timer(DASH_DURATION + 0.3).timeout
	# 3) UI弹窗(从上方弹出,占位样式;真素材 ui_popup_frame.png 到位后换皮)
	_show_dash_popup()
	await get_tree().create_timer(2.0).timeout
	# 4) 弹窗消失,交还操作
	await _hide_dash_popup()
	_cutscene = false
	_gift_running = false
	EventBus.dash_unlocked.emit()  # 广播解锁(HUD/其他监听者;Player 自身已在步骤2置位,幂等)


func _show_dash_popup() -> void:
	_dash_popup = CanvasLayer.new()
	_dash_popup.layer = 10
	var panel := PanelContainer.new()
	panel.position = Vector2(0.0, -80.0)  # 起点:屏幕上方外(x 待布局后居中)
	var label := Label.new()
	label.text = "恭喜你学会冲刺\n按 F / Shift / 鼠标右键 来拯救过去的'你'吧"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	_dash_popup.add_child(panel)
	add_child(_dash_popup)
	# 等一帧拿真实尺寸,水平居中(视口 1280 宽)
	await get_tree().process_frame
	panel.position.x = (get_viewport().get_visible_rect().size.x - panel.size.x) / 2.0
	var tw := create_tween()
	tw.tween_property(panel, "position:y", 32.0, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_dash_popup() -> void:
	if _dash_popup == null:
		return
	var panel := _dash_popup.get_child(0) as Control
	var tw := create_tween()
	tw.tween_property(panel, "position:y", -80.0, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	_dash_popup.queue_free()
	_dash_popup = null


# 进关提示(轻量版):不冻结不演示,弹窗 2s 自动收起;复用赠予弹窗样式
func show_dash_hint() -> void:
	if _dash_popup != null:
		return
	_show_dash_popup()
	await get_tree().create_timer(2.0).timeout
	await _hide_dash_popup()
