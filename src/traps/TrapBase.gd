class_name TrapBase
extends Area2D
# 陷阱基类(任务2):Area2D + 监听 body_entered + TrapConfig 驱动。
# 架构:运动层(子类 Tween/代码)+ 材质层(贴图/帧动画,占位期为色块)+ 反馈层(粒子,任务4接)。
# 硬约束:致死陷阱判定体统一四边各内缩 HITBOX_INSET=2px(擦尖不死),写死在本基类。

signal trap_activated
signal trap_hit_player

const HITBOX_INSET := 2.0
# 白闪 shader(击发前2帧强调;内嵌代码避免占用 assets/shaders 目录)
const FLASH_SHADER_CODE := """shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = mix(c, vec4(1.0, 1.0, 1.0, c.a), flash);
}"""

@export var config: TrapConfig

var sprite: Sprite2D
var hitbox: CollisionShape2D
var _flash_material: ShaderMaterial
var _sprite_base_pos := Vector2.ZERO
var _hitbox_base_pos := Vector2.ZERO

# ---- 节拍同步状态(任务3) ----
var _beat_alive := false        # 收到过 beat 信号(Conductor 在跑)
var _beat_now := -1             # 最近一次拍号(音乐内编号,循环会回卷)
var _beat_abs := -1             # 连续拍计数(跨循环不回卷,阵风相位用它)
var _gen := 0                   # 代际:reset_trap 时 +1,进行中的旧击发作废
var _beat_fire_enabled := false
var _fire_beat := -1.0          # 下次击发目标拍(Conductor 绝对拍空间,跨循环不回卷)
var _firing := false            # 击发序列进行中
var _warn_tween: Tween = null   # 预警动效 Tween(死亡重置时 kill)


func _ready() -> void:
	collision_layer = 2  # 约定:角色Layer=1,陷阱Layer=2,陷阱Mask含1
	collision_mask = 1
	if config == null:
		push_error("TrapBase: 未配置 TrapConfig")
		return
	_build_visual()
	_build_hitbox()
	body_entered.connect(_on_body_entered)
	EventBus.beat.connect(_on_beat)
	EventBus.player_died.connect(_on_player_died)  # 任务4:死亡即全陷阱自重置
	_on_ready()


func _on_ready() -> void:
	pass  # 子类钩子


# ---- 构建 ----

func _build_visual() -> void:
	sprite = Sprite2D.new()
	sprite.texture = config.texture
	if config.anchor_top:
		sprite.position = Vector2(0.0, config.hitbox_size.y / 2.0)
	var shader := Shader.new()
	shader.code = FLASH_SHADER_CODE
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = shader
	sprite.material = _flash_material
	add_child(sprite)
	_sprite_base_pos = sprite.position


func _build_hitbox() -> void:
	hitbox = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var size: Vector2 = config.hitbox_size
	if config.damage > 0:
		size = Vector2(maxf(size.x - HITBOX_INSET * 2.0, 2.0), maxf(size.y - HITBOX_INSET * 2.0, 2.0))
	rect.size = size
	hitbox.shape = rect
	# 判定体与贴图解耦:尺寸/偏移只看 config,美术换图不影响判定
	hitbox.position = config.hitbox_offset
	if config.anchor_top:
		hitbox.position += Vector2(0.0, config.hitbox_size.y / 2.0)
	add_child(hitbox)
	_hitbox_base_pos = hitbox.position


# ---- 伤害判定 ----

func _dangerous() -> bool:
	return config != null and config.damage > 0


var _hit_cd := 0.0  # 命中冷却:防止持续重叠时每帧重复发射 player_died


func _physics_process(delta: float) -> void:
	_hit_cd = maxf(_hit_cd - delta, 0.0)


func _on_body_entered(body: Node2D) -> void:
	if not (body is CharacterBody2D):
		return  # 只对角色生效,地板/墙体不触发
	_try_hit(body)


# 主动轮询重叠:高速运动陷阱(坠落/滴液/下砸)可能一帧穿过body_entered,
# 或接触事件落在激活窗口之后,运动期间每物理帧轮询兜底。
func _poll_hits() -> void:
	if not _dangerous() or _hit_cd > 0.0:
		return
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			_try_hit(body)


func _try_hit(body: Node2D) -> void:
	if not _dangerous() or _hit_cd > 0.0:
		return
	_hit_cd = 0.5
	trap_hit_player.emit()
	if body.has_method("receive_hazard"):
		# 正式接口(任务4在玩家侧实现后走这里)
		body.receive_hazard(config.knockback, config.source_id)
	else:
		# 任务4之前的直通路径:陷阱直接发全局死亡信号
		print("[陷阱:%s] 命中玩家 -> player_died" % config.source_id)
		EventBus.player_died.emit()


# ---- 预警(两层,严禁压成一句) ----
# 第一层:持续态预警≥0.5s —— 明暗脉冲(子类可覆盖为摇晃/收缩/阴影)
func play_warning(duration: float) -> void:
	if duration <= 0.0 or sprite == null:
		return
	var loops := maxi(int(duration / 0.1), 1)
	if _warn_tween and _warn_tween.is_valid():
		_warn_tween.kill()
	_warn_tween = create_tween()
	for i in loops:
		_warn_tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5), 0.05)
		_warn_tween.tween_property(sprite, "modulate", Color(0.65, 0.65, 0.65), 0.05)
	_warn_tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)


# 第一层变体:摇晃(冲压机蒸汽/摇篮摇晃的占位动效)
func play_warning_shake(duration: float) -> void:
	if duration <= 0.0 or sprite == null:
		return
	var loops := maxi(int(duration / 0.1), 1)
	if _warn_tween and _warn_tween.is_valid():
		_warn_tween.kill()
	_warn_tween = create_tween()
	for i in loops:
		_warn_tween.tween_property(sprite, "position", _sprite_base_pos + Vector2(1.0, 0.0), 0.05)
		_warn_tween.tween_property(sprite, "position", _sprite_base_pos - Vector2(1.0, 0.0), 0.05)
	_warn_tween.tween_property(sprite, "position", _sprite_base_pos, 0.05)


# 第二层:击发前 flash_frames 帧白闪(强调,非预警本体)
func flash_white() -> void:
	if _flash_material == null:
		return
	_flash_material.set_shader_parameter("flash", 1.0)
	for i in maxi(config.flash_frames, 1):
		await get_tree().process_frame
	_flash_material.set_shader_parameter("flash", 0.0)


# 等 Tween 播完;期间代际作废(死亡重置)则 kill 并返回 false。
# 不能 await tween.finished:被 kill 的 Tween 永远不发 finished,协程会挂死。
func _await_tween(tween: Tween, gen: int) -> bool:
	while tween.is_running():
		if gen != _gen:
			tween.kill()
			return false
		await get_tree().process_frame
	return gen == _gen


# ---- 重置(任务4死亡重生流程:player_died 信号驱动,全陷阱自重置) ----
func _on_player_died() -> void:
	reset_trap()


func reset_trap() -> void:
	_gen += 1  # 进行中的旧击发序列作废(各 await 后的代际检查点退出)
	_firing = false
	if _warn_tween and _warn_tween.is_valid():
		_warn_tween.kill()  # 预警动效立即停
	_warn_tween = null
	if _beat_fire_enabled:
		_arm_next_fire()  # 死亡重生后按全局拍重新布防,玩家背过的节奏不变
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2.ONE
		sprite.position = _sprite_base_pos
	if hitbox:
		hitbox.position = _hitbox_base_pos
		hitbox.scale = Vector2.ONE
	if _flash_material:
		_flash_material.set_shader_parameter("flash", 0.0)


# ---- 节拍同步(任务3:订阅 EventBus.beat,按 active_beats/cooldown_beats 激活/休眠) ----
# 排程方式:beat 信号只用于"Conductor 是否存活"判定与摆锤/阵风的拍计数;
# 击发计时直接轮询 Conductor 音频时钟(get_abs_beat),最后逐帧等钟落拍——
# 定时器链会被帧量化逐级放大(实测偏差 0.11~0.25 拍),时钟直读把误差压进 1 帧。

# 周期拍数:显式配置 active_beats+cooldown_beats 优先;否则由 period(秒)按 0.5s/拍 换算
func _period_beats() -> int:
	if config.active_beats + config.cooldown_beats > 0:
		return config.active_beats + config.cooldown_beats
	return maxi(roundi(config.period / Conductor.SEC_PER_BEAT), 1)


# 等 0.6s 判断 Conductor 是否在发拍;无音乐时子类回退自由定时(防无 Conductor 场景冻结)
func _wait_conductor() -> bool:
	await get_tree().create_timer(0.6).timeout
	return _beat_alive


# 节拍模式启动:有 Conductor 则启用对拍击发,否则回退自由定时
func _beat_mode_boot(fallback: Callable) -> void:
	if await _wait_conductor():
		_enable_beat_fire()
	else:
		fallback.call()


# 启用节拍驱动击发:trap_activated 锁定在周期整数倍拍上
func _enable_beat_fire() -> void:
	var pb := _period_beats()
	if pb < 2 or pb > 6:
		push_error("%s: 周期 %d 拍 = %.1fs,必须 ∈ {1.0,1.5,2.0,2.5,3.0}s" % [config.source_id, pb, pb * Conductor.SEC_PER_BEAT])
		return
	_beat_fire_enabled = true
	_arm_next_fire()


func _lead_seconds() -> float:
	return config.warn_duration + maxi(config.flash_frames, 1) / 60.0


# 布防:下一个"现在开始预警还来得及"的周期整数倍拍
func _arm_next_fire() -> void:
	var c := Conductor.instance
	if c == null:
		_fire_beat = -1.0
		return
	var pb := float(_period_beats())
	var now := c.get_abs_beat()
	_fire_beat = (floori(now / pb) + 1) * pb
	while _fire_beat - now < _lead_seconds() / Conductor.SEC_PER_BEAT:
		_fire_beat += pb


func _process(_delta: float) -> void:
	if config == null or not _beat_fire_enabled or _firing or _fire_beat < 0.0:
		return
	var c := Conductor.instance
	if c == null or c.state != Conductor.State.PLAYING:
		return
	# 预警提前量含小数拍:时钟抵达"目标拍-提前量"即开始击发序列
	if c.get_abs_beat() >= _fire_beat - _lead_seconds() / Conductor.SEC_PER_BEAT - Conductor.EPSILON:
		_run_fire_sequence(_fire_beat)


# 击发序列:预警+白闪 → 逐帧等钟精准落拍 → trap_activated → 激活窗口。
# fire_beat < 0 = 自由定时(无 Conductor 回退),不做落拍等待。
func _run_fire_sequence(fire_beat := -1.0) -> void:
	var gen := _gen
	_firing = true
	_fire_beat = -1.0
	await _fire_warn_flash()
	if gen != _gen or Conductor.instance == null:
		_firing = false
		return
	if fire_beat >= 0.0:
		while Conductor.instance != null and Conductor.instance.get_abs_beat() < fire_beat - Conductor.EPSILON:
			await get_tree().process_frame  # 暂停时时钟冻结,恢复后仍落在原拍
		if gen != _gen or Conductor.instance == null:
			_firing = false
			return
	trap_activated.emit()
	await _fire_activate()
	_firing = false
	if _beat_fire_enabled:
		_arm_next_fire()


func _on_beat(n: int) -> void:
	_beat_alive = true
	_beat_now = n
	_beat_abs += 1


# 击发序列钩子(子类实现):持续态预警 → 白闪
func _fire_warn_flash() -> void:
	pass


# 击发序列钩子(子类实现):激活窗口(trap_activated 由基类在拍点上发射)
func _fire_activate() -> void:
	pass
