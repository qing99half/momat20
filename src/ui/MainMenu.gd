extends Control

@onready var hint_label: Label = $HintLabel


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


func _process(_delta: float) -> void:
	# 提示文字颜色呼吸闪烁：透明度按正弦脉动
	var t := Time.get_ticks_msec() / 1000.0
	hint_label.modulate.a = 0.5 + 0.5 * sin(t * 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		get_tree().change_scene_to_file("res://src/flow/OPScene.tscn")