shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
// Spinning vortex column (fire tornado). Scrolling noise bands twist upward.

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec3 color_a : source_color = vec3(1.0, 0.85, 0.4);
uniform vec3 color_b : source_color = vec3(1.0, 0.3, 0.05);
uniform float intensity = 1.6;

void fragment() {
	vec2 uv = vec2(UV.x * 2.0 + UV.y * 1.5 - TIME * 1.4, UV.y * 1.2 - TIME * 0.8);
	float n = texture(noise_tex, uv).r;
	float n2 = texture(noise_tex, uv * 2.1 + vec2(TIME * 0.3, 0.0)).r;
	float bands = smoothstep(0.45, 0.8, n * 0.65 + n2 * 0.45);
	float edge = smoothstep(0.0, 0.15, UV.y) * (1.0 - smoothstep(0.75, 1.0, UV.y));
	float fres = 1.0 - abs(dot(NORMAL, VIEW));
	vec3 c = mix(color_b, color_a, n2);
	ALBEDO = c * intensity;
	ALPHA = clamp(bands * edge * (0.35 + fres * 0.8), 0.0, 1.0);
}
