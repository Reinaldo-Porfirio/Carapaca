shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
#include "particle.gdshaderinc"
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = (1.0 - smoothstep(0.0, 1.0, r)); a = a * a * (0.55 + 0.45 * (1.0 - smoothstep(0.0, 0.3, r)));
	ALBEDO = vcol.rgb * a * vcol.a * vfade;
}
