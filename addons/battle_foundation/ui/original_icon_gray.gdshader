shader_type canvas_item;
// #region 原Filter.grayFilter灰度，保留图标透明度而非乘暗色
void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * COLOR;
	float gray = dot(pixel.rgb, vec3(0.3086, 0.6094, 0.082));
	COLOR = vec4(vec3(gray), pixel.a);
}
// #endregion
