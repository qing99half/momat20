extends Control

# 摆摊保护(中-27):主菜单空闲 60s 自动播 ED(路演"揭晓"片段);
# ED→开发者的话→主菜单→再空闲 60s→再播,天然循环。任意按键重置计时并进 OP。
const ATTRACT_IDLE := 60.0

@onready var hint_label: Label = $HintLabel

var _idle := 0.0


func _ready() -> void:
	# S19 菜单环境底噪(循环,压低至背景层)
	var amb := AudioStreamPlayer.new()
	amb.name = "MenuAmbient"
	var stream: AudioStream = load("res://assets/audio/sfx_menu_ambient.ogg")
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	amb.stream = stream
	amb.volume_db = -6.0  # 音效层=BGM 的一半(-6dB)
	add_child(amb)
	amb.play()


func _process(delta: float) -> void:
	# 提示文字颜色呼吸闪烁：透明度按正弦脉动
	var t := Time.get_ticks_msec() / 1000.0
	hint_label.modulate.a = 0.5 + 0.5 * sin(t * 2.0)
	# 摆摊保护(中-27):空闲 60s 自动播 ED 路演
	_idle += delta
	if _idle >= ATTRACT_IDLE:
		_idle = 0.0
		get_tree().change_scene_to_file("res://src/flow/EDScene.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_idle = 0.0
		get_tree().change_scene_to_file("res://src/flow/OPScene.tscn")