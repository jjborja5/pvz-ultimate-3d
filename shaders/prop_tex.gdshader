shader_type spatial;
// Recolourable material for KayKit atlas-textured props (mountains, rocks, buildings).
// stone_detail > 0 adds world-space masonry (staggered bricks, mortar, per-brick colour
// variation and grime toward the ground) on grey/stone-coloured parts of the atlas.

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_amount = 0.0;
uniform float snow = 0.0;
uniform float snow_height = 0.6;
uniform float emission_strength = 0.0;
uniform float highlight = 0.0;
uniform float stone_detail = 0.0;
uniform float brick_height = 0.55;
uniform float brick_width = 1.1;

varying float v_height;
varying float v_up;
varying vec3 v_world;
varying vec3 v_wnormal;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	v_height = VERTEX.y;
	v_up = NORMAL.y;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 masonry(vec3 base) {
	vec3 n = abs(v_wnormal);
	vec2 uv;
	if (n.y > 0.7) {
		uv = v_world.xz / vec2(brick_width, brick_width * 0.8);
	} else if (n.x > n.z) {
		uv = vec2(v_world.z / brick_width, v_world.y / brick_height);
	} else {
		uv = vec2(v_world.x / brick_width, v_world.y / brick_height);
	}
	float row = floor(uv.y);
	uv.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float edge = min(min(f.x, 1.0 - f.x) * brick_width, min(f.y, 1.0 - f.y) * brick_height);
	float mortar = 1.0 - smoothstep(0.02, 0.06, edge);
	float h = hash21(cell);
	vec3 c = base * (0.86 + h * 0.24);
	c = mix(c, c * vec3(1.04, 1.0, 0.92), step(0.7, hash21(cell + 7.1)));   // warm stones
	c = mix(c, base * 0.55, mortar * 0.8);
	// bevel: lighter top edge of each brick
	c += base * 0.08 * smoothstep(0.88, 0.97, f.y) * (1.0 - mortar);
	// grime / damp toward the ground
	c *= mix(0.72, 1.0, smoothstep(0.0, 2.5, v_world.y));
	return c;
}

void fragment() {
	vec3 c = texture(atlas, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	if (stone_detail > 0.0) {
		float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
		float is_stone = (1.0 - smoothstep(0.08, 0.16, sat)) * step(0.25, l);
		c = mix(c, masonry(c), is_stone * stone_detail);
	}
	c = mix(c, l * tint * 1.6, tint_amount);
	float s = snow * smoothstep(snow_height, snow_height + 0.25, v_height) * smoothstep(0.2, 0.7, v_up);
	c = mix(c, vec3(0.93, 0.96, 1.0), s);
	ALBEDO = c;
	ROUGHNESS = 0.85;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * emission_strength + vec3(1.0, 0.85, 0.4) * highlight * (0.3 + rim);
}
