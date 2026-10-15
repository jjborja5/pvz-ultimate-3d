shader_type spatial;
// Recolourable material for KayKit atlas-textured props (mountains, rocks, buildings).

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_amount = 0.0;
uniform float snow = 0.0;
uniform float snow_height = 0.6;
uniform float emission_strength = 0.0;
uniform float highlight = 0.0;

varying float v_height;
varying float v_up;

void vertex() {
	v_height = VERTEX.y;
	v_up = NORMAL.y;
}

void fragment() {
	vec3 c = texture(atlas, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, l * tint * 1.6, tint_amount);
	float s = snow * smoothstep(snow_height, snow_height + 0.25, v_height) * smoothstep(0.2, 0.7, v_up);
	c = mix(c, vec3(0.93, 0.96, 1.0), s);
	ALBEDO = c;
	ROUGHNESS = 0.85;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * emission_strength + vec3(1.0, 0.85, 0.4) * highlight * (0.3 + rim);
}
