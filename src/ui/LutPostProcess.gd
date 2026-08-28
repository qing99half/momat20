extends SubViewport

## 当前使用的 LUT 调色图，可在 Inspector 里拖入，或在运行时赋值切换。
@export var lut_texture: Texture2D:
	set(value):
		lut_texture = value
		_apply_lut()

## 验证用：反色测试 LUT（256×16），确认 shader 生效后换成真正的情绪 LUT。
const TEST_INVERT_LUT := "res://assets/placeholder/placeholder_lut_test_invert.png"

var _post_mat: ShaderMaterial


func _ready() -> void:
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = load("res://assets/shaders/lut_color_grading.gdshader")
	_setup_post_process()
	# 验证用：未在 Inspector 手动设置时，默认加载反色测试 LUT 验证 shader 生效
	if lut_texture == null:
		lut_texture = load(TEST_INVERT_LUT) as Texture2D


func _setup_post_process() -> void:
	var rect := ColorRect.new()
	rect.name = "LUTPostProcess"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _post_mat
	add_child(rect)
	_apply_lut()


func _apply_lut() -> void:
	if _post_mat and lut_texture:
		_post_mat.set_shader_parameter("lut_texture", lut_texture)