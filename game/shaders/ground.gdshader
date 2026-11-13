// Chão das arenas (um tipo por arena). Procedural, com relevo por derivadas.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform int kind = 0; // 0 aço, 1 concreto molhado, 2 sal, 3 escória, 4 neve
uniform vec3 line_col : source_color = vec3(0.79, 0.64, 0.15);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash12(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash22(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
// distância à borda de célula de Voronoi (rachaduras do sal)
float voro_edge(vec2 x) {
	vec2 n = floor(x); vec2 f = fract(x); vec2 mr; float md = 8.0;
	for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) { vec2 g = vec2(float(i), float(j)); vec2 o = hash22(n + g); vec2 r = g + o - f; float d = dot(r, r); if (d < md) { md = d; mr = r; } }
	md = 8.0;
	for (int j = -2; j <= 2; j++) for (int i = -2; i <= 2; i++) { vec2 g = vec2(float(i), float(j)); vec2 o = hash22(n + g); vec2 r = g + o - f; if (dot(mr - r, mr - r) > 0.00001) md = min(md, dot(0.5 * (mr + r), normalize(r - mr))); }
	return md;
}
void fragment() {
	vec2 p = wp.xz;
	vec3 nz = texture(noise_tex, p * 0.012).rgb; vec3 nm = texture(noise_tex, p * 0.06).rgb; vec3 nf = texture(noise_tex, p * 0.31).rgb;
	vec3 alb; float met = 0.0; float rou = 0.9; float h = 0.0;
	if (kind == 0) {
		vec2 c = p / 4.0; vec2 f = fract(c); vec2 id = floor(c);
		float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		vec2 bf = fract(f * vec2(8.0, 1.0)); float bolt = (1.0 - smoothstep(0.03, 0.06, length(vec2((bf.x - 0.5) / 8.0, min(f.y, 1.0 - f.y) - 0.04))));
		alb = vec3(0.28, 0.29, 0.31) * (0.85 + hash12(id) * 0.18) * (0.8 + nm.g * 0.35);
		alb = mix(alb, vec3(0.12, 0.1, 0.09), smoothstep(0.4, 0.9, nz.r) * 0.6);
		alb = mix(alb, vec3(0.35, 0.2, 0.12), smoothstep(0.75, 0.85, nm.b) * 0.5);
		met = 0.75; rou = 0.45 + nf.b * 0.3 + smoothstep(0.4, 0.9, nz.r) * 0.2;
		h = -(1.0 - smoothstep(0.004, 0.012, e)) + bolt * 0.6 + nf.b * 0.15;
	} else if (kind == 1) {
		vec2 c = p / 6.0; vec2 f = fract(c); vec2 id = floor(c);
		float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		alb = vec3(0.4, 0.41, 0.42) * (0.88 + hash12(id) * 0.12) * (0.75 + nm.g * 0.4);
		float crack = 1.0 - smoothstep(0.0, 0.012, abs(nm.r - 0.5) * (1.0 + nz.g));
		alb *= 1.0 - crack * 0.5; alb = mix(alb, alb * vec3(0.6, 0.58, 0.55), smoothstep(0.5, 0.9, nz.r) * 0.6);
		float pud = smoothstep(0.52, 0.6, nz.g + nf.b * 0.06);
		rou = mix(0.82 + nf.b * 0.15, 0.03, pud); alb *= 1.0 - pud * 0.45; met = pud * 0.1;
		h = -(1.0 - smoothstep(0.004, 0.01, e)) - crack * 0.5 + nf.b * 0.3 * (1.0 - pud);
	} else if (kind == 2) {
		float ve = voro_edge(p / 5.5 + nz.rg * 0.6);
		float crack = 1.0 - smoothstep(0.015, 0.05, ve);
		alb = vec3(0.86, 0.83, 0.76) * (0.9 + nm.g * 0.12); alb = mix(alb, vec3(0.62, 0.55, 0.45), smoothstep(0.45, 0.9, nz.r) * 0.35);
		alb = mix(alb, vec3(0.5, 0.42, 0.34), crack * 0.7); rou = 0.88; h = crack * 0.8 + nf.b * 0.25 + smoothstep(0.0, 0.2, ve) * 0.3;
	} else if (kind == 3) {
		alb = vec3(0.13, 0.11, 0.1) * (0.7 + nm.g * 0.6); alb = mix(alb, vec3(0.03, 0.025, 0.02), smoothstep(0.4, 0.8, nz.r) * 0.7);
		float glint = smoothstep(0.85, 0.92, nf.g); alb += vec3(0.25, 0.08, 0.02) * glint * 0.3;
		vec2 f = fract(p / 12.0); float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		rou = 0.9 - glint * 0.4; met = 0.2 + glint * 0.5; h = nf.b * 0.9 + nm.b * 0.4 - (1.0 - smoothstep(0.0, 0.004, e)) * 0.6;
	} else {
		alb = vec3(0.85, 0.88, 0.93) * (0.9 + nm.g * 0.1); alb = mix(alb, vec3(0.6, 0.68, 0.78), smoothstep(0.5, 0.9, nz.r) * 0.25);
		float rip = sin(dot(p, vec2(0.38, 0.12)) * 3.0 + nm.r * 7.0) * 0.5 + 0.5;
		rou = 0.65 + nf.b * 0.2; h = rip * 0.5 + nf.b * 0.3; met = 0.0;
		alb += vec3(0.2) * smoothstep(0.93, 0.97, nf.g);
	}
	if (h != 0.0) {
		vec3 dpx = dFdx(VERTEX); vec3 dpy = dFdy(VERTEX);
		float dhx = dFdx(h) * 0.025; float dhy = dFdy(h) * 0.025;
		vec3 r1 = cross(dpy, NORMAL); vec3 r2 = cross(NORMAL, dpx); float det = dot(dpx, r1);
		if (abs(det) > 1e-10) { vec3 g = (dhx * r1 + dhy * r2) / det; float gl = length(g); if (gl > 0.5) g *= 0.5 / gl; NORMAL = normalize(NORMAL - g); }
	}
	ALBEDO = alb; METALLIC = met; ROUGHNESS = clamp(rou, 0.03, 1.0);
}
