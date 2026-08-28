extends ColorRect

@onready var top_lid: ColorRect = $TopLid
@onready var bottom_lid: ColorRect = $BottomLid

var _tween: Tween
var _lid_height := 0.0


func _ready() -> void:
	_reset_lids()


func _reset_lids() -> void:
	var vsize := get_viewport_rect().size
	_lid_height = vsize.y / 2.0
	var w := vsize.x
	top_lid.size = Vector2(w, _lid_height)
	bottom_lid.size = Vector2(w, _lid_height)
	top_lid.position = Vector2(0.0, -_lid_height)
	bottom_lid.position = Vector2(0.0, vsize.y)


func close_eyes(duration: float) -> void:
	# 闭眼：上下两块黑色矩形从屏幕上下边缘向中间合拢
	visible = true
	_reset_lids()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(top_lid, "position:y", 0.0, duration)
	_tween.parallel().tween_property(bottom_lid, "position:y", _lid_height, duration)


func open_eyes(duration: float) -> void:
	# 睁眼：两块黑色矩形从中间向上下边缘打开
	if _tween and _tween.is_valid():
		_tween.kill()
	var vsize := get_viewport_rect().size
	_tween = create_tween()
	_tween.tween_property(top_lid, "position:y", -_lid_height, duration)
	_tween.parallel().tween_property(bottom_lid, "position:y", vsize.y, duration)
	_tween.chain().tween_callback(_on_open_finished)


func _on_open_finished() -> void:
	visible = false