shader_type canvas_item;
// #region 原版ColorTransform白色剪影；保留原像素alpha
void fragment() {
	vec4 original = texture(TEXTURE, UV);
	COLOR = vec4(vec3(1.0), original.a * COLOR.a);
}
// #endregion
