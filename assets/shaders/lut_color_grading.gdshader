shader_type canvas_item;

uniform sampler2D lut_texture;
uniform sampler2D screen_texture : hint_screen_texture;

void fragment() {
	// 1. 读取屏幕颜色
	vec3 screen_color = texture(screen_texture, SCREEN_UV).rgb;

	// 2. 用 screen_color.rgb 作为坐标查 256×16 的 LUT 图
	//    256×16 = 16 个 16×16 的 tile 横向排列(对应 16×16×16 的 3D LUT)
	//    蓝通道选 tile,红/绿通道为 tile 内坐标
	vec3 c = clamp(screen_color, vec3(0.0), vec3(1.0)) * 15.0;
	float tile = floor(c.b);
	vec2 uv = (vec2(tile * 16.0 + c.r, c.g) + 0.5) / vec2(256.0, 16.0);

	// 3. 输出查到的新颜色
	COLOR = texture(lut_texture, uv);
}