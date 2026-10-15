shader_type spatial;
// Static vertex-coloured props (castle, towers, pads). Alpha band 0.8..0.95 glows.

uniform vec3 glow_color : source_color = vec3(1.0, 0.8, 0.45);
uniform float glow_strength = 2.5;
uniform float pulse_speed = 0.0;
uniform float roughness_value = 0.85;
uniform float highlight = 0.0;

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = base;
	ROUGHNESS = roughness_value;
	float glow = step(0.8, COLOR.a) * step(COLOR.a, 0.95);
	float pulse = pulse_speed > 0.0 ? 0.75 + 0.25 * sin(TIME * pulse_speed) : 1.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = glow_color * glow * glow_strength * pulse + vec3(1.0, 0.9, 0.5) * highlight * (0.25 + rim);
}
