## Construtor das carcaças: cada peça do catálogo tem um modelo próprio.
## Convenção: frente = +Z, cima = +Y, esquerda = +X (lado L = +1, lado R = -1).
## As funções de peça (core_*, head_*, hand_*…) foram portadas da versão web 1.0.
class_name Builder

const FLAME_COL := ["#ff8a3a", "#ffd9a0", "#7fc4ff", "#7ff2e0"]

static func _s(x) -> String:
	if x is float and is_equal_approx(x, roundf(x)): return str(int(x))
	return str(x)

static func _rng(a, b, step = 1, incl = false) -> Array:
	var out := []; var x: float = a
	while (x <= b if incl else x < b): out.append(x); x += step
	return out

static func att(parent, mount_obj: Node3D, child):
	mount_obj.add_child(child.g); parent.kids.append(child); return child

static func _core(def):
	match def.m.k:
		"slab": return core_slab(def)
		"wedge": return core_wedge(def)
		"pod": return core_pod(def)
		_: return core_reactor(def)

static func _legs(def):
	match def.m.k:
		"biped": return legs_biped(def)
		"reverse": return legs_reverse(def)
		"quad": return legs_quad(def)
		_: return legs_tank(def)

static func _head(def):
	match def.m.k:
		"bucket": return head_bucket(def)
		"helm": return head_helm(def)
		"fin": return head_fin(def)
		"dome": return head_dome(def)
		"facet": return head_facet(def)
		"bunker": return head_bunker(def)
		_: return head_fox(def)

static func _hand(d):
	match d.m.k:
		"rifle": return hand_rifle(d)
		"smg": return hand_smg(d)
		"shotgun": return hand_shotgun(d)
		"pistol": return hand_pistol(d)
		"flamer": return hand_flamer(d)
		"glauncher": return hand_glauncher(d)
		"bazooka": return hand_bazooka(d)
		"pulsegun": return hand_pulsegun(d)
		"sprayer": return hand_sprayer(d)
		"lrifle": return hand_lrifle(d)
		"arcgun": return hand_arcgun(d)
		"plasma": return hand_plasma(d)
		"linear": return hand_linear(d)
		"machete": return hand_machete(d)
		"eblade": return hand_eblade(d)
		"pile": return hand_pile(d)
		"saw": return hand_saw(d)
		_: return hand_shield(d)

static func _back(d, s):
	match d.m.k:
		"mbox": return back_mbox(d, s)
		"swarm": return back_swarm(d, s)
		"guided": return back_guided(d, s)
		"cluster": return back_cluster(d, s)
		"cannon": return back_cannon(d, s)
		"gatling": return back_gatling(d, s)
		"lcannon": return back_lcannon(d, s)
		"pmortar": return back_pmortar(d, s)
		"railgun": return back_railgun(d, s)
		"drones": return back_drones(d, s)
		"battery": return back_battery(d, s)
		"radar": return back_radar(d, s)
		_: return back_wing(d, s)

static func _shoulder(d, s):
	match d.m.k:
		"flare": return sh_flare(d, s)
		"smissile": return sh_smissile(d, s)
		"skirt": return sh_skirt(d, s)
		"sboost": return sh_sboost(d, s)
		_: return sh_emp(d, s)

static func _util(d):
	match d.m.k:
		"hook": return util_hook(d)
		"nanite": return util_nanite(d)
		"barrier": return util_barrier(d)
		"cloak": return util_cloak(d)
		_: return util_burst(d)

static func _mod(d, c):
	match d.m.k:
		"m_plate": return mod_m_plate(d, c)
		"m_glacis": return mod_m_glacis(d, c)
		"m_legplate": return mod_m_legplate(d)
		"m_cell": return mod_m_cell(d)
		"m_kit": return mod_m_kit(d)
		"m_armguard": return mod_m_armguard(d)
		"m_radiator": return mod_m_radiator(d, c)
		"m_gyro": return mod_m_gyro(d)
		"m_chains": return mod_m_chains(d)
		"m_ammo": return mod_m_ammo(d, c)
		"m_cap": return mod_m_cap(d, c)
		"m_era": return mod_m_era(d, c)
		"m_tiles": return mod_m_tiles(d, c)
		_: return mod_m_mast(d)

# ═════════════ POSE DAS PERNAS ═════════════
static func pose_legs(model: Dictionary, phase := 0.0, amp := 0.0, crouch := 0.0) -> void:
	var A = model.anim
	if A == null: return
	if A.type == "biped":
		var ext := 0.0
		for e in [["L", 0.0], ["R", PI]]:
			var J = A[e[0]]; var sw := sin(phase + e[1]) * amp
			var h := -0.5 - crouch * 0.22 + sw * 0.6
			var kn := 1.02 + crouch * 0.42 + maxf(0.0, cos(phase + e[1])) * amp * 0.8
			J.hip.rotation.x = h; J.knee.rotation.x = kn; J.ank.rotation.x = -(h + kn)
			ext = maxf(ext, A.Lt * cos(h) + A.Ls * cos(h + kn) + 0.52)
		model.body.position.y = ext - (model.hipY - 0.3)
	elif A.type == "reverse":
		var ext := 0.0
		for e in [["L", 0.0], ["R", PI]]:
			var J = A[e[0]]; var sw := sin(phase + e[1]) * amp
			var h := -0.95 - crouch * 0.2 + sw * 0.5
			var kn := 1.75 + crouch * 0.3 + maxf(0.0, cos(phase + e[1])) * amp * 0.5
			var an := -1.15 - crouch * 0.1 - sw * 0.2
			J.hip.rotation.x = h; J.knee.rotation.x = kn; J.ank.rotation.x = an; J.toe.rotation.x = -(h + kn + an)
			ext = maxf(ext, 2.05 * cos(h) + 2.55 * cos(h + kn) + 1.25 * cos(h + kn + an) + 0.34)
		model.body.position.y = ext - (model.hipY - 0.25)
	elif A.type == "quad":
		for i in A.legs.size():
			var L = A.legs[i]
			var ph := phase + (0.0 if (i == 0 or i == 3) else PI)
			var lift := maxf(0.0, sin(ph)) * amp
			L.u.rotation.x = -0.45 - lift * 0.35 + crouch * 0.12
			L.kn.rotation.x = 1.75 + lift * 0.2 - crouch * 0.2
			L.ft.rotation.x = -(L.u.rotation.x + L.kn.rotation.x)
			L.sh.rotation.y = L.a + sin(ph + PI / 2) * amp * 0.18
		model.body.position.y = -crouch * 0.25

# ═════════════ MONTAGEM ═════════════
static func add_flame(model: Dictionary, mount_obj: Node3D, r: float, extra := {}) -> void:
	var m := MeshInstance3D.new(); m.mesh = Mats.flame_mesh(); m.material_override = model.flame_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; m.scale = Vector3(r * 1.5, r * 1.5, 0.01); m.visible = false
	mount_obj.add_child(m)
	var f := { "m": m, "r": r, "o": mount_obj, "L": 0.0, "up": 0, "qb": 0 }
	f.merge(extra, true)
	model.flames.append(f)

static func build_mech(build: Dictionary, mat: ShaderMaterial = null) -> Dictionary:
	var p := Stats.parts_of(build)
	if mat == null: mat = Mats.mech_material(build.get("paint", {}))
	var root := Node3D.new(); root.name = "mech"
	var model := { "root": root, "mat": mat, "flames": [], "mz": {}, "wn": {}, "arm": {}, "spin": [], "spinY": [], "util": null }
	var body := Node3D.new(); body.name = "body"; root.add_child(body); model.body = body
	var legs = _legs(p.legs); body.add_child(legs.g); model.legs = legs; model.legsG = legs.g
	model.hipY = legs.hipY; model.anim = legs.anim; model.legType = legs.type
	var waist := Node3D.new(); waist.position.y = legs.hipY; body.add_child(waist); model.waist = waist
	var core = _core(p.core); waist.add_child(core.g); model.core = core
	var head = _head(p.head); att(core, core.m.head, head); model.head = head.g
	att(core, core.m.gen, gen_model(p.gen))
	att(core, core.m.fcs, fcs_model(p.fcs))
	var fcol: String = FLAME_COL[int(p.booster.m.v) if p.booster else 0]
	model.flameCol = Color(fcol)
	model.flame_mat = Mats.flame_material(Color(fcol))
	if p.booster:
		var b = booster_model(p.booster); att(core, core.m.booster, b)
		for o in b.noz: add_flame(model, o, 0.4)
	for o in legs.noz: add_flame(model, o, 0.55)
	model.legThr = legs.thr
	for o in legs.thr: add_flame(model, o, 0.32, { "up": 1 })
	for e in [["R", -1.0], ["L", 1.0]]:
		var key: String = e[0]; var s: float = e[1]
		var arm = build_arm(p.arms, s); att(core, core.m["arm" + key], arm)
		model.arm[key] = { "sh": arm.g, "el": arm.el.g, "node": arm }
		var wdef = p["hand" + key]
		if p.arms.kind == "hand" and wdef:
			var w = _hand(wdef); att(arm.el, arm.el.m.hand, w)
			model.mz["hand" + key] = w.m.mz; model.wn["hand" + key] = w
		elif p.arms.kind == "weapon":
			model.mz["hand" + key] = arm.el.m.mz; model.wn["hand" + key] = arm.el
		if p.shoulder:
			var sn = _shoulder(p.shoulder, s); att(arm, arm.m.shOut if sn.out else arm.m.sh, sn)
			if not model.mz.has("shoulder"): model.mz.shoulder = []
			if sn.m.has("mz"): model.mz.shoulder.append(sn.m.mz)
			model.wn["shoulder" + key] = sn
			for o in sn.noz: add_flame(model, o, 0.3, { "qb": s })
	for e in [["R", -1.0], ["L", 1.0]]:
		var key: String = e[0]; var s: float = e[1]
		var bdef = p["back" + key]
		if bdef == null: continue
		var b = _back(bdef, s); att(core, core.m["back" + key], b)
		var mz = core.m["back" + key]
		if b.pv:
			for k in b.kids:
				if k.g == b.pv and k.m.has("mz"): mz = k.m.mz
		elif b.m.has("mz"): mz = b.m.mz
		model.mz["back" + key] = mz; model.wn["back" + key] = b
		if b.spin: model.spin.append({ "g": b.spin, "key": "back" + key })
		if b.spinY: model.spinY.append(b.spinY)
		for o in b.noz: add_flame(model, o, 0.34)
	if p.util:
		var u = _util(p.util); att(core, core.m.util, u); model.util = u
		model.mz.util = u.m.mz if u.m.has("mz") else core.m.util
	for md in p.mods:
		var res: Dictionary = _mod(md, core)
		for e in res.get("core", []):
			att(core, core.m[e[0]], e[1])
			if e.size() > 2: e[1].g.position = Vector3(e[2][0], e[2][1], e[2][2])
		for e in res.get("legs", []):
			var found = legs.g.find_children(e[0], "Node3D", true, false)
			for o in found:
				var sx := signf(o.position.x); if sx == 0: sx = 1.0
				var nn = e[1].call(1.0 if legs.type == "quad" else sx)
				o.add_child(nn.g); legs.kids.append(nn)
				if legs.type == "quad": nn.g.rotation.y = -PI / 2
		for e in res.get("arms", []):
			for kk in [["R", -1.0], ["L", 1.0]]:
				var el = model.arm[kk[0]].node.el
				if el.m.has(e[0]): att(el, el.m[e[0]], e[1].call(kk[1]))
	legs.bake(mat); core.bake(mat)
	pose_legs(model)
	var H: float = legs.hipY; var cd: Dictionary = core.dim; var wide: bool = legs.type == "tank" or legs.type == "quad"
	model.height = H + cd.H + 1.3
	model.radius = 3.4 if legs.type == "tank" else (3.2 if legs.type == "quad" else 2.5)
	model.hz = [
		{ "part": "head", "o": Vector3(0, H + cd.H + 0.8, 0.1), "r": 1.0 },
		{ "part": "core", "o": Vector3(0, H + cd.H * 0.6, 0), "r": cd.W * 0.52 + 0.3 },
		{ "part": "armR", "o": Vector3(-(cd.W / 2 + 1.5), H + cd.H - 1.2, 0.3), "r": 1.35 },
		{ "part": "armL", "o": Vector3(cd.W / 2 + 1.5, H + cd.H - 1.2, 0.3), "r": 1.35 },
		{ "part": "legs", "o": Vector3(0, H * 0.72, 0), "r": 2.6 if wide else 1.9 },
		{ "part": "legs", "o": Vector3(0, H * 0.28, 0), "r": 3.3 if wide else 2.0 },
	]
	model.aimY = H + cd.H * 0.6
	return model

## Modelo isolado de uma peça (vitrine da loja)
static func build_part_preview(id: String, paint: Dictionary) -> Node3D:
	var d = D.PART[id]; var mat := Mats.mech_material(paint); var g := Node3D.new()
	var fake := Geo.N.new("fake"); fake.dim = { "W": 3.2, "H": 2.8, "D": 2.5 }
	var nodes := []
	match d.slot:
		"head": nodes = [_head(d)]
		"core": nodes = [_core(d)]
		"arms":
			var a = build_arm(d, 1.0); var b = build_arm(d, -1.0); a.g.position.x = 1.6; b.g.position.x = -1.6; nodes = [a, b]
		"legs": nodes = [_legs(d)]
		"gen": nodes = [gen_model(d)]
		"booster": nodes = [booster_model(d)]
		"fcs": nodes = [fcs_model(d)]
		"hand": nodes = [_hand(d)]
		"back": nodes = [_back(d, 1.0)]
		"shoulder":
			var a = _shoulder(d, 1.0); var b = _shoulder(d, -1.0); a.g.position.x = 1.2; b.g.position.x = -1.2; nodes = [a, b]
		"util": nodes = [_util(d)]
		"mod":
			var r: Dictionary = _mod(d, fake)
			for e in r.get("core", []): nodes.append(e[1])
			if r.has("legs"): nodes.append(r.legs[0][1].call(1.0))
			if r.has("arms"): nodes.append(r.arms[0][1].call(1.0))
			if nodes.size() > 1:
				for i in nodes.size(): nodes[i].g.position.x = (i - (nodes.size() - 1) / 2.0) * 1.6
	for n in nodes:
		if n.blade: n.blade.visible = true
		g.add_child(n.bake(mat))
	if d.slot == "legs" and nodes[0].anim:
		pose_legs({ "anim": nodes[0].anim, "body": g, "hipY": nodes[0].hipY })
		g.position.y = 0
	return g

static func build_drone(mat: Material) -> Node3D:
	var n := Geo.N.new("drone"); drone_geo(n); n.g.scale = Vector3.ONE * 2.2; return n.bake(mat)

static func build_hook_head(mat: Material, v := 0) -> Node3D:
	var n := Geo.N.new("hook"); hook_geo(n, v); n.g.scale = Vector3.ONE * 1.3; return n.bake(mat)

# ═════════════ PEÇAS (traduzidas) ═════════════
static func core_slab(def):
	var v = def.m.v
	var n = Geo.N.new("core")
	var W = [3.0, 3.7, 4.1][int(v)]
	var H = [2.7, 2.9, 3.1][int(v)]
	var D = [2.3, 2.7, 3.1][int(v)]
	var hd = (D / float(2))
	n.dim = { "W": W, "H": H, "D": D }
	n.put("c", Geo.cyl(0.72, 0.82, 0.7, 12), Vector3(0, 0.35, 0))
	n.put("k", Geo.cyl(0.62, 0.62, 0.3, 12), Vector3(0, 0.8, 0))
	n.put("a", Geo.bx((W * 0.6), 0.75, (D * 0.78), 0.08), Vector3(0, 1.0, 0.05))
	n.put("a", Geo.prism([[-hd, 1.25], [(hd * 0.7), 1.25], [hd, 1.8], [(hd * 0.6), H], [(-hd * 0.85), H], [-hd, 2.1]], W, 0.1))
	var sl = atan2((hd * 0.4), (H - 1.8))
	n.put("b", Geo.bx((W * 0.42), 0.95, 0.12, 0.04), Vector3(0, (((H + 1.8) / float(2)) + 0.02), ((hd * 0.8) + 0.06)), Vector3(-sl, 0, 0))
	n.put("w", Geo.bx((W * 0.3), 0.16, 0.06, 0.02), Vector3(0, (((H + 1.8) / float(2)) + 0.28), ((hd * 0.75) + 0.14)), Vector3(-sl, 0, 0))
	n.put("g", Geo.bx((W * 0.08), 0.05, 0.05, 0.01), Vector3((W * 0.14), (((H + 1.8) / float(2)) + 0.06), ((hd * 0.79) + 0.14)), Vector3(-sl, 0, 0))
	n.put("c", Geo.cyl(0.6, 0.7, 0.3, 12), Vector3(0, (H + 0.08), 0.05))
	for s in [1.0, -1.0]:
		n.put("c", Geo.bx(0.7, 0.9, (D * 0.7), 0.08), Vector3((s * ((W / float(2)) + 0.2)), (H - 0.7), 0))
		n.put("d", Geo.cyl_x(0.42, 0.5, 12), Vector3((s * ((W / float(2)) + 0.55)), (H - 0.65), 0))
		n.put("b", Geo.bx(0.25, 0.8, (D * 0.5), 0.05), Vector3((s * ((W / float(2)) + 0.02)), 1.75, 0.1))
		Geo.vent(n, "k", Vector3((s * ((W / float(2)) + 0.16)), 1.75, 0.1), (D * 0.4), 0.6, 4, (s * 0.5), "x")
		Geo.bolts(n, "d", [Vector3(((s * W) * 0.42), (H - 0.25), (hd * 0.66)), Vector3(((s * W) * 0.42), 1.5, (hd * 0.86)), Vector3(((s * W) * 0.2), 1.36, (hd * 0.84))], 0.06)
	Geo.vent(n, "k", Vector3(0, 1.52, (hd * 0.86)), (W * 0.5), 0.36, 3, -0.6)
	n.put("c", Geo.bx((W * 0.78), 1.5, 0.5, 0.06), Vector3(0, 1.9, (-hd - 0.1)))
	Geo.vent(n, "k", Vector3(0, 2.2, (-hd - 0.36)), (W * 0.6), 0.5, 4, 0.5)
	if (v == 0):
		for s in [1.0, -1.0]:
			n.put("d", Geo.cyl(0.13, 0.13, 1.5, 8), Vector3(((s * W) * 0.36), (H + 0.25), (-hd - 0.2)))
			n.put("k", Geo.cyl(0.16, 0.16, 0.2, 8), Vector3(((s * W) * 0.36), (H + 1.0), (-hd - 0.2)))
		n.put("hz", Geo.bx((W * 0.9), 0.22, 0.2, 0.03), Vector3(0, 1.3, (hd * 0.78)))
		n.put("b", Geo.bx(0.9, 0.7, 0.06, 0.01), Vector3((-W * 0.26), 2.2, (hd * 0.86)), Vector3((-sl * 0.8), 0, 0.12))
		Geo.rod(n, "d", Vector3((-W * 0.3), H, (hd * 0.5)), Vector3((-W * 0.3), (H + 0.35), (hd * 0.2)), 0.05)
		Geo.rod(n, "d", Vector3((W * 0.3), H, (hd * 0.5)), Vector3((W * 0.3), (H + 0.35), (hd * 0.2)), 0.05)
		Geo.rod(n, "d", Vector3((-W * 0.3), (H + 0.35), (hd * 0.2)), Vector3((W * 0.3), (H + 0.35), (hd * 0.2)), 0.05)
	else:
		for s in [1.0, -1.0]:
			n.put("a", Geo.prism([[(-hd * 0.8), H], [(hd * 0.5), H], [(hd * 0.3), (H + 0.28)], [(-hd * 0.7), (H + 0.28)]], 0.5, 0.05), Vector3(((s * W) * 0.33), 0, 0))
			n.put("d", Geo.tor(0.14, 0.045, 6, 10), Vector3(((s * W) * 0.4), 1.38, (hd * 0.86)), Vector3(0, 0, 0))
		n.put("b", Geo.bx((W * 0.94), 0.3, 0.16, 0.04), Vector3(0, 1.34, (hd * 0.74)))
		if (v == 2):
			n.put("b", Geo.prism([[(hd * 0.55), 1.8], [(hd + 0.25), 1.9], [(hd * 0.72), (H - 0.1)]], (W * 0.5), 0.05))
			for s in [1.0, -1.0]:
				n.put("a", Geo.bx(0.5, 1.2, (D * 0.9), 0.1), Vector3((s * ((W / float(2)) - 0.1)), (H - 0.4), -0.1))
	Geo.decal(n, ("mk" + _s(def.mk)), Vector3((W * 0.24), 2.2, (hd * 0.83)), Vector3(-sl, 0, 0), 0.9, 0.35)
	Geo.decal(n, ("n" + _s((3 + (v * 2)))), Vector3(((-W / float(2)) - 0.565), (H - 0.7), 0.2), Vector3(0, (-PI / float(2)), 0), 0.4, 0.55)
	Geo.decal(n, "warn", Vector3(0, 2.0, (-hd - 0.36)), Vector3(0, PI, 0), 0.8, 0.38)
	core_mounts(n, W, H, D, 0.75)
	return n

static func core_wedge(def):
	var v = def.m.v
	var n = Geo.N.new("core")
	var W = (2.5 + (v * 0.2))
	var H = 2.55
	var D = 2.7
	var hd = (D / float(2))
	n.dim = { "W": W, "H": H, "D": D }
	n.put("c", Geo.cyl(0.5, 0.6, 0.9, 10), Vector3(0, 0.45, 0))
	n.put("k", Geo.cyl(0.46, 0.46, 0.4, 10), Vector3(0, 0.95, 0))
	for s in [1.0, -1.0]:
		Geo.piston(n, Vector3((s * 0.5), 0.3, -0.3), Vector3((s * 0.7), 1.4, -0.2), 0.06)
	n.put("a", Geo.prism([[(-hd * 0.9), 1.3], [(hd * 0.3), 1.15], [(hd * 1.15), 1.75], [(hd * 0.35), H], [(-hd * 0.8), (H - 0.05)], [-hd, 1.9]], (W * 0.62), 0.1))
	for s in [1.0, -1.0]:
		n.put("b", Geo.prism([[(-hd * 0.7), 1.45], [(hd * 0.5), 1.4], [(hd * 0.9), 1.8], [(hd * 0.2), (H - 0.12)], [(-hd * 0.75), (H - 0.2)]], 0.32, 0.06), Vector3(((s * W) * 0.4), 0, 0), Vector3(0, (s * 0.14), 0))
		n.put("c", Geo.bx(0.55, 0.55, 1.1, 0.07), Vector3((s * ((W / float(2)) + 0.25)), (H - 0.62), -0.05))
		n.put("d", Geo.cyl_x(0.34, 0.5, 10), Vector3((s * ((W / float(2)) + 0.55)), (H - 0.62), -0.05))
		n.put("a", Geo.prism([[-0.9, (H - 0.15)], [0.5, (H - 0.15)], [-0.4, (H + 0.38)], [-1.1, (H + 0.3)]], 0.1, 0.03), Vector3(((s * W) * 0.3), 0, -0.1), Vector3(0, 0, (-s * 0.2)))
	n.put("w", Geo.prism([[(hd * 0.5), 2.05], [(hd * 0.95), 1.86], [(hd * 0.55), 2.38]], (W * 0.3), 0.02))
	n.put("g", Geo.bx(0.06, 0.3, 0.06, 0.01), Vector3(0, 1.5, (hd * 0.78)), Vector3(0.6, 0, 0))
	n.put("c", Geo.bx((W * 0.5), 1.2, 0.5, 0.06), Vector3(0, 1.9, (-hd - 0.05)))
	n.put("c", Geo.cyl(0.42, 0.5, 0.25, 10), Vector3(0, (H + 0.06), 0))
	if (v == 1):
		for s in [1.0, -1.0]:
			n.put("b", Geo.prism([[0.2, 1.3], [1.5, 1.6], [0.4, 1.95]], 0.08, 0.02), Vector3(((s * W) * 0.5), 0, 0.1), Vector3(0, (s * 0.35), 0))
		n.put("hz", Geo.bx((W * 0.3), 0.1, 0.5, 0.02), Vector3(0, (H + 0.02), -0.6))
	Geo.decal(n, ("mk" + _s(def.mk)), Vector3(((W * 0.4) + 0.17), 1.95, -0.15), Vector3(0, ((PI / float(2)) + 0.14), 0), 0.8, 0.32)
	Geo.decal(n, ("n" + _s((1 + (v * 6)))), Vector3(((-W * 0.4) - 0.17), 1.95, -0.1), Vector3(0, ((-PI / float(2)) - 0.14), 0), 0.32, 0.44)
	core_mounts(n, W, H, D, 0.72)
	return n

static func core_pod(def):
	var n = Geo.N.new("core")
	var W = 3.3
	var H = 2.75
	var D = 2.6
	var hd = (D / float(2))
	n.dim = { "W": W, "H": H, "D": D }
	n.put("c", Geo.cyl(0.66, 0.74, 0.7, 12), Vector3(0, 0.35, 0))
	n.put("k", Geo.cyl(0.56, 0.56, 0.4, 12), Vector3(0, 0.85, 0))
	n.put("a", Geo.bx(W, 1.55, D, 0.34), Vector3(0, 1.95, 0))
	n.put("b", Geo.bx((W * 0.7), 0.5, (D * 0.86), 0.14), Vector3(0, 1.2, 0.05))
	n.put("w", Geo.bx((W * 0.78), 0.32, 0.2, 0.05), Vector3(0, 2.25, (hd - 0.05)))
	var _t0 = [-0.7, -0.25, 0.25, 0.7]
	for i in _t0.size():
		var x = _t0[i]
		n.put("g", Geo.cyl_z(0.05, 0.05, 0.05, 8), Vector3(x, 2.25, (hd + 0.06)))
	for s in [1.0, -1.0]:
		Geo.rod(n, "d", Vector3((s * ((W / float(2)) + 0.06)), 1.5, (-hd * 0.7)), Vector3((s * ((W / float(2)) + 0.06)), 1.5, (hd * 0.7)), 0.05)
		Geo.rod(n, "d", Vector3((s * ((W / float(2)) + 0.06)), 2.5, (-hd * 0.7)), Vector3((s * ((W / float(2)) + 0.06)), 2.5, (hd * 0.7)), 0.05)
		n.put("b", Geo.bx(0.3, 0.6, 0.8, 0.05), Vector3((s * ((W / float(2)) + 0.1)), 2.0, -0.5))
		n.put("c", Geo.bx(0.6, 0.7, 1.2, 0.08), Vector3((s * ((W / float(2)) + 0.3)), (H - 0.68), 0))
		n.put("d", Geo.cyl_x(0.38, 0.4, 12), Vector3((s * ((W / float(2)) + 0.62)), (H - 0.65), 0))
		Geo.bolts(n, "d", [Vector3((s * 1.2), 1.55, (hd + 0.0)), Vector3((s * 1.2), 1.9, (hd + 0.0))], 0.05)
	n.put("b", Geo.bx(1.0, 0.5, 0.14, 0.04), Vector3(0, 1.72, (hd + 0.02)))
	Geo.vent(n, "k", Vector3(0, 1.72, (hd + 0.1)), 0.8, 0.36, 3, -0.5)
	n.put("c", Geo.bx((W * 0.7), 1.3, 0.45, 0.08), Vector3(0, 1.9, (-hd - 0.1)))
	n.put("c", Geo.cyl(0.55, 0.62, 0.25, 12), Vector3(0, (H + 0.05), 0))
	n.put("d", Geo.cyl(0.03, 0.03, 0.9, 5), Vector3((W * 0.42), (H + 0.4), (-hd * 0.6)))
	Geo.decal(n, ("mk" + _s(def.mk)), Vector3(-0.85, 2.62, (hd - 0.2)), Vector3(-0.78, 0, 0), 0.8, 0.3)
	Geo.decal(n, "bar", Vector3(((W / float(2)) + 0.26), 2.0, -0.5), Vector3(0, (PI / float(2)), 0), 0.6, 0.14)
	Geo.decal(n, "n4", Vector3(((-W / float(2)) - 0.61), (H - 0.68), 0.15), Vector3(0, (-PI / float(2)), 0), 0.36, 0.5)
	core_mounts(n, W, H, D, 0.78)
	return n

static func core_reactor(def):
	var n = Geo.N.new("core")
	var W = 3.1
	var H = 2.75
	var D = 2.5
	var hd = (D / float(2))
	n.dim = { "W": W, "H": H, "D": D }
	n.put("c", Geo.cyl(0.6, 0.7, 0.75, 8), Vector3(0, 0.38, 0))
	n.put("k", Geo.cyl(0.5, 0.5, 0.35, 8), Vector3(0, 0.9, 0))
	n.put("a", Geo.prism([[(-W / float(2)), 1.5], [(-W * 0.3), 1.1], [(W * 0.3), 1.1], [(W / float(2)), 1.5], [(W / float(2)), 2.3], [(W * 0.32), H], [(-W * 0.32), H], [(-W / float(2)), 2.3]], D, 0.14, "z"))
	n.put("d", Geo.tor(0.56, 0.1, 8, 20), Vector3(0, 1.95, (hd + 0.02)))
	n.put("k", Geo.cyl_z(0.5, 0.5, 0.1, 20), Vector3(0, 1.95, (hd - 0.02)))
	n.put("g", Geo.cyl_z(0.3, 0.3, 0.08, 16), Vector3(0, 1.95, (hd + 0.02)))
	for _i in _rng(0, 6, 1):
		var i = _i
		var a = (((i / float(6)) * PI) * 2)
		n.put("b", Geo.bx(0.12, 0.3, 0.1, 0.02), Vector3((cos(a) * 0.82), (1.95 + (sin(a) * 0.82)), hd), Vector3(0, 0, (a + (PI / float(2)))))
	for s in [1.0, -1.0]:
		n.put("b", Geo.prism([[0, 1.2], [0.7, 1.55], [0.7, 2.35], [0.1, 2.65]], 0.14, 0.04, "z"), Vector3(((W * 0.3) if (s > 0) else (-W * 0.3)), 0, (hd + 0.02)), Vector3(0, (0 if (s > 0) else PI), 0))
		n.put("c", Geo.bx(0.55, 0.6, 1.1, 0.12), Vector3((s * ((W / float(2)) + 0.26)), (H - 0.66), 0))
		n.put("d", Geo.cyl_x(0.36, 0.4, 8), Vector3((s * ((W / float(2)) + 0.56)), (H - 0.65), 0))
		n.put("g", Geo.bx(0.04, 0.5, 0.05, 0.01), Vector3((s * ((W / float(2)) + 0.01)), 1.9, 0.4))
		for _i in _rng(0, 4, 1):
			var i = _i
			n.put("c", Geo.bx(0.08, (1.0 - (i * 0.12)), 0.7, 0.02), Vector3((s * (0.3 + (i * 0.26))), 2.0, (-hd - 0.25)), Vector3(0.25, 0, 0))
	n.put("c", Geo.cyl(0.48, 0.56, 0.25, 8), Vector3(0, (H + 0.06), 0))
	Geo.decal(n, ("mk" + _s(def.mk)), Vector3(-0.72, 2.55, (hd + 0.01)), Vector3(0, 0, 0), 0.7, 0.27)
	Geo.decal(n, "warn", Vector3(((W / float(2)) + 0.01), 1.75, -0.45), Vector3(0, (PI / float(2)), 0), 0.7, 0.33)
	core_mounts(n, W, H, D, 0.74)
	return n

static func core_mounts(n, W, H, D, ax):
	var hd = (D / float(2))
	n.mount("head", Vector3(0, (H + 0.18), 0.05))
	n.mount("armL", Vector3(((W / float(2)) + ax), (H - 0.65), 0))
	n.mount("armR", Vector3(((-W / float(2)) - ax), (H - 0.65), 0))
	n.mount("backL", Vector3((W * 0.3), (H - 0.25), (-hd - 0.35)))
	n.mount("backR", Vector3((-W * 0.3), (H - 0.25), (-hd - 0.35)))
	n.mount("booster", Vector3(0, 1.45, (-hd - 0.3)))
	n.mount("gen", Vector3(0, 0.95, (-hd * 0.55)))
	n.mount("chest", Vector3(0, 1.9, hd))
	n.mount("hipL", Vector3(((W * 0.3) + 0.1), 0.55, 0))
	n.mount("hipR", Vector3(((-W * 0.3) - 0.1), 0.55, 0))
	n.mount("hipback", Vector3(0, 0.75, (-hd * 0.75)))
	n.mount("waist", Vector3(0, 0.3, 0))
	n.mount("backtop", Vector3(0, (H + 0.05), (-hd * 0.55)))
	n.mount("mast", Vector3((W * 0.36), H, (-hd * 0.3)))
	n.mount("fcs", Vector3((-W * 0.32), (H + 0.02), (hd * 0.25)))
	n.mount("util", Vector3((W * 0.34), 1.0, (hd * 0.72)))

static func head_bucket(def):
	var n = Geo.N.new("head")
	n.put("k", Geo.cyl(0.3, 0.36, 0.25, 8), Vector3(0, 0.1, 0))
	n.put("a", Geo.cyl(0.62, 0.66, 0.95, 14), Vector3(0, 0.68, 0))
	n.put("c", Geo.cyl(0.68, 0.68, 0.1, 14), Vector3(0, 1.18, 0))
	n.put("c", Geo.cyl(0.69, 0.69, 0.08, 14), Vector3(0, 0.3, 0))
	n.put("c", Geo.bx(0.62, 0.5, 0.4, 0.05), Vector3(0.05, 0.72, 0.56))
	n.put("d", Geo.cyl_z(0.2, 0.22, 0.2, 12), Vector3(0.05, 0.72, 0.8))
	n.put("g", Geo.cyl_z(0.14, 0.14, 0.04, 12), Vector3(0.05, 0.72, 0.9))
	n.put("g", Geo.cyl_z(0.04, 0.04, 0.04, 6), Vector3(-0.36, 0.86, 0.56))
	for s in [1.0, -1.0]:
		n.put("d", Geo.cyl_x(0.12, 0.14, 8), Vector3((s * 0.66), 0.7, 0))
	Geo.rod(n, "d", Vector3(0.5, 1.1, -0.3), Vector3(0.62, 2.0, -0.42), 0.02)
	n.put("b", Geo.bx(0.4, 0.3, 0.05, 0.01), Vector3(-0.3, 0.55, 0.6), Vector3(0, -0.3, 0.2))
	Geo.bolts(n, "d", [Vector3(0.3, 1.24, 0.3), Vector3(-0.3, 1.24, 0.3), Vector3(0.3, 1.24, -0.3), Vector3(-0.3, 1.24, -0.3)], 0.05, "y")
	return n

static func head_helm(def):
	var n = Geo.N.new("head")
	n.put("k", Geo.cyl(0.34, 0.4, 0.25, 8), Vector3(0, 0.1, 0))
	n.put("a", Geo.prism([[-0.75, 0.2], [0.55, 0.2], [0.85, 0.55], [0.7, 1.0], [0.1, 1.28], [-0.6, 1.2], [-0.85, 0.7]], 1.3, 0.1))
	n.put("k", Geo.bx(1.0, 0.14, 0.2, 0.02), Vector3(0, 0.74, 0.72))
	n.put("g", Geo.bx(0.8, 0.05, 0.05, 0.01), Vector3(0, 0.74, 0.8))
	for s in [1.0, -1.0]:
		n.put("b", Geo.prism([[-0.5, 0.15], [0.6, 0.15], [0.8, 0.5], [-0.4, 0.62]], 0.16, 0.04), Vector3((s * 0.7), 0, 0))
		Geo.bolts(n, "d", [Vector3((s * 0.79), 0.4, 0.3), Vector3((s * 0.79), 0.4, -0.2)], 0.05, "x")
	n.put("b", Geo.prism([[-0.6, 1.18], [0.3, 1.22], [0.1, 1.4], [-0.5, 1.34]], 0.22, 0.04))
	return n

static func head_fin(def):
	var n = Geo.N.new("head")
	n.put("k", Geo.cyl(0.26, 0.3, 0.3, 8), Vector3(0, 0.12, 0))
	n.put("a", Geo.prism([[-0.7, 0.3], [0.4, 0.25], [1.15, 0.5], [0.5, 0.92], [-0.5, 1.0], [-0.85, 0.7]], 0.82, 0.1))
	n.put("w", Geo.prism([[0.35, 0.5], [1.0, 0.52], [0.5, 0.8]], 0.86, 0.02))
	n.put("g", Geo.sph(0.11, 10, 8), Vector3(0.12, 0.62, 0.72))
	n.put("b", Geo.prism([[-0.9, 0.85], [-0.2, 0.95], [-1.1, 1.9], [-1.25, 1.8]], 0.07, 0.02))
	for s in [1.0, -1.0]:
		n.put("c", Geo.bx(0.12, 0.3, 0.6, 0.03), Vector3((s * 0.44), 0.5, -0.2))
	return n

static func head_dome(def):
	var n = Geo.N.new("head")
	n.put("k", Geo.cyl(0.3, 0.36, 0.25, 8), Vector3(0, 0.1, 0))
	n.put("c", Geo.cyl(0.7, 0.62, 0.4, 14), Vector3(0, 0.42, 0))
	n.put("a", Geo.sph(0.68, 16, 8, 0, (PI * 2), 0, (PI / float(2))), Vector3(0, 0.6, 0))
	n.put("k", Geo.bx(0.9, 0.24, 0.3, 0.04), Vector3(0, 0.5, 0.52))
	for x in [-0.26, 0, 0.26]:
		n.put("g", Geo.cyl_z(0.07, 0.07, 0.05, 8), Vector3(x, 0.5, 0.68))
	n.put("d", Geo.cyl(0.025, 0.025, 1.3, 5), Vector3(0.5, 1.15, -0.3))
	n.put("d", Geo.cyl(0.02, 0.02, 0.9, 5), Vector3(0.62, 0.95, -0.3))
	n.put("b", Geo.bx(0.16, 0.1, 0.16, 0.02), Vector3(0.5, 1.8, -0.3))
	n.put("b", Geo.bx(0.2, 0.36, 0.5, 0.04), Vector3(-0.66, 0.6, -0.1))
	return n

static func head_facet(def):
	var n = Geo.N.new("head")
	n.put("k", Geo.cyl(0.28, 0.34, 0.3, 8), Vector3(0, 0.12, 0))
	n.put("a", Geo.ico(0.74, 0), Vector3(0, 0.78, 0.05), Vector3(0.3, 0, 0), [0.95, 0.74, 1.12])
	n.put("g", Geo.tor(0.72, 0.035, 5, 24), Vector3(0, 0.74, 0.08), Vector3(((PI / float(2)) - 0.22), 0, 0), [0.98, 1.14, 1])
	n.put("c", Geo.bx(0.3, 0.3, 0.6, 0.06), Vector3(0, 0.5, -0.55))
	return n

static func head_bunker(def):
	var n = Geo.N.new("head")
	n.put("c", Geo.cyl(0.5, 0.56, 0.2, 10), Vector3(0, 0.1, 0))
	n.put("a", Geo.bx(1.7, 0.62, 1.5, 0.16), Vector3(0, 0.5, 0))
	n.put("b", Geo.bx(1.3, 0.14, 1.2, 0.04), Vector3(0, 0.86, -0.05))
	n.put("c", Geo.bx(0.4, 0.34, 0.4, 0.05), Vector3(0.36, 1.05, 0.25))
	n.put("g", Geo.bx(0.24, 0.1, 0.04, 0.01), Vector3(0.36, 1.08, 0.46))
	n.put("k", Geo.bx(1.1, 0.1, 0.1, 0.02), Vector3(0, 0.56, 0.75))
	n.put("g", Geo.bx(0.5, 0.035, 0.04, 0.01), Vector3(-0.2, 0.56, 0.8))
	for s in [1.0, -1.0]:
		n.put("b", Geo.bx(0.18, 0.5, 1.2, 0.05), Vector3((s * 0.92), 0.46, -0.05))
		Geo.bolts(n, "d", [Vector3((s * 0.6), 0.94, 0.4), Vector3((s * 0.6), 0.94, -0.5)], 0.06, "y")
	return n

static func head_fox(def):
	var n = Geo.N.new("head")
	n.put("k", Geo.cyl(0.26, 0.3, 0.3, 8), Vector3(0, 0.12, 0))
	n.put("a", Geo.prism([[-0.75, 0.32], [0.5, 0.26], [1.25, 0.46], [0.55, 0.9], [-0.55, 1.02], [-0.9, 0.72]], 0.78, 0.1))
	n.put("w", Geo.prism([[0.4, 0.5], [1.1, 0.5], [0.55, 0.78]], 0.82, 0.02))
	for p in [[-0.2, 0.6, 0.86], [0.2, 0.6, 0.86], [0, 0.72, 0.72]]:
		n.put("g", Geo.sph(0.06, 8, 6), Vector3(p[0], p[1], p[2]))
	for s in [1.0, -1.0]:
		n.put("b", Geo.prism([[-0.5, 0.8], [0.1, 0.9], [-1.5, 2.2], [-1.6, 2.05]], 0.06, 0.02), Vector3((s * 0.36), 0, 0), Vector3(0, 0, (-s * 0.16)))
		n.put("c", Geo.bx(0.14, 0.36, 0.7, 0.03), Vector3((s * 0.42), 0.52, -0.2))
	return n

static func build_arm(def, s):
	var k = def.m.k
	var n = Geo.N.new("arm")
	var el = n.child("elbow", Vector3((s * 0.45), -1.95, 0))
	n.el = el
	var heavy = ((k == "block") if (k == "block") else (k == "wa_cannon"))
	var ua = (0.5 if heavy else (0.3 if (k == "blade") else 0.38))
	n.put("d", Geo.sph((0.52 if heavy else 0.42), 10, 8), Vector3((s * 0.3), 0, 0))
	if (k == "cage"):
		n.put("c", Geo.bx(1.2, 0.9, 1.4, 0.06), Vector3((s * 0.6), 0.15, 0))
		n.put("hz", Geo.bx(1.3, 0.22, 1.5, 0.03), Vector3((s * 0.6), 0.62, 0))
		n.put("d", Geo.tor(0.7, 0.05, 6, 12, PI), Vector3((s * 0.62), 0.6, 0), Vector3(0, (PI / float(2)), 0))
		Geo.rod(n, "d", Vector3((s * 0.3), -0.3, 0.3), Vector3((s * 0.3), -1.8, 0.3), 0.07)
		Geo.rod(n, "d", Vector3((s * 0.6), -0.3, -0.3), Vector3((s * 0.6), -1.8, -0.3), 0.07)
		n.put("c", Geo.bx(0.5, 1.3, 0.5, 0.04), Vector3((s * 0.45), -1.0, 0))
		Geo.bolts(n, "d", [Vector3((s * 1.21), 0.3, 0.4), Vector3((s * 1.21), 0.3, -0.4), Vector3((s * 1.21), -0.05, 0)], 0.06, "x")
	elif ((k == "block") or (k == "wa_cannon")):
		n.put("a", Geo.bx(1.7, 1.5, 1.95, 0.14), Vector3((s * 0.75), 0.25, 0))
		n.put("b", Geo.bx(1.5, 0.2, 1.75, 0.05), Vector3((s * 0.78), 1.06, 0))
		n.put("b", Geo.bx(0.18, 1.1, 1.5, 0.05), Vector3((s * 1.64), 0.2, 0))
		n.put("c", Geo.bx(0.95, 1.4, 1.05, 0.08), Vector3((s * 0.45), -1.05, 0))
		Geo.bolts(n, "d", [Vector3((s * 1.74), 0.55, 0.5), Vector3((s * 1.74), 0.55, -0.5), Vector3((s * 1.74), -0.15, 0.5), Vector3((s * 1.74), -0.15, -0.5)], 0.07, "x")
		Geo.decal(n, "step", Vector3((s * 0.78), 1.17, 0), Vector3((-PI / float(2)), 0, (0 if (s > 0) else PI)), 0.9, 0.22)
	elif (k == "blade"):
		n.put("a", Geo.prism([[-0.2, -0.45], [1.0, -0.3], [1.5, 0.75], [0.9, 0.95], [-0.2, 0.5]], 1.25, 0.08, "z"), Vector3((0.05 if (s > 0) else -0.05), 0, 0), Vector3(0, (0 if (s > 0) else PI), 0))
		n.put("b", Geo.prism([[0.9, 0.5], [1.5, 0.75], [2.0, 1.75], [1.75, 1.7]], 0.1, 0.03, "z"), Vector3(0, 0, 0), Vector3(0, (0 if (s > 0) else PI), 0))
		n.put("c", Geo.cyl(0.28, 0.24, 1.5, 8), Vector3((s * 0.45), -1.0, 0))
		Geo.piston(n, Vector3((s * 0.62), -0.3, -0.25), Vector3((s * 0.55), -1.7, -0.2), 0.05)
	elif ((k == "round") or (k == "wa_missile")):
		n.put("a", Geo.cyl_x(0.82, 1.15, 16), Vector3((s * 0.72), 0.12, 0))
		n.put("c", Geo.cyl_x(0.6, 1.25, 16), Vector3((s * 0.72), 0.12, 0))
		n.put("b", Geo.bx(0.5, 0.36, 0.7, 0.06), Vector3((s * 0.8), 0.95, 0))
		n.put("g", Geo.cyl_z(0.05, 0.05, 0.04, 8), Vector3((s * 0.8), 0.98, 0.36))
		n.put("c", Geo.cyl(0.36, 0.33, 1.5, 12), Vector3((s * 0.45), -1.05, 0))
		n.put("d", Geo.tor(0.37, 0.04, 6, 12), Vector3((s * 0.45), -0.7, 0), Vector3((PI / float(2)), 0, 0))
	else:
		n.put("a", Geo.ico(0.8, 0), Vector3((s * 0.72), 0.15, 0), Vector3(0, 0, 0), [1, 1, 1.15])
		n.put("d", Geo.tor(0.92, 0.07, 6, 22), Vector3((s * 0.74), 0.15, 0), Vector3(0, (PI / float(2)), 0))
		n.put("g", Geo.tor(0.92, 0.025, 4, 22), Vector3((s * 0.86), 0.15, 0), Vector3(0, (PI / float(2)), 0))
		n.put("c", Geo.cyl(0.3, 0.3, 1.5, 6), Vector3((s * 0.45), -1.05, 0))
		n.put("g", Geo.bx(0.04, 0.9, 0.05, 0.01), Vector3((s * 0.72), -1.0, 0.1))
	n.mount("sh", Vector3((s * (0.8 if heavy else 0.72)), (1.18 if heavy else 0.95), 0))
	n.mount("shOut", Vector3((s * (1.72 if heavy else 1.4)), 0.2, 0))
	el.put("d", Geo.cyl_x((ua + 0.12), ((ua * 2) + 0.3), 12), Vector3(0, 0, 0))
	if (def.kind == "hand"):
		var fw = (1.05 if heavy else (0.62 if (k == "blade") else 0.8))
		if (k == "cage"):
			el.put("a", Geo.bx(0.8, 0.8, 1.7, 0.05), Vector3(0, 0, 1.0))
			el.put("b", Geo.bx(0.84, 0.3, 0.9, 0.04), Vector3(0, 0.3, 1.0))
			Geo.piston(el, Vector3(0, -0.45, 0.2), Vector3(0, -0.4, 1.6), 0.06)
		elif heavy:
			el.put("a", Geo.bx(1.1, 1.05, 1.9, 0.1), Vector3(0, 0, 1.05))
			el.put("b", Geo.bx(1.2, 0.5, 1.1, 0.06), Vector3(0, 0.35, 1.0))
			Geo.bolts(el, "d", [Vector3((s * 0.56), 0, 0.5), Vector3((s * 0.56), 0, 1.6)], 0.07, "x")
		elif (k == "blade"):
			el.put("a", Geo.prism([[0.1, -0.3], [1.9, -0.22], [1.9, 0.22], [0.1, 0.36]], 0.6, 0.06))
			el.put("b", Geo.prism([[0.2, 0.3], [1.5, 0.22], [0.0, 0.9]], 0.07, 0.02), Vector3((s * 0.2), 0, 0))
		elif (k == "round"):
			el.put("a", Geo.bx(0.8, 0.8, 1.8, 0.2), Vector3(0, 0, 1.05))
			Geo.rod(el, "d", Vector3((s * 0.42), 0.2, 0.3), Vector3((s * 0.42), 0.2, 1.8), 0.04)
			el.put("b", Geo.bx(0.3, 0.3, 0.5, 0.05), Vector3((s * 0.4), -0.1, 1.2))
		else:
			el.put("a", Geo.prism([[0.1, -0.35], [1.9, -0.28], [1.9, 0.28], [0.1, 0.4]], 0.72, 0.1))
			el.put("g", Geo.bx(0.04, 0.05, 1.3, 0.01), Vector3((s * 0.37), 0.05, 1.0))
			el.put("d", Geo.tor(0.44, 0.05, 6, 14), Vector3(0, 0, 1.75))
		el.put("c", Geo.bx((fw * 0.7), 0.5, 0.45, 0.05), Vector3(0, 0, 2.15))
		for i in [-1, 0, 1]:
			el.put("d", Geo.bx((fw * 0.18), 0.16, 0.5, 0.03), Vector3(((i * fw) * 0.24), -0.26, 2.3), Vector3(0.9, 0, 0))
		el.put("d", Geo.bx(0.14, 0.14, 0.4, 0.03), Vector3(((-s * fw) * 0.38), 0.05, 2.25), Vector3(0, (s * 0.5), 0))
		el.mount("hand", Vector3(0, -0.42, 2.2))
		el.mount("guard", Vector3((s * ((fw / float(2)) + 0.06)), 0.1, 1.0))
	elif (k == "wa_cannon"):
		el.put("c", Geo.bx(1.15, 1.2, 2.0, 0.1), Vector3(0, 0, 1.0))
		el.put("b", Geo.cyl_x(0.62, 0.5, 14), Vector3((s * 0.5), -0.1, 0.7))
		for i in [1.0, -1.0]:
			el.put("d", Geo.cyl_z(0.17, 0.17, 2.4, 10), Vector3((i * 0.26), 0.12, 3.1))
			el.put("c", Geo.cyl_z(0.25, 0.25, 0.5, 10), Vector3((i * 0.26), 0.12, 4.2))
			el.put("k", Geo.cyl_z(0.12, 0.12, 0.52, 8), Vector3((i * 0.26), 0.12, 4.22))
		el.put("a", Geo.bx(0.9, 0.5, 1.2, 0.06), Vector3(0, 0.5, 2.3))
		el.put("hz", Geo.bx(1.2, 0.16, 0.3, 0.02), Vector3(0, 0.62, 0.3))
		el.mount("mz", Vector3(0, 0.12, 4.5))
	elif (k == "wa_missile"):
		el.put("a", Geo.bx(1.3, 1.3, 2.5, 0.12), Vector3(0, 0, 1.3))
		el.put("c", Geo.bx(1.36, 0.3, 0.5, 0.04), Vector3(0, 0, 0.6))
		for x in [-0.3, 0.3]:
			for y in [-0.3, 0.3]:
				el.put("k", Geo.cyl_z(0.22, 0.22, 0.2, 10), Vector3(x, y, 2.5))
				el.put("b", Geo.cone(0.16, 0.3, 8), Vector3(x, y, 2.45), Vector3((PI / float(2)), 0, 0))
		el.put("b", Geo.bx(1.34, 1.34, 0.12, 0.03), Vector3(0, 0, 2.3))
		el.mount("mz", Vector3(0, 0, 2.7))
		Geo.decal(el, "warn", Vector3((s * 0.66), 0, 1.4), Vector3(0, ((s * PI) / float(2)), 0), 0.9, 0.42)
	else:
		el.put("a", Geo.prism([[0, -0.45], [2.6, -0.2], [2.6, 0.2], [0, 0.5]], 0.8, 0.1))
		for z in [0.6, 1.2, 1.8, 2.4]:
			el.put("d", Geo.tor((0.42 - (z * 0.06)), 0.06, 6, 14), Vector3(0, 0, z))
		el.put("k", Geo.cyl_z(0.2, 0.26, 0.6, 10), Vector3(0, 0, 2.9))
		el.put("g", Geo.cyl_z(0.13, 0.13, 0.05, 10), Vector3(0, 0, 3.2))
		for i in [1.0, -1.0]:
			el.put("g", Geo.bx(0.04, 0.05, 1.8, 0.01), Vector3((i * 0.41), 0.1, 1.3))
		el.mount("mz", Vector3(0, 0, 3.25))
	return n

static func foot_geo(n, len, w, h):
	n.put("c", Geo.prism([[(-len * 0.42), 0], [(len * 0.58), 0], [(len * 0.58), (h * 0.35)], [(len * 0.2), h], [(-len * 0.3), h], [(-len * 0.42), (h * 0.5)]], w, 0.06))
	n.put("k", Geo.bx((w * 1.04), 0.1, (len * 0.96), 0.02), Vector3(0, 0.03, (len * 0.08)))
	n.put("b", Geo.prism([[(len * 0.15), (h * 0.9)], [(len * 0.6), (h * 0.3)], [(len * 0.62), (h * 0.55)], [(len * 0.25), (h * 1.1)]], (w * 0.8), 0.03))

static func legs_biped(def):
	var v = def.m.v
	var n = Geo.N.new("legs")
	var hw = [1.15, 1.0, 1.4][int(v)]
	var tw = [0.95, 0.72, 1.3][int(v)]
	var sw = [0.85, 0.6, 1.25][int(v)]
	var Lt = 2.15
	var Ls = 2.2
	var hipY = 4.55
	n.hipY = hipY
	n.type = "biped"
	var pel = n.child("pelvis", Vector3(0, hipY, 0))
	pel.put("a", Geo.bx(((hw * 2) - 0.3), 0.8, 1.5, 0.1), Vector3(0, -0.25, 0))
	pel.put("b", Geo.prism([[-0.3, -0.75], [0.3, -0.75], [0.45, -0.1], [-0.45, -0.1]], 0.3, 0.05, "z"), Vector3(0, -0.2, 0.75))
	pel.put("c", Geo.cyl(0.8, 0.86, 0.25, 12), Vector3(0, 0.2, 0))
	for s in [1.0, -1.0]:
		pel.put("d", Geo.cyl_x(0.45, 0.5, 12), Vector3((s * hw), -0.3, 0))
	if (v == 0):
		pel.put("hz", Geo.bx(((hw * 2) - 0.2), 0.16, 1.56, 0.02), Vector3(0, -0.6, 0))
	n.anim = { "type": "biped", "L": null, "R": null, "Lt": Lt, "Ls": Ls }
	for s in [1.0, -1.0]:
		var hip = pel.child("hip", Vector3((s * hw), -0.3, 0))
		if (v == 0):
			hip.put("c", Geo.bx((tw * 0.7), Lt, (tw * 0.8), 0.05), Vector3(0, (-Lt / float(2)), 0))
			hip.put("a", Geo.bx(tw, (Lt * 0.7), 0.25, 0.05), Vector3(0, (-Lt * 0.5), (tw * 0.5)))
			Geo.piston(hip, Vector3(0, -0.3, (-tw * 0.5)), Vector3(0, (-Lt + 0.2), (-tw * 0.45)), 0.08)
			hip.put("b", Geo.bx(0.2, (Lt * 0.6), (tw * 0.9), 0.04), Vector3(((s * tw) * 0.5), (-Lt * 0.5), 0))
		elif (v == 1):
			hip.put("c", Geo.cyl(0.3, 0.26, Lt, 8), Vector3(0, (-Lt / float(2)), 0))
			hip.put("a", Geo.prism([[-0.45, -0.2], [0.55, -0.1], [0.5, (-Lt + 0.2)], [-0.3, (-Lt + 0.4)]], tw, 0.07))
			Geo.piston(hip, Vector3(0, -0.3, -0.42), Vector3(0, (-Lt + 0.3), -0.36), 0.05)
		else:
			hip.put("a", Geo.bx(tw, (Lt + 0.1), (tw * 1.05), 0.12), Vector3(0, (-Lt / float(2)), 0))
			hip.put("b", Geo.bx((tw * 1.06), (Lt * 0.5), 0.2, 0.05), Vector3(0, (-Lt * 0.4), (tw * 0.56)))
			Geo.bolts(hip, "d", [Vector3(((s * tw) * 0.52), -0.5, 0.3), Vector3(((s * tw) * 0.52), -0.5, -0.3), Vector3(((s * tw) * 0.52), -1.6, 0.3), Vector3(((s * tw) * 0.52), -1.6, -0.3)], 0.07, "x")
		hip.mount("plate", Vector3((s * ((tw / float(2)) + 0.08)), (-Lt * 0.5), 0))
		var knee = hip.child("knee", Vector3(0, -Lt, 0))
		knee.put("d", Geo.cyl_x((0.42 + (v * 0.03)), (tw + 0.14), 12))
		knee.put("b", Geo.prism([[0.2, -0.45], [0.75, -0.2], [0.75, 0.3], [0.2, 0.55]], (tw * 0.8), 0.06))
		if (v == 1):
			knee.put("a", Geo.prism([[-0.3, -0.2], [0.4, -0.3], [0.5, (-Ls + 0.3)], [-0.5, (-Ls + 0.2)], [-0.62, -1.0]], sw, 0.07))
			knee.put("b", Geo.prism([[-0.62, -0.9], [-0.3, -0.3], [-0.95, -0.2]], 0.07, 0.02))
		else:
			knee.put("a", Geo.prism([[-0.5, -0.2], [0.45, -0.3], [0.6, (-Ls + 0.3)], [-0.6, (-Ls + 0.2)], [-0.72, -1.0]], sw, 0.08))
			knee.put("c", Geo.bx((sw * 0.6), 0.9, 0.4, 0.05), Vector3(0, -1.0, -0.72))
			Geo.vent(knee, "k", Vector3(0, -1.0, -0.94), (sw * 0.45), 0.6, 3, 0.5)
		if (v == 2):
			knee.put("b", Geo.bx((sw * 1.05), 1.0, 0.22, 0.05), Vector3(0, -1.1, 0.6))
		Geo.decal(knee, ("band" if (v == 2) else "tick"), Vector3((s * ((sw / float(2)) + 0.005)), -1.1, 0), Vector3(0, ((s * PI) / float(2)), 0), 0.9, 0.14)
		knee.mount("thr", Vector3(0, -1.3, -0.9), Vector3((-PI * 0.38), 0, 0))
		var ank = knee.child("ankle", Vector3(0, -Ls, 0))
		ank.put("d", Geo.cyl_x(0.3, (sw + 0.1), 10))
		foot_geo(ank, [2.3, 2.0, 2.7][int(v)], [1.1, 0.85, 1.5][int(v)], 0.55)
		ank.translate_all(Vector3(0, -0.52, 0.1))
		ank.put("d", Geo.cyl_x(0.3, (sw + 0.1), 10))
		n.anim[("L" if (s > 0) else "R")] = { "hip": hip.g, "knee": knee.g, "ank": ank.g }
	n.thr = [n.anim.L.knee.get_node("thr"), n.anim.R.knee.get_node("thr")]
	return n

static func legs_reverse(def):
	var v = def.m.v
	var n = Geo.N.new("legs")
	var hw = (1.05 + (v * 0.1))
	var hipY = 4.7
	var t = (0.55 if v else 0.4)
	n.hipY = hipY
	n.type = "reverse"
	var pel = n.child("pelvis", Vector3(0, hipY, 0))
	pel.put("a", Geo.prism([[-0.9, -0.6], [0.7, -0.6], [0.9, -0.1], [0.5, 0.2], [-0.8, 0.2]], ((hw * 2) - 0.4), 0.09))
	pel.put("c", Geo.cyl(0.7, 0.76, 0.25, 12), Vector3(0, 0.2, 0))
	for s in [1.0, -1.0]:
		pel.put("d", Geo.cyl_x(0.42, 0.5, 12), Vector3((s * hw), -0.25, 0))
	n.anim = { "type": "reverse", "L": null, "R": null }
	for s in [1.0, -1.0]:
		var hip = pel.child("hip", Vector3((s * hw), -0.25, 0))
		if (v == 0):
			hip.put("a", Geo.prism([[-0.5, 0.35], [0.5, 0.45], [0.42, -2.0], [-0.35, -2.0]], (t + 0.3), 0.07))
		else:
			hip.put("c", Geo.bx(t, 2.1, 0.6, 0.05), Vector3(0, -1.0, 0))
			hip.put("hz", Geo.bx((t + 0.1), 0.5, 0.66, 0.03), Vector3(0, -0.9, 0))
			Geo.rod(hip, "d", Vector3((s * 0.3), 0, 0.36), Vector3((s * 0.3), -2.0, 0.36), 0.06)
		Geo.piston(hip, Vector3(0, -0.1, -0.45), Vector3(0, -1.7, -0.4), 0.07)
		hip.mount("plate", Vector3((s * ((t / float(2)) + 0.25)), -1.0, 0))
		var knee = hip.child("knee", Vector3(0, -2.05, 0))
		knee.put("d", Geo.cyl_x(0.4, (t + 0.5), 12))
		knee.put("b", Geo.prism([[0.1, -0.4], [0.7, -0.1], [0.6, 0.45], [0.1, 0.5]], (t + 0.2), 0.05))
		if (v == 0):
			knee.put("a", Geo.prism([[-0.34, 0.1], [0.34, 0.2], [0.24, -2.5], [-0.24, -2.5]], (t + 0.18), 0.06))
		else:
			knee.put("c", Geo.bx((t - 0.05), 2.6, 0.5, 0.05), Vector3(0, -1.25, 0))
			Geo.rod(knee, "d", Vector3((s * 0.28), -0.1, -0.3), Vector3((s * 0.28), -2.4, -0.3), 0.05)
			knee.put("a", Geo.bx((t + 0.1), 1.2, 0.2, 0.04), Vector3(0, -1.3, 0.34))
		Geo.piston(knee, Vector3(0, -0.2, 0.42), Vector3(0, -2.0, 0.34), 0.06)
		knee.mount("thr", Vector3(0, -1.4, -0.45), Vector3((-PI * 0.38), 0, 0))
		var ank = knee.child("ankle", Vector3(0, -2.55, 0))
		ank.put("d", Geo.cyl_x(0.3, (t + 0.34), 10))
		ank.put("c", Geo.prism([[-0.3, 0.2], [0.3, 0.3], [0.22, -1.2], [-0.2, -1.2]], (t + 0.1), 0.05))
		var toe = ank.child("toe", Vector3(0, -1.25, 0))
		toe.put("d", Geo.cyl_x(0.24, (t + 0.3), 8))
		for i in [-1, 1]:
			toe.put("c", Geo.prism([[0, 0.22], [1.5, -0.05], [1.5, -0.3], [0, -0.28]], 0.34, 0.05), Vector3((i * 0.32), 0, 0), Vector3(0, (-i * 0.2), 0))
		toe.put("c", Geo.prism([[0, 0.2], [-0.9, -0.1], [-0.9, -0.3], [0, -0.28]], 0.36, 0.05))
		toe.put("k", Geo.bx(1.1, 0.08, 2.3, 0.02), Vector3(0, -0.3, 0.3))
		n.anim[("L" if (s > 0) else "R")] = { "hip": hip.g, "knee": knee.g, "ank": ank.g, "toe": toe.g }
	n.thr = [n.anim.L.knee.get_node("thr"), n.anim.R.knee.get_node("thr")]
	return n

static func legs_quad(def):
	var v = def.m.v
	var n = Geo.N.new("legs")
	var hipY = 3.2
	n.hipY = hipY
	n.type = "quad"
	var hub = n.child("hub", Vector3(0, hipY, 0))
	hub.put("a", Geo.cyl(1.35, 1.5, 0.8, (8 if v else 16)), Vector3(0, -0.5, 0))
	hub.put("c", Geo.cyl(0.85, 0.95, 0.3, 12), Vector3(0, 0.05, 0))
	hub.put("c", Geo.cyl(1.0, 0.7, 0.5, (8 if v else 16)), Vector3(0, -1.1, 0))
	hub.put("g", Geo.cyl(0.5, 0.5, 0.06, 12), Vector3(0, -1.37, 0))
	hub.put("b", Geo.bx(1.4, 0.4, 0.3, 0.05), Vector3(0, -0.45, 1.36))
	Geo.decal(hub, ("mk" + _s(def.mk)), Vector3(0, -0.45, 1.52), Vector3(0, 0, 0), 0.9, 0.34)
	n.anim = { "type": "quad", "legs": [] }
	var angs = [(PI / float(4)), (-PI / float(4)), ((PI * 3) / float(4)), ((-PI * 3) / float(4))]
	var up = 2.3
	var lo = 3.3
	var _t1 = angs
	for i in _t1.size():
		var a = _t1[i]
		var sh = hub.child("qhip", Vector3((sin(a) * 1.25), -0.5, (cos(a) * 1.25)), Vector3(0, a, 0))
		sh.put("d", Geo.cyl_x(0.5, 0.9, 12))
		var u = sh.child("upper", Vector3(0, 0, 0), Vector3(-0.45, 0, 0))
		if (v == 0):
			u.put("a", Geo.bx(0.8, 0.7, up, 0.08), Vector3(0, 0, (up / float(2))))
			u.put("b", Geo.bx(0.86, 0.2, (up * 0.6), 0.04), Vector3(0, 0.38, (up / float(2))))
			Geo.piston(u, Vector3(0, -0.4, 0.2), Vector3(0, -0.35, (up - 0.2)), 0.07)
		else:
			u.put("a", Geo.prism([[0, -0.3], [up, -0.2], [up, 0.2], [0, 0.4]], 0.6, 0.08))
			u.put("g", Geo.bx(0.04, 0.05, (up * 0.7), 0.01), Vector3(0.31, 0.05, (up / float(2))))
		var kn = u.child("qknee", Vector3(0, 0, up), Vector3(1.75, 0, 0))
		kn.put("d", Geo.cyl_x(0.46, 0.95, 12))
		if (v == 0):
			kn.put("a", Geo.prism([[0, -0.4], [lo, -0.25], [lo, 0.25], [0, 0.45]], 0.7, 0.08))
			kn.put("b", Geo.prism([[0.3, 0.4], [1.8, 0.3], [0.2, 0.9]], 0.5, 0.05))
		else:
			kn.put("a", Geo.prism([[0, -0.3], [lo, -0.12], [lo, 0.12], [0, 0.34]], 0.5, 0.07))
			kn.put("b", Geo.prism([[0.2, 0.3], [2.0, 0.2], [0.1, 0.8]], 0.08, 0.02))
		var ft = kn.child("qfoot", Vector3(0, 0, lo), Vector3(-1.3, 0, 0))
		ft.put("d", Geo.sph(0.34, 8, 6))
		ft.put("c", Geo.cyl(0.62, 0.8, 0.3, (6 if v else 12)), Vector3(0, -0.28, 0))
		ft.put("k", Geo.cyl(0.82, 0.82, 0.08, (6 if v else 12)), Vector3(0, -0.44, 0))
		n.anim.legs.append({ "sh": sh.g, "u": u.g, "kn": kn.g, "ft": ft.g, "a": a })
		if (i < 2):
			sh.mount("plate", Vector3(0, 0.1, 0.9))
	n.thr = [hub.mount("thr", Vector3(0, -1.3, 0), Vector3((-PI / float(2)), 0, 0))]
	return n

static func legs_tank(def):
	var v = def.m.v
	var n = Geo.N.new("legs")
	var L = (7.4 if v else 6.4)
	var TW = (1.5 if v else 1.25)
	var HW = (3.6 if v else 3.2)
	var hipY = (3.05 if v else 2.85)
	var th = (1.9 if v else 1.7)
	n.hipY = hipY
	n.type = "tank"
	var hull = n.child("hull", Vector3(0, 0, 0))
	var hl = (L / float(2))
	hull.put("a", Geo.prism([[(-hl + 0.3), 0.7], [(hl - 1.0), 0.7], [(hl - 0.1), 1.3], [(hl - 1.2), (th + 0.5)], [(-hl + 0.2), (th + 0.5)], [-hl, 1.5]], HW, 0.1))
	hull.put("c", Geo.cyl(1.15, 1.25, 0.45, 16), Vector3(0, (th + 0.72), 0))
	hull.put("b", Geo.bx((HW * 0.8), 0.14, 1.6, 0.04), Vector3(0, (th + 0.52), (-hl + 1.2)))
	Geo.vent(hull, "k", Vector3(0, (th + 0.6), (-hl + 1.2)), (HW * 0.6), 1.2, 5, 0.3, "z")
	for s in [1.0, -1.0]:
		hull.put("d", Geo.cyl(0.14, 0.14, 0.9, 8), Vector3(((s * HW) * 0.4), (th + 0.9), (-hl + 0.5)))
		hull.put("g", Geo.bx(0.3, 0.14, 0.05, 0.02), Vector3(((s * HW) * 0.36), 1.5, (hl - 0.42)), Vector3(-0.6, 0, 0))
		var tr = n.child("track", Vector3((s * (((HW / float(2)) + (TW / float(2))) + 0.05)), 0, 0))
		tr.put("t", Geo.prism([[(-hl + 0.5), 0], [(hl - 0.7), 0], [hl, 0.75], [(hl - 0.4), th], [(-hl + 0.3), th], [(-hl - 0.1), 0.8]], TW, 0.08))
		var nW = (6 if v else 5)
		for _i in _rng(0, nW, 1):
			var i = _i
			var z = ((-hl + 1.0) + ((i * (L - 2.0)) / float((nW - 1))))
			tr.put("d", Geo.cyl_x(0.5, (TW + 0.06), 12), Vector3(0, 0.58, z))
			tr.put("c", Geo.cyl_x(0.2, (TW + 0.12), 8), Vector3(0, 0.58, z))
		tr.put("d", Geo.cyl_x(0.46, (TW + 0.08), 10), Vector3(0, (th - 0.52), (hl - 0.6)))
		tr.put("d", Geo.cyl_x(0.46, (TW + 0.08), 10), Vector3(0, (th - 0.5), (-hl + 0.5)))
		tr.put("c", Geo.bx((TW - 0.3), (th - 1.0), (L - 1.6), 0.05), Vector3(0, ((th / float(2)) + 0.1), 0))
		tr.put("b", Geo.prism([[(-hl + 0.3), (th - 0.7)], [(hl - 0.5), (th - 0.7)], [(hl - 0.3), (th + 0.12)], [(-hl + 0.2), (th + 0.12)]], 0.14, 0.04), Vector3((s * ((TW / float(2)) + 0.03)), 0, 0))
		tr.put("a", Geo.bx((TW + 0.2), 0.12, (L - 0.7), 0.04), Vector3(0, (th + 0.1), -0.05))
		if (v == 0):
			tr.put("hz", Geo.bx((TW + 0.24), 0.3, 0.14, 0.02), Vector3(0, (th - 0.1), (hl - 0.25)), Vector3(-0.5, 0, 0))
		Geo.decal(tr, ("n" + _s((6 if v else 2))), Vector3((s * ((TW / float(2)) + 0.11)), (th - 0.28), (-hl + 1.4)), Vector3(0, ((s * PI) / float(2)), 0), 0.4, 0.52)
		tr.mount("plate", Vector3((s * ((TW / float(2)) + 0.12)), (th * 0.55), 0.3))
	n.noz = []
	for s in [1.0, -1.0]:
		hull.put("c", Geo.cyl_z(0.5, 0.62, 0.9, 12), Vector3(((s * HW) * 0.26), 1.35, (-hl - 0.2)))
		hull.put("k", Geo.cyl_z(0.42, 0.52, 0.92, 12), Vector3(((s * HW) * 0.26), 1.35, (-hl - 0.22)))
		n.noz.append(hull.mount(("noz" + _s(s)), Vector3(((s * HW) * 0.26), 1.35, (-hl - 0.6)), Vector3(0, 0, 0)))
	Geo.decal(hull, ("mk" + _s(def.mk)), Vector3(0, 1.15, (hl - 0.3)), Vector3(-0.6, 0, 0), 1.1, 0.42)
	n.anim = { "type": "tank" }
	n.thr = []
	return n

static func gen_model(def):
	var v = def.m.v
	var n = Geo.N.new("gen")
	if (v == 0):
		n.put("c", Geo.cyl_x(0.5, 1.6, 12), Vector3(0, 0, -0.3))
		n.put("d", Geo.tor(0.52, 0.05, 6, 14), Vector3(0.4, 0, -0.3), Vector3(0, (PI / float(2)), 0))
		n.put("d", Geo.tor(0.52, 0.05, 6, 14), Vector3(-0.4, 0, -0.3), Vector3(0, (PI / float(2)), 0))
		n.put("g", Geo.cyl_x(0.2, 1.64, 8), Vector3(0, 0, -0.3))
	elif (v == 1):
		n.put("c", Geo.bx(1.9, 1.0, 0.8, 0.06), Vector3(0, 0, -0.35))
		for _i in _rng(0, 7, 1):
			var i = _i
			n.put("d", Geo.bx(0.06, 1.1, 0.9, 0.01), Vector3((-0.75 + (i * 0.25)), 0, -0.4))
		n.put("g", Geo.bx(1.5, 0.08, 0.05, 0.01), Vector3(0, -0.3, -0.78))
	elif (v == 2):
		n.put("c", Geo.bx(1.1, 0.7, 0.6, 0.1), Vector3(0, 0, -0.3))
		for s in [1.0, -1.0]:
			n.put("d", Geo.tor(0.3, 0.06, 6, 12, PI), Vector3((s * 0.55), 0, -0.35), Vector3(0, 0, ((-PI / float(2)) if (s > 0) else (PI / float(2)))))
		n.put("g", Geo.bx(0.5, 0.2, 0.05, 0.02), Vector3(0, 0, -0.62))
	else:
		n.put("c", Geo.ico(0.62, 1), Vector3(0, 0, -0.3), Vector3(0, 0, 0), [1.3, 1, 0.9])
		n.put("d", Geo.tor(0.66, 0.06, 6, 20), Vector3(0, 0, -0.5), Vector3(0, 0, 0))
		n.put("g", Geo.cyl_z(0.3, 0.3, 0.1, 12), Vector3(0, 0, -0.84))
		for s in [1.0, -1.0]:
			n.put("g", Geo.bx(0.05, 0.5, 0.05, 0.01), Vector3((s * 0.86), 0, -0.3))
	return n

static func nozzle(n, p, r, v, noz):
	if (v == 1):
		n.put("c", Geo.bx((r * 2.1), (r * 2.1), 0.9, 0.06), Vector3(p[0], p[1], (p[2] - 0.3)))
		n.put("k", Geo.bx((r * 1.7), (r * 1.7), 0.92, 0.02), Vector3(p[0], p[1], (p[2] - 0.32)))
		Geo.vent(n, "d", Vector3(p[0], p[1], (p[2] - 0.76)), (r * 1.6), (r * 1.5), 3, 0)
	elif (v == 2):
		n.put("c", Geo.cyl_z((r * 0.7), r, 1.0, 10), Vector3(p[0], p[1], (p[2] - 0.35)))
		for _i in _rng(0, 4, 1):
			var i = _i
			var a = (((i * PI) / float(2)) + (PI / float(4)))
			n.put("d", Geo.bx((r * 0.9), 0.06, 0.7, 0.01), Vector3((p[0] + ((cos(a) * r) * 0.86)), (p[1] + ((sin(a) * r) * 0.86)), (p[2] - 0.75)), Vector3(0, 0, (a + (PI / float(2)))))
		n.put("k", Geo.cyl_z((r * 0.6), (r * 0.75), 0.3, 10), Vector3(p[0], p[1], (p[2] - 0.75)))
	elif (v == 3):
		n.put("c", Geo.cyl_z((r * 0.8), (r * 0.8), 0.7, 12), Vector3(p[0], p[1], (p[2] - 0.3)))
		var _t2 = [0.5, 0.75, 1.0]
		for i in _t2.size():
			var z = _t2[i]
			n.put(("g" if (i == 1) else "d"), Geo.tor((r * (1.0 + (i * 0.08))), 0.04, 5, 18), Vector3(p[0], p[1], (p[2] - z)))
		n.put("k", Geo.cyl_z((r * 0.6), (r * 0.6), 0.1, 12), Vector3(p[0], p[1], (p[2] - 0.66)))
	else:
		n.put("c", Geo.cyl_z((r * 0.6), r, 0.9, 12), Vector3(p[0], p[1], (p[2] - 0.35)))
		n.put("k", Geo.cyl_z((r * 0.5), (r * 0.86), 0.3, 12), Vector3(p[0], p[1], (p[2] - 0.68)))
		n.put("d", Geo.tor((r * 0.72), 0.04, 5, 14), Vector3(p[0], p[1], (p[2] - 0.1)))
	noz.append(n.mount("noz", Vector3(p[0], p[1], (p[2] - 0.85))))

static func booster_model(def):
	var n = Geo.N.new("booster")
	var c = def.m.n
	var v = def.m.v
	n.noz = []
	n.fv = v
	n.put("c", Geo.bx((2.6 if (c > 2) else 2.0), 0.9, 0.5, 0.08), Vector3(0, 0, 0))
	if (c == 2):
		for s in [1.0, -1.0]:
			nozzle(n, [(s * 0.62), 0, -0.2], 0.42, v, n.noz)
	elif (c == 3):
		nozzle(n, [0, 0.1, -0.25], 0.46, v, n.noz)
		for s in [1.0, -1.0]:
			nozzle(n, [(s * 0.95), -0.1, -0.2], 0.34, v, n.noz)
	else:
		for s in [1.0, -1.0]:
			nozzle(n, [(s * 0.55), 0.3, -0.2], 0.36, v, n.noz)
			nozzle(n, [(s * 1.0), -0.38, -0.2], 0.3, v, n.noz)
	return n

static func fcs_model(def):
	var v = def.m.v
	var n = Geo.N.new("fcs")
	if (v == 0):
		n.put("c", Geo.bx(0.4, 0.34, 0.6, 0.04), Vector3(0, 0.2, 0))
		n.put("d", Geo.cyl_z(0.11, 0.13, 0.14, 8), Vector3(0, 0.2, 0.34))
		n.put("g", Geo.cyl_z(0.07, 0.07, 0.03, 8), Vector3(0, 0.2, 0.42))
	elif (v == 1):
		n.put("c", Geo.bx(0.56, 0.28, 0.5, 0.05), Vector3(0, 0.18, 0))
		for s in [1.0, -1.0]:
			n.put("g", Geo.cyl_z(0.06, 0.06, 0.04, 8), Vector3((s * 0.14), 0.18, 0.27))
		n.put("b", Geo.prism([[-0.25, 0.3], [0.2, 0.3], [-0.3, 0.6]], 0.05, 0.01))
	elif (v == 2):
		n.put("c", Geo.bx(0.7, 0.42, 0.2, 0.04), Vector3(0, 0.26, 0.1), Vector3(-0.2, 0, 0))
		n.put("w", Geo.bx(0.6, 0.32, 0.04, 0.01), Vector3(0, 0.27, 0.22), Vector3(-0.2, 0, 0))
		for _i in _rng(0, 3, 1):
			var i = _i
			n.put("g", Geo.bx(0.05, 0.05, 0.03, 0.01), Vector3((-0.2 + (i * 0.2)), 0.3, 0.25), Vector3(-0.2, 0, 0))
		n.put("d", Geo.cyl(0.02, 0.02, 0.6, 5), Vector3(0.3, 0.6, -0.05))
	else:
		n.put("c", Geo.cyl_z(0.14, 0.14, 1.1, 10), Vector3(0, 0.24, 0.2))
		n.put("d", Geo.cyl_z(0.18, 0.18, 0.16, 10), Vector3(0, 0.24, 0.72))
		n.put("g", Geo.cyl_z(0.11, 0.11, 0.03, 10), Vector3(0, 0.24, 0.81))
		n.put("c", Geo.bx(0.3, 0.2, 0.4, 0.03), Vector3(0, 0.1, 0))
	return n

static func hand_rifle(d):
	var v = d.m.v
	var n = Geo.N.new("w")
	n.put("c", Geo.bx(0.4, 0.62, (2.3 + (v * 0.3)), 0.06), Vector3(0, 0.42, 0.5))
	n.put("k", Geo.bx(0.22, 0.5, 0.3, 0.04), Vector3(0, 0, 0), Vector3(0.2, 0, 0))
	n.put("a", Geo.bx(0.46, 0.4, 1.0, 0.05), Vector3(0, 0.5, 1.2))
	n.put("d", Geo.cyl_z((0.09 + (v * 0.03)), (0.09 + (v * 0.03)), (2.0 + (v * 0.5)), 8), Vector3(0, 0.5, (2.6 + (v * 0.3))))
	n.put("c", Geo.cyl_z((0.15 + (v * 0.03)), (0.15 + (v * 0.03)), 0.4, 8), Vector3(0, 0.5, (3.45 + (v * 0.55))))
	n.put("c", Geo.bx(0.3, 0.75, 0.42, 0.04), Vector3(0, -0.15, 0.85), Vector3(0.2, 0, 0))
	n.put("c", Geo.prism([[-1.5, 0.15], [-0.6, 0.15], [-0.6, 0.7], [-1.5, 0.55]], 0.26, 0.04))
	if v:
		n.put("c", Geo.cyl_z(0.12, 0.12, 0.9, 8), Vector3(0, 0.92, 0.5))
		n.put("g", Geo.cyl_z(0.08, 0.08, 0.02, 8), Vector3(0, 0.92, 0.96))
		n.put("b", Geo.bx(0.5, 0.2, 1.3, 0.03), Vector3(0, 0.3, 1.9))
	else:
		n.put("hz", Geo.bx(0.42, 0.14, 0.3, 0.02), Vector3(0, 0.74, 0.1))
		Geo.rod(n, "d", Vector3(0, 0.78, 0.6), Vector3(0, 0.78, 1.6), 0.04)
	n.mount("mz", Vector3(0, 0.5, (3.7 + (v * 0.6))))
	return n

static func hand_smg(d):
	var n = Geo.N.new("w")
	n.put("c", Geo.bx(0.36, 0.55, 1.5, 0.06), Vector3(0, 0.38, 0.4))
	n.put("k", Geo.bx(0.2, 0.5, 0.28, 0.04), Vector3(0, 0, 0), Vector3(0.2, 0, 0))
	n.put("b", Geo.bx(0.4, 0.34, 0.7, 0.04), Vector3(0, 0.45, 0.9))
	n.put("d", Geo.cyl_z(0.07, 0.07, 0.9, 8), Vector3(0, 0.42, 1.55))
	n.put("c", Geo.cyl_z(0.14, 0.14, 0.5, 8), Vector3(0, 0.42, 1.75))
	n.put("c", Geo.bx(0.24, 1.0, 0.3, 0.03), Vector3(0, -0.3, 0.6))
	n.put("a", Geo.prism([[-0.2, 0.66], [0.9, 0.66], [0.7, 0.86], [-0.1, 0.86]], 0.2, 0.03))
	n.mount("mz", Vector3(0, 0.42, 2.05))
	return n

static func hand_shotgun(d):
	var n = Geo.N.new("w")
	n.put("c", Geo.bx(0.5, 0.6, 1.6, 0.06), Vector3(0, 0.4, 0.3))
	n.put("k", Geo.bx(0.22, 0.5, 0.3, 0.04), Vector3(0, 0, 0), Vector3(0.2, 0, 0))
	for s in [1.0, -1.0]:
		n.put("d", Geo.cyl_z(0.15, 0.15, 1.9, 10), Vector3((s * 0.17), 0.5, 2.0))
	n.put("c", Geo.bx(0.7, 0.3, 0.3, 0.03), Vector3(0, 0.5, 2.8))
	n.put("a", Geo.bx(0.56, 0.36, 0.9, 0.05), Vector3(0, 0.24, 1.6))
	n.put("hz", Geo.bx(0.52, 0.16, 0.5, 0.02), Vector3(0, 0.72, 0.2))
	n.put("c", Geo.prism([[-1.2, 0.1], [-0.5, 0.15], [-0.5, 0.65], [-1.2, 0.5]], 0.3, 0.04))
	n.mount("mz", Vector3(0, 0.5, 3.0))
	return n

static func hand_pistol(d):
	var n = Geo.N.new("w")
	n.put("c", Geo.bx(0.42, 0.6, 1.3, 0.07), Vector3(0, 0.42, 0.55))
	n.put("k", Geo.bx(0.24, 0.55, 0.32, 0.04), Vector3(0, 0, 0), Vector3(0.2, 0, 0))
	n.put("a", Geo.bx(0.46, 0.3, 1.4, 0.05), Vector3(0, 0.66, 0.6))
	n.put("d", Geo.cyl_z(0.17, 0.17, 0.5, 10), Vector3(0, 0.52, 1.4))
	n.put("k", Geo.cyl_z(0.11, 0.11, 0.52, 8), Vector3(0, 0.52, 1.42))
	n.mount("mz", Vector3(0, 0.52, 1.7))
	return n

static func hand_flamer(d):
	var n = Geo.N.new("w")
	n.put("c", Geo.bx(0.4, 0.5, 1.6, 0.05), Vector3(0, 0.38, 0.4))
	n.put("k", Geo.bx(0.22, 0.5, 0.3, 0.04), Vector3(0, 0, 0), Vector3(0.2, 0, 0))
	n.put("b", Geo.cyl_z(0.34, 0.34, 1.2, 12), Vector3(0, -0.1, 0.9))
	n.put("d", Geo.sph(0.34, 10, 8), Vector3(0, -0.1, 1.5))
	n.put("d", Geo.sph(0.34, 10, 8), Vector3(0, -0.1, 0.3))
	n.put("d", Geo.cyl_z(0.1, 0.1, 1.6, 8), Vector3(0, 0.42, 2.0))
	n.put("c", Geo.cyl_z(0.2, 0.12, 0.4, 8), Vector3(0, 0.42, 2.9))
	n.put("g", Geo.sph(0.06, 6, 5), Vector3(0, 0.2, 2.95))
	Geo.rod(n, "d", Vector3(0, 0.1, 1.4), Vector3(0, 0.4, 1.8), 0.04)
	n.put("hz", Geo.bx(0.42, 0.2, 0.4, 0.02), Vector3(0, 0.66, 0.3))
	n.mount("mz", Vector3(0, 0.42, 3.15))
	return n

static func hand_glauncher(d):
	var n = Geo.N.new("w")
	n.put("c", Geo.bx(0.5, 0.6, 1.4, 0.06), Vector3(0, 0.4, 0.2))
	n.put("k", Geo.bx(0.22, 0.5, 0.3, 0.04), Vector3(0, 0, 0), Vector3(0.2, 0, 0))
	n.put("a", Geo.cyl_z(0.5, 0.5, 0.7, 12), Vector3(0, 0.3, 1.1))
	for _i in _rng(0, 6, 1):
		var i = _i
		var a = (((i / float(6)) * PI) * 2)
		n.put("k", Geo.cyl_z(0.12, 0.12, 0.05, 8), Vector3((cos(a) * 0.3), (0.3 + (sin(a) * 0.3)), 1.46))
	n.put("d", Geo.cyl_z(0.24, 0.24, 1.2, 10), Vector3(0, 0.6, 1.9))
	n.put("k", Geo.cyl_z(0.19, 0.19, 1.22, 10), Vector3(0, 0.6, 1.92))
	n.put("c", Geo.prism([[-1.2, 0.1], [-0.5, 0.15], [-0.5, 0.65], [-1.2, 0.5]], 0.3, 0.04))
	n.mount("mz", Vector3(0, 0.6, 2.55))
	return n

static func hand_bazooka(d):
	var n = Geo.N.new("w")
	n.put("a", Geo.cyl_z(0.42, 0.42, 4.6, 12), Vector3(0, 0.7, 0.6))
	n.put("k", Geo.cyl_z(0.34, 0.34, 4.64, 12), Vector3(0, 0.7, 0.6))
	n.put("c", Geo.cyl_z(0.5, 0.5, 0.5, 12), Vector3(0, 0.7, 2.7))
	n.put("c", Geo.cyl_z(0.56, 0.44, 0.6, 12), Vector3(0, 0.7, -1.6))
	n.put("k", Geo.bx(0.24, 0.6, 0.32, 0.04), Vector3(0, 0.05, 0), Vector3(0.2, 0, 0))
	n.put("c", Geo.bx(0.3, 0.3, 0.9, 0.04), Vector3(0, 0.3, 0.3))
	n.put("b", Geo.bx(0.5, 0.5, 0.9, 0.05), Vector3(0.42, 0.9, 0.2))
	n.put("g", Geo.cyl_z(0.08, 0.08, 0.03, 8), Vector3(0.42, 0.95, 0.66))
	n.put("hz", Geo.cyl_z(0.44, 0.44, 0.3, 12), Vector3(0, 0.7, 1.9))
	Geo.decal(n, "warn", Vector3(-0.43, 0.7, 0.4), Vector3(0, (-PI / float(2)), 0), 0.9, 0.42)
	n.mount("mz", Vector3(0, 0.7, 3.0))
	return n

static func hand_pulsegun(d):
	var n = Geo.N.new("w")
	n.put("c", Geo.bx(0.4, 0.55, 1.4, 0.1), Vector3(0, 0.38, 0.4))
	n.put("k", Geo.bx(0.2, 0.5, 0.28, 0.04), Vector3(0, 0, 0), Vector3(0.2, 0, 0))
	for s in [1.0, -1.0]:
		n.put("a", Geo.prism([[0.6, 0.2], [2.2, 0.32], [2.2, 0.52], [0.6, 0.6]], 0.1, 0.03), Vector3((s * 0.2), 0, 0))
	n.put("g", Geo.bx(0.1, 0.1, 1.3, 0.02), Vector3(0, 0.42, 1.5))
	for z in [1.0, 1.4, 1.8]:
		n.put("d", Geo.bx(0.5, 0.06, 0.06, 0.01), Vector3(0, 0.42, z))
	n.mount("mz", Vector3(0, 0.42, 2.25))
	return n

static func hand_sprayer(d):
	var n = Geo.N.new("w")
	n.put("c", Geo.bx(0.42, 0.5, 1.5, 0.05), Vector3(0, 0.38, 0.4))
	n.put("k", Geo.bx(0.22, 0.5, 0.3, 0.04), Vector3(0, 0, 0), Vector3(0.2, 0, 0))
	n.put("cer", Geo.cyl(0.36, 0.36, 0.9, 12), Vector3(0, 1.0, 0.3))
	n.put("d", Geo.cyl(0.38, 0.38, 0.08, 12), Vector3(0, 1.45, 0.3))
	n.put("hz", Geo.cyl(0.37, 0.37, 0.2, 12), Vector3(0, 0.8, 0.3))
	n.put("d", Geo.cyl_z(0.16, 0.2, 1.4, 10), Vector3(0, 0.42, 1.8))
	n.put("k", Geo.cyl_z(0.24, 0.16, 0.3, 10), Vector3(0, 0.42, 2.6))
	n.mount("mz", Vector3(0, 0.42, 2.8))
	return n

static func hand_lrifle(d):
	var n = Geo.N.new("w")
	n.put("c", Geo.bx(0.42, 0.6, 1.8, 0.08), Vector3(0, 0.42, 0.3))
	n.put("k", Geo.bx(0.22, 0.5, 0.3, 0.04), Vector3(0, 0, 0), Vector3(0.2, 0, 0))
	n.put("a", Geo.prism([[1.0, 0.56], [3.4, 0.5], [3.4, 0.62], [1.0, 0.76]], 0.34, 0.04))
	n.put("a", Geo.prism([[1.0, 0.36], [3.4, 0.42], [3.4, 0.3], [1.0, 0.1]], 0.34, 0.04))
	n.put("g", Geo.bx(0.08, 0.06, 2.2, 0.01), Vector3(0, 0.46, 2.25))
	for z in [1.4, 2.0, 2.6]:
		n.put("d", Geo.bx(0.44, 0.5, 0.08, 0.02), Vector3(0, 0.44, z))
	n.put("c", Geo.cyl_z(0.11, 0.11, 0.8, 8), Vector3(0, 0.95, 0.4))
	n.put("g", Geo.cyl_z(0.07, 0.07, 0.02, 8), Vector3(0, 0.95, 0.81))
	n.put("b", Geo.bx(0.5, 0.36, 0.7, 0.05), Vector3(0, 0.3, -0.4))
	n.mount("mz", Vector3(0, 0.46, 3.5))
	return n

static func hand_arcgun(d):
	var n = Geo.N.new("w")
	n.put("c", Geo.bx(0.46, 0.6, 1.5, 0.08), Vector3(0, 0.42, 0.3))
	n.put("k", Geo.bx(0.22, 0.5, 0.3, 0.04), Vector3(0, 0, 0), Vector3(0.2, 0, 0))
	for _i in _rng(0, 3, 1):
		var i = _i
		var a = ((((i / float(3)) * PI) * 2) + (PI / float(2)))
		Geo.rod(n, "d", Vector3((cos(a) * 0.22), (0.45 + (sin(a) * 0.22)), 1.0), Vector3((cos(a) * 0.3), (0.45 + (sin(a) * 0.3)), 2.5), 0.04)
		n.put("g", Geo.sph(0.07, 6, 5), Vector3((cos(a) * 0.3), (0.45 + (sin(a) * 0.3)), 2.5))
	for z in [1.3, 1.7, 2.1]:
		n.put("b", Geo.tor(0.3, 0.05, 5, 14), Vector3(0, 0.45, z))
	n.put("cer", Geo.cyl_z(0.14, 0.14, 0.7, 8), Vector3(0, 0.45, 1.3))
	n.mount("mz", Vector3(0, 0.45, 2.6))
	return n

static func hand_plasma(d):
	var n = Geo.N.new("w")
	n.put("c", Geo.bx(0.5, 0.66, 1.6, 0.1), Vector3(0, 0.42, 0.2))
	n.put("k", Geo.bx(0.22, 0.5, 0.3, 0.04), Vector3(0, 0, 0), Vector3(0.2, 0, 0))
	n.put("g", Geo.sph(0.34, 12, 10), Vector3(0, 0.5, 1.4))
	n.put("d", Geo.tor(0.38, 0.06, 6, 16), Vector3(0, 0.5, 1.4), Vector3(0, (PI / float(2)), 0))
	n.put("d", Geo.tor(0.38, 0.06, 6, 16), Vector3(0, 0.5, 1.4), Vector3((PI / float(2)), 0, 0))
	n.put("a", Geo.cyl_z(0.3, 0.36, 1.1, 8), Vector3(0, 0.5, 2.3))
	n.put("k", Geo.cyl_z(0.22, 0.22, 1.12, 8), Vector3(0, 0.5, 2.32))
	for _i in _rng(0, 4, 1):
		var i = _i
		n.put("b", Geo.bx(0.06, 0.9, 0.7, 0.01), Vector3(0, 0.5, 2.2), Vector3(0, 0, ((i * PI) / float(4))))
	n.mount("mz", Vector3(0, 0.5, 2.95))
	return n

static func hand_linear(d):
	var n = Geo.N.new("w")
	n.put("c", Geo.bx(0.44, 0.62, 2.0, 0.07), Vector3(0, 0.42, 0.3))
	n.put("k", Geo.bx(0.22, 0.5, 0.3, 0.04), Vector3(0, 0, 0), Vector3(0.2, 0, 0))
	for s in [1.0, -1.0]:
		n.put("a", Geo.bx(0.1, 0.4, 3.0, 0.03), Vector3((s * 0.17), 0.5, 2.6))
	for _i in _rng(0, 6, 1):
		var i = _i
		n.put("d", Geo.bx(0.5, 0.5, 0.08, 0.02), Vector3(0, 0.5, (1.4 + (i * 0.5))))
	n.put("g", Geo.bx(0.06, 0.1, 2.6, 0.01), Vector3(0, 0.5, 2.6))
	n.put("b", Geo.bx(0.5, 0.4, 0.8, 0.05), Vector3(0, 0.1, 1.0))
	n.put("c", Geo.cyl_z(0.12, 0.12, 1.0, 8), Vector3(0, 0.96, 0.4))
	n.put("g", Geo.cyl_z(0.08, 0.08, 0.02, 8), Vector3(0, 0.96, 0.91))
	n.put("c", Geo.prism([[-1.4, 0.15], [-0.7, 0.15], [-0.7, 0.7], [-1.4, 0.6]], 0.26, 0.04))
	n.mount("mz", Vector3(0, 0.5, 4.15))
	return n

static func hand_machete(d):
	var n = Geo.N.new("w")
	n.put("k", Geo.bx(0.24, 0.3, 0.9, 0.05), Vector3(0, 0, 0))
	n.put("c", Geo.bx(0.5, 0.6, 0.3, 0.05), Vector3(0, 0, 0.55))
	n.put("d", Geo.prism([[0.6, -0.4], [3.8, -0.4], [4.6, 0.1], [4.2, 0.36], [0.6, 0.36]], 0.12, 0.04))
	n.put("g", Geo.bx(0.05, 0.05, 3.4, 0.01), Vector3(0, -0.42, 2.3))
	n.put("hz", Geo.bx(0.16, 0.2, 0.6, 0.02), Vector3(0, 0.3, 1.0))
	Geo.bolts(n, "c", [Vector3(0.07, 0, 1.0), Vector3(0.07, 0, 1.8), Vector3(0.07, 0, 2.6)], 0.07, "x")
	n.mount("mz", Vector3(0, 0, 4.4))
	n.mount("tip", Vector3(0, 0, 4.4))
	return n

static func hand_eblade(d):
	var n = Geo.N.new("w")
	n.put("k", Geo.bx(0.24, 0.3, 0.8, 0.05), Vector3(0, 0, 0))
	n.put("a", Geo.prism([[0.3, -0.36], [1.5, -0.2], [1.5, 0.2], [0.3, 0.36]], 0.5, 0.06))
	for s in [1.0, -1.0]:
		n.put("d", Geo.prism([[1.4, 0.1], [2.1, 0.22], [2.1, 0.34], [1.4, 0.3]], 0.1, 0.02), Vector3(0, (0 if (s > 0) else -0.44), 0))
	n.put("g", Geo.cyl_z(0.1, 0.1, 0.1, 8), Vector3(0, 0, 1.56))
	var bl = n.child("blade", Vector3(0, 0, 1.6))
	bl.put("g", Geo.prism([[0, -0.2], [5.6, -0.05], [6.2, 0], [5.6, 0.05], [0, 0.2]], 0.07, 0.02))
	bl.g.visible = false
	n.blade = bl.g
	n.mount("mz", Vector3(0, 0, 4.0))
	n.mount("tip", Vector3(0, 0, 7.6))
	return n

static func hand_pile(d):
	var n = Geo.N.new("w")
	n.put("k", Geo.bx(0.24, 0.3, 0.8, 0.05), Vector3(0, 0, 0))
	n.put("a", Geo.bx(0.8, 0.9, 2.6, 0.1), Vector3(0, 0.2, 0.9))
	n.put("b", Geo.bx(0.86, 0.3, 1.6, 0.05), Vector3(0, 0.55, 1.0))
	n.put("c", Geo.cyl_z(0.3, 0.3, 0.8, 10), Vector3(0, 0.2, 2.5))
	for s in [1.0, -1.0]:
		Geo.piston(n, Vector3((s * 0.5), 0.2, 0.2), Vector3((s * 0.5), 0.2, 2.0), 0.09)
	var sp = n.child("spike", Vector3(0, 0.2, 1.4))
	sp.put("d", Geo.cyl_z(0.17, 0.17, 2.6, 10), Vector3(0, 0, 1.0))
	sp.put("d", Geo.cone(0.17, 0.7, 10), Vector3(0, 0, 2.65), Vector3((PI / float(2)), 0, 0))
	n.spike = sp.g
	n.put("hz", Geo.bx(0.82, 0.2, 0.4, 0.02), Vector3(0, -0.2, 2.0))
	Geo.decal(n, "warn", Vector3(0.41, 0.2, 0.9), Vector3(0, (PI / float(2)), 0), 0.9, 0.42)
	n.mount("mz", Vector3(0, 0.2, 3.6))
	n.mount("tip", Vector3(0, 0.2, 4.6))
	return n

static func hand_saw(d):
	var n = Geo.N.new("w")
	n.put("k", Geo.bx(0.24, 0.3, 0.8, 0.05), Vector3(0, 0, 0))
	n.put("b", Geo.bx(0.7, 0.9, 1.3, 0.08), Vector3(0, 0.2, 0.5))
	n.put("d", Geo.cyl_x(0.3, 0.8, 10), Vector3(0, 0.2, 0.2))
	n.put("c", Geo.prism([[1.0, -0.22], [4.0, -0.3], [4.4, 0.2], [4.0, 0.7], [1.0, 0.62]], 0.14, 0.04))
	n.put("d", Geo.prism([[0.9, -0.34], [4.1, -0.44], [4.6, 0.2], [4.1, 0.84], [0.9, 0.74]], 0.07, 0.02))
	for _i in _rng(0, 9, 1):
		var i = _i
		n.put("d", Geo.cone(0.09, 0.22, 4), Vector3(0, -0.5, (1.2 + (i * 0.34))), Vector3(PI, 0, 0))
		n.put("d", Geo.cone(0.09, 0.22, 4), Vector3(0, 0.9, (1.2 + (i * 0.34))))
	n.put("hz", Geo.bx(0.72, 0.2, 0.5, 0.02), Vector3(0, 0.7, 0.5))
	n.mount("mz", Vector3(0, 0.2, 4.0))
	n.mount("tip", Vector3(0, 0.2, 4.6))
	return n

static func hand_shield(d):
	var n = Geo.N.new("w")
	n.put("k", Geo.bx(0.24, 0.3, 0.7, 0.05), Vector3(0, 0, 0))
	n.put("c", Geo.bx(0.7, 0.9, 0.5, 0.08), Vector3(0, 0.2, 0.6))
	n.put("d", Geo.tor(0.5, 0.07, 6, 16), Vector3(0, 0.2, 0.9))
	n.put("g", Geo.cyl_z(0.3, 0.3, 0.06, 12), Vector3(0, 0.2, 0.9))
	for _i in _rng(0, 4, 1):
		var i = _i
		var a = (((i * PI) / float(2)) + (PI / float(4)))
		n.put("a", Geo.prism([[0.5, -0.12], [1.3, -0.06], [1.3, 0.06], [0.5, 0.12]], 0.1, 0.02, "z"), Vector3(0, 0.2, 0.85), Vector3(0, 0, a))
	n.mount("mz", Vector3(0, 0.2, 1.0))
	return n

static func tubes(n, cols, rows, cx, cy, z, sp, r, tipMat = "b"):
	for _i in _rng(0, cols, 1):
		var i = _i
		for _j in _rng(0, rows, 1):
			var j = _j
			var x = (cx + ((i - ((cols - 1) / float(2))) * sp))
			var y = (cy + ((j - ((rows - 1) / float(2))) * sp))
			n.put("k", Geo.cyl_z(r, r, 0.16, 8), Vector3(x, y, z))
			n.put(tipMat, Geo.cone((r * 0.72), (r * 1.6), 8), Vector3(x, y, (z - 0.05)), Vector3((PI / float(2)), 0, 0))

static func back_mbox(d, s):
	var n = Geo.N.new("bk")
	var c = d.m.c
	var r = d.m.r
	var w = ((c * 0.62) + 0.3)
	var h = ((r * 0.62) + 0.3)
	n.put("c", Geo.bx(0.4, 0.5, 0.9, 0.05), Vector3(0, 0.3, 0.3))
	var pv = n.child("pv", Vector3(0, 0.95, 0.5), (Vector3(-1.15, 0, 0) if d.m.get("vert", 0) else Vector3(0, 0, 0)))
	pv.put("a", Geo.bx(w, h, 2.3, 0.07), Vector3(0, 0, 0.3))
	pv.put("b", Geo.bx((w + 0.06), (h + 0.06), 0.16, 0.03), Vector3(0, 0, 1.36))
	pv.put("c", Geo.bx((w * 0.6), 0.2, 1.4, 0.03), Vector3(0, ((h / float(2)) + 0.06), 0.2))
	tubes(pv, c, r, 0, 0, 1.42, 0.62, 0.22)
	Geo.decal(pv, "warn", Vector3((s * ((w / float(2)) + 0.005)), 0, 0.3), Vector3(0, ((s * PI) / float(2)), 0), 1.0, 0.46)
	pv.mount("mz", Vector3(0, 0, 1.6))
	n.pv = pv.g
	n.fixed = not (not (d.m.get("vert", 0)))
	return n

static func back_swarm(d, s):
	var n = Geo.N.new("bk")
	n.put("c", Geo.bx(0.4, 0.5, 0.9, 0.05), Vector3(0, 0.3, 0.3))
	var pv = n.child("pv", Vector3(0, 1.0, 0.4), Vector3(-0.45, 0, 0))
	pv.put("a", Geo.prism([[-1.0, -0.5], [1.0, -0.5], [1.25, 0], [1.0, 0.5], [-1.0, 0.5], [-1.25, 0]], 1.8, 0.08, "z"), Vector3(0, 0, 0.3))
	for _j in _rng(0, 3, 1):
		var j = _j
		for _i in _rng(0, 4, 1):
			var i = _i
			var x = (((i - 1.5) * 0.5) + (0 if fmod(j, 2) else 0.0))
			var y = ((j - 1) * 0.3)
			pv.put("k", Geo.cyl_z(0.12, 0.12, 0.1, 6), Vector3(x, y, 1.2))
			pv.put("b", Geo.cone(0.08, 0.16, 6), Vector3(x, y, 1.18), Vector3((PI / float(2)), 0, 0))
	pv.put("b", Geo.bx(2.2, 0.1, 0.4, 0.02), Vector3(0, 0.56, 0.8))
	pv.mount("mz", Vector3(0, 0, 1.3))
	n.pv = pv.g
	n.fixed = true
	return n

static func back_guided(d, s):
	var n = Geo.N.new("bk")
	n.put("c", Geo.bx(0.4, 0.5, 0.9, 0.05), Vector3(0, 0.3, 0.3))
	var pv = n.child("pv", Vector3(0, 0.95, 0.5))
	pv.put("a", Geo.cyl_z(0.5, 0.5, 3.4, 12), Vector3(0, 0, 0.5))
	pv.put("k", Geo.cyl_z(0.42, 0.42, 3.42, 12), Vector3(0, 0, 0.52))
	pv.put("b", Geo.cone(0.34, 0.7, 10), Vector3(0, 0, 2.0), Vector3((PI / float(2)), 0, 0))
	pv.put("c", Geo.bx(0.5, 0.44, 0.8, 0.05), Vector3((s * 0.66), 0.2, 1.4))
	pv.put("g", Geo.cyl_z(0.12, 0.12, 0.04, 10), Vector3((s * 0.66), 0.2, 1.82))
	pv.put("d", Geo.cyl_x(0.3, 0.4, 10), Vector3((s * 0.6), -0.2, 0))
	pv.put("hz", Geo.cyl_z(0.52, 0.52, 0.3, 12), Vector3(0, 0, -0.6))
	pv.mount("mz", Vector3(0, 0, 2.4))
	n.pv = pv.g
	return n

static func back_cluster(d, s):
	var n = Geo.N.new("bk")
	n.put("c", Geo.bx(0.4, 0.5, 0.9, 0.05), Vector3(0, 0.3, 0.3))
	var pv = n.child("pv", Vector3(0, 1.0, 0.4), Vector3(-0.5, 0, 0))
	pv.put("a", Geo.bx(1.3, 1.3, 2.8, 0.14), Vector3(0, 0, 0.4))
	pv.put("k", Geo.cyl_z(0.5, 0.5, 0.1, 14), Vector3(0, 0, 1.78))
	pv.put("b", Geo.sph(0.42, 12, 8), Vector3(0, 0, 1.6), Vector3(0, 0, 0), [1, 1, 1.3])
	for _i in _rng(0, 4, 1):
		var i = _i
		pv.put("d", Geo.bx(1.36, 0.08, 0.08, 0.01), Vector3(0, 0, (-0.6 + (i * 0.6))))
	for _i in _rng(0, 4, 1):
		var i = _i
		pv.put("d", Geo.bx(0.08, 1.36, 0.08, 0.01), Vector3(0, 0, (-0.6 + (i * 0.6))))
	pv.mount("mz", Vector3(0, 0, 2.0))
	n.pv = pv.g
	n.fixed = true
	return n

static func back_cannon(d, s):
	var n = Geo.N.new("bk")
	n.put("c", Geo.bx(0.5, 0.7, 1.0, 0.06), Vector3(0, 0.35, 0.2))
	var pv = n.child("pv", Vector3(0, 0.95, 0.3))
	pv.put("c", Geo.bx(1.0, 1.0, 1.9, 0.1), Vector3(0, 0, 0))
	pv.put("b", Geo.cyl_x(0.6, 0.5, 14), Vector3((-s * 0.6), 0, -0.3))
	pv.put("a", Geo.cyl_z(0.42, 0.5, 1.4, 12), Vector3(0, 0, 1.5))
	pv.put("d", Geo.cyl_z(0.3, 0.34, 3.4, 12), Vector3(0, 0, 3.6))
	pv.put("c", Geo.bx(0.9, 0.7, 0.8, 0.06), Vector3(0, 0, 5.3))
	pv.put("k", Geo.cyl_z(0.26, 0.26, 0.84, 10), Vector3(0, 0, 5.32))
	for i in [1.0, -1.0]:
		pv.put("k", Geo.bx(0.1, 0.4, 0.2, 0.01), Vector3((i * 0.46), 0, 5.2))
		Geo.piston(pv, Vector3((i * 0.5), 0.3, 0.6), Vector3((i * 0.42), 0.25, 2.2), 0.07)
	pv.put("hz", Geo.cyl_z(0.36, 0.36, 0.3, 12), Vector3(0, 0, 2.6))
	Geo.decal(pv, ("mk" + _s(d.mk)), Vector3((s * 0.505), 0, 0), Vector3(0, ((s * PI) / float(2)), 0), 1.0, 0.38)
	pv.mount("mz", Vector3(0, 0, 5.8))
	n.pv = pv.g
	n.stow = 0.9
	return n

static func back_gatling(d, s):
	var n = Geo.N.new("bk")
	n.put("c", Geo.bx(0.5, 0.7, 1.0, 0.06), Vector3(0, 0.35, 0.2))
	var pv = n.child("pv", Vector3(0, 0.95, 0.3))
	pv.put("c", Geo.bx(1.0, 1.0, 1.6, 0.1), Vector3(0, 0, 0))
	pv.put("a", Geo.bx(0.7, 1.2, 1.2, 0.08), Vector3((-s * 0.8), -0.3, -0.2))
	pv.put("hz", Geo.bx(0.74, 0.2, 1.24, 0.02), Vector3((-s * 0.8), 0.2, -0.2))
	var sp = pv.child("spin", Vector3(0, 0, 0.8))
	for _i in _rng(0, 6, 1):
		var i = _i
		var a = (((i / float(6)) * PI) * 2)
		sp.put("d", Geo.cyl_z(0.085, 0.085, 3.2, 6), Vector3((cos(a) * 0.26), (sin(a) * 0.26), 1.6))
	sp.put("c", Geo.cyl_z(0.4, 0.4, 0.2, 12), Vector3(0, 0, 1.0))
	sp.put("c", Geo.cyl_z(0.4, 0.4, 0.2, 12), Vector3(0, 0, 2.4))
	sp.put("c", Geo.cyl_z(0.42, 0.42, 0.3, 12), Vector3(0, 0, 3.1))
	n.spin = sp.g
	pv.mount("mz", Vector3(0, 0, 4.1))
	n.pv = pv.g
	n.stow = 0.5
	return n

static func back_lcannon(d, s):
	var n = Geo.N.new("bk")
	n.put("c", Geo.bx(0.5, 0.7, 1.0, 0.06), Vector3(0, 0.35, 0.2))
	var pv = n.child("pv", Vector3(0, 0.95, 0.3))
	pv.put("c", Geo.bx(0.9, 1.0, 1.8, 0.14), Vector3(0, 0, 0))
	pv.put("a", Geo.prism([[0.8, 0.14], [5.4, 0.1], [5.4, 0.34], [0.8, 0.6]], 0.6, 0.06))
	pv.put("a", Geo.prism([[0.8, -0.14], [5.4, -0.1], [5.4, -0.34], [0.8, -0.6]], 0.6, 0.06))
	pv.put("g", Geo.bx(0.12, 0.1, 4.4, 0.01), Vector3(0, 0, 3.1))
	for z in [1.4, 2.4, 3.4, 4.4]:
		pv.put("d", Geo.tor((0.5 - (z * 0.03)), 0.07, 6, 16), Vector3(0, 0, z))
	for i in [1.0, -1.0]:
		pv.put("b", Geo.bx(0.16, 0.6, 1.2, 0.04), Vector3((i * 0.5), 0, -0.2))
	pv.put("g", Geo.bx(0.6, 0.06, 0.06, 0.01), Vector3(0, 0.52, -0.3))
	pv.mount("mz", Vector3(0, 0, 5.5))
	n.pv = pv.g
	n.stow = 0.9
	return n

static func back_pmortar(d, s):
	var n = Geo.N.new("bk")
	n.put("c", Geo.bx(0.5, 0.7, 1.0, 0.06), Vector3(0, 0.35, 0.2))
	var pv = n.child("pv", Vector3(0, 1.0, 0.3), Vector3(-0.6, 0, 0))
	pv.put("c", Geo.bx(1.1, 1.1, 1.2, 0.14), Vector3(0, 0, 0))
	pv.put("g", Geo.sph(0.4, 12, 8), Vector3(0, 0.3, 0))
	pv.put("a", Geo.cyl_z(0.56, 0.62, 1.8, 10), Vector3(0, 0, 1.4))
	pv.put("k", Geo.cyl_z(0.44, 0.44, 1.82, 10), Vector3(0, 0, 1.42))
	for _i in _rng(0, 6, 1):
		var i = _i
		pv.put("b", Geo.bx(0.06, 1.5, 0.9, 0.01), Vector3(0, 0, 1.2), Vector3(0, 0, ((i * PI) / float(6))))
	pv.mount("mz", Vector3(0, 0, 2.4))
	n.pv = pv.g
	n.fixed = true
	return n

static func back_railgun(d, s):
	var n = Geo.N.new("bk")
	n.put("c", Geo.bx(0.5, 0.7, 1.0, 0.06), Vector3(0, 0.35, 0.2))
	var pv = n.child("pv", Vector3(0, 0.95, 0.3))
	pv.put("c", Geo.bx(1.0, 1.1, 2.2, 0.1), Vector3(0, 0, -0.2))
	for i in [1.0, -1.0]:
		pv.put("a", Geo.bx(0.16, 0.5, 6.4, 0.04), Vector3((i * 0.22), 0, 4.0))
		pv.put("b", Geo.bx(0.3, 0.7, 0.9, 0.05), Vector3((i * 0.6), 0, 0.0))
		pv.put("g", Geo.bx(0.05, 0.4, 0.05, 0.01), Vector3((i * 0.76), 0, 0.2))
	for _i in _rng(0, 9, 1):
		var i = _i
		pv.put("d", Geo.bx(0.7, 0.62, 0.1, 0.02), Vector3(0, 0, (1.2 + (i * 0.7))))
	pv.put("c", Geo.cyl_z(0.14, 0.14, 1.4, 8), Vector3((-s * 0.5), 0.6, 0.6))
	pv.put("g", Geo.cyl_z(0.1, 0.1, 0.03, 8), Vector3((-s * 0.5), 0.6, 1.31))
	pv.put("hz", Geo.bx(0.74, 0.66, 0.3, 0.02), Vector3(0, 0, 7.0))
	pv.mount("mz", Vector3(0, 0, 7.3))
	n.pv = pv.g
	n.stow = 1.0
	return n

static func back_drones(d, s):
	var n = Geo.N.new("bk")
	n.put("c", Geo.bx(0.5, 0.7, 1.0, 0.06), Vector3(0, 0.35, 0.2))
	n.put("a", Geo.bx(1.2, 2.0, 0.7, 0.1), Vector3(0, 1.2, -0.1))
	n.drones = []
	for _i in _rng(0, 3, 1):
		var i = _i
		var dn = n.child("dock", Vector3(0, (0.55 + (i * 0.66)), 0.36))
		drone_geo(dn)
		n.drones.append(dn.g)
	n.mount("mz", Vector3(0, 1.2, 0.6))
	return n

static func back_battery(d, s):
	var n = Geo.N.new("bk")
	n.put("c", Geo.bx(1.5, 0.3, 1.0, 0.05), Vector3(0, 0.2, -0.1))
	n.put("c", Geo.bx(1.5, 0.2, 1.0, 0.05), Vector3(0, 2.1, -0.1))
	for x in [-0.45, 0, 0.45]:
		n.put("b", Geo.cyl(0.2, 0.2, 1.8, 10), Vector3(x, 1.15, -0.1))
		n.put("g", Geo.cyl(0.21, 0.21, 0.08, 10), Vector3(x, 1.6, -0.1))
		n.put("g", Geo.cyl(0.21, 0.21, 0.08, 10), Vector3(x, 0.7, -0.1))
		n.put("d", Geo.cyl(0.12, 0.12, 0.1, 8), Vector3(x, 2.24, -0.1))
	Geo.rod(n, "k", Vector3(-0.45, 2.26, -0.1), Vector3(0.45, 2.26, -0.1), 0.05)
	Geo.rod(n, "k", Vector3((s * -0.5), 0.3, 0.2), Vector3((s * -0.9), -0.5, 0.5), 0.06)
	Geo.decal(n, "warn", Vector3(0, 1.15, 0.12), Vector3(0, 0, 0), 0.9, 0.42)
	return n

static func back_radar(d, s):
	var n = Geo.N.new("bk")
	n.put("c", Geo.bx(0.6, 0.6, 0.8, 0.06), Vector3(0, 0.3, 0))
	n.put("d", Geo.cyl(0.09, 0.11, 1.6, 8), Vector3(0, 1.2, 0))
	n.put("b", Geo.bx(0.5, 0.36, 0.5, 0.05), Vector3(0, 0.85, 0.2))
	var sp = n.child("spin", Vector3(0, 2.05, 0))
	sp.put("a", Geo.sph(0.9, 16, 6, 0, (PI * 2), 0, 0.95), Vector3(0, 0.1, -0.55), Vector3((PI / float(2)), 0, 0), [1, 1, 0.5])
	sp.put("d", Geo.cyl_z(0.03, 0.03, 0.7, 5), Vector3(0, 0.1, 0.1))
	sp.put("g", Geo.sph(0.07, 6, 5), Vector3(0, 0.1, 0.46))
	sp.put("c", Geo.bx(0.2, 0.2, 0.3, 0.03), Vector3(0, 0, -0.1))
	n.spinY = sp.g
	return n

static func back_wing(d, s):
	var n = Geo.N.new("bk")
	n.put("c", Geo.bx(0.6, 0.8, 0.8, 0.08), Vector3(0, 0.3, 0))
	n.put("a", Geo.prism([[0, 0], [3.2, 1.3], [3.4, 1.0], [1.2, -0.5], [0, -0.6]], 0.14, 0.04, "z"), Vector3((s * 0.1), 0.6, -0.3), Vector3(0.2, (-0.5 if (s > 0) else (PI + 0.5)), 0))
	n.put("b", Geo.prism([[0.4, 0.1], [2.6, 1.0], [2.7, 0.85], [0.6, -0.1]], 0.2, 0.03, "z"), Vector3((s * 0.1), 0.6, -0.3), Vector3(0.2, (-0.5 if (s > 0) else (PI + 0.5)), 0))
	n.put("c", Geo.cyl_z(0.26, 0.36, 1.0, 10), Vector3((s * 0.5), 0.3, -0.7))
	n.put("k", Geo.cyl_z(0.2, 0.3, 0.3, 10), Vector3((s * 0.5), 0.3, -1.1))
	n.noz = [n.mount("noz", Vector3((s * 0.5), 0.3, -1.25))]
	return n

static func drone_geo(n):
	n.put("a", Geo.ico(0.26, 0), Vector3(0, 0, 0), Vector3(0, 0, 0), [1.3, 0.7, 1.6])
	n.put("g", Geo.sph(0.07, 6, 5), Vector3(0, 0, 0.4))
	for s in [1.0, -1.0]:
		n.put("b", Geo.prism([[-0.3, 0], [0.2, 0], [-0.5, 0.36]], 0.04, 0.01), Vector3((s * 0.3), 0, -0.1), Vector3(0, 0, (-s * 0.9)))

static func sh_flare(d, s):
	var n = Geo.N.new("sh")
	n.put("c", Geo.bx(0.7, 0.4, 0.9, 0.05), Vector3(0, 0.2, -0.2), Vector3(0.5, 0, (s * 0.3)))
	for _i in _rng(0, 3, 1):
		var i = _i
		for _j in _rng(0, 2, 1):
			var j = _j
			n.put("k", Geo.cyl(0.09, 0.09, 0.1, 6), Vector3((-0.2 + (i * 0.2)), 0.44, (-0.3 + (j * 0.3))), Vector3(0.5, 0, (s * 0.3)))
	n.put("hz", Geo.bx(0.72, 0.1, 0.92, 0.02), Vector3(0, 0.1, -0.2), Vector3(0.5, 0, (s * 0.3)))
	n.mount("mz", Vector3(0, 0.5, -0.2))
	return n

static func sh_smissile(d, s):
	var n = Geo.N.new("sh")
	n.put("a", Geo.bx(0.9, 0.7, 1.6, 0.07), Vector3(0, 0.4, 0.1))
	n.put("b", Geo.bx(0.94, 0.74, 0.12, 0.02), Vector3(0, 0.4, 0.84))
	tubes(n, 3, 1, 0, 0.4, 0.9, 0.28, 0.11)
	n.put("c", Geo.bx(0.4, 0.16, 0.8, 0.03), Vector3(0, 0.02, 0))
	n.mount("mz", Vector3(0, 0.4, 1.0))
	return n

static func sh_skirt(d, s):
	var n = Geo.N.new("sh")
	n.out = 1
	n.put("a", Geo.prism([[-1.3, 0.9], [1.3, 0.9], [1.5, -0.6], [1.0, -2.6], [-1.0, -2.6], [-1.5, -0.6]], 0.2, 0.06, "x"), Vector3((s * 0.2), 0, 0), Vector3(0, 0, (s * 0.1)))
	n.put("hz", Geo.bx(0.22, 0.3, 2.0, 0.02), Vector3((s * 0.36), -2.3, 0), Vector3(0, 0, (s * 0.1)))
	n.put("c", Geo.bx(0.3, 0.3, 0.6, 0.04), Vector3(0, 0.2, 0))
	Geo.bolts(n, "d", [Vector3((s * 0.31), 0.5, 0.9), Vector3((s * 0.31), 0.5, -0.9), Vector3((s * 0.36), -1.0, 1.1), Vector3((s * 0.36), -1.0, -1.1)], 0.08, "x")
	Geo.decal(n, "n8", Vector3((s * 0.345), -0.6, 0), Vector3(0, ((s * PI) / float(2)), (s * 0.1)), 0.7, 0.92)
	return n

static func sh_sboost(d, s):
	var n = Geo.N.new("sh")
	n.out = 1
	n.put("c", Geo.bx(0.6, 0.9, 1.2, 0.1), Vector3((s * 0.3), 0, 0))
	n.put("d", Geo.cyl_x(0.34, 0.5, 10), Vector3((s * 0.75), 0, 0))
	n.put("k", Geo.cyl_x(0.26, 0.2, 10), Vector3((s * 0.95), 0, 0))
	n.put("b", Geo.prism([[-0.6, 0.45], [0.6, 0.45], [0.2, 0.9], [-0.7, 0.8]], 0.1, 0.02), Vector3((s * 0.4), 0, 0))
	n.noz = [n.mount("noz", Vector3((s * 1.05), 0, 0), Vector3(0, ((s * -PI) / float(2)), 0))]
	return n

static func sh_emp(d, s):
	var n = Geo.N.new("sh")
	n.put("c", Geo.cyl(0.4, 0.5, 0.3, 8), Vector3(0, 0.15, 0))
	for _i in _rng(0, 3, 1):
		var i = _i
		var a = (((i / float(3)) * PI) * 2)
		Geo.rod(n, "d", Vector3((cos(a) * 0.3), 0.3, (sin(a) * 0.3)), Vector3((cos(a) * 0.5), 1.2, (sin(a) * 0.5)), 0.04)
		n.put("cer", Geo.sph(0.07, 6, 5), Vector3((cos(a) * 0.5), 1.2, (sin(a) * 0.5)))
	n.put("g", Geo.sph(0.2, 10, 8), Vector3(0, 0.8, 0))
	n.mount("mz", Vector3(0, 0.8, 0))
	return n

static func util_hook(d):
	var v = d.m.v
	var n = Geo.N.new("ut")
	n.put("c", Geo.bx(0.7, 0.6, 0.8, 0.06), Vector3(0, 0, 0.2))
	n.put("d", Geo.cyl_x((0.36 + (v * 0.06)), 0.5, 12), Vector3(0, 0.1, -0.1))
	n.put("k", Geo.cyl_x(0.3, 0.52, 12), Vector3(0, 0.1, -0.1))
	n.put("c", Geo.cyl_z(0.14, 0.14, 0.7, 8), Vector3(0, 0, 0.8))
	var hk = n.child("claw", Vector3(0, 0, 1.2))
	hook_geo(hk, v)
	n.claw = hk.g
	if v:
		n.put("hz", Geo.bx(0.72, 0.16, 0.5, 0.02), Vector3(0, 0.3, 0.3))
	n.mount("mz", Vector3(0, 0, 1.2))
	return n

static func util_nanite(d):
	var n = Geo.N.new("ut")
	n.put("c", Geo.bx(0.8, 0.5, 0.5, 0.05), Vector3(0, 0, 0.1))
	for s in [1.0, -1.0]:
		n.put("cer", Geo.cyl(0.17, 0.17, 0.8, 10), Vector3((s * 0.22), 0.1, 0.42))
		n.put("g", Geo.cyl(0.18, 0.18, 0.1, 10), Vector3((s * 0.22), 0.3, 0.42))
		n.put("d", Geo.cyl(0.1, 0.1, 0.1, 8), Vector3((s * 0.22), 0.54, 0.42))
	return n

static func util_barrier(d):
	var n = Geo.N.new("ut")
	n.put("c", Geo.cyl_z(0.4, 0.46, 0.4, 12), Vector3(0, 0, 0.2))
	n.put("d", Geo.tor(0.4, 0.06, 6, 16), Vector3(0, 0, 0.42))
	n.put("g", Geo.sph(0.26, 12, 8, 0, (PI * 2), 0, (PI / float(2))), Vector3(0, 0, 0.4), Vector3((PI / float(2)), 0, 0))
	return n

static func util_cloak(d):
	var n = Geo.N.new("ut")
	n.put("c", Geo.bx(0.8, 0.5, 0.4, 0.08), Vector3(0, 0, 0.1))
	for _i in _rng(0, 3, 1):
		var i = _i
		for _j in _rng(0, 2, 1):
			var j = _j
			n.put("w", Geo.bx(0.2, 0.18, 0.06, 0.02), Vector3((-0.24 + (i * 0.24)), (-0.1 + (j * 0.22)), 0.32))
	n.put("g", Geo.bx(0.7, 0.03, 0.03, 0.01), Vector3(0, 0.01, 0.34))
	return n

static func util_burst(d):
	var n = Geo.N.new("ut")
	n.put("c", Geo.cyl_z(0.44, 0.5, 0.5, 8), Vector3(0, 0, 0.2))
	for z in [0.1, 0.25, 0.4]:
		n.put("d", Geo.tor(0.5, 0.05, 5, 16), Vector3(0, 0, z))
	n.put("g", Geo.cyl_z(0.3, 0.3, 0.06, 12), Vector3(0, 0, 0.47))
	n.put("hz", Geo.bx(0.5, 0.14, 0.3, 0.02), Vector3(0, 0.5, 0.15))
	return n

static func hook_geo(n, v):
	n.put("d", Geo.cyl_z(0.1, 0.1, 0.5, 8), Vector3(0, 0, 0.1))
	for _i in _rng(0, 3, 1):
		var i = _i
		var a = ((((i / float(3)) * PI) * 2) + (PI / float(2)))
		n.put(("c" if v else "d"), Geo.prism([[0.2, 0], [0.9, 0.5], [1.1, 0.3], [0.6, -0.12], [0.2, -0.14]], 0.1, 0.02), Vector3(0, 0, 0), Vector3(0, 0, a))

static func mod_m_plate(d, c):
	var n = Geo.N.new("m")
	var W = c.dim.W
	n.put("b", Geo.bx((W * 0.8), 1.15, 0.2, 0.05), Vector3(0, 0, 0.32))
	Geo.bolts(n, "d", [Vector3((W * 0.34), 0.45, 0.43), Vector3((-W * 0.34), 0.45, 0.43), Vector3((W * 0.34), -0.45, 0.43), Vector3((-W * 0.34), -0.45, 0.43)], 0.08)
	for s in [1.0, -1.0]:
		n.put("c", Geo.bx(0.14, 0.14, 0.3, 0.02), Vector3(((s * W) * 0.3), 0, 0.12))
	Geo.decal(n, "lift", Vector3(0, 0.25, 0.425), Vector3(0, 0, 0), 0.7, 0.28)
	return { "core": [["chest", n]] }

static func mod_m_glacis(d, c):
	var n = Geo.N.new("m")
	var W = c.dim.W
	n.put("b", Geo.prism([[0.1, -0.9], [0.7, -0.5], [0.85, 0.3], [0.3, 1.0], [0.1, 1.0]], (W * 0.92), 0.07))
	n.put("hz", Geo.bx((W * 0.94), 0.2, 0.14, 0.02), Vector3(0, -0.75, 0.42))
	Geo.bolts(n, "d", [Vector3((W * 0.4), 0.6, 0.6), Vector3((-W * 0.4), 0.6, 0.6), Vector3((W * 0.4), -0.2, 0.86), Vector3((-W * 0.4), -0.2, 0.86)], 0.09)
	for s in [1.0, -1.0]:
		n.put("a", Geo.bx(0.3, 1.6, 0.5, 0.06), Vector3(((s * W) * 0.5), 0, 0.1))
	Geo.decal(n, "n9", Vector3((W * 0.22), 0.6, 0.6), Vector3(-0.6, 0, 0), 0.4, 0.54)
	return { "core": [["chest", n]] }

static func mod_m_legplate(d):
	var mk = func(s):
		var n = Geo.N.new("m")
		n.put("b", Geo.prism([[-0.7, 0.9], [0.7, 0.9], [0.85, -0.2], [0.5, -1.2], [-0.5, -1.2], [-0.85, -0.2]], 0.16, 0.05, "x"), Vector3((s * 0.12), 0, 0))
		n.put("c", Geo.bx(0.12, 0.2, 0.9, 0.02), Vector3((s * 0.02), 0.6, 0))
		Geo.bolts(n, "d", [Vector3((s * 0.21), 0.6, 0.4), Vector3((s * 0.21), 0.6, -0.4)], 0.07, "x")
		return n
	return { "legs": [["plate", mk]] }

static func mod_m_cell(d):
	var mk = func(s):
		var n = Geo.N.new("m")
		n.put("c", Geo.bx(0.3, 0.7, 0.9, 0.05), Vector3((s * 0.2), 0, 0))
		for z in [-0.24, 0.24]:
			n.put("b", Geo.cyl(0.17, 0.17, 0.9, 10), Vector3((s * 0.46), 0, z))
			n.put("g", Geo.cyl(0.18, 0.18, 0.07, 10), Vector3((s * 0.46), 0.25, z))
			n.put("d", Geo.cyl(0.09, 0.09, 0.08, 8), Vector3((s * 0.46), 0.48, z))
		return n
	return { "core": [["hipL", mk.call(1)], ["hipR", mk.call(-1)]] }

static func mod_m_kit(d):
	var mk = func(s):
		var n = Geo.N.new("m")
		n.put("c", Geo.bx(0.3, 0.6, 0.8, 0.05), Vector3((s * 0.2), 0, 0))
		n.put("cer", Geo.cyl_z(0.2, 0.2, 0.9, 10), Vector3((s * 0.5), 0, 0))
		n.put("hz", Geo.cyl_z(0.21, 0.21, 0.2, 10), Vector3((s * 0.5), 0, 0.1))
		n.put("d", Geo.cyl_z(0.1, 0.1, 0.12, 8), Vector3((s * 0.5), 0, 0.5))
		return n
	return { "core": [["hipL", mk.call(1)], ["hipR", mk.call(-1)]] }

static func mod_m_armguard(d):
	var mk = func(s):
		var n = Geo.N.new("m")
		n.put("b", Geo.prism([[-0.9, -0.5], [0.9, -0.4], [1.1, 0.3], [-0.7, 0.6]], 0.14, 0.04), Vector3((s * 0.1), 0, 0))
		Geo.bolts(n, "d", [Vector3((s * 0.18), 0, 0.5), Vector3((s * 0.18), 0, -0.4)], 0.06, "x")
		return n
	return { "arms": [["guard", mk]] }

static func mod_m_radiator(d, c):
	var n = Geo.N.new("m")
	var W = c.dim.W
	n.put("c", Geo.bx((W * 0.5), 0.2, 0.5, 0.04), Vector3(0, 0.1, 0))
	for _i in _rng(0, 9, 1):
		var i = _i
		n.put("d", Geo.bx(0.04, 0.9, 0.6, 0.01), Vector3((((i - 4) * W) * 0.055), 0.6, -0.05), Vector3(0.2, 0, 0))
	Geo.rod(n, "b", Vector3((-W * 0.24), 0.9, 0.05), Vector3((W * 0.24), 0.9, 0.05), 0.04)
	return { "core": [["backtop", n]] }

static func mod_m_gyro(d):
	var n = Geo.N.new("m")
	n.put("d", Geo.tor(0.95, 0.09, 6, 22), Vector3(0, 0.1, 0), Vector3((PI / float(2)), 0, 0))
	for _i in _rng(0, 4, 1):
		var i = _i
		var a = (((i * PI) / float(2)) + (PI / float(4)))
		n.put("b", Geo.bx(0.36, 0.36, 0.36, 0.05), Vector3((cos(a) * 0.95), 0.1, (sin(a) * 0.95)), Vector3(0, -a, 0))
	return { "core": [["waist", n]] }

static func mod_m_chains(d):
	var n = Geo.N.new("m")
	n.put("c", Geo.tor(0.9, 0.06, 5, 18), Vector3(0, 0.1, 0), Vector3((PI / float(2)), 0, 0))
	for _i in _rng(0, 5, 1):
		var i = _i
		var a = ((((i / float(5)) * PI) * 2) + 0.4)
		var x = (cos(a) * 0.9)
		var z = (sin(a) * 0.9)
		for _k in _rng(0, 5, 1):
			var k = _k
			n.put("d", Geo.tor(0.07, 0.022, 4, 8), Vector3(x, (-0.05 - (k * 0.2)), z), Vector3(0, ((PI / float(2)) if fmod(k, 2) else 0), 0))
	return { "core": [["waist", n]] }

static func mod_m_ammo(d, c):
	var n = Geo.N.new("m")
	for s in [1.0, -1.0]:
		n.put("a", Geo.bx(0.7, 0.6, 0.6, 0.05), Vector3((s * 0.5), 0, -0.3))
		n.put("hz", Geo.bx(0.72, 0.14, 0.62, 0.02), Vector3((s * 0.5), 0.18, -0.3))
		n.put("d", Geo.bx(0.2, 0.08, 0.1, 0.02), Vector3((s * 0.5), 0.33, -0.3))
	return { "core": [["hipback", n]] }

static func mod_m_cap(d, c):
	var n = Geo.N.new("m")
	for x in [-0.5, 0, 0.5]:
		n.put("c", Geo.cyl(0.2, 0.2, 0.8, 10), Vector3(x, 0, -0.35))
		n.put("g", Geo.cyl(0.21, 0.21, 0.06, 10), Vector3(x, 0.2, -0.35))
		n.put("g", Geo.cyl(0.21, 0.21, 0.06, 10), Vector3(x, -0.1, -0.35))
		n.put("d", Geo.cyl(0.08, 0.08, 0.14, 8), Vector3(x, 0.46, -0.35))
	Geo.rod(n, "k", Vector3(-0.5, 0.52, -0.35), Vector3(0.5, 0.52, -0.35), 0.04)
	return { "core": [["hipback", n]] }

static func mod_m_era(d, c):
	var n = Geo.N.new("m")
	var _o3 = c.dim
	var W = _o3.W
	var H = _o3.H
	var D = _o3.D
	for s in [1.0, -1.0]:
		for _i in _rng(0, 3, 1):
			var i = _i
			for _j in _rng(0, 2, 1):
				var j = _j
				n.put("b", Geo.bx(0.14, 0.4, 0.5, 0.03), Vector3((s * ((W / float(2)) + 0.1)), ((-0.25 + (j * 0.46)) + (H - 2.2)), (-0.55 + (i * 0.56))))
		for _i in _rng(0, 2, 1):
			var i = _i
			n.put("b", Geo.bx(0.5, 0.12, 0.5, 0.03), Vector3((s * ((W * 0.26) + (i * 0.0))), (H - 1.84), (-0.5 + (i * 0.6))))
	return { "core": [["chest", n, [0, 0, (-D / float(2))]]] }

static func mod_m_tiles(d, c):
	var n = Geo.N.new("m")
	var _o4 = c.dim
	var W = _o4.W
	var H = _o4.H
	var D = _o4.D
	for s in [1.0, -1.0]:
		for _i in _rng(0, 3, 1):
			var i = _i
			for _j in _rng(0, 2, 1):
				var j = _j
				n.put("cer", Geo.bx(0.36, 0.06, 0.36, 0.02), Vector3((s * ((W * 0.16) + (j * 0.4))), ((H - 1.84) + 0.0), (-0.6 + (i * 0.4))))
		for _i in _rng(0, 3, 1):
			var i = _i
			n.put("cer", Geo.bx(0.06, 0.36, 0.36, 0.02), Vector3((s * ((W / float(2)) + 0.06)), (H - 2.3), (-0.5 + (i * 0.4))))
	return { "core": [["chest", n, [0, 0, (-D / float(2))]]] }

static func mod_m_mast(d):
	var n = Geo.N.new("m")
	n.put("c", Geo.bx(0.3, 0.3, 0.3, 0.04), Vector3(0, 0.15, 0))
	n.put("d", Geo.cyl(0.03, 0.045, 2.6, 6), Vector3(0, 1.5, 0))
	var _t5 = [1.4, 2.0, 2.5]
	for i in _t5.size():
		var y = _t5[i]
		n.put("d", Geo.bx((0.7 - (i * 0.2)), 0.03, 0.03, 0.005), Vector3(0, y, 0))
	n.put("g", Geo.sph(0.06, 6, 5), Vector3(0, 2.84, 0))
	return { "core": [["mast", n]] }
