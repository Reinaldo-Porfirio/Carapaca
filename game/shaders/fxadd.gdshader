// Brilho aditivo simples (rastros, feixes, anéis, esferas). Cor da instância/uniforme × intensidade.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float energy = 2.0;
uniform bool use_instance = false;
uniform bool radial = false;
varying vec4 ic;
void vertex() { ic = use_instance ? COLOR : vec4(1.0); }
void fragment() {
	float a = 1.0;
	if (radial) a = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	vec4 c = use_instance ? ic : col;
	ALBEDO = c.rgb * energy * c.a * a;
}
