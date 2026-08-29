extends Control
# 开发者的话(ED 之后,策划流程表:ED → 开发者的话 → Menu)。
# 任意按键或 10s 自动回主菜单。文案为占位,定稿后只改 $Body.text。

var _done := false


func _ready() -> void:
	await get_tree().create_timer(10.0).timeout
	if not is_inside_tree():
		return  # 已被按键路径切走,场景释放后不再重复跳
	_go_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_go_menu()


func _go_menu() -> void:
	if _done:
		return
	_done = true
	get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")
