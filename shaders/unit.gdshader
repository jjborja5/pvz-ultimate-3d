shader_type spatial;
// GPU-animated horde shader. Each enemy is a single MultiMesh instance.
// Vertex colour alpha encodes the body part (see MeshKit.PART_*).
// INSTANCE_CUSTOM: x = animation clock, y = hit flash, z = frozen amount, w = attack blend.

uniform float hip_height = 0.8;
uniform float shoulder_height = 1.45;
uniform float stride = 0.65;
uniform vec3 glow_color : source_color = vec3(1.0, 0.35, 0.1);
uniform float glow_strength = 3.0;
uniform float rim_strength = 0.18;

varying float v_flash;
varying float v_frozen;
varying float v_part;

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rot_z(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

void vertex() {
	float t = INSTANCE_CUSTOM.x;
	float atk = INSTANCE_CUSTOM.w;
	float part = COLOR.a;
	float s = sin(t);
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	vec3 hip = vec3(0.0, hip_height, 0.0);
	vec3 sh = vec3(0.0, shoulder_height, 0.0);
	if (part < 0.2) {
		mat3 r = rot_x(s * stride * (1.0 - atk));
		v = r * (v - hip) + hip; n = r * n;
	} else if (part < 0.4) {
		mat3 r = rot_x(-s * stride * (1.0 - atk));
		v = r * (v - hip) + hip; n = r * n;
	} else if (part < 0.6) {
		float chop = sin(t * 1.6) * 1.1 - 0.7;
		mat3 r = rot_x(mix(-s * stride * 0.6, chop, atk));
		v = r * (v - sh) + sh; n = r * n;
	} else if (part < 0.8) {
		mat3 r = rot_x(s * stride * 0.6 * (1.0 - atk));
		v = r * (v - sh) + sh; n = r * n;
	}
	// body bob + sway
	mat3 sway = rot_z(sin(t) * 0.07);
	v = sway * v;
	n = sway * n;
	v.y += abs(cos(t)) * 0.08;
	VERTEX = v;
	NORMAL = n;
	v_flash = INSTANCE_CUSTOM.y;
	v_frozen = INSTANCE_CUSTOM.z;
	v_part = part;
}

void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	base = mix(base, vec3(0.55, 0.8, 1.0), v_frozen * 0.65);
	ALBEDO = base;
	ROUGHNESS = 0.75;
	float glow = step(0.8, v_part) * step(v_part, 0.95);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength;
	EMISSION = glow_color * glow * glow_strength
		+ vec3(1.0, 0.95, 0.85) * v_flash * 1.6
		+ vec3(0.5, 0.8, 1.0) * v_frozen * 0.5
		+ base * rim;
}
