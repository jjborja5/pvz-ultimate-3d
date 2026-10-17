shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
// Soft light beam: bright core facing the camera, transparent rim, fades toward both ends
// so overlapping pillars never wash out the screen.

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform float intensity = 1.2;
uniform float fade = 1.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float core = pow(facing, 3.0);
	float ends = smoothstep(0.0, 0.25, UV.y) * (1.0 - smoothstep(0.75, 1.0, UV.y));
	float shimmer = 0.85 + 0.15 * sin(UV.y * 40.0 - TIME * 12.0);
	float a = core * ends * shimmer * fade;
	ALBEDO = mix(color.rgb, vec3(1.0), core * 0.5) * intensity * a;
}
