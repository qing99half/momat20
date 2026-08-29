extends SubViewport

## 当前使用的 LUT 调色图，可在 Inspector 里拖入，或在运行时赋值切换。
@export var lut_texture: Texture2D:
	set(value):
		lut_texture = value
		_apply_lut()

## 默认中性 LUT(附录E:6个关卡先都挂中性,画面无变化);
## 反色测试 LUT 仅验证 shader 生效时使用,由测试显式设置。
const NEUTRAL_LUT := "res://assets/placeholder/placeholder_lut_neutral.png"

var _post_mat: ShaderMaterial


func _ready() -> void:
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = load("res://assets/shaders/lut_color_grading.gdshader")
	_setup_post_process()
	# 默认挂中性 LUT(画面无变化);换情绪 LUT 时给 lut_texture 赋值即可
	if lut_texture == null:
		lut_texture = load(NEUTRAL_LUT) as Texture2D


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