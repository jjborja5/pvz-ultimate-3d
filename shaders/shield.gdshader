shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
// Energy shield bubble: fresnel rim, scrolling hex cells, ripple on hit.

uniform vec3 color : source_color = vec3(0.3, 0.8, 1.0);
uniform float strength = 1.0;
uniform float hit = 0.0;

float hexd(vec2 p) {
	p *= vec2(1.0, 1.1547);
	vec2 a = mod(p, vec2(1.0, 1.732)) - vec2(0.5, 0.866);
	vec2 b = mod(p + vec2(0.5, 0.866), vec2(1.0, 1.732)) - vec2(0.5, 0.866);
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	return max(q.x * 0.866 + q.y * 0.5, q.y);
}

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	float h = smoothstep(0.36, 0.46, hexd(UV * vec2(18.0, 9.0) + vec2(0.0, TIME * 0.2)));
	float ripple = 0.5 + 0.5 * sin(UV.y * 40.0 - TIME * 6.0);
	float a = (fres * 0.9 + h * 0.25 * (0.4 + fres) + ripple * 0.05 + hit * 0.5) * strength;
	ALBEDO = color * (1.0 + hit);
	ALPHA = clamp(a, 0.0, 1.0);
}
