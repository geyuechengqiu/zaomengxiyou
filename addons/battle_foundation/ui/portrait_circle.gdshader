shader_type canvas_item;
// #region 原头像圆形裁切
// RoleInfoViewer原版头像：中心(38,40)，半径30；使用同窗口裁切。
void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * COLOR;
	pixel.a *= 1.0 - smoothstep(0.49, 0.5, distance(UV, vec2(0.5)));
	COLOR = pixel;
}
// #endregion
