shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Single camera-facing health bar (structures).

uniform float ratio = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float fill = step(UV.x, ratio);
	vec3 col = mix(vec3(0.1, 0.03, 0.03), mix(vec3(1.0, 0.2, 0.1), vec3(0.3, 0.6, 1.0), ratio), fill);
	float border = step(UV.y, 0.15) + step(0.85, UV.y) + step(UV.x, 0.02) + step(0.98, UV.x);
	ALBEDO = mix(col, vec3(0.02), clamp(border, 0.0, 1.0));
}
