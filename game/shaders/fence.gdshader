// Barreira de contenção do campo.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 col : source_color = vec3(0.35, 0.72, 1.0);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float h = wp.y / 26.0;
	float l = step(0.9, fract(wp.y * 0.5 - TIME * 0.5));
	float near = smoothstep(150.0, 25.0, distance(wp, CAMERA_POSITION_WORLD));
	float a = (0.025 + l * 0.07) * smoothstep(1.0, 0.0, h) * near + smoothstep(0.06, 0.0, h) * 0.14;
	ALBEDO = col * 1.4 * a;
}
