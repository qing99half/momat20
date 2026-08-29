class_name Checkpoint
extends Area2D
# 台灯检查点(任务4):昏黄小台灯,玩家经过时"啪"亮起+音效,并把 位置+朝向 存给玩家。
# 2态贴图(灭/亮)待美术出图;占位期用单帧 prop_lamp + 明暗调制区分两态。
# 每关3盏:起点1盏+核心段入口1盏+组合考试段入口1盏(即死系统下压低最坏重跑到20~25s)。
# 配套关卡规则:台灯前后5格内不放动态陷阱(与重生保护共同防连死)。
# 零直接调用:台灯只调玩家公开的 set_checkpoint 接口(与 TrapBase.receive_hazard 同一模式)。

const LAMP_TEXTURE := preload("res://assets/placeholder/placeholder_prop_lamp.png")
const CHECKPOINT_SFX := preload("res://assets/placeholder/placeholder_S5.wav")  # S5=台灯检查点音

const COLOR_DIM := Color(0.45, 0.42, 0.38)   # 灭:昏沉沉的暗灯
const COLOR_LIT := Color(1.7, 1.4, 0.85)     # 亮:昏黄暖光(超亮调制模拟发光)

@export var respawn_offset := Vector2(20.0, 0.0)  # 重生点相对灯座的偏移(默认站台灯旁,不叠灯上)

var lit := false

var _sprite: Sprite2D
var _sfx: AudioStreamPlayer


func _ready() -> void:
	collision_layer = 0  # 约定:角色Layer=1;台灯只做触发,自己不在任何层
	collision_mask = 1
	_sprite = Sprite2D.new()
	_sprite.texture = LAMP_TEXTURE
	_sprite.position = Vector2(0.0, -20.0)  # 20×40 贴图,底部与玩家脚底同线(原点=落地线)
	_sprite.modulate = COLOR_DIM
	add_child(_sprite)
	var hitbox := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24.0, 24.0)  # 触发区比灯大一圈(3×3格),经过即点亮
	hitbox.shape = rect
	hitbox.position = Vector2(0.0, -10.0)
	add_child(hitbox)
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = CHECKPOINT_SFX
	add_child(_sfx)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if lit or not (body is CharacterBody2D):
		return
	lit = true
	_sprite.modulate = COLOR_LIT  # "啪"亮起
	_sfx.play()
	if body.has_method("set_checkpoint"):
		var facing := false
		var sp: Variant = body.get("sprite")
		if sp is Sprite2D:
			facing = sp.flip_h
		body.set_checkpoint(global_position + respawn_offset, facing)
	print("[台灯] 检查点已点亮 (x=%.1f)" % global_position.x)
