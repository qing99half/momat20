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

# ---- 死亡与重生(任务4) ----
# 无生命值/无死亡计数/无Game Over;触陷阱=碎裂粒子 + 1s后台灯旁聚合重生。
# 无无敌帧系统(D-537):仅重生后 0.5s 内 can_die=false,防"重生瞬间与陷阱相位重叠即死"连死循环。
const RESPAWN_DELAY := 1.0       # 死亡→重生等待(秒)
const RESPAWN_PROTECT := 0.5     # 重生保护窗(秒,防连死,非无敌帧)
const SHATTER_LIFETIME := 0.8    # 碎裂粒子寿命(秒)
const SHATTER_GRAVITY := 300.0   # 碎裂粒子重力(px/s²)
const SHATTER_SPEED_MIN := 200.0 # 碎裂粒子初速下限(px/s)
const SHATTER_SPEED_MAX := 400.0 # 碎裂粒子初速上限(px/s)

var can_die := true                  # 死亡期间/重生保护窗内=false(防连续触发)
var _frozen := false                 # 死亡流程中冻结输入与移动
var _checkpoint_pos := Vector2.ZERO  # 最近台灯位置(默认=出生点)
var _checkpoint_flip := false        # 经过台灯时的朝向
var _shatter: GPUParticles2D         # 碎裂:像素方块向四周飞散
var _gather: GPUParticles2D          # 重生:碎裂倒放=向中心聚合
var _sfx_death: AudioStreamPlayer    # S4 死亡碎裂音
var _sfx_rebirth: AudioStreamPlayer  # S13 重生上行单音

@onready var sprite: Sprite2D = $Sprite2D


# WASD 输入层(代码级,不动 project.godot;方向键/空格保留兼容)
func _input(event: InputEvent) -> void:
	if _frozen:
		return  # 死亡流程中冻结输入
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
	if _frozen:
		return  # 死亡流程中冻结移动(粒子/计时走协程,不吃物理帧)
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


# ---- 死亡与重生(任务4) ----

func _ready() -> void:
	# 出生点=默认检查点(台灯①被经过后覆盖为台灯位置)
	_checkpoint_pos = global_position
	_checkpoint_flip = sprite.flip_h
	_build_death_fx()


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
	# 音效(占位 wav;S4=死亡碎裂,S13=重生上行单音)
	_sfx_death = AudioStreamPlayer.new()
	_sfx_death.stream = load("res://assets/placeholder/placeholder_S4.wav")
	add_child(_sfx_death)
	_sfx_rebirth = AudioStreamPlayer.new()
	_sfx_rebirth.stream = load("res://assets/placeholder/placeholder_S13.wav")
	add_child(_sfx_rebirth)


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
