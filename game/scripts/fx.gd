## Efeitos: partículas na GPU, rastros, mísseis, feixes, anéis, luzes dinâmicas, marcas no chão e detritos.
class_name FX extends Node3D

const N_ADD := 3600
const N_SMK := 1400
var add_mm: MultiMesh
var smk_mm: MultiMesh
var add_mat: ShaderMaterial
var smk_mat: ShaderMaterial
var ia := 0
var ismk := 0
var now := 0.0
var tr_mm: MultiMesh
var ms_mm: MultiMesh
var db_mm: MultiMesh
var beams := []
var rings := []
var orbs := []
var lights := []
var scorch := []
var si := 0
var debris := []
var shake := 0.0
var _beam_mesh: Mesh
static var add_shader: Shader = preload("res://shaders/particle_add.gdshader")
static var smk_shader: Shader = preload("res://shaders/particle_smoke.gdshader")
static var fxadd_shader: Shader = preload("res://shaders/fxadd.gdshader")

func _init() -> void: name = "fx"

func setup() -> void:
	var qn := 1.0 if Settings.quality >= 1 else 0.55
	var quad := QuadMesh.new(); quad.size = Vector2(1, 1)
	add_mat = ShaderMaterial.new(); add_mat.shader = add_shader
	smk_mat = ShaderMaterial.new(); smk_mat.shader = smk_shader; smk_mat.set_shader_parameter("noise_tex", Mats.noise)
	add_mm = _mm(quad, int(N_ADD * qn), add_mat, true, 3)
	smk_mm = _mm(quad, int(N_SMK * qn), smk_mat, true, 2)
	# rastros (caixa unitária de z -1 a 0)
	var tb := BoxMesh.new(); tb.size = Vector3(1, 1, 1)
	var tm := _xform_mesh(tb, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.5)))
	var tmat := ShaderMaterial.new(); tmat.shader = fxadd_shader; tmat.set_shader_parameter("use_instance", true); tmat.set_shader_parameter("energy", 2.2)
	tr_mm = _mm(tm, 500, tmat, false, 3, true)
	var mc := CylinderMesh.new(); mc.top_radius = 0.16; mc.bottom_radius = 0.2; mc.height = 1.6; mc.radial_segments = 6; mc.rings = 1
	var mmesh := _xform_mesh(mc, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
	var msm := StandardMaterial3D.new(); msm.albedo_color = Color("#c8c8c0"); msm.metallic = 0.6; msm.roughness = 0.4
	ms_mm = _mm(mmesh, 200, msm, false, 0)
	var dbm := BoxMesh.new(); dbm.size = Vector3.ONE
	var dmat := StandardMaterial3D.new(); dmat.albedo_color = Color.WHITE; dmat.vertex_color_use_as_albedo = true; dmat.metallic = 0.7; dmat.roughness = 0.55
	db_mm = _mm(dbm, 90, dmat, false, 0, true)
	get_child(get_child_count() - 1).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# feixes
	var bc := CylinderMesh.new(); bc.top_radius = 1; bc.bottom_radius = 1; bc.height = 1; bc.radial_segments = 8; bc.rings = 1; bc.cap_top = false; bc.cap_bottom = false
	_beam_mesh = _xform_mesh(bc, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.5)))
	for i in 16: beams.append(_pool_item(_beam_mesh, false))
	var rm := Geo.N.new("r"); rm.slots = { "x": 0 }; rm.put("x", Geo.ring(0.86, 1.0, 40))
	var ring_mesh: Mesh = rm.bake(StandardMaterial3D.new()).get_child(0).mesh
	for i in 10: rings.append(_pool_item(ring_mesh, false))
	var sp := SphereMesh.new(); sp.radius = 1; sp.height = 2; sp.radial_segments = 24; sp.rings = 12
	for i in 4: orbs.append(_pool_item(sp, true))
	for i in (3 if Settings.quality >= 1 else 2):
		var l := OmniLight3D.new(); l.light_energy = 0; l.omni_range = 60; l.omni_attenuation = 1.6; l.shadow_enabled = false; add_child(l)
		lights.append({ "l": l, "life": 0.0, "max": 1.0, "i0": 0.0 })
	# marcas de queimado
	var sq := QuadMesh.new(); sq.size = Vector2(1, 1); sq.orientation = PlaneMesh.FACE_Y
	for i in 28:
		var m := MeshInstance3D.new(); m.mesh = sq; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var smat := ShaderMaterial.new(); smat.shader = _scorch_shader(); m.material_override = smat; m.visible = false; add_child(m)
		scorch.append({ "m": m, "life": 0.0 })

static var _sc_shader: Shader
static func _scorch_shader() -> Shader:
	if _sc_shader: return _sc_shader
	_sc_shader = Shader.new()
	_sc_shader.code = "shader_type spatial;\nrender_mode blend_mix, depth_draw_never, shadows_disabled, unshaded;\nuniform float op = 0.75;\nvoid fragment(){ float r = length(UV - 0.5) * 2.0; ALBEDO = vec3(0.02, 0.018, 0.016); ALPHA = (1.0 - smoothstep(0.1, 1.0, r)) * op; }\n"
	return _sc_shader

func _mm(mesh: Mesh, count: int, mat: Material, custom: bool, prio: int, colors := true) -> MultiMesh:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = colors; mm.use_custom_data = custom; mm.mesh = mesh; mm.instance_count = count
	if not custom: mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = mat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	if mat is ShaderMaterial: mat.render_priority = prio
	add_child(mi)
	if custom:
		for i in count:
			mm.set_instance_transform(i, Transform3D.IDENTITY); mm.set_instance_custom_data(i, Color(-100, 0.001, 0, 0)); mm.set_instance_color(i, Color(0, 0, 0, 0))
	return mm

static func _xform_mesh(src: Mesh, xf: Transform3D) -> ArrayMesh:
	var arr := src.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]; var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i in vs.size(): vs[i] = xf * vs[i]; ns[i] = (xf.basis * ns[i]).normalized()
	arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = ns; arr[Mesh.ARRAY_TANGENT] = null
	var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr); return am

func _pool_item(mesh: Mesh, radial: bool) -> Dictionary:
	var m := MeshInstance3D.new(); m.mesh = mesh; m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; m.visible = false
	var mat := ShaderMaterial.new(); mat.shader = fxadd_shader; mat.set_shader_parameter("radial", radial); mat.render_priority = 3
	m.material_override = mat; add_child(m)
	return { "m": m, "mat": mat, "life": 0.0, "max": 1.0, "w": 1.0, "r": 1.0, "len": 1.0 }

# ───────── emissão ─────────
func emit_add(p: Vector3, v: Vector3, life: float, s0: float, s1: float, c: Color, boost := 2.4, drag := 0.0, grav := 0.0, stretch := 0.0) -> void:
	var i := ia; ia = (ia + 1) % add_mm.instance_count
	add_mm.set_instance_transform(i, Transform3D(Basis(v, Vector3(drag, grav, stretch), Vector3(boost, 0, 1)), p))
	add_mm.set_instance_color(i, c); add_mm.set_instance_custom_data(i, Color(now, life, s0, s1))

func emit_smoke(p: Vector3, v: Vector3, life: float, s0: float, s1: float, c: Color, drag := 1.2, grav := -0.4) -> void:
	var i := ismk; ismk = (ismk + 1) % smk_mm.instance_count
	smk_mm.set_instance_transform(i, Transform3D(Basis(v, Vector3(drag, grav, 0), Vector3(1, 0, 1)), p))
	smk_mm.set_instance_color(i, c); smk_mm.set_instance_custom_data(i, Color(now, life, s0, s1))

static func rnd(a := 1.0) -> float: return (randf() - 0.5) * 2.0 * a

func light(pos: Vector3, color: Color, intensity: float, life: float) -> void:
	var best = lights[0]
	for L in lights:
		if L.life < best.life: best = L
	if best.life > 0 and best.i0 > intensity * 2: return
	best.l.position = pos; best.l.light_color = color; best.i0 = intensity * 0.07; best.life = life; best.max = life; best.l.light_energy = best.i0
	best.l.omni_range = clampf(20.0 + intensity * 0.35, 20.0, 70.0)

func beam(a: Vector3, b: Vector3, color: Color, width: float, life: float) -> void:
	var B = beams[0]
	for x in beams:
		if x.life <= 0: B = x; break
	var len := a.distance_to(b)
	if len < 0.01: return
	B.m.global_position = a
	var dir := (b - a) / len
	B.m.look_at(b, Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT, true)
	B.m.scale = Vector3(width, width, len); B.mat.set_shader_parameter("col", color); B.mat.set_shader_parameter("energy", 2.4)
	B.m.visible = true; B.life = life; B.max = life; B.w = width; B.len = len

func ring(pos: Vector3, color: Color, r: float, life: float) -> void:
	var R = rings[0]
	for x in rings:
		if x.life <= 0: R = x; break
	R.m.global_position = pos; R.mat.set_shader_parameter("col", color); R.mat.set_shader_parameter("energy", 1.8); R.m.visible = true; R.life = life; R.max = life; R.r = r; R.m.scale = Vector3.ONE * 0.1

func orb(pos: Vector3, color: Color, r: float, life: float) -> void:
	var O = orbs[0]
	for x in orbs:
		if x.life <= 0: O = x; break
	O.m.global_position = pos; O.mat.set_shader_parameter("col", color); O.mat.set_shader_parameter("energy", 1.6); O.m.visible = true; O.life = life; O.max = life; O.r = r; O.m.scale = Vector3.ONE * 0.1

func mark(pos: Vector3, r: float) -> void:
	var S = scorch[si]; si = (si + 1) % scorch.size()
	S.m.position = Vector3(pos.x, pos.y + 0.06, pos.z); S.m.scale = Vector3(r * 2, 1, r * 2); S.m.rotation.y = randf() * 6.0; S.m.visible = true; S.life = 30.0
	S.m.material_override.set_shader_parameter("op", 0.75)

func sparks(p: Vector3, n: int, color: Color = Color("#ffc070"), speed := 22.0, dir = null, size := 1.0) -> void:
	for i in n:
		var v := Vector3(rnd(speed), rnd(speed) + speed * 0.3, rnd(speed))
		if dir != null: v += dir * speed
		emit_add(p, v, 0.25 + randf() * 0.5, 0.32 * size, 0.06, color, 3.0, 1.5, 34.0, 0.012)

func puff(p: Vector3, n: int, size: float, color: Color = Color("#444444"), a := 0.5, spread := 2.0, up := 2.0, life := 1.6) -> void:
	for i in n:
		var c := Color(color.r, color.g, color.b, a * 0.62)
		emit_smoke(p + Vector3(rnd(spread * 0.3), rnd(spread * 0.3), rnd(spread * 0.3)), Vector3(rnd(spread), up + rnd(spread * 0.5), rnd(spread)), life * (0.7 + randf() * 0.6), size * 0.5, size * (1.6 + randf()), c)

func muzzle(p: Vector3, dir: Vector3, color: Color = Color("#ffd9a0"), size := 1.0) -> void:
	emit_add(p, dir * 6, 0.05, 1.7 * size, 0.7 * size, color, 3.0)
	for i in 3: emit_add(p, dir * (30 + i * 22) + Vector3(rnd(5), rnd(5), rnd(5)), 0.05, 0.9 * size, 0.2, color, 3.0, 6.0)
	light(p, color, 18 * size, 0.06)

func explosion(p: Vector3, r: float, color: Color = Color("#ffb060"), big := false) -> void:
	var n := mini(60, int(10 + r * 3))
	emit_add(p, Vector3.ZERO, 0.14, r * 2.0, r * 3.2, Color(1, 0.87, 0.67), 3.0)
	for i in n:
		var sp := r * (2.0 + randf() * 4.0)
		var v := Vector3(rnd(1), rnd(1) + 0.3, rnd(1)).normalized() * sp
		emit_add(p, v, 0.3 + randf() * 0.5, r * 1.3, r * 0.4, color, 2.2, 3.2, 0.0)
	sparks(p, int(n * 0.6), Color("#ffd28a"), r * 4, null, 0.9)
	puff(p, int(6 + r * 0.6), r * 1.6, Color("#2c2a28"), 0.55, r * 0.9, r * 0.5, 2.4)
	ring(Vector3(p.x, maxf(0.3, p.y - r * 0.3), p.z), color, r * 1.6, 0.35)
	light(p, color, 60 + r * 14, 0.3 + r * 0.012)
	if p.y < r * 0.8: mark(Vector3(p.x, 0, p.z), r * 0.9)
	if big: orb(p, color, r * 1.2, 0.3)

func thrust(p: Vector3, dir: Vector3, color: Color, size: float, speed := 30.0) -> void:
	emit_add(p, dir * speed + Vector3(rnd(2), rnd(2), rnd(2)), 0.12 + randf() * 0.1, size * 1.6, size * 0.3, color, 2.0, 2.0)

func dust(p: Vector3, n: int, size := 3.0, color: Color = Color("#8a8272")) -> void: puff(p, n, size, color, 0.28, size, 1.0, 1.4)

func spawn_debris(p: Vector3, n: int, color: Color = Color("#77736c"), speed := 20.0, size := 0.6) -> void:
	for i in n:
		if debris.size() >= 90: debris.pop_front()
		debris.append({ "p": p + Vector3(rnd(1), rnd(1), rnd(1)), "v": Vector3(rnd(speed), randf() * speed, rnd(speed)), "r": Vector3(rnd(3), rnd(3), rnd(3)), "w": Vector3(rnd(8), rnd(8), rnd(8)),
			"s": Vector3(size * (0.4 + randf()), size * (0.2 + randf() * 0.6), size * (0.4 + randf() * 1.2)), "life": 6.0 + randf() * 4.0, "c": color * (0.6 + randf() * 0.6) })

func add_shake(a: float) -> void: shake = minf(1.6, shake + a)

# ───────── atualização ─────────
func tick(dt: float, ground: Callable) -> void:
	now += dt
	add_mat.set_shader_parameter("now", now); smk_mat.set_shader_parameter("now", now)
	for B in beams:
		if B.life > 0:
			B.life -= dt; var t := maxf(0.0, B.life / B.max); B.m.scale = Vector3(B.w * t, B.w * t, B.len); B.mat.set_shader_parameter("energy", 2.4 * t)
			if B.life <= 0: B.m.visible = false
	for R in rings:
		if R.life > 0:
			R.life -= dt; var t := 1.0 - maxf(0.0, R.life / R.max); R.m.scale = Vector3.ONE * R.r * (0.15 + t); R.mat.set_shader_parameter("energy", (1.0 - t) * 1.6)
			if R.life <= 0: R.m.visible = false
	for O in orbs:
		if O.life > 0:
			O.life -= dt; var t := 1.0 - maxf(0.0, O.life / O.max); O.m.scale = Vector3.ONE * O.r * (0.2 + t * 0.9); O.mat.set_shader_parameter("energy", (1.0 - t) * 1.2)
			if O.life <= 0: O.m.visible = false
	for L in lights:
		if L.life > 0: L.life -= dt; L.l.light_energy = L.i0 * maxf(0.0, L.life / L.max)
		elif L.l.light_energy != 0.0: L.l.light_energy = 0.0
	for S in scorch:
		if S.life > 0:
			S.life -= dt
			if S.life < 5: S.m.material_override.set_shader_parameter("op", 0.75 * S.life / 5.0)
			if S.life <= 0: S.m.visible = false
	var i := debris.size() - 1
	while i >= 0:
		var d = debris[i]; d.life -= dt
		if d.life <= 0: debris.remove_at(i); i -= 1; continue
		d.v.y -= 30 * dt; d.p += d.v * dt
		var gy: float = ground.call(d.p.x, d.p.z) + d.s.y * 0.5
		if d.p.y < gy:
			d.p.y = gy; d.v.y *= -0.35; d.v.x *= 0.6; d.v.z *= 0.6; d.w *= 0.5
			if absf(d.v.y) < 1: d.v.y = 0
		d.r += d.w * dt
		i -= 1
	var k := 0
	for d in debris:
		var sc: Vector3 = d.s * (d.life if d.life < 1 else 1.0)
		db_mm.set_instance_transform(k, Transform3D(Geo.euler(d.r).scaled_local(sc), d.p)); db_mm.set_instance_color(k, d.c); k += 1
	db_mm.visible_instance_count = k
	shake = maxf(0.0, shake - dt * 2.2)

## Desenha os projéteis vivos (rastros e mísseis).
func draw_projectiles(list: Array) -> void:
	var nt := 0; var nm := 0
	for p in list:
		var v: Vector3 = p.vel
		if v.length_squared() < 1e-6: continue
		var dir := v.normalized()
		var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
		var bs := Basis.looking_at(dir, up, true)
		if p.vis == "t":
			if nt >= 500: continue
			var len: float = minf(p.trail, p.travel)
			tr_mm.set_instance_transform(nt, Transform3D(bs.scaled_local(Vector3(p.w, p.w, len)), p.pos)); tr_mm.set_instance_color(nt, p.col); nt += 1
		elif p.vis == "m":
			if nm >= 200: continue
			ms_mm.set_instance_transform(nm, Transform3D(bs.scaled_local(Vector3.ONE * p.w), p.pos)); nm += 1
	tr_mm.visible_instance_count = nt; ms_mm.visible_instance_count = nm
