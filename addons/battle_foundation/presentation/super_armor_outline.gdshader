shader_type canvas_item;
render_mode unshaded;
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
// 原GlowFilter(color,1,5,5,3)：整个人物的独立GPU轮廓，不在附件图集上扩边。
uniform float blur_width : hint_range(1.0, 12.0) = 5.0;
uniform float strength : hint_range(0.0, 6.0) = 3.0;
varying vec4 canvas_modulation;

void vertex() {
	canvas_modulation = COLOR;
}

void fragment() {
	float body_alpha = texture(TEXTURE, UV).a;
	float glow = 0.0;
	float weights = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float weight = exp(-float(x * x + y * y) * 0.5);
			vec2 uv = UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * blur_width * 0.25;
			if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
				glow += texture(TEXTURE, uv).a * weight;
			}
			weights += weight;
		}
	}
	// 只绘制轮廓外侧，身体、受击变色、武器和透明度仍由原节点渲染。
	float alpha = clamp(glow / weights * strength, 0.0, 1.0) * (1.0 - body_alpha);
	COLOR = vec4(outline_color.rgb, alpha * outline_color.a) * canvas_modulation;
}
