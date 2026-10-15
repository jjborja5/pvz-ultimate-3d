shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Camera-facing health bars for the horde, one MultiMesh instance each.
// INSTANCE_CUSTOM.x = health ratio, INSTANCE_CUSTOM.y = width scale.

varying float v_ratio;

void vertex() {
	VERTEX.x *= INSTANCE_CUSTOM.y;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	v_ratio = INSTANCE_CUSTOM.x;
}

void fragment() {
	float fill = step(UV.x, v_ratio);
	vec3 good = vec3(0.25, 0.95, 0.2);
	vec3 bad = vec3(1.0, 0.18, 0.08);
	vec3 col = mix(vec3(0.12, 0.02, 0.02), mix(bad, good, v_ratio), fill);
	float border = step(UV.y, 0.18) + step(0.82, UV.y) + step(UV.x, 0.03) + step(0.97, UV.x);
	col = mix(col, vec3(0.03, 0.02, 0.02), clamp(border, 0.0, 1.0));
	ALBEDO = col;
}
