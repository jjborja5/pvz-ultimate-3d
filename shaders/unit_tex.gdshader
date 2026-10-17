shader_type spatial;
// Textured horde shader for baked KayKit character frames (one MultiMesh per frame).
// INSTANCE_CUSTOM: x = hit flash, y = frozen, z = burning, w = elite/ghost glow.

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_amount = 0.0;
uniform vec3 glow_color : source_color = vec3(1.0, 0.3, 0.1);
uniform float glow_strength = 4.0;
uniform float emissive_body = 0.0;      // lava/ghost bosses glow from within
uniform float ghost = 0.0;              // spectral allies
uniform float rim_strength = 0.22;

varying vec4 v_fx;

void vertex() {
	v_fx = INSTANCE_CUSTOM;
}

void fragment() {
	vec3 c = texture(atlas, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 tinted = mix(c, l * tint * 1.7, tint_amount);
	tinted = mix(tinted, vec3(0.55, 0.8, 1.0) * (0.5 + l), v_fx.y * 0.55);
	ALBEDO = tinted;
	ROUGHNESS = 0.7;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float glow = step(0.8, COLOR.a) * step(COLOR.a, 0.95);
	vec3 e = glow_color * glow * glow_strength;
	e += vec3(1.0, 0.95, 0.85) * v_fx.x * 0.8;
	e += vec3(1.0, 0.4, 0.05) * v_fx.z * (0.4 + rim * 1.5);
	// w: 0 = none, 1..2 = elite aura hue (+1), >= 2.5 = boss immunity shield
	if (v_fx.w >= 2.5) {
		e += vec3(0.3, 0.9, 1.0) * (0.6 + rim * 3.0);
	} else if (v_fx.w > 0.5) {
		float h = fract(v_fx.w - 1.0);
		vec3 aura = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
		e += aura * rim * 3.0 + aura * 0.15;
	}
	e += tinted * emissive_body * (0.5 + rim);
	e += tinted * rim * rim_strength;
	EMISSION = e;
	if (ghost > 0.0) {
		ALBEDO = mix(tinted, vec3(0.2, 0.9, 1.0), 0.6) * 0.5;
		EMISSION = vec3(0.2, 0.8, 1.0) * (0.25 + rim * 1.4);
	}
}
