// 180：墨晕开的一片 —— 以 center 为圆心、半径 radius（像素，节点本地坐标）以内显出来，边缘按噪声起伏、羽化 softness。
// 开局第三页的地图预览（MapPreview）整块挂它：底图与圈只在晕开的那片里看得见，外面露出纸。
shader_type canvas_item;

uniform vec2 center = vec2(0.0);
uniform float radius = 0.0;
uniform float softness = 24.0;
uniform sampler2D noise : repeat_enable, filter_linear;
// 噪声把边缘推进 / 拉回多少（× radius）
uniform float noise_amp = 0.12;
// 噪声纹理的平铺尺度（像素一格）与随时间的漂移
uniform float noise_scale = 256.0;
uniform float drift_speed = 0.02;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
	if (radius <= 0.0) {
		COLOR.a = 0.0;
	} else {
		float n = texture(noise, local_pos / noise_scale + vec2(TIME * drift_speed)).r;
		float edge = radius * (1.0 + (n - 0.5) * noise_amp * 2.0);
		float d = length(local_pos - center);
		COLOR.a *= 1.0 - smoothstep(edge - softness, edge + softness, d);
	}
}
