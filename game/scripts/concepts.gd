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
	"suc_ratazana": 1.7, "suc_guindasteiro": 1.3, "suc_rei": 1.5, "nle_mariposa": 1.4 }

const LIST := [
	["hb_bastiao", "HB"], ["hb_fortaleza", "HB"], ["hb_locomotiva", "HB"], ["hb_morser", "HB"], ["hb_sapador", "HB"], ["hb_inspektor", "HB"],
	["tsk_gaviao", "TSK"], ["tsk_duelista", "TSK"], ["tsk_andorinha", "TSK"], ["tsk_garca", "TSK"], ["tsk_kitsune", "TSK"], ["tsk_fenix", "TSK"],
	["mrs_pastor", "MRS"], ["mrs_enxame", "MRS"], ["mrs_vigia", "MRS"], ["mrs_mula", "MRS"], ["mrs_lince", "MRS"], ["mrs_atendimento", "MRS"],
	["nle_aranha", "NLE"], ["nle_escudeiro", "NLE"], ["nle_vindkraft", "NLE"], ["nle_isbryter", "NLE"], ["nle_mariposa", "NLE"], ["nle_raiz", "NLE"],
	["suc_remendo", "SUC"], ["suc_rei", "SUC"], ["suc_cacamba", "SUC"], ["suc_ratazana", "SUC"], ["suc_guindasteiro", "SUC"], ["suc_roubada", "SUC"],
]

static func build(id: String) -> Node3D:
	var fac: String = "HB"
	for e in LIST:
		if e[0] == id: fac = e[1]
	var mat := Mats.mech_material(PAINT[fac])
	if id == "suc_roubada": return _roubada(mat)
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
	var n := Geo.N.new("c")
	n.put("a", Geo.prism([[-14, 6], [11, 6], [14, 8], [12.5, 11], [-12, 11.5], [-14, 9.5]], 9.0, 0.3))
	n.put("c", Geo.bx(8.0, 0.35, 22, 0.08), Vector3(0, 11.65, -0.5))
	for s in [1.0, -1.0]:
		n.put("b", Geo.bx(0.45, 3.2, 24, 0.08), Vector3(s * 4.7, 7.6, -0.5))
		for z in [-9.0, 0.0, 9.0]:
			leg(n, Vector3(s * 4.6, 7.0, z), Vector3(s * 7.4, 6.2, z + 0.6), Vector3(s * 7.8, 0.6, z), 1.6, 1.3)
			n.put("k", Geo.cyl(1.6, 1.9, 0.6, 12), Vector3(s * 7.8, 0.3, z))
			Geo.piston(n, Vector3(s * 4.8, 9.0, z - 0.8), Vector3(s * 7.2, 6.8, z - 0.8), 0.22)
		n.put("c", Geo.cyl(0.8, 1.0, 5.0, 12), Vector3(s * 2.4, 14.6, -11.2)); n.put("k", Geo.cyl(0.9, 0.9, 0.3, 12), Vector3(s * 2.4, 17.2, -11.2))
		for z in [-11.0, 11.0]:
			n.put("c", Geo.cyl(0.6, 0.7, 0.6, 10), Vector3(s * 3.4, 12.1, z))
			for b in [-0.18, 0.18]: n.put("d", Geo.cyl_z(0.07, 0.07, 1.8, 6), Vector3(s * 3.4 + b, 12.5, z + 0.9))
	for tz in [7.5, -1.5]:
		n.put("c", Geo.cyl(2.4, 2.6, 1.0, 16), Vector3(0, 12.3, tz)); n.put("a", Geo.bx(4.2, 1.9, 4.6, 0.2), Vector3(0, 13.7, tz))
		n.put("hz", Geo.cyl(2.65, 2.65, 0.3, 16), Vector3(0, 12.0, tz))
		for b in [-0.75, 0.75]: n.put("d", Geo.cyl_z(0.34, 0.4, 8.0, 12), Vector3(b, 13.8, tz + 6.0))
	n.put("b", Geo.bx(4.2, 4.6, 3.6, 0.15), Vector3(0, 14.1, -8.0)); n.put("w", Geo.bx(4.3, 0.6, 3.7, 0.03), Vector3(0, 15.4, -8.0))
	n.put("g", Geo.bx(3.6, 0.12, 3.75, 0.01), Vector3(0, 15.4, -8.0))
	Geo.rod(n, "d", Vector3(0, 16.4, -8.4), Vector3(0, 20.5, -8.4), 0.12)
	n.put("d", Geo.sph(1.1, 12, 6, 0, TAU, 0, PI * 0.45), Vector3(0, 19.6, -7.8), Vector3(-0.9, 0, 0))
	n.put("g", Geo.cyl_z(1.8, 1.8, 0.4, 20), Vector3(0, 8.6, -14.1)); n.put("d", Geo.tor(2.0, 0.2, 6, 24), Vector3(0, 8.6, -14.25))
	n.put("b", Geo.prism([[11.5, 6.0], [15.2, 5.4], [14.0, 8.2]], 8.6, 0.2))
	Geo.decal(n, "mkHB", Vector3(4.96, 8.2, 3.0), Vector3(0, PI / 2, 0), 4.0, 1.6)
	return n

static func hb_locomotiva() -> Geo.N:
	var n := Geo.N.new("c")
	n.put("a", Geo.cyl_z(1.6, 1.6, 8.0, 18), Vector3(0, 4.3, 0.2)); n.put("c", Geo.cyl_z(1.72, 1.72, 0.6, 18), Vector3(0, 4.3, 4.3))
	for z in [-2.2, 0.0, 2.2]: n.put("d", Geo.tor(1.62, 0.08, 5, 24), Vector3(0, 4.3, z))
	n.put("hz", Geo.prism([[4.2, 1.0], [6.0, 0.9], [4.6, 3.2], [4.2, 3.4]], 3.6, 0.1))
	n.put("g", Geo.cyl_z(0.4, 0.45, 0.3, 14), Vector3(0, 5.6, 4.7)); n.put("k", Geo.cyl(0.42, 0.58, 1.9, 12), Vector3(0, 6.5, 3.0))
	n.put("b", Geo.bx(3.6, 2.8, 2.6, 0.12), Vector3(0, 5.2, -4.5)); n.put("w", Geo.bx(3.7, 0.7, 1.6, 0.03), Vector3(0, 5.9, -4.3))
	for s in [1.0, -1.0]:
		for z in [-2.6, 2.6]:
			leg(n, Vector3(s * 1.8, 3.6, z), Vector3(s * 2.8, 2.3, z + 0.6), Vector3(s * 2.8, 0.4, z), 0.9, 0.75)
			n.put("k", Geo.bx(1.1, 0.4, 1.6, 0.06), Vector3(s * 2.8, 0.2, z + 0.2))
		for z in [-1.0, 1.0]: n.put("d", Geo.cyl_x(1.05, 0.3, 16), Vector3(s * 1.55, 2.6, z))
		beam(n, "c", Vector3(s * 1.75, 2.6, -1.0), Vector3(s * 1.75, 2.6, 1.0), 0.18, 0.18)
	n.put("c", Geo.cyl(0.9, 1.0, 0.5, 14), Vector3(0, 6.1, -1.2)); n.put("a", Geo.bx(1.8, 0.9, 2.0, 0.08), Vector3(0, 6.7, -1.1))
	for b in [-0.35, 0.35]: n.put("d", Geo.cyl_z(0.16, 0.18, 3.4, 10), Vector3(b, 6.75, 1.4))
	Geo.decal(n, "n7", Vector3(1.83, 5.3, -4.0), Vector3(0, PI / 2, 0), 0.8, 1.0)
	return n

static func hb_morser() -> Geo.N:
	var n := Geo.N.new("c")
	n.put("a", Geo.bx(4.6, 1.5, 5.2, 0.15), Vector3(0, 3.2, 0)); n.put("hz", Geo.bx(4.7, 0.3, 5.3, 0.03), Vector3(0, 2.5, 0))
	for sx in [1.0, -1.0]:
		for sz in [1.0, -1.0]:
			leg(n, Vector3(sx * 2.0, 3.0, sz * 2.2), Vector3(sx * 3.7, 3.9, sz * 3.4), Vector3(sx * 4.3, 0.35, sz * 4.1), 0.8, 0.6)
			n.put("k", Geo.cyl(0.9, 1.05, 0.3, 10), Vector3(sx * 4.3, 0.15, sz * 4.1))
	n.put("c", Geo.bx(2.4, 1.4, 2.2, 0.1), Vector3(0, 4.6, -0.5))
	Geo.rod(n, "c", Vector3(0, 4.7, -0.7), Vector3(0, 8.2, 2.4), 1.05, 18)
	n.put("d", Geo.tor(1.1, 0.16, 6, 20), Vector3(0, 8.2, 2.4), Vector3(PI / 2 - 0.85, 0, 0))
	for s in [1.0, -1.0]: Geo.piston(n, Vector3(s * 1.3, 4.0, -1.3), Vector3(s * 1.2, 6.4, 0.6), 0.14)
	for i in 4: n.put("b", Geo.cyl(0.32, 0.32, 1.2, 10), Vector3(-1.4 + i * 0.32, 4.4, -2.3)); n.put("g", Geo.cone(0.32, 0.35, 10), Vector3(-1.4 + i * 0.32, 5.15, -2.3))
	n.put("b", Geo.bx(1.3, 1.2, 1.3, 0.08), Vector3(1.6, 4.5, 1.9)); n.put("w", Geo.bx(1.32, 0.35, 1.0, 0.02), Vector3(1.6, 4.8, 2.0))
	return n

static func hb_sapador() -> Geo.N:
	var n := Geo.N.new("c")
	for s in [1.0, -1.0]:
		n.put("t", Geo.prism([[-3.0, 0.0], [2.4, 0.0], [3.2, 0.8], [2.6, 1.7], [-2.8, 1.7], [-3.4, 0.8]], 1.2, 0.08), Vector3(s * 2.0, 0, 0))
		for z in [-2.0, -0.7, 0.6, 1.9]: n.put("d", Geo.cyl_x(0.5, 1.28, 12), Vector3(s * 2.0, 0.6, z))
	n.put("a", Geo.bx(3.0, 1.7, 5.4, 0.14), Vector3(0, 2.5, 0))
	n.put("b", Geo.prism([[3.4, 0.2], [4.3, 0.4], [4.0, 2.4], [3.4, 2.6]], 5.6, 0.1)); n.put("hz", Geo.bx(5.7, 0.3, 0.3, 0.03), Vector3(0, 0.5, 4.2))
	n.put("a", Geo.bx(2.4, 2.2, 2.4, 0.15), Vector3(0, 4.4, -0.6)); n.put("w", Geo.bx(1.6, 0.5, 0.1, 0.02), Vector3(0, 4.9, 0.62))
	var sh := Vector3(-1.5, 5.0, -0.2); var el := Vector3(-2.2, 4.2, 2.0); var tip := Vector3(-2.2, 3.4, 4.6)
	joint(n, sh, 0.6); beam(n, "c", sh, el, 0.9, 1.0, 0.08); joint(n, el, 0.55); beam(n, "a", el, tip, 1.1, 1.1, 0.08)
	Geo.piston(n, sh + Vector3(-0.3, 0.7, 0), el + Vector3(-0.3, 0.5, 0), 0.12)
	Geo.rod(n, "d", tip, tip + Vector3(0, -0.3, 2.2), 0.55, 14); n.put("d", Geo.cone(0.55, 1.4, 14), tip + Vector3(0, -0.36, 3.0), Vector3(PI / 2, 0, 0))
	for k in 3: n.put("hz", Geo.tor(0.56, 0.06, 5, 16), tip + Vector3(0, -0.3, 0.6 + k * 0.6), Vector3(PI / 2, 0, 0))
	for s in [1.0, -1.0]: n.put("g", Geo.cyl(0.16, 0.16, 0.25, 8), Vector3(s * 1.0, 5.65, -1.5))
	Geo.decal(n, "warn", Vector3(1.51, 2.6, 0.6), Vector3(0, PI / 2, 0), 1.6, 0.75)
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

static func tsk_garca() -> Geo.N:
	var n := Geo.N.new("c")
	for s in [1.0, -1.0]:
		leg(n, Vector3(s * 0.7, 10.2, 0), Vector3(s * 0.95, 5.6, 1.4), Vector3(s * 0.95, 0.3, -0.1), 0.42, 0.34)
		for t in [-0.35, 0.0, 0.35]: beam(n, "c", Vector3(s * 0.95, 0.25, -0.1), Vector3(s * 0.95 + t, 0.08, 1.1), 0.1, 0.08, 0.01)
		beam(n, "c", Vector3(s * 0.95, 0.25, -0.1), Vector3(s * 0.95, 0.08, -0.9), 0.1, 0.08, 0.01)
	n.put("a", Geo.prism([[-0.9, 10.0], [0.8, 10.0], [1.2, 10.9], [0.5, 11.6], [-1.0, 11.4]], 1.4, 0.08))
	Geo.rod(n, "d", Vector3(0, 11.5, 0.3), Vector3(0, 12.4, 0.6), 0.12)
	n.put("c", Geo.bx(0.4, 0.35, 0.6, 0.04), Vector3(0, 12.55, 0.7)); n.put("a", Geo.prism([[0.9, 12.5], [2.2, 12.45], [0.9, 12.7]], 0.22, 0.02))
	n.put("g", Geo.cyl_z(0.07, 0.07, 0.04, 8), Vector3(0.14, 12.6, 1.01))
	n.put("c", Geo.bx(0.5, 0.5, 2.4, 0.05), Vector3(-0.9, 11.7, -0.2)); n.put("d", Geo.cyl_z(0.12, 0.14, 7.8, 10), Vector3(-0.9, 11.75, 4.7))
	n.put("b", Geo.bx(0.36, 0.36, 0.8, 0.04), Vector3(-0.9, 11.75, 8.6)); n.put("w", Geo.cyl_z(0.16, 0.16, 1.2, 10), Vector3(-0.9, 12.15, 0.6))
	for s in [1.0, -1.0]: beam(n, "c", Vector3(s * 0.75, 11.0, 0.2), Vector3(s * 0.9, 10.0, 1.1), 0.22, 0.22); beam(n, "a", Vector3(s * 0.9, 10.0, 1.1), Vector3(-0.6, 11.4, 2.0), 0.2, 0.2)
	n.put("b", Geo.bx(1.6, 0.08, 0.8, 0.02), Vector3(0, 11.5, -0.9), Vector3(0.3, 0, 0))
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

static func nle_vindkraft() -> Geo.N:
	var n := Geo.N.new("c")
	for s in [1.0, -1.0]: leg(n, Vector3(s * 0.9, 5.0, 0), Vector3(s * 1.0, 2.7, 0.4), Vector3(s * 1.0, 0.4, 0), 0.75, 0.62); n.put("k", Geo.bx(1.0, 0.35, 1.8, 0.05), Vector3(s * 1.0, 0.18, 0.25))
	n.put("a", Geo.prism([[-1.0, 5.0], [1.0, 5.0], [1.2, 7.4], [-1.1, 7.6]], 2.4, 0.12)); n.put("c", Geo.bx(1.2, 0.8, 0.9, 0.06), Vector3(0, 8.0, 0.4)); n.put("g", Geo.bx(0.8, 0.12, 0.05, 0.01), Vector3(0, 8.05, 0.86))
	Geo.rod(n, "c", Vector3(0, 6.8, -1.0), Vector3(0, 9.2, -1.6), 0.35); n.put("cer", Geo.cyl_z(0.55, 0.6, 2.0, 14), Vector3(0, 9.5, -1.4)); n.put("d", Geo.cone(0.55, 0.9, 14), Vector3(0, 9.5, -2.85), Vector3(-PI / 2, 0, 0))
	for k in 3: n.put("cer", Geo.prism([[0.0, 0.3], [5.6, 0.12], [5.8, -0.05], [0.0, -0.3]], 0.12, 0.02, "z"), Vector3(0, 9.5, -2.5), Vector3(0, 0, k * TAU / 3 + 0.4))
	for s in [1.0, -1.0]:
		var sh := Vector3(s * 1.5, 7.0, 0); var el := Vector3(s * 1.8, 5.6, 0.6)
		joint(n, sh, 0.4); beam(n, "a", sh, el, 0.5, 0.55); beam(n, "c", el, el + Vector3(0, -0.4, 1.4), 0.45, 0.5)
		for k in 4: n.put("d", Geo.tor(0.3 - k * 0.04, 0.06, 5, 12), el + Vector3(0, -0.4 + k * 0.32, 1.6), Vector3(PI / 2, 0, 0))
		n.put("g", Geo.sph(0.2, 8, 6), el + Vector3(0, 0.95, 1.6))
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
