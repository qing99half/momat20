extends Control

@onready var hint_label: Label = $HintLabel


func _process(_delta: float) -> void:
	# 提示文字颜色呼吸闪烁：透明度按正弦脉动
	var t := Time.get_ticks_msec() / 1000.0
	hint_label.modulate.a = 0.5 + 0.5 * sin(t * 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		get_tree().change_scene_to_file("res://src/flow/OPScene.tscn")