shader_type spatial;
// Battlefield ground: vertex-coloured biome palette with noise detail, grass tufts
// shading and soft cavity darkening on slopes.

uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform float snow = 0.0;
uniform float cloud_shadows = 0.35;

varying vec3 v_world;
varying vec3 v_normal;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal = NORMAL;
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	float n1 = texture(detail, v_world.xz * 0.045).r;
	float n2 = texture(detail, v_world.xz * 0.21).r;
	float n3 = texture(detail, v_world.xz * 0.9).r;
	vec3 c = base * (0.78 + n1 * 0.32) * (0.9 + n2 * 0.2) * (0.94 + n3 * 0.12);
	// warm/cool hue variation across the field
	c *= mix(vec3(1.04, 1.0, 0.92), vec3(0.94, 1.0, 1.06), n1);
	float slope = 1.0 - clamp(v_normal.y, 0.0, 1.0);
	c *= 1.0 - slope * 0.35;
	// drifting cloud shadows
	float cs = texture(detail, v_world.xz * 0.008 + vec2(TIME * 0.006, TIME * 0.003)).r;
	c *= 1.0 - cloud_shadows * smoothstep(0.45, 0.7, cs);
	float s = snow * smoothstep(3.0, 7.0, v_world.y + n2 * 2.0) * clamp(v_normal.y * 1.4, 0.0, 1.0);
	c = mix(c, vec3(0.92, 0.95, 1.0), s);
	ALBEDO = c;
	ROUGHNESS = 0.92;
}
