extends Node2D
# 死亡重生自测关(任务4·验收①):玩家自动向右走进尖刺。
# 应该看到:碰尖刺 → 角色碎成像素块飞散消失 → 1秒后在台灯旁聚合出现,台灯已点亮。
# 自动校验:player_died 触发 / 死亡期间节拍停发 / 1s后回台灯旁 / sprite恢复 / 保护窗后 can_die。

const PlayerScene := preload("res://src/player/Player.tscn")
const CheckpointScene := preload("res://src/player/Checkpoint.tscn")
const SpikeScene := preload("res://src/traps/scenes/trap_washboard.tscn")

const LAMP_POS := Vector2(48.0, 160.0)
const RESPAWN_POS := LAMP_POS + Vector2(8.0, 0.0)  # 台灯默认重生偏移

var player: CharacterBody2D
var _death_count := 0
var _dead := false
var _beats_during_death := 0


func _ready() -> void:
	# 地板(400px 宽,顶面 y=160)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(400.0, 16.0)
	shape.shape = rect
	shape.position = Vector2(200.0, 168.0)
	floor_body.add_child(shape)
	var vis := ColorRect.new()
	vis.size = Vector2(400.0, 16.0)
	vis.position = Vector2(0.0, 160.0)
	vis.color = Color(0.4, 0.35, 0.3)
	floor_body.add_child(vis)
	add_child(floor_body)
	# 台灯检查点(起点)
	var lamp := CheckpointScene.instantiate()
	lamp.position = LAMP_POS
	add_child(lamp)
	# 尖刺带(静态致死)
	var spike := SpikeScene.instantiate()
	spike.position = Vector2(140.0, 156.0)
	add_child(spike)
	# 玩家
	player = PlayerScene.instantiate()
	player.position = LAMP_POS
	add_child(player)
	# Conductor:验证死亡期间音乐继续但节拍事件停发
	var conductor := Conductor.new()
	add_child(conductor)
	conductor.play("res://assets/placeholder/placeholder_M1.wav")
	EventBus.player_died.connect(_on_player_died)
	EventBus.beat.connect(_on_beat)
	print("死亡自测:0.5s后玩家自动向右走进尖刺")
	await get_tree().create_timer(0.5).timeout
	Input.action_press("ui_right")
	_verify()


func _on_player_died() -> void:
	_death_count += 1
	_dead = true
	Input.action_release("ui_right")
	print("[自测] player_died #%d (x=%.1f)" % [_death_count, player.position.x])


func _on_beat(_n: int) -> void:
	if _dead:
		_beats_during_death += 1


func _verify() -> void:
	# 等死亡发生(最多5s)
	var t := 0.0
	while _death_count == 0 and t < 5.0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	if _death_count == 0:
		print("AUTO-TEST FAIL: 5s内未触发 player_died")
		return
	# 死亡后0.6s:应处于冻结+隐藏状态,节拍停发
	await get_tree().create_timer(0.6).timeout
	var hidden_ok: bool = not player.sprite.visible
	var frozen_ok: bool = player._frozen
	var beats_ok: bool = _beats_during_death == 0
	_dead = false  # 窗口采样完毕,之后节拍恢复不计
	print("[自测] 死亡中: sprite隐藏=%s 输入冻结=%s 节拍停发=%s" % [hidden_ok, frozen_ok, beats_ok])
	# 死亡后1.2s:应已在台灯旁重生
	await get_tree().create_timer(0.6).timeout
	var pos_ok: bool = player.global_position.distance_to(RESPAWN_POS) < 4.0
	var shown_ok: bool = player.sprite.visible
	var unfrozen_ok: bool = not player._frozen
	print("[自测] 重生后: 回台灯旁=%s (pos=%s) sprite显示=%s 输入恢复=%s" % [pos_ok, player.global_position, shown_ok, unfrozen_ok])
	# 再等0.5s:重生保护窗结束,can_die 应恢复 true
	await get_tree().create_timer(0.6).timeout
	var can_die_ok: bool = player.can_die
	print("[自测] 保护窗结束: can_die=%s" % can_die_ok)
	var ok: bool = hidden_ok and frozen_ok and beats_ok and pos_ok and shown_ok and unfrozen_ok and can_die_ok
	print("AUTO-TEST %s: 死亡→碎裂→1s后台灯旁聚合重生 全流程" % ("PASS" if ok else "FAIL"))
