// Céu procedural: gradiente, sol, estrelas e aurora.
shader_type sky;
uniform vec3 top : source_color = vec3(0.2, 0.3, 0.45);
uniform vec3 hor : source_color = vec3(0.7, 0.6, 0.5);
uniform vec3 bot : source_color = vec3(0.2, 0.2, 0.2);
uniform vec3 sun_dir = vec3(0.3, 0.6, 0.4);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_pow = 200.0;
uniform float glow = 0.5;
uniform float aurora = 0.0;
uniform float stars = 0.0;
uniform float energy = 1.0;
float h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void sky() {
	vec3 d = EYEDIR; float y = d.y;
	vec3 c = y > 0.0 ? mix(hor, top, pow(y, 0.45)) : mix(hor, bot, pow(-y, 0.3));
	float s = max(0.0, dot(d, normalize(sun_dir)));
	c += sun_col * (pow(s, sun_pow) * 3.0 + pow(s, 8.0) * glow);
	if (!AT_CUBEMAP_PASS && stars > 0.0 && y > 0.0) { vec3 q = floor(d * 220.0); c += step(0.9975, h(q)) * stars * y * (0.5 + 0.5 * h(q + 1.0)); }
	if (aurora > 0.0 && y > 0.05) {
		float a = sin(d.x * 5.0 + sin(d.z * 3.0 + TIME * 0.12) * 2.0) * 0.5 + 0.5;
		float band = smoothstep(0.12, 0.3, y) * smoothstep(0.75, 0.3, y);
		c += vec3(0.1, 0.9, 0.55) * pow(a, 3.0) * band * aurora + vec3(0.5, 0.2, 0.8) * pow(1.0 - a, 6.0) * band * aurora * 0.4;
	}
	COLOR = c * energy;
}
