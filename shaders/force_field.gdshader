shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
// Shimmering arcane barrier: hexagonal cells, scrolling energy, flares when hit.

uniform vec3 color : source_color = vec3(0.3, 0.7, 1.0);
uniform float hit = 0.0;

float hex_edge(vec2 p) {
	p *= vec2(1.0, 1.1547);
	vec2 a = mod(p, vec2(1.0, 1.7320)) - vec2(0.5, 0.866);
	vec2 b = mod(p + vec2(0.5, 0.866), vec2(1.0, 1.7320)) - vec2(0.5, 0.866);
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	float d = max(q.x * 0.866 + q.y * 0.5, q.y);
	return smoothstep(0.38, 0.47, d);
}

void fragment() {
	vec2 uv = UV;
	float edges = hex_edge(uv * vec2(6.0, 3.0) + vec2(0.0, TIME * 0.15));
	float wave = 0.5 + 0.5 * sin(uv.y * 18.0 - TIME * 4.0);
	float fade = smoothstep(0.0, 0.15, uv.y) * smoothstep(1.0, 0.7, uv.y) * smoothstep(0.0, 0.05, uv.x) * smoothstep(1.0, 0.95, uv.x);
	float a = (0.12 + edges * 0.55 + wave * 0.08 + hit * 0.6) * fade;
	ALBEDO = color * (1.2 + hit * 2.0);
	ALPHA = a;
}
