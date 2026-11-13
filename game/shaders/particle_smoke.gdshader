shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
#include "particle.gdshaderinc"
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
void fragment() {
	vec2 uv = UV - 0.5;
	float r = length(uv) * 2.0;
	float n = texture(noise_tex, UV * 0.35 + vcol.a * 3.1).r;
	float a = (1.0 - smoothstep(0.25, 1.0, r + (n - 0.5) * 0.7));
	ALBEDO = vcol.rgb * (0.75 + n * 0.5); ALPHA = a * vcol.a * vfade * 0.85;
}
