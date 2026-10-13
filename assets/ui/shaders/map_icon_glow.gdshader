shader_type canvas_item;
render_mode unshaded;
void fragment() {
    vec2 uv = (UV - vec2(0.06)) / 0.88;
    float halo = 0.0;
    for (int i = 0; i < 16; i++) {
        float a = float(i) * 6.2831853 / 16.0;
        vec2 direction = vec2(cos(a), sin(a));
        vec2 inner = uv + direction * TEXTURE_PIXEL_SIZE * 4.0;
        vec2 outer = uv + direction * TEXTURE_PIXEL_SIZE * 9.0;
        if (all(greaterThanEqual(inner, vec2(0.0))) && all(lessThanEqual(inner,vec2(1.0)))) halo += texture(TEXTURE,inner).a;
        if (all(greaterThanEqual(outer, vec2(0.0))) && all(lessThanEqual(outer,vec2(1.0)))) halo += texture(TEXTURE,outer).a;
    }
    float center = 0.0;
    if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv,vec2(1.0)))) center = texture(TEXTURE,uv).a;
    halo = clamp(halo / 12.0, 0.0, 1.0) * (1.0 - center);
    COLOR = vec4(1.0, 0.87, 0.3, halo * (0.65 + 0.3 * sin(TIME * 3.0)));
}
