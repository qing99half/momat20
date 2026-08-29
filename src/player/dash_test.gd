extends Node2D
# 冲刺白盒验收场(任务9):4格(80px)缺口平跳稳过;6格(120px)缺口平跳/站冲都过不去,
# 只有"起跳→空中按F"跳冲组合能过。数值:冲刺60px/锁0.15s/冷却1s(20px格体系)。
# 操作:方向键或A/D移动,空格或W跳,F冲刺;按G重播二章赠予演出(残影+演示冲刺+弹窗)。

const PLAYER_SCENE := "res://src/player/Player.tscn"
const GROUND_Y := 320.0  # 地面行(LevelSpecs 约定)

var _player: CharacterBody2D


func _ready() -> void:
	# 平台分段(缺口:400~480=4格80px;800~920=6格120px)
	for seg in [[0.0, 400.0], [480.0, 800.0], [920.0, 1500.0]]:
		_make_ground(seg[0], seg[1])
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	_player.position = Vector2(100.0, GROUND_Y)
	add_child(_player)
	_player.dash_unlocked = true  # 白盒直接解锁(须在 add_child 后:._ready 会按章节自查覆盖);正式流程由二章赠予演出/章节过场解锁
	print("[冲刺验收] 4格缺口(80px)=平跳稳过 | 6格缺口(120px)=平跳必掉、站冲必掉,只有起跳→空中按F能过")
	print("[冲刺验收] 冲刺=60px/锁方向0.15s/冷却1s;空中限一次,落地重置;按G看赠予演出")


func _make_ground(x0: float, x1: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2((x0 + x1) / 2.0, GROUND_Y + 40.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(x1 - x0, 80.0)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	var view := ColorRect.new()
	view.color = Color(0.3, 0.7, 0.3)
	view.position = Vector2(x0, GROUND_Y)
	view.size = Vector2(x1 - x0, 80.0)
	add_child(view)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_G:
			_player.play_dash_gift_cutscene()
