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


func _ready() -> void:
	collision_layer = 2  # 约定:角色Layer=1,陷阱Layer=2,陷阱Mask含1
	collision_mask = 1
	if config == null:
		push_error("TrapBase: 未配置 TrapConfig")
		return
	_build_visual()
	_build_hitbox()
	body_entered.connect(_on_body_entered)
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
	if config.anchor_top:
		hitbox.position = Vector2(0.0, config.hitbox_size.y / 2.0)
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
	var tween := create_tween()
	for i in loops:
		tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5), 0.05)
		tween.tween_property(sprite, "modulate", Color(0.65, 0.65, 0.65), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)


# 第一层变体:摇晃(冲压机蒸汽/摇篮摇晃的占位动效)
func play_warning_shake(duration: float) -> void:
	if duration <= 0.0 or sprite == null:
		return
	var loops := maxi(int(duration / 0.1), 1)
	var tween := create_tween()
	for i in loops:
		tween.tween_property(sprite, "position", _sprite_base_pos + Vector2(1.0, 0.0), 0.05)
		tween.tween_property(sprite, "position", _sprite_base_pos - Vector2(1.0, 0.0), 0.05)
	tween.tween_property(sprite, "position", _sprite_base_pos, 0.05)


# 第二层:击发前 flash_frames 帧白闪(强调,非预警本体)
func flash_white() -> void:
	if _flash_material == null:
		return
	_flash_material.set_shader_parameter("flash", 1.0)
	for i in maxi(config.flash_frames, 1):
		await get_tree().process_frame
	_flash_material.set_shader_parameter("flash", 0.0)


# ---- 重置(任务4死亡重生流程会调用) ----
func reset_trap() -> void:
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2.ONE
		sprite.position = _sprite_base_pos
	if hitbox:
		hitbox.position = _hitbox_base_pos
		hitbox.scale = Vector2.ONE
	if _flash_material:
		_flash_material.set_shader_parameter("flash", 0.0)
