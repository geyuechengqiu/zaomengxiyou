// #region 脚本实现
shader_type canvas_item;

// 进度值 (0.0 - 1.0)
uniform float value: hint_range(0.0, 1.0) = 0.0;

// 遮罩颜色
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);

// 起始角度偏移 (默认从 12 点方向开始)
uniform float rotation_offset_deg = -90.0;

void fragment() {
	// 获取当前像素相对于 UV 中心的向量
	vec2 uv =  UV - vec2(0.5);

    // 计算当前像素的角度 (atan2 返回范围 -PI 到 PI)
	float angle = atan(uv.y, uv.x);

    // 将角度转换为 0.0 - 1.0 的范围 (0 是 3点钟方向, 顺时针增加)
    // 我们需要加上偏移量来调整起始位置
    float rotation_rad = radians(rotation_offset_deg);
	float normalize_angle = fract((angle - rotation_rad)/ (2.0 * PI));

    // 核心逻辑：如果当前角度大于进度值，则显示遮罩颜色
    // 进度 0.0 -> 全黑 (1.0 > 0.0)
    // 进度 1.0 -> 全透明 (0.0 > 1.0)
    // 这里我们做"冷却倒计时"效果：value 代表"剩余时间比例"
    // value = 1.0 (刚开始冷却) -> 全黑
    // value = 0.0 (冷却结束) -> 全透明
    if (normalize_angle < value) {
		COLOR = bg_color;
	}
	else{
		COLOR = vec4(0.0); // 全透明
	}
}
// #endregion
