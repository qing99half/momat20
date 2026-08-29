class_name MotherNPC
extends CharacterBody2D
# 三章母亲NPC(任务12.3):程序驱动无输入,慢走向右50px/s(与女儿同速)。
# 距门<3格(60px)切"侧脸回望"帧;阶段一原地走(12.4 二段式),阶段二真实位移。
# 帧布局(8帧,美术案帧序列明细表):0~5慢走 / 6推门 / 7侧脸回望。

const SPEED := 50.0
const FRAME_WALK := 0
const FRAME_PUSH := 6
const FRAME_LOOK_BACK := 7
const LOOK_BACK_DISTANCE := 60.0  # 3格=60px

var walking := false        # 阶段二真实位移(三章场景脚本驱动)
var walk_in_place := true   # 阶段一原地走(位置锁定,只播动画)
var door_x := 1000.0
var _anim_t := 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _physics_process(delta: float) -> void:
	_anim_t += delta
	velocity = Vector2(SPEED if walking else 0.0, 0.0)
	move_and_slide()
	_update_frame()


func _update_frame() -> void:
	if absf(door_x - global_position.x) < LOOK_BACK_DISTANCE:
		_sprite.frame = FRAME_LOOK_BACK  # 临近相遇,转头看向女儿
	elif walking or walk_in_place:
		_sprite.frame = FRAME_WALK + int(_anim_t * 10.0) % 6  # 慢走6帧 ~10fps
	else:
		_sprite.frame = FRAME_WALK  # 站立=慢走首帧


## 12.5 推门:定格推门帧(与女儿并肩,手在同一位置)
func push_pose() -> void:
	walking = false
	walk_in_place = false
	set_physics_process(false)
	_sprite.frame = FRAME_PUSH
