// 339：反应的飘字 —— 字从左到右由 color_a 过渡到 color_b（两种元素色）。
// 字本身用白色，这里按横向位置乘上两色之间的颜色；描边是黑的，乘了还是黑，不受影响。
// 过渡只在中间三分之一，字短时两头的颜色也看得出。
shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(1.0);
uniform vec4 color_b : source_color = vec4(1.0);
// 字的宽（像素，节点本地坐标）
uniform float width = 1.0;

varying float local_x;

void vertex() {
	local_x = VERTEX.x;
}

void fragment() {
	float k = smoothstep(1.0 / 3.0, 2.0 / 3.0, local_x / max(width, 1.0));
	COLOR.rgb *= mix(color_a.rgb, color_b.rgb, k);
}
