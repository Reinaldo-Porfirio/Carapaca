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
		float rust = smoothstep(0.62, 0.8, nf.g + low * 0.25);
		alb = mix(base * (0.85 + nz.g * 0.2), vec3(0.32, 0.17, 0.1), rust * 0.85); met = mix(0.55, 0.3, rust); rou = mix(0.55, 0.9, rust);
		alb = mix(alb, alb * 0.6, grime * 0.4);
	}
	else if (s == 14) { emi = lamp_col * 5.0; alb = vec3(1.0); }
	else if (s == 15) { emi = vec3(1.0, 0.12, 0.06) * 4.0; alb = vec3(0.5, 0.05, 0.02); }
	else if (s == 16) { // escória incandescente
		float flow = texture(noise_tex, wp.xz * 0.05 + vec2(time_s * 0.01, time_s * 0.004)).r;
		float crust = smoothstep(0.45, 0.72, texture(noise_tex, wp.xz * 0.13 - vec2(time_s * 0.006, 0.0)).g);
		emi = mix(vec3(1.0, 0.3, 0.04) * (1.3 + flow * 2.2), vec3(0.05, 0.02, 0.01), crust); alb = vec3(0.1, 0.04, 0.02); rou = 0.6;
	}
	else if (s == 17) { emi = vec3(1.0, 0.82, 0.55) * 2.6 * (0.6 + hash12(floor(pp * 0.8)) * 0.6); alb = vec3(0.4); }
	else if (s == 18) { emi = vec3(1.0, 0.62, 0.3) * 6.0; alb = vec3(1.0); }
	else if (s == 19) { // torcida: pontos de luz
		vec2 g = floor(pp * vec2(1.4, 1.1)); float on = step(0.6, hash12(g)) * (0.5 + 0.5 * nf.g); float c = hash12(g + 3.0);
		vec3 col = c < 0.3 ? vec3(1.0, 0.86, 0.66) : (c < 0.6 ? vec3(1.0) : (c < 0.8 ? vec3(0.66, 0.82, 1.0) : vec3(1.0, 0.47, 0.31)));
		emi = col * on * 1.6 * (0.7 + 0.3 * sin(time_s * 2.0 + c * 30.0)); alb = vec3(0.03);
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
