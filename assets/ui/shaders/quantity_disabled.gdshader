shader_type canvas_item;
uniform bool is_disabled = false;
void fragment() {
    vec4 pixel = texture(TEXTURE, UV) * COLOR;
    if (is_disabled) pixel.rgb = vec3(dot(pixel.rgb, vec3(0.299, 0.587, 0.114)));
    COLOR = pixel;
}
