// Partículas de clima presas à câmera (neve, garoa, brasas, poeira). Posição calculada na GPU.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 vel = vec3(0.0, -9.0, 0.0);
uniform vec3 col : source_color = vec3(1.0);
uniform float size = 0.6;
uniform float alpha = 0.6;
uniform float sway = 0.0;
uniform float t = 0.0;
uniform bool additive = false;
uniform vec3 cam = vec3(0.0);
varying float va;
void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	vec3 p = cd.xyz * vec3(160.0, 90.0, 160.0) + vel * t * (0.6 + cd.w * 0.8);
	p.x += sin(t * (0.5 + cd.w) + cd.w * 40.0) * sway; p.z += cos(t * (0.4 + cd.w) + cd.w * 20.0) * sway;
	p = mod(p - cam + vec3(80.0, 30.0, 80.0), vec3(160.0, 90.0, 160.0)) + cam - vec3(80.0, 30.0, 80.0);
	vec4 v = VIEW_MATRIX * vec4(p, 1.0);
	float sz = size * (0.5 + cd.w);
	v.xy += VERTEX.xy * sz;
	va = smoothstep(90.0, 40.0, -v.z) * smoothstep(1.0, 4.0, -v.z);
	POSITION = PROJECTION_MATRIX * v;
}
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = (1.0 - smoothstep(0.2, 1.0, r)) * alpha * va;
	ALBEDO = col * (additive ? 2.5 : 1.0); ALPHA = a;
}
