// Material único do cenário (slots pela cor do vértice, R * 32). Triplanar em espaço de mundo.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 lamp_col : source_color = vec3(1.0, 0.95, 0.86);
uniform float wet = 0.0;
uniform float time_s = 0.0;
varying vec3 wp;
varying vec3 wn;
varying float slot;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); slot = COLOR.r * 32.0; }
float hash12(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec3 an = abs(wn); vec3 w = pow(an, vec3(6.0)); w /= (w.x + w.y + w.z);
	vec3 nz = texture(noise_tex, wp.zy * 0.035).rgb * w.x + texture(noise_tex, wp.xz * 0.035).rgb * w.y + texture(noise_tex, wp.xy * 0.035).rgb * w.z;
	vec3 nf = texture(noise_tex, wp.zy * 0.21).rgb * w.x + texture(noise_tex, wp.xz * 0.21).rgb * w.y + texture(noise_tex, wp.xy * 0.21).rgb * w.z;
	vec2 pp = (an.x > an.y && an.x > an.z) ? wp.zy : ((an.y > an.z) ? wp.xz : wp.xy);
	int s = int(slot + 0.5);
	vec3 alb = vec3(0.5); float met = 0.0; float rou = 0.85; vec3 emi = vec3(0.0); float h = 0.0;
	float grime = smoothstep(0.3, 0.85, nz.r);
	float low = 1.0 - smoothstep(0.0, 6.0, wp.y);
	if (s == 0) { // concreto
		vec2 c = pp / vec2(4.0, 2.0); vec2 f = fract(c); float e = min(min(f.x, 1.0 - f.x) * 4.0, min(f.y, 1.0 - f.y) * 2.0);
		alb = vec3(0.47, 0.47, 0.46) * (0.82 + nf.g * 0.3) * (0.92 + hash12(floor(c)) * 0.12); rou = 0.9; h = -(1.0 - smoothstep(0.02, 0.06, e));
		alb = mix(alb, alb * vec3(0.55, 0.5, 0.45), grime * 0.6 + low * 0.25);
	} else if (s == 1) { alb = vec3(0.16, 0.165, 0.175) * (0.85 + nf.g * 0.3); met = 0.45; rou = 0.7 - nf.b * 0.2; alb = mix(alb, alb * 0.6, grime * 0.5); }
	else if (s == 2) { alb = vec3(0.36, 0.38, 0.41) * (0.85 + nz.g * 0.25); met = 0.9; rou = 0.38 + nf.b * 0.25; vec2 f = fract(pp / 1.6); h = -(1.0 - smoothstep(0.0, 0.02, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)))); }
	else if (s == 3) { float r2 = smoothstep(0.3, 0.7, nz.g + nf.b * 0.3); alb = mix(vec3(0.35, 0.2, 0.13), vec3(0.5, 0.27, 0.14), r2) * (0.75 + nf.g * 0.4); met = 0.35; rou = 0.92; h = nf.b * 0.5; }
	else if (s == 4) { // rocha estratificada
		float band = sin(wp.y * 2.4 + nz.r * 6.0) * 0.5 + 0.5;
		alb = mix(vec3(0.53, 0.43, 0.33), vec3(0.72, 0.62, 0.5), band) * (0.8 + nf.g * 0.35); rou = 0.95; h = band * 0.6 + nf.b * 0.6;
	}
	else if (s == 5) { alb = vec3(0.78, 0.8, 0.8) * (0.9 + nf.g * 0.12); met = 0.2; rou = 0.55; alb = mix(alb, alb * 0.75, grime * 0.4); vec2 f = fract(pp / 2.0); h = -(1.0 - smoothstep(0.0, 0.015, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)))); }
	else if (s == 6) { float st = step(0.5, fract((pp.x + pp.y) * 0.5)); alb = mix(vec3(0.02), vec3(0.8, 0.58, 0.05), st) * (0.8 + nf.g * 0.3); rou = 0.75; met = 0.3; alb = mix(alb, alb * 0.5, grime * 0.5); }
	else if (s >= 7 && s <= 13) { // contêineres corrugados
		vec3 cols[7] = vec3[7](vec3(0.55, 0.23, 0.16), vec3(0.18, 0.36, 0.49), vec3(0.25, 0.42, 0.29), vec3(0.78, 0.6, 0.16), vec3(0.73, 0.71, 0.67), vec3(0.33, 0.35, 0.36), vec3(0.48, 0.29, 0.42));
		vec3 base = cols[s - 7];
		float axis = an.x > an.z ? wp.z : wp.x;
		float rib = sin(axis * 6.2832 * 2.4);
		h = (an.y > 0.7) ? 0.0 : rib;
		// ferrugem: escorre de cima em filetes e se acumula embaixo (sem manchas de "oncinha")
		float drip = texture(noise_tex, vec2(axis * 0.9, wp.y * 0.05 + 0.4)).g;
		float rust = smoothstep(0.66, 0.86, drip * 0.55 + nz.g * 0.35 + low * 0.3 + nf.b * 0.08) * 0.65;
		vec3 faded = mix(base, vec3(dot(base, vec3(0.33))), 0.25 * nz.r) * (0.88 + nz.g * 0.16);
		alb = mix(faded, vec3(0.3, 0.18, 0.11) * (0.8 + nf.r * 0.3), rust); met = mix(0.5, 0.25, rust); rou = mix(0.5 + nf.b * 0.15, 0.88, rust);
		alb = mix(alb, alb * 0.62, grime * 0.35 + low * 0.2);
	}
	else if (s == 14) { emi = lamp_col * 5.0; alb = vec3(1.0); }
	else if (s == 15) { emi = vec3(1.0, 0.12, 0.06) * 4.0; alb = vec3(0.5, 0.05, 0.02); }
	else if (s == 16) { // escória incandescente
		// placas de crosta escura separadas por rachaduras incandescentes que andam devagar
		vec2 q = wp.xz + vec2(time_s * 0.35, time_s * 0.12);
		float n1 = texture(noise_tex, q * 0.028).r; float n2 = texture(noise_tex, q * 0.07 + 0.5).g;
		float r1 = 1.0 - abs(n1 * 2.0 - 1.0); float r2 = 1.0 - abs(n2 * 2.0 - 1.0);
		float w1 = fwidth(r1) * 1.5; float w2 = fwidth(r2) * 1.5;
		float c1 = smoothstep(0.82 - w1, 0.94 + w1, r1); float c2 = smoothstep(0.88 - w2, 0.96 + w2, r2) * 0.6;
		float far = smoothstep(0.08, 0.3, w2); c1 = mix(c1, 0.3, far); c2 = mix(c2, 0.2, far);
		float hot = smoothstep(0.55, 0.8, texture(noise_tex, q * 0.02).b);
		float glw = clamp(max(c1, c2) + hot * 0.35, 0.0, 1.0);
		emi = vec3(1.0, 0.28, 0.04) * (glw * 3.2 + 0.1) + vec3(1.0, 0.6, 0.2) * c1 * 1.2;
		alb = vec3(0.07, 0.05, 0.045) * (0.8 + nf.g * 0.4); rou = 0.85 - glw * 0.4; h = (1.0 - glw) * 0.6 + nf.b * 0.4;
	}
	else if (s == 17) { emi = vec3(1.0, 0.82, 0.55) * 2.6 * (0.6 + hash12(floor(pp * 0.8)) * 0.6); alb = vec3(0.4); }
	else if (s == 18) { emi = vec3(1.0, 0.62, 0.3) * 6.0; alb = vec3(1.0); }
	else if (s == 19) { // torcida: silhuetas sentadas na penumbra, com raros flashes; vira média de cor de longe (sem chuvisco)
		vec2 cc = pp * vec2(1.5, 1.2); vec2 g = floor(cc); vec2 f = fract(cc);
		float fw = max(fwidth(cc.x), fwidth(cc.y)); float near = 1.0 - smoothstep(0.25, 0.9, fw);
		float c = hash12(g + 3.0); float pres = step(0.22, hash12(g));
		vec3 cloth = c < 0.25 ? vec3(0.32, 0.1, 0.08) : (c < 0.5 ? vec3(0.1, 0.14, 0.24) : (c < 0.75 ? vec3(0.22, 0.22, 0.2) : vec3(0.4, 0.33, 0.12)));
		float body = smoothstep(0.08, 0.22, f.x) * smoothstep(0.92, 0.78, f.x) * smoothstep(0.98, 0.55, f.y);
		float head = 1.0 - smoothstep(0.12, 0.17, length((f - vec2(0.5, 0.78)) * vec2(1.0, 1.3)));
		float fig = clamp(body * step(f.y, 0.6) + head, 0.0, 1.0) * pres;
		vec3 avg = mix(vec3(0.05, 0.05, 0.055), vec3(0.2, 0.16, 0.13), 0.45);
		alb = mix(avg, mix(vec3(0.04, 0.04, 0.045), cloth * (0.7 + 0.3 * nf.g), fig), near);
		float fl = step(0.992, hash12(g + floor(time_s * 0.8 + c * 13.0)));
		emi = vec3(1.0, 0.96, 0.9) * (fl * near * 3.0 + 0.04 * (1.0 - near)); rou = 0.95;
	}
	else if (s == 20) { alb = vec3(0.86, 0.9, 0.94) * (0.9 + nf.g * 0.12); rou = 0.75; h = nf.b * 0.4; }
	else if (s == 21) { alb = vec3(0.55, 0.75, 0.86) * (0.8 + nz.g * 0.3); met = 0.1; rou = 0.08 + nf.b * 0.12; }
	// chão molhado (garoa)
	if (wet > 0.0 && wn.y > 0.7) { float pud = smoothstep(0.45, 0.6, nz.g) * wet; rou = mix(rou, 0.05, pud); alb *= 1.0 - pud * 0.35; }
	if (h != 0.0) {
		vec3 dpx = dFdx(VERTEX); vec3 dpy = dFdy(VERTEX);
		float dhx = dFdx(h) * 0.02; float dhy = dFdy(h) * 0.02;
		vec3 r1 = cross(dpy, NORMAL); vec3 r2 = cross(NORMAL, dpx); float det = dot(dpx, r1);
		if (abs(det) > 1e-10) { vec3 g = (dhx * r1 + dhy * r2) / det; float gl = length(g); if (gl > 0.5) g *= 0.5 / gl; NORMAL = normalize(NORMAL - g); }
	}
	ALBEDO = alb; METALLIC = met; ROUGHNESS = clamp(rou, 0.04, 1.0); EMISSION = emi;
}
