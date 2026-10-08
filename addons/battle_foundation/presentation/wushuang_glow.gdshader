// #region 原版GlowFilter的整个人物轮廓辉光；纹理来自隔离的GPU快照
shader_type canvas_item;
render_mode unshaded;
uniform vec4 glow_color : source_color = vec4(1.0, 0.1882353, 0.0, 1.0);
uniform float blur_width : hint_range(1.0, 60.0) = 10.0;
uniform bool include_body = false;
varying vec4 canvas_modulation;

void vertex() {
	// fragment 的 COLOR 已乘原纹理，不能用它调制轮廓外的辉光。
	canvas_modulation = COLOR;
}

void fragment() {
	vec4 modulation = canvas_modulation;
	vec4 body = texture(TEXTURE, UV);
	float halo = 0.0;
	float weight_sum = 0.0;
	// 5×5 Gaussian近似Flash quality=2模糊；不在图集上采样，避免邻近附件串色。
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float weight = exp(-float(x * x + y * y) * 0.5);
			vec2 uv = UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * blur_width * 0.25;
			float alpha = 0.0;
			if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) alpha = texture(TEXTURE, uv).a;
			halo += alpha * weight;
			weight_sum += weight;
		}
	}
	halo = clamp(halo / weight_sum * glow_color.a, 0.0, 1.0);
	if (include_body) {
		float alpha = body.a + halo * (1.0 - body.a);
		vec3 rgb = (body.rgb * body.a + glow_color.rgb * halo * (1.0 - body.a)) / max(alpha, 0.00001);
		COLOR = vec4(rgb, alpha) * modulation;
	} else {
		COLOR = vec4(glow_color.rgb, halo) * modulation;
	}
}
// #endregion
