## Concepts 2.0: esboços em 3D dos mechas das facções (fora do Padrão Carcaça).
## Blocagem para avaliação visual: proporções, silhueta e ideia. Não são peças jogáveis.
class_name Concepts

const PAINT := {
	"HB": { "a": "#77756d", "b": "#b8862e", "c": "#2d2c2a", "glow": "#ffb347", "wear": 0.65 },
	"TSK": { "a": "#e6e1d6", "b": "#b3261e", "c": "#18181c", "glow": "#ff5a40", "wear": 0.22 },
	"MRS": { "a": "#2f6f9e", "b": "#dfe7ec", "c": "#1d2730", "glow": "#5fe6ff", "wear": 0.18 },
	"NLE": { "a": "#4f8f86", "b": "#2b3236", "c": "#cfd8d2", "glow": "#7ff2e0", "wear": 0.35 },
	"SUC": { "a": "#8a4f2a", "b": "#d9792b", "c": "#3a3d3a", "glow": "#ffd04a", "wear": 0.95 },
}

## Porte final de cada conceito em relação ao modelo-base (Carcaça ≈ 8 m).
const SCALE := { "tsk_gaviao": 1.5, "tsk_andorinha": 1.6, "tsk_duelista": 1.2, "tsk_fenix": 1.25, "tsk_kitsune": 1.4, "mrs_lince": 1.45,
	"suc_ratazana": 1.7, "hb_haubitze": 1.15, "hb_panzer": 1.2, "suc_guindasteiro": 1.3, "suc_rei": 1.5, "nle_mariposa": 1.4 }

const LIST := [
	["hb_bastiao", "HB"], ["hb_fortaleza", "HB"], ["hb_assalto", "HB"], ["hb_haubitze", "HB"], ["hb_panzer", "HB"], ["hb_inspektor", "HB"],
	["tsk_gaviao", "TSK"], ["tsk_duelista", "TSK"], ["tsk_andorinha", "TSK"], ["tsk_garca", "TSK"], ["tsk_kitsune", "TSK"], ["tsk_fenix", "TSK"],
	["mrs_pastor", "MRS"], ["mrs_enxame", "MRS"], ["mrs_vigia", "MRS"], ["mrs_mula", "MRS"], ["mrs_lince", "MRS"], ["mrs_atendimento", "MRS"],
	["nle_aranha", "NLE"], ["nle_escudeiro", "NLE"], ["nle_torden", "NLE"], ["nle_isbryter", "NLE"], ["nle_mariposa", "NLE"], ["nle_raiz", "NLE"],
	["suc_remendo", "SUC"], ["suc_rei", "SUC"], ["suc_cacamba", "SUC"], ["suc_ratazana", "SUC"], ["suc_guindasteiro", "SUC"], ["suc_roubada", "SUC"],
]

static func build(id: String) -> Node3D:
	var fac: String = "HB"
	for e in LIST:
		if e[0] == id: fac = e[1]
	var mat := Mats.mech_material(PAINT[fac])
	if id == "suc_roubada": return _roubada(mat)
	if id == "hb_fortaleza": return _fortaleza_scene(mat)
	if id == "hb_assalto": return _assalto_scene()
	if id == "tsk_fenix": return _fenix_scene()
	var n: Geo.N = Concepts.new().call(id)
	var root := n.bake(mat)
	root.scale = Vector3.ONE * float(SCALE.get(id, 1.0))
	return root

# ───────── auxiliares ─────────
## Viga de seção w×d ligando a→b.
static func beam(n: Geo.N, slot, a: Vector3, b: Vector3, w: float, d: float, bev := 0.04, up := Vector3.UP) -> void:
	var len := a.distance_to(b)
	if len < 1e-4: return
	var y := (b - a) / len
	var ref := up if absf(up.dot(y)) < 0.95 else Vector3.FORWARD
	var x := ref.cross(y).normalized(); var z := x.cross(y).normalized()
	n.put(slot, Geo._xf(Geo.bx(w, len, d, bev), Basis(x, y, z)), (a + b) * 0.5)

static func joint(n: Geo.N, p: Vector3, r: float, slot = "d") -> void:
	n.put(slot, Geo.sph(r, 10, 8), p)

## Perna de dois segmentos com juntas.
static func leg(n: Geo.N, hip: Vector3, knee: Vector3, foot: Vector3, w1: float, w2: float, s1 = "a", s2 = "c") -> void:
	joint(n, hip, w1 * 0.62); beam(n, s1, hip, knee, w1, w1 * 1.1, 0.08); joint(n, knee, w2 * 0.66)
	beam(n, s2, knee, foot, w2, w2 * 1.05, 0.06)

static func ring_pts(r: float, y: float, k: int, a0 := 0.0) -> Array:
	var out := []
	for i in k: var a := a0 + TAU * i / k; out.append(Vector3(cos(a) * r, y, sin(a) * r))
	return out

static func drone(n: Geo.N, p: Vector3, sc := 1.0) -> void:
	n.put("a", Geo.sph(0.45 * sc, 10, 8), p); n.put("b", Geo.sph(0.48 * sc, 10, 4, 0, TAU, 0, PI * 0.45), p)
	n.put("g", Geo.cyl_z(0.16 * sc, 0.16 * sc, 0.12 * sc, 10), p + Vector3(0, 0, 0.42 * sc))
	for q in ring_pts(0.85 * sc, 0, 4, PI / 4):
		beam(n, "c", p, p + q, 0.08 * sc, 0.08 * sc, 0.01)
		n.put("d", Geo.tor(0.36 * sc, 0.045 * sc, 5, 16), p + q, Vector3(PI / 2, 0, 0))
	n.put("d", Geo.cyl_z(0.05 * sc, 0.05 * sc, 0.6 * sc, 6), p + Vector3(0, -0.35 * sc, 0.3 * sc))

# ═════════ HALDANE-BRÄCK ═════════
static func hb_bastiao() -> Geo.N:
	var n := Geo.N.new("c")
	for s in [1.0, -1.0]:
		var hip := Vector3(s * 2.3, 5.4, -0.8); var knee := Vector3(s * 2.5, 2.9, -2.0); var ank := Vector3(s * 2.5, 0.8, -0.5)
		n.put("d", Geo.cyl_x(0.75, 1.4), hip); beam(n, "a", hip, knee, 1.5, 1.7, 0.16)
		n.put("d", Geo.cyl_x(0.6, 1.6), knee); beam(n, "c", knee, ank, 1.1, 1.2, 0.12)
		Geo.piston(n, hip + Vector3(s * 0.95, -0.3, 0.5), ank + Vector3(s * 0.75, 0.3, 0.2), 0.14)
		n.put("k", Geo.bx(1.9, 0.55, 3.0, 0.12), Vector3(s * 2.5, 0.3, 0.2))
		for t in [-0.6, 0.0, 0.6]: n.put("d", Geo.bx(0.36, 0.3, 0.7, 0.05), Vector3(s * 2.5 + t, 0.2, 1.9))
	n.put("a", Geo.prism([[-2.6, 4.8], [2.0, 4.8], [2.6, 6.0], [1.8, 8.4], [-1.6, 8.6], [-2.8, 7.2]], 4.6, 0.15))
	n.put("a", Geo.bx(6.4, 5.4, 0.55, 0.12), Vector3(0, 6.0, 3.4), Vector3(-0.1, 0, 0))
	for s in [1.0, -1.0]: n.put("b", Geo.bx(1.7, 4.8, 0.45, 0.1), Vector3(s * 3.75, 5.8, 2.75), Vector3(-0.1, s * 0.55, 0))
	n.put("hz", Geo.bx(6.5, 0.4, 0.62, 0.03), Vector3(0, 3.6, 3.45), Vector3(-0.1, 0, 0))
	n.put("k", Geo.bx(2.9, 0.42, 0.14, 0.02), Vector3(0, 7.5, 3.66), Vector3(-0.1, 0, 0))
	n.put("g", Geo.bx(2.6, 0.14, 0.1, 0.02), Vector3(0, 7.5, 3.72), Vector3(-0.1, 0, 0))
	var bp := []
	for x in [-2.8, -1.4, 0.0, 1.4, 2.8]:
		for y in [4.2, 8.3]: bp.append(Vector3(x, y, 3.72 - (y - 6.0) * 0.1))
	Geo.bolts(n, "d", bp, 0.1)
	Geo.decal(n, "warn", Vector3(1.7, 5.0, 3.78), Vector3(-0.1, 0, 0), 1.5, 0.7)
	Geo.decal(n, "mkHB", Vector3(-1.7, 6.0, 3.74), Vector3(-0.1, 0, 0), 1.7, 0.66)
	n.put("c", Geo.cyl(1.1, 1.3, 0.7, 14), Vector3(0, 8.95, -0.6)); n.put("a", Geo.bx(1.5, 1.1, 2.6, 0.1), Vector3(0, 9.8, -0.3))
	n.put("d", Geo.cyl_z(0.3, 0.34, 6.6, 12), Vector3(0, 9.9, 4.1)); n.put("c", Geo.bx(0.8, 0.6, 0.8, 0.06), Vector3(0, 9.9, 7.4))
	for s in [1.0, -1.0]:
		n.put("c", Geo.cyl(0.32, 0.36, 2.4, 10), Vector3(s * 1.4, 9.6, -2.4)); n.put("k", Geo.cyl(0.36, 0.36, 0.2, 10), Vector3(s * 1.4, 10.8, -2.4))
	Geo.vent(n, "k", Vector3(0, 6.6, -2.75), 3.2, 1.8, 5, 0.5, "z")
	return n

static func hb_fortaleza() -> Geo.N:
	# cidade-fortaleza andante: ~70 m de comprimento, convés a 25 m, mastro a ~45 m
	var n := Geo.N.new("c")
	# casco em degraus
	n.put("a", Geo.prism([[-35, 14], [29, 14], [36, 18], [34.5, 24.5], [-33, 25], [-36, 20]], 22.0, 0.6))
	n.put("c", Geo.bx(20.5, 0.7, 62, 0.15), Vector3(0, 25.3, -1.0))
	for s in [1.0, -1.0]:
		n.put("b", Geo.bx(1.2, 6.5, 58, 0.2), Vector3(s * 11.5, 18.5, -2.0))
		n.put("hz", Geo.bx(1.3, 0.8, 58.2, 0.05), Vector3(s * 11.55, 15.0, -2.0))
		# canhões de bordada (casamatas)
		for k in 6:
			var z := -24.0 + k * 9.0
			n.put("c", Geo.bx(2.0, 2.6, 3.4, 0.2), Vector3(s * 12.6, 19.5, z))
			n.put("d", Geo.cyl_x(0.42, 5.0, 12), Vector3(s * 15.6, 19.6, z))
		# pernas: 4 por lado, joelho alto, pé largo
		for z in [-25.0, -9.0, 7.0, 23.0]:
			var hip := Vector3(s * 11.0, 17.5, z); var knee := Vector3(s * 20.0, 31.0, z + 1.5); var foot := Vector3(s * 26.0, 3.2, z)
			n.put("c", Geo.bx(3.0, 6.0, 6.0, 0.3), Vector3(s * 11.6, 18.0, z))
			n.put("d", Geo.cyl_z(2.4, 2.4, 4.6, 16), hip); beam(n, "a", hip, knee, 3.6, 4.2, 0.35)
			beam(n, "b", hip.lerp(knee, 0.2) + Vector3(0, 0, 0), hip.lerp(knee, 0.75), 3.8, 4.5, 0.25)
			for o in [-1.7, 1.7]: Geo.piston(n, hip + Vector3(-s * 0.6, -1.8, o), hip.lerp(knee, 0.7) + Vector3(-s * 1.4, -1.2, o), 0.5)
			n.put("d", Geo.cyl_z(2.2, 2.2, 4.8, 16), knee); n.put("c", Geo.sph(2.3, 12, 6, 0, TAU, 0, PI * 0.5), knee + Vector3(0, 0.6, 0))
			beam(n, "c", knee, foot, 3.0, 3.4, 0.3); beam(n, "a", knee.lerp(foot, 0.15), knee.lerp(foot, 0.65), 3.3, 3.9, 0.25)
			Geo.piston(n, knee + Vector3(s * 1.0, -1.6, 2.2), foot + Vector3(s * 0.4, 2.0, 2.0), 0.4)
			n.put("d", Geo.sph(1.6, 10, 8), foot)
			n.put("k", Geo.cyl(3.6, 4.4, 1.8, 14), Vector3(s * 26.0, 0.9, z)); n.put("hz", Geo.cyl(4.45, 4.45, 0.4, 14), Vector3(s * 26.0, 1.9, z))
			for a in [0.0, 1.57, 3.14, 4.71]: n.put("c", Geo.bx(1.4, 0.9, 2.6, 0.1), Vector3(s * 26.0 + cos(a) * 4.4, 0.45, z + sin(a) * 4.4), Vector3(0, -a, 0))
			n.put("g", Geo.cyl(0.4, 0.4, 0.3, 8), Vector3(s * 11.0, 13.8, z))
	# hangar de tropas na proa: rampa baixada até o chão
	n.put("k", Geo.bx(10.0, 8.5, 0.6, 0.1), Vector3(0, 18.4, 32.6), Vector3(-0.25, 0, 0))
	n.put("w", Geo.bx(9.0, 7.5, 0.5, 0.05), Vector3(0, 18.3, 32.2), Vector3(-0.25, 0, 0))
	beam(n, "c", Vector3(0, 14.2, 33.0), Vector3(0, 0.3, 47.0), 9.6, 0.6, 0.1, Vector3.FORWARD)
	for s in [1.0, -1.0]: beam(n, "hz", Vector3(s * 4.9, 14.3, 33.0), Vector3(s * 4.9, 0.4, 47.0), 0.4, 0.8, 0.05, Vector3.FORWARD)
	for k in 5: n.put("g", Geo.bx(0.5, 0.15, 0.5, 0.02), Vector3(-4.0 + k * 2.0, 14.6, 33.6))
	# portas laterais de desembarque com guindastes
	for s in [1.0, -1.0]:
		n.put("k", Geo.bx(0.3, 5.0, 8.0, 0.05), Vector3(s * 12.3, 18.5, 10.0)); n.put("hz", Geo.bx(0.32, 0.4, 8.0, 0.02), Vector3(s * 12.32, 21.2, 10.0))
		Geo.rod(n, "b", Vector3(s * 9.0, 25.8, 14.0), Vector3(s * 14.0, 33.0, 12.0), 0.35); Geo.rod(n, "k", Vector3(s * 14.0, 33.0, 12.0), Vector3(s * 14.0, 24.0, 12.0), 0.08)
	# superestrutura: conveses de tripulação com janelas
	n.put("a", Geo.bx(14.0, 6.0, 30.0, 0.4), Vector3(0, 28.6, -6.0)); n.put("b", Geo.bx(14.2, 0.5, 30.2, 0.05), Vector3(0, 31.7, -6.0))
	for s in [1.0, -1.0]:
		for row in 2:
			for k in 12:
				var wz := -19.0 + k * 2.3
				n.put("w", Geo.bx(0.1, 0.8, 1.3, 0.01), Vector3(s * 7.02, 27.2 + row * 2.4, wz))
				if (k + row * 3) % 4 != 0: n.put("g", Geo.bx(0.08, 0.5, 1.0, 0.01), Vector3(s * 7.06, 27.2 + row * 2.4, wz))
	# ponte de comando e mastros
	n.put("a", Geo.bx(10.0, 5.0, 8.0, 0.3), Vector3(0, 34.6, -14.0)); n.put("c", Geo.bx(7.5, 4.0, 6.0, 0.25), Vector3(0, 39.1, -14.5))
	n.put("w", Geo.bx(7.6, 1.1, 6.1, 0.03), Vector3(0, 39.6, -14.5)); n.put("g", Geo.bx(7.0, 0.3, 6.15, 0.01), Vector3(0, 39.6, -14.5))
	Geo.rod(n, "d", Vector3(0, 41.0, -15.0), Vector3(0, 48.0, -15.0), 0.3)
	for y in [43.5, 46.0]: beam(n, "d", Vector3(-3.0, y, -15.0), Vector3(3.0, y, -15.0), 0.15, 0.15, 0.02)
	n.put("d", Geo.sph(2.2, 14, 6, 0, TAU, 0, PI * 0.45), Vector3(3.6, 42.5, -12.5), Vector3(-1.0, 0.6, 0))
	n.put("d", Geo.sph(1.6, 12, 6, 0, TAU, 0, PI * 0.45), Vector3(-3.4, 42.0, -16.0), Vector3(-1.0, -2.4, 0))
	# chaminés
	for k in 3:
		var cz := -24.0 - k * 4.2
		n.put("c", Geo.cyl(1.7, 2.0, 11.0, 14), Vector3(0, 31.0, cz)); n.put("k", Geo.cyl(1.85, 1.85, 0.6, 14), Vector3(0, 36.6, cz)); n.put("g", Geo.cyl(1.4, 1.4, 0.2, 14), Vector3(0, 36.85, cz))
	# torres principais triplas (proa, sobreposta) e popa
	for t in [[22.0, 26.0, 1.0], [12.0, 29.2, 1.0]]:
		var tz: float = t[0]; var ty: float = t[1]; var dir: float = t[2]
		if ty > 27.0: n.put("c", Geo.cyl(4.6, 5.0, 3.2, 18), Vector3(0, 27.2, tz))
		n.put("c", Geo.cyl(4.2, 4.5, 1.2, 18), Vector3(0, ty + 0.6, tz)); n.put("hz", Geo.cyl(4.55, 4.55, 0.4, 18), Vector3(0, ty + 0.2, tz))
		n.put("a", Geo.prism([[-4.5, 0.0], [3.0, 0.0], [4.6, 1.6], [3.4, 3.6], [-4.0, 3.6]], 8.4, 0.3), Vector3(0, ty + 1.2, tz))
		for b in [-2.2, 0.0, 2.2]: n.put("d", Geo.cyl_z(0.55, 0.65, 15.0, 12), Vector3(b, ty + 2.8, tz + dir * 11.0))
	n.put("c", Geo.cyl(4.0, 4.3, 1.2, 18), Vector3(0, 26.6, -31.0)); n.put("a", Geo.bx(7.6, 3.4, 7.8, 0.3), Vector3(0, 28.8, -31.0))
	for b in [-1.6, 1.6]: n.put("d", Geo.cyl_z(0.5, 0.6, 11.0, 12), Vector3(b, 29.4, -40.0))
	# silos de mísseis (lançamento vertical)
	for i in 4:
		for j in 5:
			var p := Vector3(-4.5 + i * 3.0, 25.75, 0.0 + j * 2.0 - 0.5)
			n.put("k", Geo.bx(2.4, 0.3, 1.6, 0.04), p); n.put("hz", Geo.bx(2.5, 0.12, 0.2, 0.01), p + Vector3(0, 0.12, 0.85))
	# antiaéreas nos cantos do convés
	for p in [Vector3(8.5, 26.2, 26.0), Vector3(-8.5, 26.2, 26.0), Vector3(8.5, 26.2, 4.0), Vector3(-8.5, 26.2, 4.0), Vector3(8.5, 32.4, -20.0), Vector3(-8.5, 26.2, -26.0)]:
		n.put("c", Geo.cyl(1.0, 1.2, 1.0, 12), p); n.put("a", Geo.bx(1.6, 1.0, 1.8, 0.1), p + Vector3(0, 0.9, 0))
		for b in [-0.35, 0.35]: n.put("d", Geo.cyl_z(0.14, 0.14, 3.2, 8), p + Vector3(b, 1.3, 2.2), Vector3(-0.5, 0, 0))
	# bateria de morteiros na popa
	for k in 3: Geo.rod(n, "c", Vector3(-4.0 + k * 4.0, 26.0, -21.5), Vector3(-4.0 + k * 4.0, 30.5, -19.0), 1.0, 14)
	# reator traseiro e luzes sob o casco
	n.put("g", Geo.cyl_z(4.0, 4.0, 0.6, 24), Vector3(0, 19.5, -36.2)); n.put("d", Geo.tor(4.4, 0.5, 6, 28), Vector3(0, 19.5, -36.4))
	for z in [-20.0, 0.0, 20.0]: n.put("g", Geo.bx(6.0, 0.2, 0.6, 0.02), Vector3(0, 13.9, z))
	Geo.decal(n, "mkHB", Vector3(11.0, 22.6, -12.0), Vector3(0, PI / 2, 0), 9.0, 3.5)
	Geo.decal(n, "n2", Vector3(-11.0, 22.6, 18.0), Vector3(0, -PI / 2, 0), 3.0, 4.0)
	return n

## Heavy Assault: bípede de assalto superblindado (~10 m). v = "M" (corpo a corpo) ou "I" (tiro).
static func hb_heavy(v: String) -> Geo.N:
	var n := Geo.N.new("c")
	# pernas curtas, grossas e afastadas
	for s in [1.0, -1.0]:
		var hip := Vector3(s * 1.4, 4.3, 0); var knee := Vector3(s * 1.6, 2.4, 0.45); var ank := Vector3(s * 1.6, 0.8, 0.0)
		n.put("d", Geo.cyl_x(0.62, 1.2, 12), hip); beam(n, "a", hip, knee, 1.45, 1.6, 0.16)
		n.put("b", Geo.bx(1.6, 1.3, 0.3, 0.06), hip.lerp(knee, 0.5) + Vector3(0, 0, 0.85), Vector3(-0.15, 0, 0))
		n.put("d", Geo.cyl_x(0.55, 1.3, 12), knee); n.put("a", Geo.sph(0.75, 10, 6, 0, TAU, 0, PI * 0.5), knee + Vector3(0, 0, 0.35), Vector3(1.4, 0, 0), [1.1, 1.0, 0.9])
		beam(n, "c", knee, ank, 1.3, 1.4, 0.14)
		n.put("a", Geo.bx(1.55, 1.7, 0.38, 0.08), knee.lerp(ank, 0.5) + Vector3(0, 0, 0.8), Vector3(0.12, 0, 0))
		n.put("k", Geo.bx(1.75, 0.6, 2.6, 0.12), Vector3(s * 1.6, 0.3, 0.3)); n.put("a", Geo.bx(1.8, 0.35, 1.0, 0.08), Vector3(s * 1.6, 0.55, 1.35), Vector3(-0.25, 0, 0))
		n.put("hz", Geo.bx(1.82, 0.2, 0.2, 0.02), Vector3(s * 1.6, 0.2, 1.62))
		# saiote pesado
		n.put("a", Geo.bx(1.4, 1.5, 0.3, 0.06), Vector3(s * 0.75, 3.95, 1.25), Vector3(0.22, 0, s * -0.05))
		n.put("b", Geo.bx(0.3, 1.6, 1.8, 0.06), Vector3(s * 2.15, 4.0, 0.0), Vector3(0, 0, s * 0.18))
	n.put("c", Geo.bx(2.6, 1.0, 1.8, 0.12), Vector3(0, 4.5, 0))
	# tronco largo em barril
	n.put("a", Geo.prism([[-1.3, 4.7], [1.2, 4.7], [1.75, 5.7], [1.55, 7.6], [-0.9, 8.3], [-1.7, 7.0]], 3.8, 0.2))
	n.put("b", Geo.prism([[1.25, 5.0], [1.85, 5.8], [1.7, 7.3], [1.3, 7.1]], 3.0, 0.1))
	for y in [5.55, 6.3]: n.put("c", Geo.bx(2.4, 0.08, 0.1, 0.01), Vector3(0, y, 1.82 - (y - 5.5) * 0.12))
	Geo.bolts(n, "d", [Vector3(1.2, 7.0, 1.78), Vector3(-1.2, 7.0, 1.78), Vector3(1.3, 5.2, 1.6), Vector3(-1.3, 5.2, 1.6)], 0.09)
	# cabeça afundada entre os ombros, com gola blindada
	n.put("c", Geo.bx(2.3, 0.55, 0.9, 0.12), Vector3(0, 7.6, 1.25), Vector3(-0.25, 0, 0))
	n.put("a", Geo.bx(1.05, 0.95, 1.1, 0.14), Vector3(0, 8.3, 1.15)); n.put("c", Geo.bx(1.15, 0.25, 1.15, 0.05), Vector3(0, 8.82, 1.1))
	n.put("k", Geo.bx(0.85, 0.24, 0.1, 0.02), Vector3(0, 8.32, 1.71))
	for x in [-0.25, 0.0, 0.25]: n.put("g", Geo.bx(0.14, 0.09, 0.05, 0.01), Vector3(x, 8.32, 1.77))
	n.put("d", Geo.bx(0.5, 0.18, 0.12, 0.02), Vector3(0, 8.0, 1.72))
	if v == "I":
		n.put("c", Geo.bx(0.35, 0.35, 0.6, 0.04), Vector3(0.62, 8.95, 0.9)); n.put("g", Geo.cyl_z(0.1, 0.1, 0.04, 8), Vector3(0.62, 8.95, 1.22))
		Geo.rod(n, "d", Vector3(-0.45, 8.9, 0.8), Vector3(-0.6, 10.0, 0.6), 0.04)
	# ombreiras enormes em camadas
	for s in [1.0, -1.0]:
		var sp := Vector3(s * 2.35, 8.0, 0.0)
		# ombreira angular: capuz de chapa grossa com aresta elevada e bordas em camadas
		n.put("a", Geo.prism([[-0.9 * s, 0.45], [0.35 * s, 0.85], [1.25 * s, 0.25], [1.2 * s, -0.75], [-0.55 * s, -0.4]], 2.6, 0.14, "z"), sp)
		n.put("b", Geo.bx(0.3, 0.3, 2.7, 0.04), sp + Vector3(s * 0.35, 0.9, 0), Vector3(0, 0, s * -0.4))
		n.put("hz", Geo.bx(0.16, 0.95, 2.66, 0.02), sp + Vector3(s * 1.3, -0.25, 0), Vector3(0, 0, s * 0.05))
		n.put("a", Geo.bx(1.6, 0.2, 2.3, 0.04), sp + Vector3(s * 0.7, -0.95, 0), Vector3(0, 0, s * -0.55))
		n.put("c", Geo.bx(1.35, 0.18, 2.0, 0.04), sp + Vector3(s * 0.85, -1.32, 0), Vector3(0, 0, s * -0.6))
		Geo.bolts(n, "d", [sp + Vector3(s * 0.9, 0.42, 1.0), sp + Vector3(s * 0.9, 0.42, -1.0), sp + Vector3(s * 0.9, 0.42, 0.0)], 0.08, "y")
		# braços maciços
		var sh := Vector3(s * 2.45, 7.3, 0.0); var el := Vector3(s * 2.75, 5.7, 0.35); var wr := Vector3(s * 2.75, 4.5, 1.25)
		beam(n, "c", sh, el, 0.9, 1.0, 0.1); n.put("d", Geo.sph(0.55, 10, 8), el)
		beam(n, "a", el, wr, 1.3, 1.45, 0.14); n.put("b", Geo.bx(1.4, 0.25, 1.3, 0.04), el.lerp(wr, 0.25) + Vector3(0, 0.0, 0.0), Vector3(-0.7, 0, 0))
		var gun: bool = v == "I" and s < 0
		if gun:
			# antebraço com alojamento de arma (a arma em si vem na rodada de armas)
			n.put("c", Geo.bx(1.0, 0.9, 2.2, 0.08), wr + Vector3(0, -0.15, 0.6)); n.put("hz", Geo.bx(1.02, 0.15, 0.4, 0.02), wr + Vector3(0, 0.3, 1.2))
			for b in [-0.22, 0.22]: n.put("d", Geo.cyl_z(0.16, 0.18, 1.4, 10), wr + Vector3(b, -0.2, 2.2))
			n.put("k", Geo.bx(0.5, 0.6, 0.8, 0.04), wr + Vector3(0, -0.75, 0.3))
		else:
			# manopla blindada
			var big: float = 1.25 if v == "M" else 1.0
			n.put("a", Geo.bx(1.25 * big, 1.15 * big, 1.25 * big, 0.12), wr + Vector3(0, -0.5, 0.35))
			for k in 4: n.put("d", Geo.bx(0.24 * big, 0.3 * big, 0.5 * big, 0.04), wr + Vector3(-0.42 * big + k * 0.28 * big, -0.85 * big, 0.95 * big))
			n.put("b", Geo.bx(1.3 * big, 0.3, 0.5 * big, 0.04), wr + Vector3(0, -0.05, 0.85 * big))
	if v == "M":
		n.put("c", Geo.bx(2.8, 1.6, 0.35, 0.08), Vector3(0, 6.2, 2.0), Vector3(-0.08, 0, 0)); n.put("hz", Geo.bx(2.85, 0.25, 0.37, 0.02), Vector3(0, 5.35, 2.05), Vector3(-0.08, 0, 0))
	# motor nas costas com chaminés
	n.put("c", Geo.bx(2.8, 2.6, 1.3, 0.15), Vector3(0, 7.0, -1.75)); Geo.vent(n, "k", Vector3(0, 6.8, -2.42), 2.0, 1.4, 4, 0.5, "z")
	for s in [1.0, -1.0]:
		Geo.rod(n, "k", Vector3(s * 0.9, 7.8, -2.0), Vector3(s * 1.1, 9.6, -2.6), 0.24); n.put("g", Geo.cyl(0.18, 0.18, 0.06, 10), Vector3(s * 1.1, 9.62, -2.6))
	Geo.decal(n, "mkHB", Vector3(2.9, 8.35, 0.0), Vector3(0, PI / 2, -0.25), 1.2, 0.47)
	Geo.decal(n, "n4" if v == "M" else "n6", Vector3(-1.6, 2.8, 1.22), Vector3(-0.12, 0, 0), 0.6, 0.8)
	return n

## Pneu blindado com cubo e aro.
static func wheel(n: Geo.N, p: Vector3, r: float, w: float) -> void:
	n.put("k", Geo.cyl_x(r, w, 16), p); n.put("d", Geo.cyl_x(r * 0.55, w + 0.04, 12), p); n.put("c", Geo.cyl_x(r * 0.22, w + 0.1, 8), p)
	for k in 6: n.put("k", Geo.bx(w + 0.02, 0.12, r * 0.35, 0.01), p + Vector3(0, cos(k * TAU / 6) * r * 0.92, sin(k * TAU / 6) * r * 0.92), Vector3(-k * TAU / 6, 0, 0))

## Obuseiro autopropulsado 8×8: cabine, torre de canhão longo e pás de ancoragem traseiras.
static func hb_haubitze() -> Geo.N:
	var n := Geo.N.new("c")
	n.put("a", Geo.prism([[-6.6, 1.3], [5.4, 1.3], [6.8, 2.3], [6.5, 3.1], [-6.6, 3.1]], 3.7, 0.15))
	n.put("hz", Geo.bx(3.75, 0.25, 0.3, 0.02), Vector3(0, 1.45, 6.6))
	for s in [1.0, -1.0]:
		for z in [4.3, 2.3, -2.3, -4.3]: wheel(n, Vector3(s * 2.05, 1.0, z), 0.98, 0.8)
		for z in [3.3, -3.3]: n.put("b", Geo.bx(1.0, 0.25, 4.2, 0.04), Vector3(s * 2.05, 2.15, z))
		n.put("c", Geo.bx(0.5, 0.9, 2.2, 0.06), Vector3(s * 2.05, 2.75, 0.0)); n.put("hz", Geo.bx(0.52, 0.12, 2.2, 0.01), Vector3(s * 2.06, 3.1, 0.0))
		Geo.rod(n, "k", Vector3(s * 1.5, 3.1, 3.6), Vector3(s * 1.5, 5.4, 3.4), 0.16)
		var top := Vector3(s * 1.25, 1.7, -6.5); var spade := Vector3(s * 1.55, 0.25, -8.6)
		beam(n, "c", top, spade, 0.4, 0.5); Geo.piston(n, Vector3(s * 1.25, 2.6, -6.0), spade + Vector3(0, 0.6, 0.3), 0.12)
		n.put("hz", Geo.bx(1.3, 1.0, 0.18, 0.03), spade + Vector3(0, 0.2, -0.1), Vector3(-0.5, 0, 0))
	# cabine blindada
	n.put("a", Geo.prism([[3.9, 3.0], [6.5, 3.0], [6.2, 4.4], [5.0, 5.0], [3.9, 5.0]], 3.6, 0.12))
	n.put("w", Geo.prism([[5.05, 4.4], [6.15, 4.35], [5.0, 4.95]], 3.2, 0.03))
	for s in [1.0, -1.0]: n.put("g", Geo.cyl_z(0.18, 0.18, 0.06, 10), Vector3(s * 1.3, 3.4, 6.55))
	n.put("c", Geo.cyl(0.3, 0.35, 0.3, 10), Vector3(0.9, 5.15, 4.4)); n.put("d", Geo.cyl_z(0.06, 0.06, 1.2, 6), Vector3(0.9, 5.35, 5.0))
	# torre do obuseiro
	n.put("c", Geo.cyl(1.9, 2.0, 0.5, 18), Vector3(0, 3.35, -1.6))
	n.put("a", Geo.prism([[-4.2, 3.5], [1.0, 3.5], [1.7, 4.4], [1.1, 5.7], [-4.0, 5.8], [-4.4, 4.6]], 3.5, 0.15))
	n.put("b", Geo.bx(3.6, 0.3, 4.9, 0.05), Vector3(0, 5.85, -1.6))
	n.put("c", Geo.bx(1.3, 1.3, 0.9, 0.1), Vector3(0, 4.7, 1.55))
	var el := 0.42; var g0 := Vector3(0, 4.75, 1.8); var dir := Vector3(0, sin(el), cos(el))
	Geo.rod(n, "d", g0, g0 + dir * 10.5, 0.36, 14); Geo.rod(n, "c", g0 + dir * 4.0, g0 + dir * 5.2, 0.52, 14); Geo.rod(n, "c", g0, g0 + dir * 1.6, 0.55, 14)
	n.put("c", Geo.bx(0.85, 0.6, 1.0, 0.06), g0 + dir * 10.8, Vector3(-el, 0, 0))
	for s in [1.0, -1.0]: Geo.piston(n, Vector3(s * 0.75, 4.2, 0.6), g0 + dir * 2.6 + Vector3(s * 0.45, -0.3, 0), 0.1)
	n.put("c", Geo.bx(0.5, 0.5, 1.4, 0.05), Vector3(1.4, 6.2, -3.2)); beam(n, "c", Vector3(1.4, 6.45, -3.8), Vector3(1.4, 7.2, -5.6), 0.22, 0.22)
	for k in 5: n.put("b", Geo.cyl(0.22, 0.22, 1.0, 10), Vector3(-1.4 + k * 0.3, 1.0 + 1.3, -5.6)); n.put("g", Geo.cone(0.22, 0.3, 10), Vector3(-1.4 + k * 0.3, 2.95, -5.6))
	Geo.decal(n, "mkHB", Vector3(1.76, 4.8, -1.8), Vector3(0, PI / 2, 0), 2.2, 0.85)
	Geo.decal(n, "n5", Vector3(-1.76, 4.8, -2.2), Vector3(0, -PI / 2, 0), 0.8, 1.0)
	return n

## Tanque pesado de esteiras: saias blindadas, torre grande, canhão longo, cúpula e fumígenos.
static func hb_panzer() -> Geo.N:
	var n := Geo.N.new("c")
	n.put("a", Geo.prism([[-6.0, 1.0], [4.4, 1.0], [6.4, 2.1], [5.6, 3.1], [-5.7, 3.3], [-6.3, 2.3]], 4.4, 0.18))
	n.put("b", Geo.prism([[4.4, 2.0], [6.5, 2.1], [5.7, 3.15], [4.4, 3.2]], 4.2, 0.08))
	for s in [1.0, -1.0]:
		n.put("t", Geo.prism([[-6.0, 0.0], [5.0, 0.0], [6.1, 0.85], [5.5, 1.85], [-5.7, 1.85], [-6.5, 0.85]], 1.5, 0.08), Vector3(s * 2.85, 0, 0))
		for k in 7: n.put("d", Geo.cyl_x(0.58, 1.56, 14), Vector3(s * 2.85, 0.62, -4.5 + k * 1.5))
		n.put("c", Geo.cyl_x(0.75, 1.6, 12), Vector3(s * 2.85, 1.05, -5.75)); n.put("c", Geo.cyl_x(0.65, 1.6, 12), Vector3(s * 2.85, 1.0, 5.4))
		n.put("b", Geo.bx(0.28, 1.35, 11.0, 0.05), Vector3(s * 3.72, 1.95, -0.3)); n.put("hz", Geo.bx(0.3, 0.22, 11.0, 0.02), Vector3(s * 3.73, 1.35, -0.3))
		for k in 8: n.put("c", Geo.bx(0.2, 0.5, 1.1, 0.03), Vector3(s * 3.9, 2.25, -5.0 + k * 1.3))
		n.put("g", Geo.cyl_z(0.15, 0.15, 0.06, 10), Vector3(s * 1.6, 2.9, 6.12))
		# fumígenos
		for k in 3: n.put("k", Geo.cyl_z(0.12, 0.12, 0.45, 8), Vector3(s * (2.05 + k * 0.05), 5.0 + k * 0.22, 1.2), Vector3(-0.5, s * 0.6, 0))
	Geo.vent(n, "k", Vector3(0, 3.35, -4.6), 3.4, 1.6, 6, 0.0, "x")
	# torre
	n.put("c", Geo.cyl(2.3, 2.4, 0.4, 20), Vector3(0, 3.45, -0.5))
	n.put("a", Geo.prism([[-4.4, 3.6], [1.6, 3.6], [2.8, 4.2], [2.1, 5.3], [-3.8, 5.4], [-4.6, 4.5]], 4.0, 0.18))
	for s in [1.0, -1.0]: n.put("b", Geo.prism([[0.4, 3.7], [2.85, 4.2], [2.15, 5.25], [0.4, 5.3]], 0.6, 0.06), Vector3(s * 1.75, 0, 0))
	n.put("c", Geo.bx(1.7, 1.3, 0.8, 0.1), Vector3(0, 4.45, 2.95))
	Geo.rod(n, "d", Vector3(0, 4.5, 3.2), Vector3(0, 4.5, 12.2), 0.32, 14); Geo.rod(n, "c", Vector3(0, 4.5, 7.0), Vector3(0, 4.5, 8.2), 0.45, 14)
	n.put("c", Geo.cyl_z(0.42, 0.42, 0.6, 12), Vector3(0, 4.5, 12.3))
	# cesto traseiro, cúpula e metralhadora remota
	for s in [1.0, -1.0]: beam(n, "d", Vector3(s * 1.7, 4.4, -4.6), Vector3(s * 1.7, 4.4, -5.8), 0.08, 0.08, 0.01)
	n.put("c", Geo.bx(3.0, 0.7, 1.0, 0.06), Vector3(0, 4.6, -5.3)); n.put("hz", Geo.bx(3.02, 0.12, 1.02, 0.01), Vector3(0, 4.95, -5.3))
	n.put("c", Geo.cyl(0.65, 0.7, 0.5, 12), Vector3(-1.1, 5.65, -1.4))
	for k in 5: n.put("g", Geo.bx(0.18, 0.1, 0.05, 0.01), Vector3(-1.1 + cos(k * 1.2) * 0.66, 5.7, -1.4 + sin(k * 1.2) * 0.66), Vector3(0, -k * 1.2 + PI / 2, 0))
	n.put("c", Geo.bx(0.5, 0.45, 0.7, 0.04), Vector3(1.0, 5.75, -1.8)); n.put("d", Geo.cyl_z(0.06, 0.07, 1.4, 6), Vector3(1.0, 5.82, -1.0))
	n.put("c", Geo.bx(0.8, 0.12, 0.8, 0.02), Vector3(0.2, 5.45, -2.8))
	Geo.rod(n, "d", Vector3(-1.9, 5.4, -3.6), Vector3(-1.9, 7.6, -3.7), 0.04)
	Geo.decal(n, "mkHB", Vector3(2.31, 4.55, -1.5), Vector3(0, PI / 2 + 0.05, 0), 2.0, 0.78)
	Geo.decal(n, "n8", Vector3(-2.31, 4.55, -1.8), Vector3(0, -PI / 2 - 0.05, 0), 0.8, 1.0)
	return n

static func hb_inspektor() -> Geo.N:
	var n := Geo.N.new("c")
	for s in [1.0, -1.0]:
		var hip := Vector3(s * 0.8, 3.5, 0); var knee := Vector3(s * 1.0, 2.1, 0.9); var ank := Vector3(s * 1.0, 0.7, -0.3)
		leg(n, hip, knee, ank, 0.45, 0.38); joint(n, ank, 0.25)
		n.put("k", Geo.bx(0.6, 0.25, 1.4, 0.04), Vector3(s * 1.0, 0.15, 0.2))
	n.put("a", Geo.bx(2.0, 1.6, 2.2, 0.2), Vector3(0, 4.4, 0)); n.put("w", Geo.bx(1.5, 0.45, 0.1, 0.02), Vector3(0, 4.75, 1.1))
	Geo.rod(n, "d", Vector3(0.4, 5.2, -0.4), Vector3(0.4, 6.6, -0.4), 0.09)
	n.put("c", Geo.bx(0.4, 0.3, 0.6, 0.04), Vector3(0.4, 6.75, -0.25)); n.put("g", Geo.cyl_z(0.08, 0.08, 0.04, 8), Vector3(0.4, 6.75, 0.07))
	for s in [1.0, -1.0]: n.put("b", Geo.cyl_z(0.42, 0.1, 0.6, 10), Vector3(s * 1.15, 5.1, 0.7))
	var sh := Vector3(-1.15, 4.4, 0.2)
	beam(n, "c", sh, Vector3(-1.5, 3.6, 1.1), 0.3, 0.3); beam(n, "c", Vector3(-1.5, 3.6, 1.1), Vector3(-1.5, 3.3, 2.0), 0.28, 0.28)
	n.put("b", Geo.bx(0.9, 0.7, 0.9, 0.06), Vector3(-1.5, 3.0, 2.3)); n.put("hz", Geo.bx(0.95, 0.12, 0.95, 0.02), Vector3(-1.5, 2.6, 2.3))
	n.put("cer", Geo.bx(0.7, 0.9, 0.05, 0.01), Vector3(1.2, 4.2, 0.9), Vector3(0, -0.3, 0.1)); Geo.decal(n, "tick", Vector3(1.22, 4.3, 0.95), Vector3(0, -0.3, 0.1), 0.6, 0.1)
	Geo.decal(n, "mkHB", Vector3(0, 4.0, 1.12), Vector3.ZERO, 1.2, 0.47)
	return n

# ═════════ TSUBAME KŌKI ═════════
static func tsk_gaviao() -> Geo.N:
	var n := Geo.N.new("c"); var Y := 3.2
	n.put("a", Geo.prism([[-3.2, -0.35], [1.6, -0.55], [3.8, -0.05], [1.8, 0.6], [-2.4, 0.75], [-3.4, 0.3]], 1.5, 0.12), Vector3(0, Y, 0))
	n.put("w", Geo.prism([[0.4, 0.5], [2.4, 0.2], [1.0, 1.0]], 1.0, 0.05), Vector3(0, Y, 0))
	n.put("c", Geo.bx(0.5, 0.3, 4.0, 0.05), Vector3(0, Y + 0.85, -1.0))
	for s in [1.0, -1.0]:
		n.put("a", Geo.prism([[0.6 * s, 1.0], [5.0 * s, -0.4], [5.2 * s, -1.3], [0.6 * s, -1.4]], 0.2, 0.05, "y"), Vector3(0, Y + 0.1, 0))
		n.put("b", Geo.prism([[0.6 * s, 1.0], [5.0 * s, -0.4], [5.0 * s, -0.65], [0.6 * s, 0.72]], 0.24, 0.04, "y"), Vector3(0, Y + 0.1, 0))
		var fan := Vector3(s * 5.2, Y + 0.1, -0.85)
		n.put("c", Geo.tor(1.15, 0.18, 8, 24), fan, Vector3(PI / 2, 0, 0)); n.put("d", Geo.cyl(0.25, 0.25, 0.3, 10), fan)
		for a in [0.0, PI / 3, 2 * PI / 3]: n.put("k", Geo.bx(2.1, 0.04, 0.22, 0.01), fan, Vector3(0, a, 0.15))
		n.put("d", Geo.cyl_z(0.4, 0.5, 1.0, 12), Vector3(s * 0.7, Y + 0.25, -3.3)); n.put("g", Geo.cyl_z(0.33, 0.33, 0.05, 12), Vector3(s * 0.7, Y + 0.25, -3.83))
		n.put("b", Geo.bx(0.08, 1.4, 1.2, 0.02), Vector3(s * 0.5, Y + 1.0, -5.8), Vector3(0, 0, s * -0.5))
		beam(n, "c", Vector3(s * 0.6, Y - 0.45, 0.8), Vector3(s * 0.9, Y - 1.5, 1.3), 0.14, 0.14); n.put("k", Geo.bx(0.3, 0.12, 0.8, 0.02), Vector3(s * 0.9, Y - 1.56, 1.4))
	n.put("c", Geo.bx(0.5, 0.45, 3.2, 0.05), Vector3(0, Y + 0.3, -4.6))
	n.put("d", Geo.cyl_z(0.3, 0.3, 2.0, 10), Vector3(0, Y - 0.75, 1.4))
	for a in ring_pts(0.13, 0, 5): n.put("d", Geo.cyl_z(0.05, 0.05, 1.2, 6), Vector3(a.x, Y - 0.75 + a.z, 2.9))
	n.put("g", Geo.cyl_z(0.12, 0.12, 0.06, 10), Vector3(0, Y - 0.1, 3.95))
	Geo.decal(n, "n4", Vector3(0.76, Y + 0.1, -1.6), Vector3(0, PI / 2, 0), 0.5, 0.65)
	return n

static func tsk_duelista() -> Geo.N:
	var n := Geo.N.new("c")
	for s in [1.0, -1.0]:
		leg(n, Vector3(s * 0.7, 5.4, 0), Vector3(s * 0.8, 2.9, 0.35), Vector3(s * 0.8, 0.45, 0.05), 0.72, 0.6)
		n.put("b", Geo.bx(0.78, 0.75, 0.5, 0.06), Vector3(s * 0.8, 3.0, 0.62), Vector3(-0.3, 0, 0))
		n.put("c", Geo.prism([[-0.6, 0.0], [1.2, 0.0], [0.9, 0.35], [-0.5, 0.42]], 0.6, 0.05), Vector3(s * 0.8, 0, 0.05))
		for z in [1.0, -1.0]:
			n.put("a", Geo.bx(0.8, 1.6, 0.12, 0.03), Vector3(s * 0.55, 4.85, z * 0.55), Vector3(z * 0.25, 0, 0))
			n.put("b", Geo.bx(0.7, 0.3, 0.13, 0.02), Vector3(s * 0.55, 4.05, z * 0.62), Vector3(z * 0.25, 0, 0))
		n.put("a", Geo.bx(0.12, 1.5, 0.9, 0.03), Vector3(s * 1.0, 4.9, 0), Vector3(0, 0, s * 0.2))
		var sh := Vector3(s * 1.35, 7.85, 0); joint(n, sh, 0.38)
		for k in 3: n.put("a" if k % 2 == 0 else "b", Geo.bx(1.0, 0.12, 1.35, 0.03), sh + Vector3(s * (0.3 + k * 0.08), 0.15 - k * 0.32, 0), Vector3(0, 0, s * -0.5))
	n.put("d", Geo.cyl(0.55, 0.6, 0.6, 12), Vector3(0, 5.65, 0))
	n.put("a", Geo.prism([[-0.6, 6.0], [0.6, 6.0], [0.9, 7.4], [0.5, 8.2], [-0.7, 8.1], [-0.8, 6.8]], 1.8, 0.1))
	n.put("b", Geo.prism([[0.62, 6.5], [0.95, 7.4], [0.55, 8.1], [0.5, 7.2]], 1.2, 0.05))
	for s in [1.0, -1.0]:
		var sh := Vector3(s * 1.4, 7.6, 0.0); var el := Vector3(s * 1.5, 6.4, 0.25); var wr := Vector3(s * 1.5, 5.6, 1.1)
		beam(n, "c", sh, el, 0.42, 0.45); joint(n, el, 0.26); beam(n, "a", el, wr, 0.5, 0.55); n.put("c", Geo.bx(0.35, 0.4, 0.4, 0.04), wr + Vector3(0, -0.1, 0.15))
	var hand := Vector3(-1.5, 5.45, 1.35)
	n.put("k", Geo.bx(0.12, 0.12, 0.9, 0.02), hand + Vector3(0, 0.12, -0.25), Vector3(0.5, 0, 0))
	n.put("b", Geo.cyl_z(0.26, 0.26, 0.06, 10), hand + Vector3(0, 0, 0.22), Vector3(0.5, 0, 0))
	n.put("d", Geo.bx(0.07, 0.24, 5.4, 0.01), hand + Vector3(0, -1.32, 2.5), Vector3(0.5, 0, 0)); n.put("g", Geo.bx(0.03, 0.04, 5.2, 0.005), hand + Vector3(0, -1.42, 2.42), Vector3(0.5, 0, 0))
	n.put("b", Geo.cyl_z(0.62, 0.62, 0.12, 14), Vector3(1.75, 5.9, 0.75), Vector3(-0.6, 0.3, 0))
	n.put("k", Geo.bx(0.2, 0.28, 4.6, 0.03), Vector3(0.95, 4.6, -1.3), Vector3(0.7, 0.1, 0))
	n.put("d", Geo.cyl(0.24, 0.28, 0.3, 10), Vector3(0, 8.3, 0)); n.put("c", Geo.bx(0.55, 0.5, 0.62, 0.06), Vector3(0, 8.6, 0.08))
	n.put("a", Geo.sph(0.46, 12, 6, 0, TAU, 0, PI * 0.5), Vector3(0, 8.78, 0)); n.put("g", Geo.bx(0.42, 0.06, 0.05, 0.01), Vector3(0, 8.62, 0.4))
	for s in [1.0, -1.0]:
		beam(n, "d", Vector3(0, 8.95, 0.38), Vector3(s * 0.55, 9.75, 0.5), 0.08, 0.04, 0.01)
		n.put("a", Geo.bx(0.5, 0.1, 0.55, 0.02), Vector3(s * 0.42, 8.45, -0.1), Vector3(0, 0, s * -0.45))
	n.put("b", Geo.bx(0.9, 1.0, 0.5, 0.06), Vector3(0, 7.3, -0.85))
	Geo.rod(n, "d", Vector3(0, 7.6, -1.05), Vector3(0, 10.8, -1.05), 0.05)
	n.put("b", Geo.bx(0.05, 1.7, 0.95, 0.01), Vector3(0, 9.85, -1.55)); Geo.decal(n, "n1", Vector3(0.04, 9.85, -1.55), Vector3(0, PI / 2, 0), 0.6, 0.8)
	return n

static func tsk_andorinha() -> Geo.N:
	var n := Geo.N.new("c"); var Y := 4.0
	n.put("a", Geo.prism([[-4.2, -0.3], [2.6, -0.45], [5.4, 0.0], [2.8, 0.55], [-3.6, 0.6]], 1.3, 0.1), Vector3(0, Y, 0))
	n.put("w", Geo.prism([[1.2, 0.45], [3.4, 0.2], [1.8, 0.85]], 0.8, 0.04), Vector3(0, Y, 0))
	for s in [1.0, -1.0]:
		n.put("a", Geo.prism([[0.6 * s, -1.2], [4.6 * s, 0.6], [4.8 * s, 0.0], [0.6 * s, -2.6]], 0.16, 0.04, "y"), Vector3(0, Y, 0))
		n.put("b", Geo.prism([[0.5 * s, 2.6], [1.6 * s, 2.2], [1.6 * s, 1.9], [0.5 * s, 2.0]], 0.1, 0.02, "y"), Vector3(0, Y + 0.1, 0))
		n.put("b", Geo.bx(0.08, 1.5, 1.4, 0.02), Vector3(s * 0.55, Y + 1.0, -3.3), Vector3(0, 0, s * 0.35))
		n.put("d", Geo.cyl_z(0.5, 0.55, 1.6, 14), Vector3(s * 0.75, Y, -3.7)); n.put("g", Geo.cyl_z(0.42, 0.42, 0.05, 14), Vector3(s * 0.75, Y, -4.52))
		beam(n, "c", Vector3(s * 0.45, Y - 0.45, -0.8), Vector3(s * 0.55, Y - 0.6, -2.8), 0.35, 0.4); beam(n, "c", Vector3(s * 0.55, Y - 0.6, -2.8), Vector3(s * 0.5, Y - 0.75, -1.0), 0.3, 0.32)
	n.put("d", Geo.cyl_z(0.16, 0.18, 4.4, 10), Vector3(0, Y - 0.62, 2.0)); n.put("c", Geo.bx(0.4, 0.35, 1.0, 0.04), Vector3(0, Y - 0.6, -0.2))
	Geo.decal(n, "n3", Vector3(0.66, Y + 0.05, -1.0), Vector3(0, PI / 2, 0), 0.45, 0.6)
	return n

## Garça: bípede esguio de pernas de ave, com propulsor de asas de penas (planador/atiradora aérea).
static func tsk_garca() -> Geo.N:
	var n := Geo.N.new("c")
	# pernas de ave: coxa à frente, calcanhar alto para trás, dedos longos
	for s in [1.0, -1.0]:
		var hip := Vector3(s * 0.7, 5.8, -0.1); var knee := Vector3(s * 0.85, 4.1, 0.9); var heel := Vector3(s * 0.9, 2.0, -0.75); var foot := Vector3(s * 0.9, 0.3, 0.15)
		joint(n, hip, 0.38); beam(n, "a", hip, knee, 0.55, 0.65, 0.06); joint(n, knee, 0.32)
		beam(n, "c", knee, heel, 0.4, 0.45, 0.05); joint(n, heel, 0.26); beam(n, "c", heel, foot, 0.3, 0.32, 0.04)
		n.put("b", Geo.bx(0.6, 0.6, 0.18, 0.03), hip.lerp(knee, 0.5) + Vector3(0, 0, 0.36), Vector3(-0.95, 0, 0))
		for t in [-0.4, 0.0, 0.4]: beam(n, "c", foot, foot + Vector3(t, -0.2, 1.3), 0.12, 0.1, 0.01)
		beam(n, "c", foot, foot + Vector3(0, -0.2, -0.8), 0.12, 0.1, 0.01)
	n.put("c", Geo.bx(1.5, 0.7, 0.9, 0.08), Vector3(0, 6.0, -0.1))
	# tronco fino e longo
	n.put("a", Geo.prism([[-0.7, 6.1], [0.55, 6.1], [0.9, 7.1], [0.65, 8.4], [-0.55, 8.5], [-0.9, 7.3]], 1.6, 0.1))
	n.put("b", Geo.prism([[0.6, 6.5], [0.95, 7.1], [0.7, 8.1], [0.55, 7.2]], 1.0, 0.05))
	n.put("c", Geo.bx(1.64, 0.18, 1.5, 0.02), Vector3(0, 6.75, 0.0), Vector3(0, 0, 0.18))
	# pescoço longo, cabeça com bico-sensor e penacho
	beam(n, "c", Vector3(0, 8.35, 0.15), Vector3(0, 9.45, 0.8), 0.28, 0.3)
	n.put("a", Geo.prism([[0.45, 9.35], [1.35, 9.42], [1.3, 9.72], [0.6, 9.82], [0.35, 9.6]], 0.48, 0.05))
	n.put("d", Geo.prism([[1.3, 9.45], [2.55, 9.53], [1.3, 9.65]], 0.22, 0.02))
	for x in [0.23, -0.23]: n.put("g", Geo.bx(0.04, 0.07, 0.18, 0.01), Vector3(x, 9.62, 1.1))
	for k in 3: beam(n, "c", Vector3(0, 9.78, 0.6), Vector3((k - 1) * 0.12, 10.05 - k * 0.12, -0.7 - k * 0.25), 0.05, 0.03, 0.005)
	# braços finos segurando uma arma longa (marcador de lugar: a arma vem na rodada de armas)
	for s in [1.0, -1.0]: joint(n, Vector3(s * 0.95, 8.0, 0.0), 0.3)
	beam(n, "a", Vector3(-0.95, 8.0, 0.0), Vector3(-1.15, 6.95, 0.35), 0.3, 0.32); beam(n, "c", Vector3(-1.15, 6.95, 0.35), Vector3(-0.75, 6.6, 1.1), 0.28, 0.3)
	beam(n, "a", Vector3(0.95, 8.0, 0.0), Vector3(1.2, 7.0, 0.9), 0.3, 0.32); beam(n, "c", Vector3(1.2, 7.0, 0.9), Vector3(0.1, 6.85, 2.5), 0.28, 0.3)
	beam(n, "c", Vector3(-0.75, 6.65, 0.5), Vector3(0.0, 6.85, 2.9), 0.28, 0.42, 0.03, Vector3.FORWARD)
	Geo.rod(n, "d", Vector3(0.0, 6.88, 2.9), Vector3(0.45, 7.05, 7.4), 0.1); n.put("w", Geo.cyl_z(0.13, 0.13, 0.9, 10), Vector3(-0.25, 7.15, 1.6), Vector3(-0.04, 0.1, 0))
	# propulsor dorsal com asas de garça
	n.put("c", Geo.bx(1.3, 1.6, 0.9, 0.1), Vector3(0, 7.6, -0.9)); n.put("b", Geo.bx(1.32, 0.2, 0.92, 0.02), Vector3(0, 8.3, -0.9))
	for s in [1.0, -1.0]:
		n.put("d", Geo.cyl_z(0.26, 0.34, 0.7, 12), Vector3(s * 0.38, 6.95, -1.45)); n.put("g", Geo.cyl_z(0.22, 0.22, 0.05, 12), Vector3(s * 0.38, 6.95, -1.82))
		var root := Vector3(s * 0.65, 8.0, -1.05); var elbow := Vector3(s * 3.1, 9.7, -1.7); var tip := Vector3(s * 6.9, 9.1, -2.6)
		joint(n, root, 0.32); beam(n, "c", root, elbow, 0.34, 0.3); joint(n, elbow, 0.26); beam(n, "c", elbow, tip, 0.26, 0.24)
		beam(n, "b", root + Vector3(0, 0.22, 0), elbow + Vector3(0, 0.2, 0), 0.12, 0.34, 0.02); beam(n, "b", elbow + Vector3(0, 0.18, 0), tip + Vector3(0, 0.14, 0), 0.1, 0.3, 0.02)
		n.put("d", Geo.cyl_z(0.16, 0.2, 0.5, 10), elbow + Vector3(0, -0.25, -0.2)); n.put("g", Geo.cyl_z(0.13, 0.13, 0.04, 10), elbow + Vector3(0, -0.25, -0.46))
		# penas: secundárias ao longo do braço da asa, primárias mais longas na ponta
		for i in 18:
			var t := i / 17.0
			var p := root.lerp(elbow, t * 2.0) if t < 0.5 else elbow.lerp(tip, (t - 0.5) * 2.0)
			var L := 1.9 + t * 2.1
			var d := Vector3(s * (0.15 + t * 0.6), -1.0, -0.45 - t * 0.35).normalized()
			var off := Vector3(0, 0, -0.035 * (i % 2))
			beam(n, "a", p + off, p + off + d * L * 0.8, 0.78 - t * 0.2, 0.05, 0.01, Vector3.BACK)
			beam(n, "c", p + off + d * L * 0.8, p + off + d * L, 0.66 - t * 0.18, 0.05, 0.01, Vector3.BACK)
		for i in 11:
			var t := i / 10.0
			var p := root.lerp(elbow, t * 2.0) if t < 0.5 else elbow.lerp(tip, (t - 0.5) * 2.0)
			beam(n, "a", p + Vector3(0, 0.06, 0.12), p + Vector3(s * (0.12 + t * 0.3), -1.0, -0.3), 0.78, 0.06, 0.01, Vector3.BACK)
			beam(n, "b", p + Vector3(0, 0.08, 0.16), p + Vector3(s * 0.1, -0.35, 0.02), 0.7, 0.05, 0.01, Vector3.BACK)
	Geo.decal(n, "n4", Vector3(0.82, 7.4, 0.62), Vector3(0, 0.5, 0), 0.4, 0.55)
	return n

static func tsk_kitsune() -> Geo.N:
	var n := Geo.N.new("c")
	n.put("c", Geo.prism([[-2.0, 2.4], [1.6, 2.5], [2.3, 3.0], [1.5, 3.4], [-1.8, 3.3]], 1.4, 0.1))
	n.put("a", Geo.prism([[-0.6, 3.3], [1.4, 3.35], [1.1, 3.6], [-0.4, 3.55]], 1.0, 0.04))
	for sx in [1.0, -1.0]:
		leg(n, Vector3(sx * 0.6, 2.7, 1.4), Vector3(sx * 0.75, 1.6, 1.0), Vector3(sx * 0.75, 0.25, 1.6), 0.36, 0.28, "c", "a")
		leg(n, Vector3(sx * 0.6, 2.7, -1.6), Vector3(sx * 0.75, 1.7, -0.9), Vector3(sx * 0.75, 0.25, -1.7), 0.42, 0.3, "c", "a")
		for z in [1.75, -1.55]: n.put("k", Geo.bx(0.36, 0.18, 0.6, 0.03), Vector3(sx * 0.75, 0.1, z))
		n.put("c", Geo.prism([[2.2, 3.6], [2.55, 3.65], [2.35, 4.25]], 0.12, 0.02), Vector3(sx * 0.32, 0, 0))
	n.put("c", Geo.prism([[1.9, 2.9], [3.3, 2.95], [3.5, 3.15], [2.1, 3.65]], 0.75, 0.06)); n.put("g", Geo.bx(0.6, 0.06, 0.05, 0.01), Vector3(0, 3.25, 3.0), Vector3(0, 0, 0))
	for k in 3:
		var a := (k - 1) * 0.55; var base := Vector3(0, 3.0, -1.9)
		var p1 := base + Vector3(sin(a) * 0.8, 0.9, -0.8); var p2 := p1 + Vector3(sin(a) * 0.9, 1.4, -0.3); var p3 := p2 + Vector3(sin(a) * 0.5, 1.0, 0.4)
		beam(n, "c", base, p1, 0.28, 0.12); beam(n, "c", p1, p2, 0.24, 0.1); beam(n, "b", p2, p3, 0.2, 0.08); n.put("g", Geo.sph(0.09, 6, 4), p3)
	return n

static func tsk_fenix() -> Geo.N:
	var n := tsk_duelista()
	for s in [1.0, -1.0]:
		for k in 6:
			var a := 0.25 + k * 0.2
			var base := Vector3(s * 0.4, 7.6, -1.0); var tip := base + Vector3(s * sin(a) * (3.2 + k * 0.25), cos(a) * (2.6 + k * 0.2) - 0.6, -0.4 - k * 0.1)
			beam(n, "b" if k % 2 == 0 else "a", base, tip, 0.32, 0.06, 0.01); n.put("g", Geo.bx(0.06, 0.06, 0.06, 0.01), tip)
		n.put("d", Geo.bx(0.06, 0.2, 3.4, 0.01), Vector3(s * 0.35, 8.0, -0.95), Vector3(-0.9, 0, s * 0.6))
	n.put("hz", Geo.bx(1.6, 0.08, 1.0, 0.02), Vector3(0, 4.35, 0.35))
	n.put("g", Geo.sph(0.16, 8, 6), Vector3(0, 9.4, 0.45))
	return n

## Fênix «Sky Lord»: comandante da Revoada. Armadura samurai de alta patente e asas de fênix.
static func tsk_skylord() -> Geo.N:
	var n := Geo.N.new("c")
	# pernas com protetores de coxa (haidate) e canela (suneate)
	for s in [1.0, -1.0]:
		var hip := Vector3(s * 0.72, 5.5, 0); var knee := Vector3(s * 0.82, 3.0, 0.35); var ank := Vector3(s * 0.82, 0.5, 0.05)
		leg(n, hip, knee, ank, 0.7, 0.6, "c", "c")
		for k in 4: n.put("a" if k % 2 == 0 else "b", Geo.bx(0.92, 0.3, 0.14, 0.03), hip.lerp(knee, 0.2 + k * 0.18) + Vector3(0, 0, 0.45), Vector3(-0.08, 0, 0))
		n.put("b", Geo.bx(0.85, 0.8, 0.5, 0.06), knee + Vector3(0, 0.05, 0.32), Vector3(-0.3, 0, 0))
		n.put("a", Geo.bx(0.8, 2.0, 0.22, 0.05), knee.lerp(ank, 0.5) + Vector3(0, 0, 0.38), Vector3(0.05, 0, 0))
		for e in [-0.38, 0.38]: n.put("b", Geo.bx(0.06, 2.0, 0.24, 0.01), knee.lerp(ank, 0.5) + Vector3(e, 0, 0.39), Vector3(0.05, 0, 0))
		n.put("c", Geo.prism([[-0.6, 0.0], [1.2, 0.0], [0.95, 0.38], [-0.5, 0.45]], 0.66, 0.05), Vector3(s * 0.82, 0, 0.05))
		n.put("b", Geo.bx(0.68, 0.1, 0.3, 0.02), Vector3(s * 0.82, 0.38, 0.95))
	# saiote em três camadas (kusazuri), vermelho com bordas douradas
	for tier in 3:
		var y := 5.3 - tier * 0.5; var spread := 0.62 + tier * 0.06
		for side in [[0.0, 1.0], [0.0, -1.0], [1.0, 0.0], [-1.0, 0.0]]:
			var dx: float = side[0]; var dz: float = side[1]
			var pos := Vector3(dx * (0.95 + tier * 0.08), y, dz * (spread + 0.1))
			var rot := Vector3(dz * (0.18 + tier * 0.06), 0, -dx * (0.18 + tier * 0.06))
			var w := 0.12 if dx != 0.0 else 1.6
			var d := 1.3 if dx != 0.0 else 0.12
			n.put("a", Geo.bx(w, 0.55, d, 0.03), pos, rot); n.put("b", Geo.bx(w + 0.02, 0.07, d + 0.02, 0.01), pos + Vector3(0, -0.26, 0), rot)
	n.put("d", Geo.cyl(0.55, 0.6, 0.5, 12), Vector3(0, 5.75, 0))
	# couraça (dō) em lâminas horizontais com emblema da fênix
	n.put("c", Geo.prism([[-0.65, 5.95], [0.62, 5.95], [0.95, 7.3], [0.55, 8.25], [-0.75, 8.15], [-0.85, 6.9]], 2.0, 0.1))
	for k in 5:
		var y := 6.15 + k * 0.38
		n.put("a", Geo.bx(2.06, 0.3, 0.12, 0.02), Vector3(0, y, 0.68 + minf(k, 3) * 0.08), Vector3(-0.12, 0, 0))
		n.put("b", Geo.bx(2.08, 0.05, 0.14, 0.01), Vector3(0, y - 0.15, 0.69 + minf(k, 3) * 0.08), Vector3(-0.12, 0, 0))
	n.put("b", Geo.prism([[0.0, 0.42], [0.22, 0.05], [0.12, -0.35], [0.0, -0.18], [-0.12, -0.35], [-0.22, 0.05]], 0.06, 0.01, "z"), Vector3(0, 7.25, 1.06))
	n.put("g", Geo.sph(0.09, 6, 4), Vector3(0, 7.3, 1.1))
	# ombreiras (sode): placas largas em cinco lâminas
	for s in [1.0, -1.0]:
		var sh := Vector3(s * 1.35, 7.95, 0); joint(n, sh, 0.4)
		for k in 5:
			var pc := sh + Vector3(s * (0.5 + k * 0.05), 0.15 - k * 0.3, 0)
			n.put("a" if k < 4 else "c", Geo.bx(1.15, 0.26, 1.55, 0.03), pc, Vector3(0, 0, s * -0.42))
			n.put("b", Geo.bx(1.17, 0.05, 1.57, 0.01), pc + Vector3(0, -0.12, 0), Vector3(0, 0, s * -0.42))
		n.put("b", Geo.bx(0.3, 0.3, 0.3, 0.05), sh + Vector3(s * 0.45, 0.35, 0.0))
		var el := Vector3(s * 1.55, 6.35, 0.3); var wr := Vector3(s * 1.5, 5.5, 1.1)
		beam(n, "c", sh, el, 0.44, 0.46); joint(n, el, 0.28); beam(n, "a", el, wr, 0.52, 0.56)
		for k in 3: n.put("b", Geo.bx(0.58, 0.05, 0.62, 0.01), el.lerp(wr, 0.25 + k * 0.25), Vector3(-0.75, 0, 0))
		n.put("c", Geo.bx(0.38, 0.42, 0.42, 0.04), wr + Vector3(0, -0.12, 0.18))
	# katana na mão direita, espada curta na cintura
	var hand := Vector3(-1.5, 5.35, 1.4)
	n.put("k", Geo.bx(0.12, 0.12, 0.95, 0.02), hand + Vector3(0, 0.15, -0.3), Vector3(0.35, 0, 0))
	n.put("b", Geo.cyl_z(0.28, 0.28, 0.07, 12), hand + Vector3(0, 0, 0.22), Vector3(0.35, 0, 0))
	n.put("d", Geo.bx(0.07, 0.25, 5.6, 0.01), hand + Vector3(0, -0.95, 2.85), Vector3(0.35, 0, 0)); n.put("g", Geo.bx(0.03, 0.04, 5.4, 0.005), hand + Vector3(0, -1.06, 2.78), Vector3(0.35, 0, 0))
	n.put("c", Geo.bx(0.18, 0.24, 2.6, 0.03), Vector3(0.95, 5.2, 0.5), Vector3(0.45, 0.15, 0)); n.put("b", Geo.bx(0.2, 0.26, 0.12, 0.01), Vector3(0.95, 5.55, -0.25), Vector3(0.45, 0.15, 0))
	# kabuto: cúpula, abas viradas, proteção de nuca em camadas, máscara e crista dourada
	n.put("d", Geo.cyl(0.24, 0.28, 0.3, 10), Vector3(0, 8.3, 0))
	n.put("c", Geo.sph(0.52, 14, 8, 0, TAU, 0, PI * 0.55), Vector3(0, 8.85, 0.05)); n.put("b", Geo.tor(0.5, 0.05, 5, 20), Vector3(0, 8.85, 0.05), Vector3(PI / 2, 0, 0))
	for k in 3: n.put("a", Geo.sph(0.62 + k * 0.12, 14, 3, PI * 0.15, PI * 1.7, PI * 0.5, PI * 0.18), Vector3(0, 8.85 - k * 0.2, 0.05), Vector3(0, PI, 0))
	for s in [1.0, -1.0]: n.put("a", Geo.bx(0.08, 0.42, 0.5, 0.02), Vector3(s * 0.62, 8.75, 0.3), Vector3(0, s * 0.6, s * -0.25)); n.put("b", Geo.bx(0.09, 0.44, 0.06, 0.01), Vector3(s * 0.66, 8.75, 0.52), Vector3(0, s * 0.6, s * -0.25))
	n.put("k", Geo.prism([[-0.3, 8.35], [0.3, 8.35], [0.24, 8.72], [0.0, 8.8], [-0.24, 8.72]], 0.12, 0.02, "z"), Vector3(0, 0, 0.5))
	for x in [-0.12, 0.12]: n.put("g", Geo.bx(0.12, 0.04, 0.05, 0.005), Vector3(x, 8.66, 0.58), Vector3(0, 0, -x * 1.5))
	n.put("b", Geo.tor(0.62, 0.07, 5, 20, PI), Vector3(0, 9.2, 0.42), Vector3(0, 0, 0))
	n.put("b", Geo.prism([[0.0, 0.0], [0.16, 0.35], [0.06, 0.8], [0.0, 0.62], [-0.06, 0.8], [-0.16, 0.35]], 0.06, 0.01, "z"), Vector3(0, 9.2, 0.46))
	n.put("g", Geo.sph(0.07, 6, 4), Vector3(0, 9.42, 0.5))
	# propulsor dorsal e asas de fênix (penas em chama que sobem e se curvam)
	n.put("c", Geo.bx(1.2, 1.4, 0.8, 0.1), Vector3(0, 7.5, -0.95)); n.put("b", Geo.bx(1.22, 0.12, 0.82, 0.01), Vector3(0, 8.15, -0.95))
	for s in [1.0, -1.0]:
		n.put("d", Geo.cyl_z(0.24, 0.32, 0.6, 12), Vector3(s * 0.36, 6.9, -1.45)); n.put("g", Geo.cyl_z(0.2, 0.2, 0.05, 12), Vector3(s * 0.36, 6.9, -1.78))
		var root := Vector3(s * 0.6, 8.2, -1.05); var elbow := Vector3(s * 2.9, 10.3, -1.8); var tip := Vector3(s * 5.6, 12.6, -2.5)
		joint(n, root, 0.3, "b"); beam(n, "b", root, elbow, 0.3, 0.28); joint(n, elbow, 0.24, "b"); beam(n, "b", elbow, tip, 0.24, 0.22)
		for i in 16:
			var t := i / 15.0
			var p := root.lerp(elbow, t * 2.0) if t < 0.5 else elbow.lerp(tip, (t - 0.5) * 2.0)
			var L := 1.8 + t * 1.6
			var d1 := Vector3(s * (0.35 + t * 0.7), -0.85 + t * 0.35, -0.5).normalized()
			var d2 := Vector3(s * (0.5 + t * 0.4), 0.55 + t * 0.4, -0.3).normalized()
			var m := p + d1 * L
			beam(n, "b" if t < 0.35 else "a", p, m, 0.58 - t * 0.12, 0.05, 0.01, Vector3.BACK)
			beam(n, "a", m, m + d2 * L * 0.3, 0.42 - t * 0.08, 0.05, 0.01, Vector3.BACK)
			beam(n, "g" if t > 0.3 else "b", m + d2 * L * 0.3, m + d2 * L * 0.6, 0.3 - t * 0.06, 0.05, 0.01, Vector3.BACK)
		for i in 6:
			var t := i / 5.0
			var p := root.lerp(elbow, t * 2.0) if t < 0.5 else elbow.lerp(tip, (t - 0.5) * 2.0)
			beam(n, "b", p + Vector3(0, 0.08, 0.1), p + Vector3(s * 0.3, -0.8, -0.2), 0.6, 0.06, 0.01, Vector3.BACK)
	# penas de cauda longas
	for k in 5:
		var a := (k - 2) * 0.28
		var p0 := Vector3(sin(a) * 0.4, 6.6, -1.2); var p1 := p0 + Vector3(sin(a) * 0.9, -1.6, -1.4); var p2 := p1 + Vector3(sin(a) * 1.1, -1.6, -0.7); var p3 := p2 + Vector3(sin(a) * 0.8, -0.9, 0.5)
		beam(n, "b", p0, p1, 0.36, 0.05, 0.01, Vector3.BACK); beam(n, "a", p1, p2, 0.32, 0.05, 0.01, Vector3.BACK); beam(n, "g", p2, p3, 0.22, 0.05, 0.01, Vector3.BACK)
	return n

# ═════════ MERIDIANO ═════════
static func mrs_pastor() -> Geo.N:
	var n := Geo.N.new("c")
	n.put("a", Geo.sph(1.6, 16, 12), Vector3(0, 5.2, 0), Vector3.ZERO, [1.0, 0.8, 1.2]); n.put("b", Geo.tor(1.62, 0.12, 6, 28), Vector3(0, 5.0, 0), Vector3(PI / 2, 0, 0), [1.0, 1.2, 1.0])
	for p in ring_pts(1.55, 5.25, 12): n.put("g", Geo.sph(0.07, 6, 4), Vector3(p.x, p.y, p.z * 1.18))
	n.put("k", Geo.cyl_z(0.45, 0.5, 0.3, 16), Vector3(0, 5.3, 1.86)); n.put("g", Geo.cyl_z(0.28, 0.28, 0.05, 16), Vector3(0, 5.3, 2.03))
	for a in [PI / 2, PI / 2 + TAU / 3, PI / 2 + 2 * TAU / 3]:
		var d := Vector3(cos(a), 0, sin(a)); var hip := Vector3(0, 4.6, 0) + d * 1.0; var knee := Vector3(0, 5.8, 0) + d * 2.7; var foot := Vector3(0, 0.25, 0) + d * 3.5
		leg(n, hip, knee, foot, 0.4, 0.3, "c", "c"); n.put("k", Geo.cone(0.5, 0.4, 8), foot + Vector3(0, -0.05, 0))
	Geo.rod(n, "d", Vector3(0, 6.3, -0.4), Vector3(0, 9.0, -0.4), 0.08)
	for y in [7.4, 8.2]: beam(n, "d", Vector3(-0.7, y, -0.4), Vector3(0.7, y, -0.4), 0.05, 0.05, 0.01)
	n.put("b", Geo.sph(1.0, 14, 6, 0, TAU, 0, PI * 0.42), Vector3(0, 8.4, -0.4), Vector3(-1.1, 0, 0))
	for s in [1.0, -1.0]:
		n.put("c", Geo.bx(0.2, 1.6, 1.4, 0.03), Vector3(s * 1.75, 5.0, 0)); drone(n, Vector3(s * 2.25, 5.5, 0), 0.6); drone(n, Vector3(s * 2.25, 4.5, 0), 0.6)
	Geo.decal(n, "mkMRS", Vector3(0, 4.3, 1.6), Vector3(0.6, 0, 0), 1.2, 0.47)
	return n

static func mrs_enxame() -> Geo.N:
	var n := Geo.N.new("c")
	var pts := [Vector3(0, 3.0, 0), Vector3(1.8, 3.6, -0.8), Vector3(-1.7, 2.6, -0.6), Vector3(0.9, 1.8, 1.0), Vector3(-0.8, 4.1, 0.9), Vector3(2.5, 2.2, 1.1), Vector3(-2.4, 3.9, -1.6)]
	for p in pts: drone(n, p, 1.1)
	return n

static func mrs_vigia() -> Geo.N:
	var n := Geo.N.new("c")
	n.put("a", Geo.cyl(1.4, 1.6, 1.0, 8), Vector3(0, 2.2, 0))
	for p in ring_pts(1.0, 0, 4, PI / 4): leg(n, Vector3(p.x, 2.0, p.z), Vector3(p.x * 2.6, 2.6, p.z * 2.6), Vector3(p.x * 3.2, 0.2, p.z * 3.2), 0.4, 0.3, "c", "c")
	for k in 4: n.put("a" if k % 2 == 0 else "c", Geo.cyl(0.55 - k * 0.08, 0.6 - k * 0.08, 2.6, 12), Vector3(0, 3.9 + k * 2.4, 0))
	n.put("b", Geo.cyl(0.9, 0.7, 0.9, 12), Vector3(0, 13.6, 0)); n.put("k", Geo.cyl_z(0.4, 0.45, 0.4, 14), Vector3(0, 13.6, 0.85)); n.put("g", Geo.cyl_z(0.26, 0.26, 0.05, 14), Vector3(0, 13.6, 1.06))
	n.put("c", Geo.bx(3.6, 0.15, 0.3, 0.02), Vector3(0, 14.3, 0)); n.put("d", Geo.cyl(0.05, 0.05, 1.6, 6), Vector3(0, 15.0, 0))
	for s in [1.0, -1.0]:
		n.put("b", Geo.bx(0.1, 2.2, 1.6, 0.02), Vector3(s * 0.85, 9.0, 0), Vector3(0, 0, s * 0.15))
		for y in [8.3, 9.0, 9.7]: n.put("g", Geo.bx(0.12, 0.05, 1.4, 0.01), Vector3(s * (0.9 + (9.0 - y) * -0.15 * 0), y, 0), Vector3(0, 0, s * 0.15))
	return n

static func mrs_mula() -> Geo.N:
	var n := Geo.N.new("c")
	n.put("a", Geo.bx(3.6, 2.6, 6.0, 0.18), Vector3(0, 3.6, -0.3)); n.put("c", Geo.bx(2.6, 1.6, 1.6, 0.12), Vector3(0, 3.4, 3.4))
	n.put("w", Geo.bx(2.0, 0.6, 0.1, 0.02), Vector3(0, 3.7, 4.2))
	for s in [1.0, -1.0]:
		for z in [-2.4, -0.3, 1.8]:
			leg(n, Vector3(s * 1.7, 2.6, z), Vector3(s * 2.8, 2.9, z), Vector3(s * 3.1, 0.2, z), 0.45, 0.35, "c", "c")
	for i in 3:
		for j in 4:
			var p := Vector3(-1.0 + i * 1.0 + (0.5 if j % 2 else 0.0) - 0.25, 2.8 + j * 0.62, -3.32)
			n.put("k", Geo.cyl_z(0.32, 0.32, 0.12, 6), p); n.put("g", Geo.cyl_z(0.2, 0.2, 0.13, 6), p)
	Geo.rod(n, "d", Vector3(1.2, 4.9, 1.0), Vector3(1.2, 6.2, 1.0), 0.15); beam(n, "c", Vector3(1.2, 6.2, 1.0), Vector3(-0.6, 6.6, -1.4), 0.25, 0.25)
	drone(n, Vector3(-0.8, 5.5, -1.6), 0.8); drone(n, Vector3(0.9, 5.4, -1.8), 0.8)
	n.put("b", Geo.bx(3.62, 0.3, 6.02, 0.03), Vector3(0, 4.3, -0.3)); Geo.decal(n, "mkMRS", Vector3(1.81, 3.4, -0.6), Vector3(0, PI / 2, 0), 2.0, 0.78)
	return n

static func mrs_lince() -> Geo.N:
	var n := Geo.N.new("c")
	n.put("a", Geo.prism([[-1.9, 2.3], [1.5, 2.4], [2.1, 2.8], [1.4, 3.3], [-1.8, 3.1]], 1.3, 0.12)); n.put("b", Geo.bx(1.32, 0.12, 2.6, 0.03), Vector3(0, 3.18, -0.2))
	for sx in [1.0, -1.0]:
		leg(n, Vector3(sx * 0.6, 2.6, 1.3), Vector3(sx * 0.72, 1.4, 1.75), Vector3(sx * 0.72, 0.25, 1.4), 0.38, 0.3, "c", "c")
		leg(n, Vector3(sx * 0.6, 2.6, -1.5), Vector3(sx * 0.72, 1.3, -2.1), Vector3(sx * 0.72, 0.25, -1.4), 0.42, 0.3, "c", "c")
		for z in [1.5, -1.3]: n.put("k", Geo.bx(0.32, 0.16, 0.5, 0.03), Vector3(sx * 0.72, 0.1, z))
	beam(n, "c", Vector3(0, 3.0, 1.8), Vector3(0, 3.6, 2.6), 0.4, 0.4)
	n.put("a", Geo.prism([[2.3, 3.4], [3.6, 3.45], [3.5, 3.85], [2.4, 4.0]], 0.7, 0.06)); n.put("g", Geo.cyl_z(0.16, 0.16, 0.05, 12), Vector3(0, 3.65, 3.6))
	n.put("c", Geo.cyl(0.5, 0.55, 0.3, 12), Vector3(0, 3.45, -0.4)); n.put("k", Geo.bx(0.5, 0.5, 1.0, 0.04), Vector3(0, 3.85, -0.3)); n.put("d", Geo.cyl_z(0.1, 0.12, 2.0, 8), Vector3(0, 3.9, 1.2))
	Geo.rod(n, "d", Vector3(0, 2.9, -1.9), Vector3(0, 4.2, -2.9), 0.04)
	return n

static func mrs_atendimento() -> Geo.N:
	var n := Geo.N.new("c")
	for s in [1.0, -1.0]:
		leg(n, Vector3(s * 0.8, 3.8, 0), Vector3(s * 0.85, 2.0, 0.3), Vector3(s * 0.85, 0.45, 0), 0.6, 0.55, "b", "a")
		n.put("a", Geo.sph(0.62, 10, 6, 0, TAU, 0, PI * 0.5), Vector3(s * 0.85, 0.05, 0.1), Vector3.ZERO, [1.0, 0.7, 1.4])
	n.put("b", Geo.sph(1.6, 16, 10), Vector3(0, 5.2, 0), Vector3.ZERO, [1.1, 0.9, 0.9])
	n.put("k", Geo.bx(2.4, 1.5, 0.3, 0.12), Vector3(0, 5.4, 1.2)); n.put("w", Geo.bx(2.2, 1.3, 0.05, 0.02), Vector3(0, 5.4, 1.36))
	for s in [1.0, -1.0]: n.put("g", Geo.sph(0.16, 8, 6), Vector3(s * 0.5, 5.65, 1.4), Vector3.ZERO, [1.0, 1.0, 0.3])
	n.put("g", Geo.tor(0.45, 0.06, 5, 16, PI), Vector3(0, 5.25, 1.4), Vector3(0, 0, PI))
	for s in [1.0, -1.0]:
		n.put("a", Geo.cyl(0.55, 0.5, 0.9, 12), Vector3(s * 1.75, 6.2, 0)); n.put("k", Geo.cyl_z(0.35, 0.12, 0.6, 12), Vector3(s * 1.75, 6.2, 0.6))
	beam(n, "a", Vector3(1.75, 5.6, 0), Vector3(2.4, 7.2, 0.4), 0.35, 0.35); Geo.rod(n, "d", Vector3(2.4, 7.2, 0.4), Vector3(2.5, 9.0, 0.4), 0.04)
	n.put("b", Geo.bx(1.1, 0.7, 0.03, 0.005), Vector3(3.05, 8.6, 0.4)); Geo.decal(n, "mkMRS", Vector3(3.05, 8.6, 0.42), Vector3.ZERO, 1.0, 0.39)
	beam(n, "a", Vector3(-1.75, 5.6, 0), Vector3(-2.0, 4.4, 0.6), 0.35, 0.35); n.put("c", Geo.sph(0.3, 8, 6), Vector3(-2.0, 4.3, 0.65))
	return n

# ═════════ NORDLYS ═════════
static func nle_aranha() -> Geo.N:
	var n := Geo.N.new("c")
	n.put("a", Geo.cyl(2.2, 2.4, 0.9, 6), Vector3(0, 3.2, 0)); n.put("b", Geo.cyl(1.8, 2.1, 0.4, 6), Vector3(0, 3.85, 0))
	n.put("w", Geo.cyl(0.9, 0.9, 1.2, 16), Vector3(0, 4.6, -0.4)); n.put("g", Geo.cyl(0.65, 0.65, 1.22, 16), Vector3(0, 4.6, -0.4)); n.put("d", Geo.tor(0.95, 0.08, 5, 20), Vector3(0, 5.2, -0.4), Vector3(PI / 2, 0, 0))
	n.put("b", Geo.bx(1.0, 0.5, 0.7, 0.06), Vector3(0, 3.35, 2.3))
	for x in [-0.3, 0.0, 0.3]: n.put("g", Geo.sph(0.08, 6, 4), Vector3(x, 3.4, 2.66))
	beam(n, "c", Vector3(0, 4.3, 0.6), Vector3(0, 5.4, 3.6), 0.5, 0.5); n.put("w", Geo.cyl_z(0.32, 0.36, 0.3, 14), Vector3(0, 5.45, 3.8), Vector3(-0.35, 0, 0))
	for k in 3: n.put("d", Geo.tor(0.32, 0.06, 5, 14), Vector3(0, 4.6 + k * 0.33, 1.4 + k * 0.85), Vector3(PI / 2 - 0.35, 0, 0))
	for i in 6:
		var a := PI / 6 + i * PI / 3; var d := Vector3(cos(a), 0, sin(a))
		var hip := Vector3(0, 3.2, 0) + d * 2.1; var knee := Vector3(0, 6.2, 0) + d * 4.0; var foot := Vector3(0, 0.25, 0) + d * 6.0
		joint(n, hip, 0.32); beam(n, "a", hip, knee, 0.42, 0.55, 0.06); joint(n, knee, 0.3); beam(n, "c", knee, foot, 0.28, 0.32, 0.04); n.put("k", Geo.cone(0.25, 0.5, 6), foot + Vector3(0, 0.0, 0), Vector3(PI, 0, 0))
	for s in [1.0, -1.0]: n.put("b", Geo.cyl_z(0.3, 0.3, 1.6, 10), Vector3(s * 0.9, 4.2, -1.9)); n.put("g", Geo.tor(0.31, 0.04, 5, 12), Vector3(s * 0.9, 4.2, -1.9))
	return n

static func nle_escudeiro() -> Geo.N:
	var n := Geo.N.new("c")
	n.put("a", Geo.cyl(2.0, 2.3, 1.6, 10), Vector3(0, 2.6, 0))
	for p in ring_pts(1.7, 0, 4, PI / 4): leg(n, Vector3(p.x, 2.2, p.z), Vector3(p.x * 1.7, 1.6, p.z * 1.7), Vector3(p.x * 1.9, 0.3, p.z * 1.9), 0.6, 0.5, "b", "a"); n.put("k", Geo.cyl(0.6, 0.7, 0.3, 8), Vector3(p.x * 1.9, 0.15, p.z * 1.9))
	n.put("w", Geo.sph(1.6, 16, 8, 0, TAU, 0, PI * 0.5), Vector3(0, 3.4, 0)); n.put("g", Geo.sph(1.1, 12, 6, 0, TAU, 0, PI * 0.5), Vector3(0, 3.4, 0))
	n.put("d", Geo.tor(1.65, 0.12, 6, 28), Vector3(0, 3.45, 0), Vector3(PI / 2, 0, 0))
	for p in ring_pts(2.05, 0, 6): n.put("b", Geo.cyl(0.18, 0.18, 1.8, 8), Vector3(p.x, 3.6, p.z)); n.put("g", Geo.sph(0.15, 6, 4), Vector3(p.x, 4.55, p.z))
	n.put("c", Geo.bx(1.4, 0.6, 0.6, 0.05), Vector3(0, 2.9, 2.2)); n.put("w", Geo.bx(1.0, 0.25, 0.05, 0.01), Vector3(0, 3.0, 2.52))
	return n

## Arco elétrico em zigue-zague entre dois pontos (para mostrar descarga).
static func arc(n: Geo.N, a: Vector3, b: Vector3, segs := 5, amp := 0.35, w := 0.07) -> void:
	var prev := a
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := a.lerp(b, t)
		if i < segs: p += Vector3(sin(i * 2.3) * amp, cos(i * 1.7) * amp * 0.6, sin(i * 3.1) * amp)
		beam(n, "g", prev, p, w, w, 0.005); prev = p

## Bobina de Tesla: base, isoladores de cerâmica, enrolamento, toroide e esfera de descarga.
static func tesla(n: Geo.N, base: Vector3, h := 2.6, r := 0.32) -> Vector3:
	n.put("c", Geo.cyl(r * 1.5, r * 1.7, 0.35, 12), base + Vector3(0, 0.18, 0))
	for k in 4: n.put("cer", Geo.cyl(r * 1.25, r * 1.25, 0.14, 12), base + Vector3(0, 0.45 + k * 0.2, 0)); n.put("k", Geo.cyl(r * 0.8, r * 0.8, 0.07, 10), base + Vector3(0, 0.55 + k * 0.2, 0))
	var c0 := base + Vector3(0, 1.25, 0)
	n.put("d", Geo.cyl(r, r, h * 0.55, 14), c0 + Vector3(0, h * 0.275, 0))
	for k in 9: n.put("b", Geo.tor(r + 0.03, 0.03, 4, 16), c0 + Vector3(0, 0.08 + k * h * 0.06, 0), Vector3(PI / 2, 0, 0))
	var top := c0 + Vector3(0, h * 0.55 + 0.15, 0)
	n.put("d", Geo.tor(r * 2.0, r * 0.55, 8, 22), top, Vector3(PI / 2, 0, 0))
	n.put("g", Geo.sph(r * 0.7, 10, 8), top + Vector3(0, 0.12, 0))
	return top

## Torden: bípede de combate com bobinas de Tesla nos ombros e projetores de arco nos antebraços.
static func nle_torden() -> Geo.N:
	var n := Geo.N.new("c")
	for s in [1.0, -1.0]:
		var hip := Vector3(s * 0.95, 5.0, 0); var knee := Vector3(s * 1.05, 2.7, 0.45); var ank := Vector3(s * 1.05, 0.55, 0.0)
		leg(n, hip, knee, ank, 0.85, 0.72, "a", "b")
		n.put("a", Geo.bx(1.0, 0.8, 0.45, 0.06), knee + Vector3(0, 0.05, 0.42), Vector3(-0.3, 0, 0))
		for k in 3: n.put("cer", Geo.cyl(0.46, 0.46, 0.1, 12), knee.lerp(ank, 0.3 + k * 0.18))
		n.put("b", Geo.bx(1.2, 0.5, 2.0, 0.08), Vector3(s * 1.05, 0.25, 0.25)); n.put("a", Geo.bx(1.25, 0.25, 0.7, 0.04), Vector3(s * 1.05, 0.45, 1.05), Vector3(-0.2, 0, 0))
		n.put("d", Geo.cone(0.14, 0.9, 8), Vector3(s * 1.05, 0.1, -1.0), Vector3(PI + 0.4, 0, 0)); n.put("g", Geo.sph(0.06, 6, 4), Vector3(s * 1.05, -0.3, -1.2))
	n.put("c", Geo.bx(2.1, 0.9, 1.4, 0.1), Vector3(0, 5.2, 0))
	# tronco blindado com janela do reator
	n.put("a", Geo.prism([[-1.0, 5.4], [0.9, 5.4], [1.3, 6.4], [1.1, 7.8], [-0.9, 8.0], [-1.2, 6.7]], 2.5, 0.15))
	n.put("c", Geo.bx(1.6, 0.5, 1.6, 0.06), Vector3(0, 5.55, 0))
	n.put("b", Geo.prism([[0.95, 5.6], [1.35, 6.4], [1.2, 7.4], [0.9, 7.2]], 2.0, 0.06))
	n.put("k", Geo.cyl_z(0.42, 0.46, 0.2, 16), Vector3(0, 6.75, 1.33)); n.put("g", Geo.cyl_z(0.3, 0.3, 0.22, 16), Vector3(0, 6.75, 1.35))
	for k in 3: n.put("d", Geo.tor(0.46 + k * 0.04, 0.03, 4, 18), Vector3(0, 6.75, 1.36 + k * 0.02))
	# cabeça com visor e aletas isolantes
	n.put("d", Geo.cyl(0.26, 0.3, 0.3, 10), Vector3(0, 8.15, 0.1)); n.put("b", Geo.bx(0.85, 0.6, 0.8, 0.08), Vector3(0, 8.5, 0.3))
	n.put("g", Geo.bx(0.62, 0.1, 0.05, 0.01), Vector3(0, 8.55, 0.71))
	for s in [1.0, -1.0]:
		for k in 3: n.put("cer", Geo.bx(0.06, 0.34, 0.5, 0.01), Vector3(s * (0.47 + k * 0.08), 8.55, 0.25))
	# bobinas de Tesla nos ombros + braços com projetores de arco
	var tops := []
	for s in [1.0, -1.0]:
		var sh := Vector3(s * 1.55, 7.45, -0.1)
		n.put("a", Geo.bx(1.2, 0.9, 1.5, 0.1), sh + Vector3(s * 0.15, 0.1, 0)); n.put("b", Geo.bx(1.25, 0.15, 1.55, 0.02), sh + Vector3(s * 0.15, 0.6, 0))
		tops.append(tesla(n, sh + Vector3(s * 0.25, 0.55, -0.2), 2.6, 0.32))
		var el := Vector3(s * 2.0, 6.1, 0.35); var wr := Vector3(s * 2.05, 5.4, 2.0)
		joint(n, sh + Vector3(0, -0.4, 0), 0.4); beam(n, "a", sh + Vector3(0, -0.4, 0), el, 0.52, 0.56); joint(n, el, 0.32)
		n.put("c", Geo.cyl_z(0.58, 0.66, 1.9, 16), el.lerp(wr, 0.5), Vector3(-0.38, 0, 0))
		for k in 8: n.put("b", Geo.tor(0.64, 0.045, 4, 18), el.lerp(wr, 0.12 + k * 0.1), Vector3(-0.38, 0, 0))
		var tip := wr + Vector3(0, -0.1, 0.3)
		for k in 2: n.put("cer", Geo.cyl_z(0.44 - k * 0.06, 0.48 - k * 0.06, 0.2, 14), tip + Vector3(0, -0.07 * k, 0.2 * k), Vector3(-0.38, 0, 0))
		var forks := []
		for k in 3:
			var ang := k * TAU / 3 + PI / 2
			var e0 := tip + Vector3(cos(ang) * 0.3, sin(ang) * 0.3, 0.3); var e1 := e0 + Vector3(cos(ang) * 0.12, sin(ang) * 0.12 - 0.35, 1.2)
			beam(n, "d", e0, e1, 0.1, 0.1, 0.01); n.put("g", Geo.sph(0.12, 8, 6), e1); forks.append(e1)
		arc(n, forks[0], forks[1], 3, 0.1, 0.05); arc(n, forks[1], forks[2], 3, 0.1, 0.05); arc(n, forks[2], forks[0], 3, 0.1, 0.05)
		var cen: Vector3 = (forks[0] + forks[1] + forks[2]) / 3.0
		arc(n, cen, cen + Vector3(s * 0.3, -0.6, 1.6), 4, 0.18, 0.05)
	# arco entre as duas bobinas e descargas no ar
	arc(n, tops[0] + Vector3(0, 0.2, 0), tops[1] + Vector3(0, 0.2, 0), 8, 0.35, 0.07)
	arc(n, tops[0] + Vector3(0, 0.25, 0), tops[0] + Vector3(0.9, 1.5, -0.4), 4, 0.25, 0.05)
	arc(n, tops[1] + Vector3(0, 0.25, 0), tops[1] + Vector3(-1.0, 1.3, 0.3), 4, 0.25, 0.05)
	# banco de capacitores nas costas, com cabos para as bobinas
	n.put("b", Geo.bx(2.2, 1.8, 0.9, 0.1), Vector3(0, 6.8, -1.45))
	for k in 4:
		var cp := Vector3(-0.75 + k * 0.5, 7.0, -2.05)
		n.put("c", Geo.cyl(0.2, 0.2, 1.5, 12), cp); n.put("g", Geo.tor(0.21, 0.03, 4, 12), cp + Vector3(0, 0.3, 0), Vector3(PI / 2, 0, 0)); n.put("cer", Geo.cyl(0.22, 0.22, 0.12, 12), cp + Vector3(0, 0.8, 0))
	for s in [1.0, -1.0]: beam(n, "k", Vector3(s * 0.9, 7.6, -1.6), Vector3(s * 1.7, 8.2, -0.5), 0.12, 0.12, 0.02)
	Geo.decal(n, "mkNLE", Vector3(-1.2, 6.5, 1.08), Vector3(0, -0.35, 0), 1.0, 0.39)
	return n

static func nle_isbryter() -> Geo.N:
	var n := Geo.N.new("c")
	n.put("a", Geo.prism([[-3.4, 2.0], [2.2, 2.0], [4.6, 2.6], [2.6, 5.0], [-3.0, 5.2]], 3.6, 0.15))
	n.put("b", Geo.prism([[2.2, 1.4], [5.4, 2.2], [3.0, 4.4]], 3.8, 0.12)); n.put("hz", Geo.bx(3.9, 0.25, 0.4, 0.03), Vector3(0, 2.0, 4.7), Vector3(0, 0, 0))
	for sx in [1.0, -1.0]:
		for sz in [1.0, -1.0]:
			leg(n, Vector3(sx * 1.8, 2.6, sz * 1.8), Vector3(sx * 2.8, 2.2, sz * 2.0), Vector3(sx * 2.8, 0.35, sz * 2.0), 0.8, 0.65, "c", "a")
			n.put("c", Geo.bx(0.7, 0.18, 2.6, 0.04), Vector3(sx * 2.8, 0.1, sz * 2.0 + 0.3))
		Geo.rod(n, "d", Vector3(sx * 1.2, 4.4, 1.0), Vector3(sx * 1.2, 4.6, 5.6), 0.2); n.put("g", Geo.cone(0.22, 0.6, 10), Vector3(sx * 1.2, 4.6, 5.9), Vector3(PI / 2, 0, 0))
		n.put("k", Geo.cyl(0.35, 0.4, 1.6, 10), Vector3(sx * 0.9, 5.8, -2.4))
	n.put("c", Geo.bx(1.6, 0.9, 1.4, 0.08), Vector3(0, 5.6, 0.4)); n.put("w", Geo.bx(1.4, 0.35, 0.05, 0.01), Vector3(0, 5.7, 1.12))
	return n

static func nle_mariposa() -> Geo.N:
	var n := Geo.N.new("c"); var Y := 5.0
	n.put("a", Geo.sph(0.8, 12, 8), Vector3(0, Y, 0), Vector3.ZERO, [0.8, 0.8, 2.2]); n.put("g", Geo.cyl_z(0.25, 0.25, 0.05, 12), Vector3(0, Y, 1.78))
	for s in [1.0, -1.0]:
		for k in 2:
			var ang := Vector3(0, s * (0.3 + k * 0.7), s * (0.35 - k * 0.15))
			var c := Vector3(s * 3.0, Y + 0.6 - k * 1.0, 0.8 - k * 1.9)
			n.put("w", Geo.bx(4.6, 0.06, 2.4, 0.01), c, ang); n.put("b", Geo.bx(4.7, 0.1, 0.12, 0.01), c + Vector3(0, 0, 1.2).rotated(Vector3.UP, ang.y), ang)
			for g in 3: n.put("g", Geo.bx(4.4, 0.07, 0.04, 0.005), c + Vector3(0, 0.0, -0.8 + g * 0.8).rotated(Vector3.UP, ang.y), ang)
		beam(n, "d", Vector3(s * 0.2, Y + 0.5, 1.4), Vector3(s * 0.9, Y + 1.6, 3.0), 0.05, 0.05, 0.01)
		n.put("c", Geo.cyl_z(0.25, 0.3, 0.8, 10), Vector3(s * 0.6, Y - 0.2, -1.5))
	drone(n, Vector3(0.0, Y - 1.4, 0.4), 0.55); drone(n, Vector3(0.9, Y - 1.2, -0.7), 0.55)
	return n

static func nle_raiz() -> Geo.N:
	var n := Geo.N.new("c")
	var t := Vector3(-0.45, 0, 0)
	var root := n.child("r", Vector3(0, 1.8, 0), t)
	root.put("a", Geo.cyl_z(1.4, 1.5, 4.0, 14), Vector3(0, 0, -0.6)); root.put("d", Geo.cone(1.4, 2.4, 14), Vector3(0, 0, 2.6), Vector3(PI / 2, 0, 0))
	for k in 4: root.put("b", Geo.tor(1.25 - k * 0.27, 0.12, 5, 16), Vector3(0, 0, 1.7 + k * 0.5), Vector3(0, 0, 0))
	root.put("g", Geo.tor(1.42, 0.06, 5, 20), Vector3(0, 0, 1.4)); root.put("c", Geo.cyl_z(1.2, 1.3, 0.6, 14), Vector3(0, 0, -2.9))
	for s in [1.0, -1.0]:
		for z in [-1.6, -0.2, 1.0]:
			var hip := Vector3(s * 1.3, -0.4, z); var knee := Vector3(s * 2.4, 0.4, z + 0.3); var foot := Vector3(s * 2.8, -1.6, z + 0.6)
			joint(root, hip, 0.25); beam(root, "c", hip, knee, 0.3, 0.3); joint(root, knee, 0.22); beam(root, "a", knee, foot, 0.24, 0.24); root.put("k", Geo.cone(0.2, 0.5, 6), foot, Vector3(PI, 0, 0))
	root.put("w", Geo.bx(0.8, 0.3, 0.05, 0.01), Vector3(0, 1.2, 0.5), Vector3(-0.6, 0, 0))
	return n

# ═════════ SUCATEIROS ═════════
static func suc_remendo() -> Geo.N:
	var n := Geo.N.new("c")
	leg(n, Vector3(1.3, 3.9, 0), Vector3(1.5, 2.2, 0.5), Vector3(1.5, 0.6, 0), 0.8, 0.65, "c", "b"); n.put("k", Geo.bx(1.2, 0.5, 1.8, 0.08), Vector3(1.5, 0.25, 0.2)); n.put("hz", Geo.bx(0.9, 0.5, 0.1, 0.02), Vector3(1.5, 2.6, 0.95), Vector3(-0.2, 0, 0))
	n.put("t", Geo.prism([[-1.6, 0.0], [1.4, 0.0], [1.9, 0.7], [1.4, 1.5], [-1.5, 1.5], [-2.0, 0.7]], 1.0, 0.06), Vector3(-1.6, 0, 0))
	for z in [-1.0, 0.0, 1.0]: n.put("d", Geo.cyl_x(0.45, 1.08, 10), Vector3(-1.6, 0.55, z))
	beam(n, "d", Vector3(-1.6, 1.5, 0), Vector3(-0.6, 3.6, 0), 0.4, 0.4); beam(n, "d", Vector3(1.3, 3.9, 0), Vector3(-0.6, 3.6, 0), 0.3, 0.3)
	n.put("a", Geo.cyl_x(1.5, 3.4, 16), Vector3(0, 5.0, 0)); n.put("c", Geo.cyl_x(1.55, 0.2, 16), Vector3(1.7, 5.0, 0)); n.put("c", Geo.cyl_x(1.55, 0.2, 16), Vector3(-1.7, 5.0, 0))
	var patches := [["b", Vector3(0.5, 5.6, 1.4), Vector3(-0.4, 0.2, 0.1)], ["cer", Vector3(-0.8, 4.4, 1.45), Vector3(0.3, -0.2, 0)], ["hz", Vector3(0.9, 4.2, 1.35), Vector3(0.5, 0.3, 0.2)], ["c", Vector3(-0.4, 6.3, 0.6), Vector3(-1.0, 0, 0.3)]]
	for p in patches: n.put(p[0], Geo.bx(1.0, 0.8, 0.08, 0.02), p[1], p[2])
	n.put("b", Geo.bx(1.5, 1.1, 1.3, 0.08), Vector3(0.4, 6.8, 0.6)); n.put("w", Geo.bx(1.3, 0.4, 0.05, 0.01), Vector3(0.4, 6.95, 1.27))
	n.put("g", Geo.cyl(0.14, 0.14, 0.2, 8), Vector3(0.9, 7.45, 0.6))
	n.put("c", Geo.cyl(0.5, 0.6, 0.5, 10), Vector3(1.9, 5.9, 0)); beam(n, "hz", Vector3(1.9, 6.1, 0), Vector3(3.1, 8.6, 2.6), 0.32, 0.32)
	Geo.rod(n, "k", Vector3(3.1, 8.5, 2.6), Vector3(3.1, 5.3, 2.6), 0.03); n.put("d", Geo.tor(0.3, 0.07, 5, 12, PI * 1.4), Vector3(3.1, 5.0, 2.6), Vector3(0, PI / 2, 2.4))
	Geo.piston(n, Vector3(1.9, 5.5, 0.3), Vector3(2.5, 7.3, 1.5), 0.1)
	beam(n, "c", Vector3(-1.8, 5.2, 0), Vector3(-2.3, 4.4, 1.0), 0.45, 0.45); n.put("k", Geo.tor(0.8, 0.32, 8, 18), Vector3(-2.4, 4.3, 1.4)); n.put("d", Geo.cyl_z(0.35, 0.35, 0.5, 10), Vector3(-2.4, 4.3, 1.4))
	for s in [1.0, -1.0]: Geo.rod(n, "k", Vector3(s * 0.7, 5.6, -1.2), Vector3(s * 0.9, 8.2, -1.6), 0.13)
	n.put("k", Geo.tor(0.6, 0.24, 6, 14), Vector3(0, 5.0, -1.75), Vector3(PI / 2 - 0.2, 0, 0))
	Geo.decal(n, "mkQF", Vector3(-0.2, 5.0, 1.52), Vector3(0, 0, PI + 0.2), 1.2, 0.47); Geo.decal(n, "n7", Vector3(0.95, 5.2, 1.2), Vector3(0, 0.6, -0.3), 0.5, 0.65)
	return n

static func suc_rei() -> Geo.N:
	var n := Geo.N.new("c")
	leg(n, Vector3(2.6, 6.5, 0), Vector3(3.2, 3.6, -1.6), Vector3(3.2, 0.9, 0), 2.0, 1.6, "c", "a"); n.put("k", Geo.bx(2.6, 0.9, 3.8, 0.12), Vector3(3.2, 0.45, 0.4))
	for k in 6: n.put("k", Geo.tor(1.05, 0.42, 8, 18), Vector3(-2.8, 0.42 + k * 0.84, 0), Vector3(PI / 2, 0, 0))
	beam(n, "d", Vector3(-2.8, 5.0, 0), Vector3(-1.0, 6.8, 0), 0.8, 0.8)
	n.put("b", Geo.bx(9.0, 3.2, 3.0, 0.2), Vector3(0, 8.4, 0)); n.put("a", Geo.bx(9.05, 0.5, 3.05, 0.04), Vector3(0, 9.7, 0))
	for i in 7: n.put("w", Geo.bx(0.9, 0.9, 0.05, 0.01), Vector3(-3.6 + i * 1.2, 8.9, 1.52))
	n.put("g", Geo.bx(0.5, 0.3, 0.05, 0.01), Vector3(4.2, 7.4, 1.52)); n.put("g", Geo.bx(0.5, 0.3, 0.05, 0.01), Vector3(3.4, 7.4, 1.52))
	n.put("c", Geo.cyl(0.8, 1.0, 1.0, 12), Vector3(-3.4, 10.4, 0)); beam(n, "hz", Vector3(-3.4, 10.8, 0), Vector3(-6.2, 14.6, 2.0), 0.6, 0.6)
	Geo.rod(n, "k", Vector3(-6.2, 14.4, 2.0), Vector3(-6.2, 8.5, 2.0), 0.08); n.put("k", Geo.sph(1.3, 12, 8), Vector3(-6.2, 7.3, 2.0))
	beam(n, "c", Vector3(4.6, 8.6, 0), Vector3(6.0, 6.8, 1.6), 0.9, 0.9); n.put("d", Geo.cone(0.9, 2.2, 12), Vector3(6.4, 6.2, 3.2), Vector3(PI / 2 + 0.3, 0, 0))
	for p in ring_pts(1.3, 10.4, 7): Geo.rod(n, "d", Vector3(p.x + 1.6, 10.0, p.z), Vector3(p.x * 1.15 + 1.6, 11.6, p.z * 1.15), 0.08)
	n.put("hz", Geo.tor(1.35, 0.12, 5, 20), Vector3(1.6, 10.6, 0), Vector3(PI / 2, 0, 0))
	Geo.decal(n, "warn", Vector3(-1.5, 7.6, 1.52), Vector3(0, 0, 0.15), 2.2, 1.0); Geo.decal(n, "n9", Vector3(1.6, 7.6, 1.53), Vector3.ZERO, 0.8, 1.0)
	return n

static func suc_cacamba() -> Geo.N:
	var n := Geo.N.new("c")
	for sx in [1.0, -1.0]:
		for sz in [1.0, -1.0]:
			var hip := Vector3(sx * 1.4, 2.8, sz * 1.5); var knee := Vector3(sx * 2.0, 1.8, sz * 1.5 + 0.8); var ank := Vector3(sx * 2.0, 0.6, sz * 1.5 - 0.3)
			leg(n, hip, knee, ank, 0.4, 0.32, "c", "c"); n.put("k", Geo.bx(0.6, 0.22, 0.9, 0.03), Vector3(sx * 2.0, 0.12, sz * 1.5))
	n.put("b", Geo.bx(3.2, 0.25, 4.4, 0.04), Vector3(0, 3.0, 0))
	for s in [1.0, -1.0]: n.put("b", Geo.bx(0.2, 2.0, 4.4, 0.04), Vector3(s * 1.5, 4.0, 0), Vector3(0, 0, s * -0.12)); n.put("b", Geo.bx(3.4, 2.0, 0.2, 0.04), Vector3(0, 4.0, s * 2.1), Vector3(s * 0.12, 0, 0))
	n.put("hz", Geo.bx(3.5, 0.4, 4.7, 0.03), Vector3(0, 4.7, 0))
	n.put("c", Geo.bx(3.4, 0.12, 2.2, 0.02), Vector3(0, 5.6, -2.0), Vector3(-1.0, 0, 0))
	var junk := [[0.6, 4.6, 0.5, 0.5], [-0.5, 4.8, -0.6, 0.7], [0.2, 5.0, 1.1, 0.4], [-0.9, 4.5, 1.0, 0.6]]
	for j in junk: n.put("a" if j[3] > 0.5 else "cer", Geo.bx(j[3] * 1.4, j[3], j[3] * 1.1, 0.03), Vector3(j[0], j[1], j[2]), Vector3(0.3, j[0], 0.2))
	n.put("k", Geo.tor(0.5, 0.2, 6, 14), Vector3(-0.6, 5.2, 0.4), Vector3(0.6, 0, 0.4))
	Geo.rod(n, "c", Vector3(0.6, 4.4, -0.8), Vector3(1.0, 7.0, 0.4), 0.42, 12)
	Geo.decal(n, "n0", Vector3(1.62, 4.0, 0.8), Vector3(0, PI / 2 - 0.12, 0), 0.8, 1.0); Geo.decal(n, "arrow", Vector3(0, 4.0, 2.22), Vector3(0.12, 0, 0.4), 0.9, 0.9)
	return n

static func suc_ratazana() -> Geo.N:
	var n := Geo.N.new("c")
	n.put("k", Geo.tor(1.0, 0.42, 8, 22), Vector3(0, 1.42, -1.6), Vector3(0, PI / 2, 0)); n.put("d", Geo.cyl_x(0.5, 0.7, 12), Vector3(0, 1.42, -1.6))
	n.put("k", Geo.tor(0.75, 0.32, 8, 20), Vector3(0, 1.07, 2.4), Vector3(0, PI / 2, 0)); n.put("d", Geo.cyl_x(0.35, 0.5, 10), Vector3(0, 1.07, 2.4))
	for s in [1.0, -1.0]: beam(n, "d", Vector3(s * 0.35, 1.1, 2.4), Vector3(s * 0.3, 2.8, 1.6), 0.14, 0.14)
	n.put("a", Geo.prism([[-1.8, 1.6], [1.4, 1.8], [1.9, 2.6], [0.6, 3.2], [-1.6, 3.0]], 1.0, 0.1)); n.put("b", Geo.bx(1.1, 0.25, 1.6, 0.04), Vector3(0, 3.1, -0.4))
	n.put("w", Geo.prism([[0.5, 3.1], [1.4, 3.0], [0.7, 3.6]], 0.8, 0.03)); n.put("g", Geo.cyl_z(0.2, 0.2, 0.06, 10), Vector3(0, 2.6, 1.95))
	for s in [1.0, -1.0]:
		var sh := Vector3(s * 0.6, 2.9, 0.6); var el := Vector3(s * 1.1, 2.3, 1.3)
		beam(n, "c", sh, el, 0.24, 0.24); n.put("c", Geo.bx(0.3, 0.3, 1.3, 0.04), el + Vector3(0, 0, 0.7))
		n.put("hz", Geo.bx(0.08, 0.35, 1.2, 0.02), el + Vector3(s * 0.18, 0, 0.75))
		Geo.rod(n, "k", Vector3(s * 0.4, 1.8, -1.6), Vector3(s * 0.55, 2.6, -2.6), 0.12)
	for k in 5: n.put("d", Geo.cone(0.08, 0.4, 5), Vector3(-0.4 + k * 0.2, 3.25, -1.2), Vector3(-0.4, 0, 0))
	return n

static func suc_guindasteiro() -> Geo.N:
	var n := Geo.N.new("c")
	for s in [1.0, -1.0]:
		n.put("t", Geo.prism([[-2.4, 0.0], [2.0, 0.0], [2.6, 0.7], [2.0, 1.4], [-2.2, 1.4], [-2.8, 0.7]], 1.0, 0.06), Vector3(s * 1.6, 0, 0))
		for z in [-1.6, 0.0, 1.6]: n.put("d", Geo.cyl_x(0.45, 1.06, 10), Vector3(s * 1.6, 0.5, z))
	n.put("a", Geo.bx(2.4, 1.2, 3.6, 0.1), Vector3(0, 2.0, 0)); n.put("c", Geo.cyl(1.4, 1.5, 0.5, 14), Vector3(0, 2.85, 0))
	n.put("b", Geo.bx(2.0, 1.8, 1.8, 0.1), Vector3(0.4, 4.0, 0.6)); n.put("w", Geo.bx(1.6, 0.6, 0.05, 0.01), Vector3(0.4, 4.3, 1.52))
	n.put("hz", Geo.bx(2.4, 1.6, 1.4, 0.08), Vector3(0, 3.9, -1.6))
	var a := Vector3(-0.6, 3.4, 0.4); var b := Vector3(-1.4, 12.0, 6.0)
	for o in [Vector3(-0.35, 0, -0.35), Vector3(0.35, 0, -0.35), Vector3(0, 0, 0.35)]: Geo.rod(n, "b", a + o, b + o * 0.4, 0.09)
	for k in 8:
		var t := (k + 0.5) / 8.0; var p := a.lerp(b, t)
		Geo.rod(n, "b", p + Vector3(-0.35, 0, -0.35) * (1 - t * 0.6), p + Vector3(0.35, 0, -0.35) * (1 - t * 0.6), 0.05); Geo.rod(n, "b", p + Vector3(0.35, 0, -0.35) * (1 - t * 0.6), p + Vector3(0, 0, 0.35) * (1 - t * 0.6), 0.05)
	Geo.rod(n, "k", b, b + Vector3(0, -6.0, 0), 0.04); n.put("k", Geo.cyl(1.0, 1.0, 0.35, 16), b + Vector3(0, -6.2, 0)); n.put("g", Geo.cyl(0.9, 0.9, 0.05, 16), b + Vector3(0, -6.4, 0))
	n.put("d", Geo.cyl_x(0.3, 0.8, 10), b)
	Geo.rod(n, "k", Vector3(0, 4.6, -1.6), b, 0.03)
	return n

static func _roubada(mat: Material) -> Node3D:
	var b: Dictionary = D.RIVALS[9].build.duplicate(true)
	b.paint = PAINT.SUC.duplicate(); b.paint.a = "#5a6a3a"
	var md: Dictionary = Builder.build_mech(b)
	var root: Node3D = md.root
	var n := Geo.N.new("extra"); var H: float = md.height
	for s in [1.0, -1.0]:
		for k in 3: n.put("d", Geo.cone(0.12, 0.8, 6), Vector3(s * (2.6 + k * 0.3), H - 1.6, -0.3 + k * 0.3), Vector3(0, 0, s * -0.9))
	n.put("k", Geo.tor(0.7, 0.28, 6, 14), Vector3(0, H - 2.4, -1.9), Vector3(PI / 2 - 0.3, 0, 0))
	n.put("b", Geo.bx(1.6, 1.0, 0.08, 0.02), Vector3(0.3, H - 3.2, 1.55), Vector3(0.2, 0.1, 0.25)); n.put("hz", Geo.bx(1.0, 0.6, 0.08, 0.02), Vector3(-0.6, H - 4.0, 1.5), Vector3(-0.1, -0.2, -0.3))
	Geo.rod(n, "k", Vector3(-1.0, H - 1.5, -1.0), Vector3(-1.3, H + 1.2, -1.4), 0.1)
	n.put("b", Geo.bx(0.05, 0.8, 1.1, 0.01), Vector3(-1.3, H + 0.8, -1.95)); Geo.decal(n, "n7", Vector3(-1.27, H + 0.8, -1.95), Vector3(0, PI / 2, 0), 0.5, 0.6)
	root.add_child(n.bake(Mats.mech_material(PAINT.SUC)))
	return root

## Fortaleza com tropas desembarcando pela rampa (Carcaças e um Bastião) para mostrar o porte.
static func _fortaleza_scene(mat: Material) -> Node3D:
	var root := hb_fortaleza().bake(mat)
	var pb: Dictionary = D.STARTER_BUILD.duplicate(true); pb.paint = PAINT.HB.duplicate()
	for q in [[Vector3(-2.2, 4.4, 41.0), 0.1], [Vector3(2.4, 1.2, 46.5), -0.2], [Vector3(-3.0, 0.0, 52.0), 0.4]]:
		var md: Dictionary = Builder.build_mech(pb); md.root.position = q[0]; md.root.rotation.y = q[1]; root.add_child(md.root)
	var bas := hb_bastiao().bake(Mats.mech_material(PAINT.HB)); bas.position = Vector3(13.0, 0, 44.0); bas.rotation.y = -0.4; root.add_child(bas)
	return root

## Heavy Assault: variantes M (corpo a corpo, ocre) e I (tiro, vermelho-óxido) lado a lado.
static func _assalto_scene() -> Node3D:
	var root := Node3D.new()
	var pm: Dictionary = PAINT.HB.duplicate()
	var m := hb_heavy("M").bake(Mats.mech_material(pm)); m.position = Vector3(-4.4, 0, 0); m.rotation.y = 0.2; root.add_child(m)
	var pi: Dictionary = PAINT.HB.duplicate(); pi.b = "#8c3a26"
	var i := hb_heavy("I").bake(Mats.mech_material(pi)); i.position = Vector3(4.6, 0, -0.6); i.rotation.y = -0.15; root.add_child(i)
	return root

## Fênix comum ao lado do Fênix «Sky Lord» (vermelho-laca, dourado e preto).
static func _fenix_scene() -> Node3D:
	var root := Node3D.new()
	var f := tsk_fenix().bake(Mats.mech_material(PAINT.TSK)); f.scale = Vector3.ONE * 1.25; f.position = Vector3(-4.6, 0, 0.4); f.rotation.y = 0.2; root.add_child(f)
	var lord := tsk_skylord().bake(Mats.mech_material({ "a": "#8a1c16", "b": "#c9a227", "c": "#151517", "glow": "#ff7a2a", "wear": 0.12 }))
	lord.scale = Vector3.ONE * 1.3; lord.position = Vector3(5.0, 0, -0.4); lord.rotation.y = -0.15; root.add_child(lord)
	return root
