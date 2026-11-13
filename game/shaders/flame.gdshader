// Chama de propulsor: cone aditivo, mais quente junto ao bocal.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 col : source_color = vec3(1.0, 0.55, 0.22);
uniform float energy = 3.2;
varying float t;
void vertex() { t = clamp(-VERTEX.z, 0.0, 1.0); }
void fragment() {
	float f = 1.0 - t;
	float rim = pow(abs(dot(NORMAL, VIEW)), 0.6);
	vec3 c = mix(col, vec3(1.0, 0.95, 0.9), f * f * 0.7);
	ALBEDO = c * energy * f * rim;
	ALPHA = f * rim;
}
