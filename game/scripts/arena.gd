## Arenas procedurais: cinco temas, obstáculos e disposição sorteados por semente.
class_name Arena extends Node3D

const ENV_SLOTS := { "con": 0, "dark": 1, "stl": 2, "rust": 3, "rock": 4, "white": 5, "hz": 6, "k0": 7, "k1": 8, "k2": 9, "k3": 10, "k4": 11, "k5": 12, "k6": 13,
	"lamp": 14, "red": 15, "lava": 16, "win": 17, "lampw": 18, "crowd": 19, "snowm": 20, "ice": 21 }
static var env_shader: Shader = preload("res://shaders/env.gdshader")
static var ground_shader: Shader = preload("res://shaders/ground.gdshader")
static var sky_shader: Shader = preload("res://shaders/sky.gdshader")
static var weather_shader: Shader = preload("res://shaders/weather.gdshader")
static var fence_shader: Shader = preload("res://shaders/fence.gdshader")

var id := ""
var def: Dictionary
var size := 150.0
var obstacles: Array = []   # { min, max, alive, hp?, node?, explosive? }
var hazards: Array = []
var ceiling := 130.0
var circle := true
var grav := 1.0
var heat := 0.0
var spawn_p := Vector3.ZERO
var spawn_e := Vector3.ZERO
var dust := Color("#55585c")
var sun: DirectionalLight3D
var sun_dir := Vector3(0.3, 1, 0.2)
var env: Environment
var weather: MultiMeshInstance3D
var weather_mat: ShaderMaterial
var env_mat: ShaderMaterial
var sky_mat: ShaderMaterial
var exposure := 1.0
var clamped := false
var t := 0.0
var rng
var n: Geo.N
var floods: Array = []

func build(arena_id: String, seed_v: int, opts := {}) -> Arena:
	id = arena_id; def = D.ARENAS[id]; size = def.size
	rng = D.Rng.new(seed_v * 7919 + id.length() * 131)
	var R := size
	env_mat = ShaderMaterial.new(); env_mat.shader = env_shader; env_mat.set_shader_parameter("noise_tex", Mats.noise)
	n = Geo.N.new("arena"); n.slots = ENV_SLOTS; n.div = 32.0
	var sky_cfg := {}; var sun_col := Color.WHITE; var sun_i := 2.5; var amb := 1.0; var fog := [Color("#888888"), 0.002]; var gkind := 1; var wx = null; var line_col := Color("#c9a227")
	match id:
		"coliseu":
			gkind = 0; sun_dir = Vector3(-0.35, 1, -0.5); sun_col = Color("#e6ecff"); sun_i = 1.5; amb = 0.45; fog = [Color("#0c1016"), 0.0035]
			sky_cfg = { "top": Color("#05070d"), "hor": Color("#1c2638"), "bot": Color("#0a0d12"), "sun_col": Color("#8fa8d8"), "sun_pow": 400.0, "glow": 0.12, "stars": 1.2 }
			_coliseu(R)
		"doca":
			circle = false; gkind = 1; sun_dir = Vector3(-0.7, 0.32, 0.4); sun_col = Color("#ffb27a"); sun_i = 2.0; amb = 0.9; fog = [Color("#4a5058"), 0.006]
			sky_cfg = { "top": Color("#2c3644"), "hor": Color("#b9825e"), "bot": Color("#2a2c30"), "sun_col": Color("#ffb070"), "sun_pow": 300.0, "glow": 0.9 }
			wx = { "n": 1400, "vel": Vector3(-3, -52, 2), "col": Color("#aab4c0"), "size": 0.12, "alpha": 0.45, "stretch": 1 }
			env_mat.set_shader_parameter("wet", 1.0)
			_doca(R)
		"salar":
			gkind = 2; sun_dir = Vector3(0.75, 0.36, -0.45); sun_col = Color("#ffd2a0"); sun_i = 3.2; amb = 0.6; fog = [Color("#d8c8b4"), 0.0016]; line_col = Color("#8a7a66")
			sky_cfg = { "top": Color("#4a78b0"), "hor": Color("#f0d2b0"), "bot": Color("#c9b9a0"), "sun_col": Color("#fff0d0"), "sun_pow": 500.0, "glow": 1.0 }
			wx = { "n": 500, "vel": Vector3(14, -0.5, 4), "col": Color("#e8dcc8"), "size": 0.5, "alpha": 0.25, "sway": 2.0 }
			exposure = 0.7
			_salar(R)
		"fundicao":
			circle = false; gkind = 3; heat = 1.0; sun_dir = Vector3(-0.3, 0.8, -0.4); sun_col = Color("#ff9a5a"); sun_i = 1.4; amb = 0.9; fog = [Color("#2a120a"), 0.008]
			sky_cfg = { "top": Color("#0c0606"), "hor": Color("#5a2410"), "bot": Color("#1c0a06"), "sun_col": Color("#ff7a30"), "sun_pow": 60.0, "glow": 0.5 }
			wx = { "n": 600, "vel": Vector3(1.5, 9, 0.5), "col": Color("#ff8a30"), "size": 0.35, "alpha": 0.9, "add": true, "sway": 3.0 }
			_fundicao(R)
		_:
			gkind = 4; sun_dir = Vector3(-0.5, 0.42, -0.6); sun_col = Color("#b9d0ff"); sun_i = 1.8; amb = 1.0; fog = [Color("#3a4c66"), 0.006]; line_col = Color("#b3261c")
			sky_cfg = { "top": Color("#060c1c"), "hor": Color("#3a5478"), "bot": Color("#2a3a50"), "sun_col": Color("#cfe0ff"), "sun_pow": 700.0, "glow": 0.25, "stars": 1.0, "aurora": 0.55 }
			wx = { "n": 1800, "vel": Vector3(-7, -9, 3), "col": Color("#ffffff"), "size": 0.5, "alpha": 0.8, "sway": 1.5 }
			_boreal(R)
	add_child(n.bake(env_mat))
	_ground(R, gkind, line_col)
	_fence(R, Color("#ff6a20") if id == "fundicao" else (Color("#ffc070") if id == "salar" else Color("#5ab8ff")))
	# ambiente
	sun_dir = sun_dir.normalized()
	sky_mat = ShaderMaterial.new(); sky_mat.shader = sky_shader
	for k in sky_cfg: sky_mat.set_shader_parameter(k, sky_cfg[k])
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	var sky := Sky.new(); sky.sky_material = sky_mat; sky.radiance_size = Sky.RADIANCE_SIZE_128; sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env = Environment.new()
	env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = amb; env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX; env.tonemap_exposure = exposure * 1.1; env.tonemap_white = 6.0
	env.glow_enabled = true; env.glow_intensity = 0.55; env.glow_strength = 0.9; env.glow_bloom = 0.04; env.glow_hdr_threshold = 1.1; env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true; env.fog_light_color = fog[0]; env.fog_density = fog[1] * (3.0 if opts.get("fog", false) else 1.0); env.fog_sky_affect = 0.35; env.fog_aerial_perspective = 0.25
	if id == "fundicao" or id == "doca": env.fog_height = 8.0; env.fog_height_density = 0.04
	env.adjustment_enabled = true; env.adjustment_contrast = 1.14 if id == "salar" else 1.06; env.adjustment_saturation = 1.04 if id == "salar" else 0.95
	env.set_meta("vfog", { "coliseu": 0.003, "doca": 0.008, "salar": 0.0, "fundicao": 0.01, "boreal": 0.006 }.get(id, 0.0))
	env.set_meta("vfog_col", fog[0].lerp(Color.WHITE, 0.5)); env.set_meta("ssr", id == "doca")
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	Settings.apply_env(env)
	sun = DirectionalLight3D.new(); sun.light_color = sun_col; sun.light_energy = sun_i; sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS; sun.directional_shadow_max_distance = 220.0; sun.shadow_bias = 0.08; sun.shadow_normal_bias = 2.6; sun.shadow_blur = 1.2
	add_child(sun); sun.look_at_from_position(sun_dir * 100.0, Vector3.ZERO, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.FORWARD)
	Settings.apply_sun(sun)
	_lights_extra(R)
	if wx != null: _weather(wx)
	spawn_p = Vector3(0, 0, -R * 0.62); spawn_e = Vector3(0, 0, R * 0.62)
	dust = Color({ "coliseu": "#55585c", "doca": "#5a5c5e", "salar": "#e0d6c4", "fundicao": "#3a2a22", "boreal": "#e6eef4" }[id])
	return self

# ───────── auxiliares de construção ─────────
func box(slot: String, x: float, z: float, w: float, h: float, d: float, y0 := 0.0, col := true, bev := 0.25) -> void:
	n.put(slot, Geo.bx(w, h, d, minf(bev, minf(w * 0.2, minf(h * 0.2, d * 0.2)))), Vector3(x, y0 + h / 2.0, z))
	if col: obstacles.append({ "min": Vector3(x - w / 2.0, y0, z - d / 2.0), "max": Vector3(x + w / 2.0, y0 + h, z + d / 2.0), "alive": true })

func free_at(x: float, z: float, r: float) -> bool:
	var R := size
	if Vector2(x, z + R * 0.62).length() < 26 + r or Vector2(x, z - R * 0.62).length() < 26 + r or Vector2(x, z).length() < 14 + r: return false
	for o in obstacles:
		var cx: float = (o.min.x + o.max.x) / 2.0; var cz: float = (o.min.z + o.max.z) / 2.0; var rr: float = maxf(o.max.x - o.min.x, o.max.z - o.min.z) / 2.0
		if Vector2(x - cx, z - cz).length() < rr + r + 7: return false
	return true

func scatter(count: int, rmin: float, rmax: float, r: float, fn: Callable) -> void:
	var made := 0; var tries := 0
	while tries < count * 30 and made < count:
		tries += 1
		var a: float = rng.rf() * TAU; var d: float = rng.rr(rmin, rmax); var x := cos(a) * d; var z := sin(a) * d
		if not free_at(x, z, r): continue
		fn.call(x, z, made); made += 1

# ───────── temas ─────────
func _coliseu(R: float) -> void:
	var segs := 28; var len := TAU * (R + 4) / segs + 1
	for i in segs:
		var a := float(i) / segs * TAU; var c := cos(a); var s := sin(a); var ry := -a + PI / 2
		n.put("con", Geo.bx(len, 20, 8, 0.4), Vector3(c * (R + 4), 10, s * (R + 4)), Vector3(0, ry, 0))
		n.put("hz", Geo.bx(len, 1.6, 8.3, 0.1), Vector3(c * (R + 4), 19.2, s * (R + 4)), Vector3(0, ry, 0))
		for k in 3:
			n.put("dark", Geo.bx(len + 1 + k, 12, 13, 0.3), Vector3(c * (R + 14 + k * 12), 24 + k * 11, s * (R + 14 + k * 12)), Vector3(0, ry, 0))
			n.put("crowd", Geo.bx(len + k, 6.5, 0.4, 0.01), Vector3(c * (R + 7.6 + k * 12), 33.5 + k * 11, s * (R + 7.6 + k * 12)), Vector3(0, ry, 0))
		if i % 2 == 0: n.put("lamp", Geo.bx(len * 0.6, 0.5, 0.4, 0.01), Vector3(c * (R + 0.4), 16.5, s * (R + 0.4)), Vector3(0, ry, 0))
		if i % 7 == 1:
			floods.append(Vector3(c * (R + 50.4), 84, s * (R + 50.4)))
			n.put("dark", Geo.bx(3, 86, 3, 0.2), Vector3(c * (R + 52), 43, s * (R + 52)))
			n.put("lamp", Geo.bx(18, 8, 1, 0.1), Vector3(c * (R + 50.4), 84, s * (R + 50.4)), Vector3(0, ry, 0))
			n.put("dark", Geo.bx(20, 10, 2, 0.2), Vector3(c * (R + 51.6), 84, s * (R + 51.6)), Vector3(0, ry, 0))
	var rot: float = rng.rf() * PI
	for i in 4:
		var a := rot + i * PI / 2; var x := cos(a) * 50; var z := sin(a) * 50
		box("con", x, z, 11, 28, 11, 0, true, 0.5); n.put("hz", Geo.bx(11.4, 2, 11.4, 0.1), Vector3(x, 3, z)); n.put("lamp", Geo.bx(11.2, 0.4, 11.2, 0.05), Vector3(x, 22, z))
	for i in 8:
		var a := rot + PI / 8 + i * PI / 4; var x := cos(a) * 98; var z := sin(a) * 98
		if not free_at(x, z, 8): continue
		if i % 2: box("dark", x, z, 18, 7, 6)
		else: box("dark", x, z, 6, 7, 18)
		n.put("hz", Geo.bx(18.3 if i % 2 else 6.3, 1, 6.3 if i % 2 else 18.3, 0.05), Vector3(x, 6.4, z))
	for i in 2:
		var a := rot + PI / 4 + i * PI; box("stl", cos(a) * 78, sin(a) * 78, 24, 8, 24, 0, true, 0.6)
	scatter(rng.ri(4, 7), 20, R - 25, 5, func(x, z, _i): box("con", x, z, rng.rr(5, 9), rng.rr(4, 9), rng.rr(5, 9)))

func _doca(R: float) -> void:
	var CW := 13.0; var CH := 5.4; var CD := 5.2
	var stack := func(x: float, z: float, along_x: bool, h: int):
		var w := CW if along_x else CD; var d := CD if along_x else CW
		for k in h:
			n.put("k%d" % rng.ri(0, 6), Geo.bx(w, CH - 0.1, d, 0.12), Vector3(x, k * CH + CH / 2, z))
			n.put("dark", Geo.bx(0.3 if along_x else d * 0.9, CH * 0.8, d * 0.9 if along_x else 0.3, 0.02), Vector3(x + (w / 2 if along_x else 0.0), k * CH + CH / 2, z + (0.0 if along_x else d / 2)))
		obstacles.append({ "min": Vector3(x - w / 2, 0, z - d / 2), "max": Vector3(x + w / 2, h * CH, z + d / 2), "alive": true })
	for gx in range(-4, 5):
		for gz in range(-4, 5):
			if rng.chance(0.42): continue
			var x: float = gx * 34 + rng.rr(-5, 5); var z: float = gz * 34 + rng.rr(-5, 5)
			if not free_at(x, z, 9) or absf(x) > R - 14 or absf(z) > R - 14: continue
			var ax: bool = rng.chance(0.5); var h: int = rng.ri(1, 3); stack.call(x, z, ax, h)
			if rng.chance(0.4): stack.call(x + (0.0 if ax else CD + 0.4), z + (CD + 0.4 if ax else 0.0), ax, rng.ri(1, h))
	for cx in [-70.0, 75.0]:
		for dd in [[-16, -24], [16, -24], [-16, 24], [16, 24]]:
			if free_at(cx + dd[0], dd[1], 3): box("stl", cx + dd[0], dd[1], 4, 50, 4, 0, true, 0.3)
		n.put("stl", Geo.bx(40, 5, 6, 0.3), Vector3(cx, 52, -24)); n.put("stl", Geo.bx(40, 5, 6, 0.3), Vector3(cx, 52, 24)); n.put("hz", Geo.bx(8, 4, 64, 0.2), Vector3(cx, 57, 0))
		n.put("k3", Geo.bx(9, 7, 9, 0.3), Vector3(cx + rng.rr(-10, 10), 49, rng.rr(-15, 15))); n.put("lamp", Geo.bx(3, 0.5, 3, 0.05), Vector3(cx, 46.5, 0))
	for i in range(-5, 6):
		for sg in [-1.0, 1.0]:
			var h: int = rng.ri(2, 4)
			n.put("k%d" % rng.ri(0, 6), Geo.bx(30, h * CH, 6, 0.2), Vector3(i * 32, h * CH / 2, sg * (R + 4)))
			n.put("k%d" % rng.ri(0, 6), Geo.bx(6, h * CH, 30, 0.2), Vector3(sg * (R + 4), h * CH / 2, i * 32))
	scatter(10, 30, R - 15, 2, func(x, z, _i):
		n.put("dark", Geo.bx(0.6, 18, 0.6, 0.05), Vector3(x, 9, z)); n.put("lampw", Geo.bx(2.4, 0.5, 1.2, 0.05), Vector3(x, 18, z))
		obstacles.append({ "min": Vector3(x - 0.5, 0, z - 0.5), "max": Vector3(x + 0.5, 18, z + 0.5), "alive": true }))
	n.put("dark", Geo.bx(120, 26, 30, 1), Vector3(-60, 13, R + 90)); n.put("white", Geo.bx(30, 20, 20, 0.5), Vector3(-90, 36, R + 90)); n.put("k0", Geo.bx(60, 10, 26, 0.3), Vector3(-40, 31, R + 90))
	_add_light(Vector3(0, 30, 0), Color("#ffb060"), 0.0, 1.0)

func _salar(R: float) -> void:
	scatter(rng.ri(9, 13), 26, R - 28, 14, func(x, z, _i):
		var w: float = rng.rr(14, 30); var d: float = rng.rr(14, 30); var h: float = rng.rr(7, 18)
		box("rock", x, z, w, h, d, 0, true, 1.2)
		if rng.chance(0.7): box("rock", x + rng.rr(-3, 3), z + rng.rr(-3, 3), w * 0.62, rng.rr(5, 12), d * 0.62, h, true, 1.0))
	scatter(2, 40, R - 50, 24, func(x, z, _i):
		var ax: bool = rng.chance(0.5)
		box("rust", x, z, 46 if ax else 11, 9, 11 if ax else 46, 0, true, 0.8)
		n.put("rust", Geo.bx(10 if ax else 9, 8, 9 if ax else 10, 0.4), Vector3(x + (12.0 if ax else 0.0), 13, z + (0.0 if ax else 12.0)))
		n.put("dark", Geo.cyl(1.4, 1.4, 9, 10), Vector3(x + (12.0 if ax else 0.0), 20, z + (0.0 if ax else 12.0))))
	scatter(8, 20, R - 20, 4, func(x, z, _i): box("rock", x, z, rng.rr(4, 7), rng.rr(3, 6), rng.rr(4, 7), 0, true, 0.8))
	for i in 26:
		var a: float = i / 26.0 * TAU + rng.rr(-0.08, 0.08); var d: float = R + rng.rr(140, 320); var h: float = rng.rr(50, 130)
		n.put("rock", Geo.cone(h * rng.rr(0.9, 1.5), h, 7), Vector3(cos(a) * d, h / 2 - 4, sin(a) * d), Vector3(0, rng.rf() * 3, 0))
	for i in 36:
		var a := i / 36.0 * TAU
		n.put("dark", Geo.bx(0.5, 7, 0.5, 0.05), Vector3(cos(a) * R, 3.5, sin(a) * R)); n.put("red", Geo.bx(0.7, 0.7, 0.7, 0.1), Vector3(cos(a) * R, 7.2, sin(a) * R))

func _fundicao(R: float) -> void:
	var ch := []
	var chan := func(x0: float, z0: float, x1: float, z1: float):
		var w := absf(x1 - x0); var d := absf(z1 - z0); var cx := (x0 + x1) / 2; var cz := (z0 + z1) / 2
		n.put("lava", Geo.bx(w, 0.3, d, 0.02), Vector3(cx, 0.12, cz))
		hazards.append({ "type": "heat", "x0": minf(x0, x1), "x1": maxf(x0, x1), "z0": minf(z0, z1), "z1": maxf(z0, z1) }); ch.append([cx, cz, w, d])
		n.put("dark", Geo.bx(w + (0.0 if w > d else 2.4), 0.7, d + (2.4 if w > d else 0.0), 0.1), Vector3(cx, -0.2, cz))
	var o1: float = rng.rr(-50, -25); var o2: float = rng.rr(25, 50)
	chan.call(-R, o1 - 5, R, o1 + 5); chan.call(o2 - 5, -R * 0.2, o2 + 5, R); chan.call(-o2 - 4, -R, -o2 + 4, o1 - 5)
	_add_light(Vector3(0, 5, o1), Color("#ff5a10"), 6.0, 160.0); _add_light(Vector3(o2, 5, R * 0.4), Color("#ff5a10"), 6.0, 150.0)
	var in_chan := func(x: float, z: float, r: float) -> bool:
		for c in ch:
			if absf(x - c[0]) < c[2] / 2 + r and absf(z - c[1]) < c[3] / 2 + r: return true
		return false
	scatter(4, 30, R - 30, 12, func(x, z, _i):
		if in_chan.call(x, z, 12): return
		box("dark", x, z, 17, 46, 17, 0, true, 0.8)
		for k in 4: n.put("lava", Geo.bx(17.3 if k % 2 else 5.0, 1.2, 5.0 if k % 2 else 17.3, 0.05), Vector3(x, 8 + k * 8, z))
		n.put("rust", Geo.cyl(5, 7, 14, 12), Vector3(x, 53, z)); n.put("lava", Geo.cyl(4.4, 4.4, 0.4, 12), Vector3(x, 60.1, z)); n.put("hz", Geo.bx(17.4, 2, 17.4, 0.1), Vector3(x, 2.5, z)))
	scatter(3, 20, R - 30, 16, func(x, z, _i):
		if in_chan.call(x, z, 16): return
		var ax: bool = rng.chance(0.5); var w := 30.0 if ax else 11.0; var d := 11.0 if ax else 30.0
		box("stl", x, z, w, 1.6, d, 12, true, 0.2); n.put("hz", Geo.bx(w + 0.3, 0.5, d + 0.3, 0.05), Vector3(x, 13.2, z))
		for sx in [-1, 1]:
			for sz in [-1, 1]: box("stl", x + sx * (w / 2 - 1.5), z + sz * (d / 2 - 1.5), 2, 12, 2, 0, true, 0.15))
	scatter(7, 18, R - 16, 6, func(x, z, _i):
		if in_chan.call(x, z, 7): return
		if rng.chance(0.5): box("rust", x, z, 9, 9, 9, 0, true, 1.2); n.put("lava", Geo.bx(7, 0.3, 7, 0.02), Vector3(x, 9.05, z))
		else: box("con", x, z, rng.rr(6, 12), rng.rr(5, 8), rng.rr(6, 12)))
	for i in range(-3, 4):
		for sg in [-1.0, 1.0]:
			n.put("rust", Geo.bx(46, 60, 8, 0.4), Vector3(i * 46, 30, sg * (R + 5))); n.put("rust", Geo.bx(8, 60, 46, 0.4), Vector3(sg * (R + 5), 30, i * 46))
			n.put("win", Geo.bx(30, 3, 0.4, 0.02), Vector3(i * 46, 38, sg * (R + 0.9))); n.put("win", Geo.bx(0.4, 3, 30, 0.02), Vector3(sg * (R + 0.9), 22, i * 46))
	for i in 5:
		var a: float = rng.rf() * 7; var d: float = R + rng.rr(40, 120)
		n.put("dark", Geo.cyl(5, 8, 150, 10), Vector3(cos(a) * d, 75, sin(a) * d)); n.put("lava", Geo.cyl(4.5, 4.5, 1, 10), Vector3(cos(a) * d, 150.2, sin(a) * d))

func _boreal(R: float) -> void:
	scatter(5, 26, R - 30, 12, func(x, z, _i):
		var ax: bool = rng.chance(0.5); var w := 19.0 if ax else 9.0; var d := 9.0 if ax else 19.0
		box("white", x, z, w, 6.5, d, 1.2, true, 0.5)
		for sx in [-1, 1]:
			for sz in [-1, 1]: n.put("dark", Geo.bx(1, 1.6, 1, 0.1), Vector3(x + sx * (w / 2 - 1), 0.7, z + sz * (d / 2 - 1)))
		var ob: Dictionary = obstacles[-1]; var mn: Vector3 = ob.min; mn.y = 0.0; ob.min = mn
		n.put("win", Geo.bx(12.0 if ax else 0.3, 1.2, 0.3 if ax else 12.0, 0.02), Vector3(x + (0.0 if ax else w / 2), 5, z + (d / 2 if ax else 0.0)))
		n.put("red", Geo.bx(w + 0.2, 0.5, d + 0.2, 0.05), Vector3(x, 7.2, z)))
	scatter(3, 30, R - 30, 4, func(x, z, _i):
		box("stl", x, z, 2.6, 56, 2.6, 0, true, 0.1)
		for k in 5: n.put("stl", Geo.bx(6 - k, 0.3, 0.3, 0.02), Vector3(x, 14 + k * 9, z))
		n.put("red", Geo.bx(0.8, 0.8, 0.8, 0.1), Vector3(x, 56.6, z)); n.put("white", Geo.cyl(4, 0.6, 2, 14), Vector3(x + 2.6, 40, z), Vector3(0, 0, -1.1)))
	scatter(6, 18, R - 20, 6, func(x, z, _i): box("ice", x, z, rng.rr(7, 12), rng.rr(6, 11), rng.rr(7, 12), 0, true, 1.4))
	# tanques de combustível destrutíveis
	scatter(rng.ri(5, 7), 24, R - 26, 8, func(x, z, _i):
		var tk := Geo.N.new("tank"); tk.slots = ENV_SLOTS; tk.div = 32.0
		tk.put("white", Geo.cyl(5, 5, 9, 18), Vector3(0, 5.6, 0)); tk.put("red", Geo.cyl(5.06, 5.06, 1.6, 18), Vector3(0, 7, 0)); tk.put("dark", Geo.cyl(5.6, 5.8, 1.1, 18), Vector3(0, 0.55, 0))
		tk.put("dark", Geo.cyl(0.5, 0.5, 1.2, 8), Vector3(2, 10.6, 1)); tk.put("hz", Geo.bx(10.4, 0.4, 0.3, 0.02), Vector3(0, 2.2, 5.1))
		tk.g.position = Vector3(x, 0, z); add_child(tk.bake(env_mat))
		obstacles.append({ "min": Vector3(x - 4.4, 0, z - 4.4), "max": Vector3(x + 4.4, 10.1, z + 4.4), "alive": true, "hp": 500.0, "node": tk.g, "explosive": { "r": 34.0, "dmg": 1100.0, "imp": 900.0 } }))
	for i in 44:
		var a: float = i / 44.0 * TAU; var d: float = R + rng.rr(6, 18); var h: float = rng.rr(6, 14)
		n.put("snowm", Geo.cone(h * 1.8, h, 6), Vector3(cos(a) * d, h / 2 - 1, sin(a) * d), Vector3(0, rng.rf() * 3, 0))
		if i % 3 == 0: n.put("dark", Geo.bx(0.4, 9, 0.4, 0.05), Vector3(cos(a) * R, 4.5, sin(a) * R)); n.put("red", Geo.bx(0.7, 0.7, 0.7, 0.1), Vector3(cos(a) * R, 9.2, sin(a) * R))
	for i in 18:
		var a: float = i / 18.0 * TAU + rng.rr(-0.1, 0.1); var d: float = R + rng.rr(200, 420); var h: float = rng.rr(70, 170)
		n.put("snowm", Geo.cone(h * rng.rr(0.8, 1.3), h, 6), Vector3(cos(a) * d, h / 2 - 6, sin(a) * d), Vector3(0, rng.rf() * 3, 0))

## Holofotes, sonda de reflexo (metais refletem a própria arena) e ajustes de luz por tema.
func _lights_extra(R: float) -> void:
	for f in floods:
		var sp := SpotLight3D.new(); sp.light_color = Color("#dfe8ff"); sp.light_energy = 5.0; sp.spot_range = 420.0; sp.spot_angle = 30.0; sp.spot_attenuation = 0.4; sp.spot_angle_attenuation = 1.6
		sp.light_volumetric_fog_energy = 0.5; sp.shadow_enabled = false; add_child(sp)
		var tgt: Vector3 = Vector3(-f.x, 0, -f.z).normalized() * R * 0.15
		sp.look_at_from_position(f + Vector3(0, -2, 0) - Vector3(f.x, 0, f.z).normalized() * 3.0, tgt)
	if Settings.quality >= 1:
		var pr := ReflectionProbe.new(); pr.size = Vector3(R * 2 + 60, 140, R * 2 + 60); pr.position = Vector3(0, 12, 0); pr.origin_offset = Vector3(0, -6, 0)
		pr.update_mode = ReflectionProbe.UPDATE_ONCE; pr.box_projection = false; pr.interior = false; pr.intensity = 0.9; pr.max_distance = R * 3.0
		pr.ambient_mode = ReflectionProbe.AMBIENT_DISABLED; pr.mesh_lod_threshold = 4.0; add_child(pr)

func _add_light(p: Vector3, c: Color, e: float, r: float) -> void:
	if e <= 0: return
	var l := OmniLight3D.new(); l.position = p; l.light_color = c; l.light_energy = e; l.omni_range = r; l.omni_attenuation = 1.2; add_child(l)

func _ground(R: float, kind: int, line_col: Color) -> void:
	var gm := ShaderMaterial.new(); gm.shader = ground_shader; gm.set_shader_parameter("noise_tex", Mats.noise); gm.set_shader_parameter("kind", kind)
	var pm := PlaneMesh.new(); pm.size = Vector2(R * 2 + 900, R * 2 + 900); pm.subdivide_width = 8; pm.subdivide_depth = 8
	var g := MeshInstance3D.new(); g.mesh = pm; g.material_override = gm; g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(g)
	# marcações pintadas
	var lm := StandardMaterial3D.new(); lm.albedo_color = Color(line_col, 0.35 if id == "salar" else 0.6); lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; lm.roughness = 0.8
	lm.render_priority = 1
	var marks := Geo.N.new("marks"); marks.slots = { "x": 0 }
	var rr := [[11.0, 12.0], [R * 0.5, R * 0.5 + 0.6]]
	if circle: rr.append([R - 2.5, R - 1.5])
	for q in rr: marks.put("x", Geo.ring(q[0], q[1], 72), Vector3(0, 0.05, 0))
	for zz in [-R * 0.62, R * 0.62]: marks.put("x", Geo.ring(8, 8.7, 4), Vector3(0, 0.05, zz), Vector3(0, PI / 4, 0))
	var mm := marks.bake(lm, false); add_child(mm)

func _fence(R: float, c: Color) -> void:
	if id == "coliseu": return
	var fm := ShaderMaterial.new(); fm.shader = fence_shader; fm.set_shader_parameter("col", c)
	var mi := MeshInstance3D.new(); mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if circle:
		var cm := CylinderMesh.new(); cm.top_radius = R; cm.bottom_radius = R; cm.height = 26; cm.radial_segments = 64; cm.cap_top = false; cm.cap_bottom = false; mi.mesh = cm
	else:
		# só as quatro paredes: uma tampa inferior ficaria no plano do chão e piscaria (z-fighting + faixas animadas)
		var cm := CylinderMesh.new(); cm.top_radius = R * sqrt(2.0); cm.bottom_radius = R * sqrt(2.0); cm.height = 26; cm.radial_segments = 4; cm.rings = 1
		cm.cap_top = false; cm.cap_bottom = false; mi.mesh = cm; mi.rotation.y = PI / 4
	mi.material_override = fm; mi.position.y = 13; add_child(mi)

func _weather(o: Dictionary) -> void:
	var count: int = o.n
	if Settings.quality == 0: count = count / 3
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_custom_data = true
	var q := QuadMesh.new(); q.size = Vector2(1, 1)
	if o.get("stretch", 0): q.size = Vector2(0.25, 4.0)
	mm.mesh = q; mm.instance_count = count
	var r := RandomNumberGenerator.new(); r.seed = 7
	for i in count:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(r.randf(), r.randf(), r.randf(), r.randf()))
	weather_mat = ShaderMaterial.new(); weather_mat.shader = weather_shader
	weather_mat.set_shader_parameter("vel", o.vel); weather_mat.set_shader_parameter("col", o.col); weather_mat.set_shader_parameter("size", o.size)
	weather_mat.set_shader_parameter("alpha", o.alpha); weather_mat.set_shader_parameter("sway", o.get("sway", 0.0)); weather_mat.set_shader_parameter("additive", o.get("add", false))
	weather = MultiMeshInstance3D.new(); weather.multimesh = mm; weather.material_override = weather_mat; weather.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weather.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	if o.get("add", false):
		var mat2 := weather_mat
		mat2.render_priority = 2
	add_child(weather)

func tick(dt: float, cam_pos: Vector3) -> void:
	t += dt
	env_mat.set_shader_parameter("time_s", t)
	if weather_mat: weather_mat.set_shader_parameter("t", t); weather_mat.set_shader_parameter("cam", cam_pos)

# ───────── consultas físicas ─────────
## Altura do chão / topo de obstáculo sob um ponto.
func ground_at(x: float, z: float, y := 1e9, r := 0.0) -> float:
	var g := 0.0
	for o in obstacles:
		if not o.alive: continue
		if x > o.min.x - r and x < o.max.x + r and z > o.min.z - r and z < o.max.z + r and o.max.y <= y + 1.3 and o.max.y > g: g = o.max.y
	return g

func in_hazard(x: float, z: float):
	for h in hazards:
		if x > h.x0 and x < h.x1 and z > h.z0 and z < h.z1: return h.type
	return null

var hit_ob = null
## Raio contra obstáculos e chão. Retorna a distância (INF se nada) e guarda o objeto em hit_ob.
func ray(o: Vector3, d: Vector3, max_d: float) -> float:
	var best := max_d; var ob = null
	if d.y < -1e-5:
		var tg := -o.y / d.y
		if tg >= 0 and tg < best: best = tg; ob = "ground"
	for b in obstacles:
		if not b.alive: continue
		var t0 := 0.0; var t1 := best; var ok := true
		for ax in 3:
			var dv: float = d[ax]
			if absf(dv) < 1e-9: dv = 1e-9
			var inv := 1.0 / dv
			var a: float = (b.min[ax] - o[ax]) * inv; var c: float = (b.max[ax] - o[ax]) * inv
			if a > c: var q := a; a = c; c = q
			if a > t0: t0 = a
			if c < t1: t1 = c
			if t0 > t1: ok = false; break
		if ok and t0 < best: best = t0; ob = b
	hit_ob = ob
	return best if ob != null else INF

func los(a: Vector3, b: Vector3) -> bool:
	var d := b - a; var l := d.length()
	if l < 0.01: return true
	return ray(a, d / l, l) == INF

func clamp_pos(p: Vector3, r: float) -> Vector3:
	clamped = false
	var m := size - r - 1
	if circle:
		var dd := Vector2(p.x, p.z).length()
		if dd > m: p.x *= m / dd; p.z *= m / dd; clamped = true
	else:
		if p.x > m: p.x = m; clamped = true
		if p.x < -m: p.x = -m; clamped = true
		if p.z > m: p.z = m; clamped = true
		if p.z < -m: p.z = -m; clamped = true
	return p
