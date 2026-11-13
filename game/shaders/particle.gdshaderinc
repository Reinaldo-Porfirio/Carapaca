// Partícula analítica: a CPU só escreve no momento da emissão; a posição é calculada aqui.
// transform: origem = posição inicial; coluna X = velocidade; coluna Y = (arrasto, gravidade, estica); coluna Z = (brilho, -, -)
// custom = (instante de emissão, vida, tamanho inicial, tamanho final) · cor da instância = RGBA
uniform float now = 0.0;
uniform float max_ratio = 0.45;
varying vec4 vcol;
varying float vfade;
void vertex() {
	mat4 M = MODEL_MATRIX;
	vec3 p0 = M[3].xyz; vec3 v0 = M[0].xyz; float drag = M[1].x; float grav = M[1].y; float stretch = M[1].z; float boost = M[2].x;
	vec4 cd = INSTANCE_CUSTOM;
	float age = now - cd.x; float life = cd.y;
	float tt = clamp(age / max(life, 0.001), 0.0, 1.0);
	vec3 p; vec3 vel;
	if (drag > 0.001) {
		float e = exp(-drag * age);
		p = p0 + v0 * (1.0 - e) / drag; p.y -= grav * (age / drag - (1.0 - e) / (drag * drag));
		vel = v0 * e; vel.y -= grav * (1.0 - e) / drag;
	} else { p = p0 + v0 * age; p.y -= 0.5 * grav * age * age; vel = v0; vel.y -= grav * age; }
	float sz = mix(cd.z, cd.w, tt);
	vec4 v = VIEW_MATRIX * vec4(p, 1.0);
	vec2 q = VERTEX.xy * sz;
	if (stretch > 0.0) {
		vec3 vv = (VIEW_MATRIX * vec4(vel, 0.0)).xyz;
		vec2 dir = length(vv.xy) > 0.001 ? normalize(vv.xy) : vec2(1.0, 0.0);
		vec2 nor = vec2(-dir.y, dir.x);
		float len = sz + length(vel) * stretch;
		q = dir * VERTEX.x * len + nor * VERTEX.y * sz;
	}
	v.xy += q;
	float ratio = sz / max(0.5, -v.z);
	float fade = tt < 0.1 ? tt * 10.0 : 1.0 - (tt - 0.1) / 0.9;
	vfade = fade * clamp(max_ratio / max(ratio, 0.0001), 0.0, 1.0) * smoothstep(1.5, 3.0, -v.z);
	vcol = vec4(COLOR.rgb * boost, COLOR.a);
	bool alive = age >= 0.0 && age < life;
	POSITION = alive ? PROJECTION_MATRIX * v : vec4(0.0, 0.0, 2.0, 1.0);
}
