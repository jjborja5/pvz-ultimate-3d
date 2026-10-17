shader_type spatial;
// Animated lava / water surface using a scrolling noise texture.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 color_a : source_color = vec3(1.0, 0.25, 0.02);
uniform vec3 color_b : source_color = vec3(1.0, 0.85, 0.3);
uniform float emissive = 3.0;
uniform float scroll = 0.03;
uniform float uv_scale = 0.06;
uniform float roughness_value = 0.4;
uniform float wave_height = 0.12;

void vertex() {
	vec2 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y += sin(w.x * 0.4 + TIME * 1.2) * cos(w.y * 0.3 + TIME) * wave_height;
}

void fragment() {
	vec2 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz * uv_scale;
	float n1 = texture(noise_tex, w + vec2(TIME * scroll, TIME * scroll * 0.6)).r;
	float n2 = texture(noise_tex, w * 1.9 - vec2(TIME * scroll * 0.7, TIME * scroll * 1.3)).r;
	float n = smoothstep(0.35, 0.8, n1 * 0.6 + n2 * 0.5);
	vec3 c = mix(color_a, color_b, n);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = c * 0.4;
	ROUGHNESS = roughness_value;
	METALLIC = emissive < 1.0 ? 0.2 : 0.0;
	SPECULAR = emissive < 1.0 ? 0.8 : 0.3;
	// sky-tinted fresnel sheen + glints on water; churning glow on lava
	EMISSION = c * emissive * (0.4 + n) + (emissive < 1.0 ? vec3(0.6, 0.8, 1.0) * fres * 0.5 + vec3(1.0) * pow(n2, 8.0) * 0.8 : vec3(0.0));
}
