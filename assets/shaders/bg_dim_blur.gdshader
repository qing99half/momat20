shader_type canvas_item;
// 远景背景处理:调暗 + 轻模糊(5 点采样近似高斯,远处景深效果)
// dim 亮度系数(越小越暗);blur_radius 模糊半径(像素)
uniform float dim : hint_range(0.0, 1.0) = 0.62;
uniform float blur_radius : hint_range(0.0, 8.0) = 2.2;

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE * blur_radius;
	vec4 c = texture(TEXTURE, UV) * 0.4;
	c += texture(TEXTURE, UV + vec2(ps.x, 0.0)) * 0.15;
	c += texture(TEXTURE, UV - vec2(ps.x, 0.0)) * 0.15;
	c += texture(TEXTURE, UV + vec2(0.0, ps.y)) * 0.15;
	c += texture(TEXTURE, UV - vec2(0.0, ps.y)) * 0.15;
	COLOR = vec4(c.rgb * dim, c.a);
}
