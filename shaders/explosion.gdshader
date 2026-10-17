shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_mix;
// Expanding fireball: fbm-distorted sphere that cools from white-hot to smoke and
// dissolves. "age" goes 0 -> 1 over the explosion's life (instance uniform).

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec3 hot : source_color = vec3(1.0, 0.95, 0.7);
uniform vec3 mid : source_color = vec3(1.0, 0.45, 0.08);
uniform vec3 cool : source_color = vec3(0.18, 0.12, 0.1);
instance uniform float age = 0.0;
instance uniform float seed = 0.0;

varying vec3 v_n;

void vertex() {
	vec2 uv = UV * vec2(2.0, 1.0) + vec2(seed, seed * 0.7);
	float n = texture(noise_tex, uv + vec2(0.0, -age * 0.6)).r;
	VERTEX += NORMAL * (n - 0.5) * 0.55 * (0.3 + age);
	v_n = NORMAL;
}

void fragment() {
	vec2 uv = UV * vec2(3.0, 1.5) + vec2(seed, seed);
	float n = texture(noise_tex, uv + vec2(age * 0.2, -age * 0.8)).r;
	float n2 = texture(noise_tex, uv * 2.3 - vec2(age * 0.5, age)).r;
	float heat = clamp(1.0 - age * 1.4 + (n - 0.5) * 0.6, 0.0, 1.0);
	vec3 col = mix(cool, mid, smoothstep(0.0, 0.5, heat));
	col = mix(col, hot, smoothstep(0.6, 1.0, heat));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	ALBEDO = col;
	EMISSION = col * heat * 3.0;
	float dissolve = smoothstep(age - 0.15, age + 0.05, n * 0.7 + n2 * 0.3 + 0.15);
	ALPHA = clamp(dissolve * (1.0 - fres * 0.6) * (1.0 - smoothstep(0.75, 1.0, age)), 0.0, 1.0);
}
