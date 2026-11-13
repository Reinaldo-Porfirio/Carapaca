// Material único das carcaças. O "slot" de cada face vem da cor do vértice (R * 16).
// Painéis, sulcos, sujeira e lascas são procedurais (triplanar em espaço local), sem texturas grandes.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 paint_a : source_color = vec3(0.54, 0.56, 0.53);
uniform vec3 paint_b : source_color = vec3(0.79, 0.33, 0.12);
uniform vec3 paint_c : source_color = vec3(0.17, 0.18, 0.19);
uniform vec3 glow : source_color = vec3(1.0, 0.6, 0.24);
uniform vec3 decal_ink : source_color = vec3(0.1, 0.1, 0.11);
uniform float wear : hint_range(0.0, 1.0) = 0.5;
uniform float glow_energy = 4.0;
uniform float track_scroll = 0.0;
uniform float cloak : hint_range(0.0, 1.0) = 0.0;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform int debug_mode = 0;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D decal_tex : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;

varying vec3 lp;
varying vec3 ln;
varying float slot;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	slot = floor(COLOR.r * 16.0 + 0.5);
}

float hash12(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec3 an = abs(normalize(ln));
	vec3 w = pow(an, vec3(5.0)); w /= (w.x + w.y + w.z);
	// três ruídos (R grosso, G médio, B fino) amostrados em triplanar
	vec3 nz = texture(noise_tex, lp.zy * 0.13).rgb * w.x + texture(noise_tex, lp.xz * 0.13).rgb * w.y + texture(noise_tex, lp.xy * 0.13).rgb * w.z;
	vec3 nf = texture(noise_tex, lp.zy * 0.9 + 0.31).rgb * w.x + texture(noise_tex, lp.xz * 0.9 + 0.31).rgb * w.y + texture(noise_tex, lp.xy * 0.9 + 0.31).rgb * w.z;
	vec2 pp = (an.x > an.y && an.x > an.z) ? lp.zy : ((an.y > an.z) ? lp.xz : lp.xy);
	int s = int(slot + 0.5);
	vec3 alb = paint_a; float met = 0.25; float rou = 0.6; float ao = 1.0; float h = 0.0; vec3 emi = vec3(0.0);
	if (s == 10) {
		vec4 d = texture(decal_tex, UV);
		float worn = smoothstep(0.35, 0.65, nf.b + (1.0 - wear) * 0.35);
		if (d.a * worn < 0.4) discard;
		alb = decal_ink; met = 0.1; rou = 0.8;
	} else if (s <= 2 || s == 8) {
		// painéis: grade 1,15 m com variação por placa e sulcos
		vec2 cell = pp / 1.15 + vec2(0.37, 0.61);
		vec2 f = fract(cell); vec2 id = floor(cell);
		float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		float groove = 1.0 - smoothstep(0.006, 0.02, edge);
		vec2 rv = abs(f - 0.5);
		float rivet = (1.0 - smoothstep(0.010, 0.018, length(vec2(abs(rv.x - 0.44), abs(rv.y - 0.44))))) * step(0.55, hash12(id + 7.0));
		vec3 base = s == 0 ? paint_a : (s == 1 ? paint_b : paint_c);
		if (s == 8) {
			float st = step(0.5, fract((pp.x + pp.y) * 1.6));
			base = mix(vec3(0.02, 0.019, 0.022), vec3(0.85, 0.62, 0.05), st);
		}
		base *= 0.93 + hash12(id) * 0.12;
		vec3 dbg_base = base;
		// sujeira e escorridos
		float grime = smoothstep(0.35, 0.9, nz.r) * (0.25 + wear * 0.55);
		float streak = smoothstep(0.55, 0.95, texture(noise_tex, vec2(pp.x * 0.7, pp.y * 0.06)).g) * wear * 0.5;
		base = mix(base, base * vec3(0.42, 0.36, 0.3), clamp(grime + streak, 0.0, 0.85));
		// lascas: tinta arrancada revela metal, mais perto das bordas das placas
		float near_edge = 1.0 - smoothstep(0.0, 0.1, edge);
		float chipth = 0.9 - wear * 0.16 - near_edge * 0.3;
		float chip = smoothstep(chipth, chipth + 0.06, nz.g * 0.8 + nf.g * 0.2) * smoothstep(0.0, 0.5, wear + near_edge);
		alb = mix(base, vec3(0.5, 0.49, 0.47), chip);
		met = mix(s == 2 ? 0.45 : 0.15, 0.6, chip);
		rou = mix(0.62 + grime * 0.3 - nz.b * 0.1, 0.38, chip);
		ao = 1.0 - groove * 0.55;
		h = -groove * 0.9 + rivet * 0.6 - chip * 0.15;
		alb = mix(alb, vec3(0.75), rivet * 0.25);
		if (debug_mode == 8) alb = dbg_base;
		if (debug_mode == 9) alb = vec3(chip);
		if (debug_mode == 10) alb = vec3(rivet);
		if (debug_mode == 11) alb = vec3(groove);
	} else if (s == 3) { alb = vec3(0.6, 0.6, 0.62) * (0.85 + nz.g * 0.25); met = 1.0; rou = 0.25 + nz.b * 0.2 + wear * 0.1; }
	else if (s == 4) { alb = vec3(0.05, 0.05, 0.053); met = 0.2; rou = 0.8; }
	else if (s == 5) { alb = vec3(0.015, 0.02, 0.025); met = 1.0; rou = 0.06; }
	else if (s == 6) { alb = vec3(0.86, 0.84, 0.78) * (0.92 + nz.g * 0.1); met = 0.0; rou = 0.28 + nf.b * 0.2; }
	else if (s == 7) { alb = glow * 0.6; met = 0.0; rou = 0.4; emi = glow * glow_energy; }
	else if (s == 9) {
		float t = fract((lp.z + track_scroll) * 2.2);
		float pad = smoothstep(0.08, 0.14, t) * (1.0 - smoothstep(0.7, 0.76, t));
		alb = mix(vec3(0.03), vec3(0.11, 0.105, 0.1), pad) * (0.8 + nz.g * 0.4); met = 0.55; rou = 0.75; h = pad * 0.8;
	}
	// relevo por derivadas (sulcos, rebites, lascas)
	if (h != 0.0) {
		vec3 dpx = dFdx(VERTEX); vec3 dpy = dFdy(VERTEX);
		float fade = 1.0 - smoothstep(0.02, 0.08, length(fwidth(lp)));
		float dhx = dFdx(h) * 0.02 * fade; float dhy = dFdy(h) * 0.02 * fade;
		vec3 r1 = cross(dpy, NORMAL); vec3 r2 = cross(NORMAL, dpx);
		float det = dot(dpx, r1);
		if (abs(det) > 1e-10) {
			vec3 g = (dhx * r1 + dhy * r2) / det;
			float gl = length(g);
			if (gl > 0.6) g *= 0.6 / gl;
			NORMAL = normalize(NORMAL - g);
		}
	}
	if (cloak > 0.0) {
		float dth = hash12(floor(FRAGCOORD.xy) + vec2(TIME * 60.0, 0.0));
		if (dth < cloak) discard;
		emi += vec3(0.2, 0.35, 0.45) * (1.0 - dth) * cloak;
	}
	emi += vec3(1.0, 0.35, 0.08) * heat * (0.4 + 0.6 * nz.r);
	if (debug_mode == 1) { alb = vec3(h * 0.5 + 0.5); met = 0.0; rou = 1.0; NORMAL = normalize(ln); }
	if (debug_mode == 2) { alb = vec3(slot / 10.0); met = 0.0; rou = 1.0; }
	if (debug_mode == 3) { alb = nf; met = 0.0; rou = 1.0; }
	if (debug_mode >= 4 && debug_mode != 5 && debug_mode != 7) { met = 0.0; rou = 1.0; }
	if (debug_mode == 5) { rou = 1.0; }
	if (debug_mode == 7) { alb = vec3(fract(slot * 0.37), fract(slot * 0.61 + 0.2), fract(slot * 0.83 + 0.5)); met = 0.0; rou = 1.0; emi = vec3(0.0); }
	ALBEDO = alb; METALLIC = met; ROUGHNESS = clamp(rou, 0.04, 1.0); AO = ao; AO_LIGHT_AFFECT = 0.4; EMISSION = emi;
}
