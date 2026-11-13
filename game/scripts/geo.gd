## Geometria procedural: primitivas (chanfro, extrusão, cilindro, esfera, toro…) e o nó de construção N,
## que funde todas as peças rígidas de um nó numa única malha. O material de cada face é codificado
## na cor do vértice (canal R = índice do "slot"), então cada nó vira UMA chamada de desenho.
class_name Geo

# slots de material das carcaças
const SLOT := { "a": 0, "b": 1, "c": 2, "d": 3, "k": 4, "w": 5, "cer": 6, "g": 7, "hz": 8, "t": 9, "dc": 10 }

## Dados de geometria crus (triângulos em ordem anti-horária, como no three.js; invertidos no bake).
class GD:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	func tri(a: Vector3, b: Vector3, c: Vector3, na = null, nb = null, nc = null) -> void:
		v.append(a); v.append(b); v.append(c)
		if na == null:
			var nn := (b - a).cross(c - a).normalized()
			n.append(nn); n.append(nn); n.append(nn)
		else:
			n.append(na); n.append(nb); n.append(nc)
		uv.append(Vector2.ZERO); uv.append(Vector2.ZERO); uv.append(Vector2.ZERO)
	## triângulo com normais suaves, orientado para concordar com elas
	func stri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
		if (b - a).cross(c - a).dot(na + nb + nc) < 0: tri(a, c, b, na, nc, nb)
		else: tri(a, b, c, na, nb, nc)
	## triângulo plano orientado para a normal esperada
	func ntri(a: Vector3, b: Vector3, c: Vector3, ne: Vector3) -> void:
		if (b - a).cross(c - a).dot(ne) < 0: tri(a, c, b)
		else: tri(a, b, c)
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		tri(a, b, c); tri(a, c, d)
	## quad convexo orientado para fora (a partir da origem)
	func oquad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		if (b - a).cross(c - a).dot(a + b + c + d) < 0: quad(d, c, b, a)
		else: quad(a, b, c, d)
	func otri(a: Vector3, b: Vector3, c: Vector3) -> void:
		if (b - a).cross(c - a).dot(a + b + c) < 0: tri(c, b, a)
		else: tri(a, b, c)

static func euler(r: Vector3) -> Basis:
	return Basis(Vector3.RIGHT, r.x) * Basis(Vector3.UP, r.y) * Basis(Vector3.BACK, r.z)

# ───────── primitivas ─────────
static func bx(w: float, h: float, d: float, b: float = 0.05) -> GD:
	var g := GD.new()
	b = minf(b, minf(w * 0.45, minf(h * 0.45, d * 0.45)))
	var hw := w / 2.0; var hh := h / 2.0; var hd := d / 2.0
	if b < 0.002:
		for s in [-1.0, 1.0]:
			g.oquad(Vector3(s * hw, -hh, -hd), Vector3(s * hw, hh, -hd), Vector3(s * hw, hh, hd), Vector3(s * hw, -hh, hd))
			g.oquad(Vector3(-hw, s * hh, -hd), Vector3(hw, s * hh, -hd), Vector3(hw, s * hh, hd), Vector3(-hw, s * hh, hd))
			g.oquad(Vector3(-hw, -hh, s * hd), Vector3(hw, -hh, s * hd), Vector3(hw, hh, s * hd), Vector3(-hw, hh, s * hd))
		return g
	var P := func(sx, sy, sz, t): # t: 0 = ponto da face X, 1 = Y, 2 = Z
		if t == 0: return Vector3(sx * hw, sy * (hh - b), sz * (hd - b))
		if t == 1: return Vector3(sx * (hw - b), sy * hh, sz * (hd - b))
		return Vector3(sx * (hw - b), sy * (hh - b), sz * hd)
	for s in [-1.0, 1.0]:
		g.oquad(P.call(s, -1, -1, 0), P.call(s, 1, -1, 0), P.call(s, 1, 1, 0), P.call(s, -1, 1, 0))
		g.oquad(P.call(-1, s, -1, 1), P.call(1, s, -1, 1), P.call(1, s, 1, 1), P.call(-1, s, 1, 1))
		g.oquad(P.call(-1, -1, s, 2), P.call(1, -1, s, 2), P.call(1, 1, s, 2), P.call(-1, 1, s, 2))
	for sa in [-1.0, 1.0]:
		for sb in [-1.0, 1.0]:
			# arestas paralelas a Z (entre faces X e Y), a X (Y-Z) e a Y (X-Z)
			g.oquad(P.call(sa, sb, -1, 0), P.call(sa, sb, 1, 0), P.call(sa, sb, 1, 1), P.call(sa, sb, -1, 1))
			g.oquad(P.call(-1, sa, sb, 1), P.call(1, sa, sb, 1), P.call(1, sa, sb, 2), P.call(-1, sa, sb, 2))
			g.oquad(P.call(sa, -1, sb, 0), P.call(sa, 1, sb, 0), P.call(sa, 1, sb, 2), P.call(sa, -1, sb, 2))
			for sc in [-1.0, 1.0]:
				g.otri(P.call(sa, sb, sc, 0), P.call(sa, sb, sc, 1), P.call(sa, sb, sc, 2))
	return g

## Extrusão de um perfil 2D. axis "x": pts=(z,y) extrusão em X · "z": pts=(x,y) em Z · "y": pts=(x,z) em Y
static func prism(pts: Array, depth: float, b: float = 0.04, axis: String = "x") -> GD:
	var g := GD.new()
	var P := PackedVector2Array()
	for q in pts: P.append(Vector2(q[0], q[1]))
	# remove pontos repetidos e garante sentido anti-horário
	var area := 0.0
	for i in P.size(): area += P[i].x * P[(i + 1) % P.size()].y - P[(i + 1) % P.size()].x * P[i].y
	if area < 0: P.reverse()
	var n := P.size()
	b = minf(b, depth * 0.45)
	# recuo por esquadria para o chanfro
	var inset := PackedVector2Array()
	for i in n:
		var a := P[(i - 1 + n) % n]; var c := P[i]; var e := P[(i + 1) % n]
		var n1 := Vector2((c - a).y, -(c - a).x).normalized(); var n2 := Vector2((e - c).y, -(e - c).x).normalized()
		var m := (n1 + n2)
		if m.length() < 1e-4: m = n1
		m = m.normalized(); var cs := maxf(0.4, m.dot(n1))
		inset.append(c - m * minf(b / cs, b * 2.5))
	var M := func(q: Vector2, wv: float) -> Vector3:
		if axis == "z": return Vector3(q.x, q.y, wv)
		if axis == "x": return Vector3(-wv, q.y, q.x)
		return Vector3(q.x, -wv, q.y)
	var hd := depth / 2.0; var hi := hd - b
	var tris := Geometry2D.triangulate_polygon(inset if b > 0.002 else P)
	var cap: PackedVector2Array = inset if b > 0.002 else P
	var ct := hd if b > 0.002 else hd
	for i in range(0, tris.size(), 3):
		var A := cap[tris[i]]; var B := cap[tris[i + 1]]; var C := cap[tris[i + 2]]
		var nf: Vector3 = M.call(Vector2.ZERO, 1.0)
		g.ntri(M.call(A, ct), M.call(B, ct), M.call(C, ct), nf)
		g.ntri(M.call(C, -ct), M.call(B, -ct), M.call(A, -ct), -nf)
	var zw := hi if b > 0.002 else hd
	for i in n:
		var a := P[i]; var c := P[(i + 1) % n]
		g.tri(M.call(a, -zw), M.call(c, -zw), M.call(c, zw)); g.tri(M.call(a, -zw), M.call(c, zw), M.call(a, zw))
		if b > 0.002:
			var ia := inset[i]; var ic := inset[(i + 1) % n]
			g.tri(M.call(a, zw), M.call(c, zw), M.call(ic, hd)); g.tri(M.call(a, zw), M.call(ic, hd), M.call(ia, hd))
			g.tri(M.call(ia, -hd), M.call(ic, -hd), M.call(c, -zw)); g.tri(M.call(ia, -hd), M.call(c, -zw), M.call(a, -zw))
	return g

static func cyl(rt: float, rb: float, h: float, seg: int = 14, open_ended: bool = false) -> GD:
	var g := GD.new(); var hh := h / 2.0
	var slope := (rb - rt) / h
	for i in seg:
		var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
		var s0 := Vector3(sin(a0), 0, cos(a0)); var s1 := Vector3(sin(a1), 0, cos(a1))
		var n0 := Vector3(s0.x, slope, s0.z).normalized(); var n1 := Vector3(s1.x, slope, s1.z).normalized()
		var t0 := s0 * rt + Vector3(0, hh, 0); var t1 := s1 * rt + Vector3(0, hh, 0); var b0 := s0 * rb - Vector3(0, hh, 0); var b1 := s1 * rb - Vector3(0, hh, 0)
		if rt > 0.0001:
			g.stri(t0, b0, b1, n0, n0, n1); g.stri(t0, b1, t1, n0, n1, n1)
		else:
			g.stri(t0, b0, b1, (n0 + n1).normalized(), n0, n1)
		if not open_ended:
			if rt > 0.0001: g.tri(Vector3(0, hh, 0), t0, t1, Vector3.UP, Vector3.UP, Vector3.UP)
			if rb > 0.0001: g.tri(Vector3(0, -hh, 0), b1, b0, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN)
	return g

static func _xf(g: GD, bs: Basis) -> GD:
	for i in g.v.size(): g.v[i] = bs * g.v[i]; g.n[i] = bs * g.n[i]
	return g
static func cyl_x(r: float, h: float, seg: int = 14) -> GD: return _xf(cyl(r, r, h, seg), Basis(Vector3.BACK, PI / 2))
static func cyl_z(rt: float, rb: float, h: float, seg: int = 14) -> GD: return _xf(cyl(rt, rb, h, seg), Basis(Vector3.RIGHT, PI / 2))
static func cone(r: float, h: float, seg: int = 12) -> GD: return cyl(0.0, r, h, seg)

## Esfera com os mesmos parâmetros do three.js (phi = volta horizontal, theta = do polo norte para baixo).
static func sph(r: float, ws: int = 14, hs: int = 10, phi0: float = 0.0, phil: float = TAU, th0: float = 0.0, thl: float = PI) -> GD:
	var g := GD.new()
	var V := func(i, j) -> Vector3:
		var ph: float = phi0 + phil * i / ws; var th: float = th0 + thl * j / hs
		return Vector3(-cos(ph) * sin(th), cos(th), sin(ph) * sin(th))
	for j in hs:
		for i in ws:
			var a: Vector3 = V.call(i, j); var b: Vector3 = V.call(i, j + 1); var c: Vector3 = V.call(i + 1, j + 1); var d: Vector3 = V.call(i + 1, j)
			if j > 0 or th0 > 0.0: g.stri(a * r, b * r, d * r, a, b, d)
			if j < hs - 1 or th0 + thl < PI - 0.001: g.stri(b * r, c * r, d * r, b, c, d)
	return g

static func ico(r: float, detail: int = 0) -> GD:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var vs := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var fs := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var tris := []
	for f in fs: tris.append([vs[f[0]].normalized(), vs[f[1]].normalized(), vs[f[2]].normalized()])
	for k in detail:
		var nt := []
		for tr in tris:
			var a: Vector3 = tr[0]; var b: Vector3 = tr[1]; var c: Vector3 = tr[2]
			var ab := (a + b).normalized(); var bc := (b + c).normalized(); var ca := (c + a).normalized()
			nt.append_array([[a, ab, ca], [ab, b, bc], [ca, bc, c], [ab, bc, ca]])
		tris = nt
	var g := GD.new()
	for tr in tris: g.otri(tr[0] * r, tr[1] * r, tr[2] * r)
	return g

## Toro no plano XY (como o three.js), com arco opcional.
static func tor(R: float, r: float, rs: int = 8, ts: int = 20, arc: float = TAU) -> GD:
	var g := GD.new()
	var V := func(i, j) -> Array:
		var u: float = arc * i / ts; var v: float = TAU * j / rs
		var c := Vector3(cos(u), sin(u), 0.0)
		var nn := c * cos(v) + Vector3(0, 0, sin(v))
		return [c * R + nn * r, nn]
	for i in ts:
		for j in rs:
			var a: Array = V.call(i, j); var b: Array = V.call(i + 1, j); var c: Array = V.call(i + 1, j + 1); var d: Array = V.call(i, j + 1)
			g.stri(a[0], b[0], d[0], a[1], b[1], d[1]); g.stri(b[0], c[0], d[0], b[1], c[1], d[1])
	return g

## Plano no XY voltado para +Z, com retângulo de UV (u0, v0 = canto superior esquerdo; u1, v1 = inferior direito).
static func plane(w: float, h: float, uvr = null) -> GD:
	var g := GD.new(); var hw := w / 2.0; var hh := h / 2.0
	g.quad(Vector3(-hw, -hh, 0), Vector3(hw, -hh, 0), Vector3(hw, hh, 0), Vector3(-hw, hh, 0))
	if uvr != null:
		var u0: float = uvr[0]; var v0: float = uvr[1]; var u1: float = uvr[2]; var v1: float = uvr[3]
		g.uv = PackedVector2Array([Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0), Vector2(u0, v1), Vector2(u1, v0), Vector2(u0, v0)])
	return g

## Anel deitado no chão (voltado para +Y).
static func ring(r0: float, r1: float, seg: int = 48) -> GD:
	var g := GD.new()
	for i in seg:
		var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
		var p0 := Vector3(cos(a0), 0, sin(a0)); var p1 := Vector3(cos(a1), 0, sin(a1))
		g.tri(p0 * r0, p1 * r1, p0 * r1, Vector3.UP, Vector3.UP, Vector3.UP); g.tri(p0 * r0, p1 * r0, p1 * r1, Vector3.UP, Vector3.UP, Vector3.UP)
	# garante a face para cima
	for i in range(0, g.v.size(), 3):
		if (g.v[i + 1] - g.v[i]).cross(g.v[i + 2] - g.v[i]).y < 0:
			var t := g.v[i + 1]; g.v[i + 1] = g.v[i + 2]; g.v[i + 2] = t
	return g

# ───────── nó de construção ─────────
class N:
	var g: Node3D
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var kids: Array = []
	var m := {}
	var dim := {}
	var extra := {}
	# referências usadas pela animação e pelas armas
	var hipY := 0.0
	var type := ""
	var anim = null
	var thr: Array = []
	var noz: Array = []
	var drones: Array = []
	var blade: Node3D = null
	var spike: Node3D = null
	var pv: Node3D = null
	var spin: Node3D = null
	var spinY: Node3D = null
	var claw: Node3D = null
	var el = null
	var fixed = false
	var stow := 0.0
	var out = 0
	var fv = 0
	var slots := Geo.SLOT
	var div := 16.0
	func _init(name: String = "", _x = null) -> void:
		g = Node3D.new(); g.name = name if name != "" else "n"
	## Adiciona geometria com posição p, rotação r (euler XYZ) e escala s.
	func put(slot, geo: Geo.GD, p: Vector3 = Vector3.ZERO, r: Vector3 = Vector3.ZERO, s = 1.0) -> N:
		var sc: Vector3 = s if s is Vector3 else (Vector3(s[0], s[1], s[2]) if s is Array else Vector3(s, s, s))
		var bs := Geo.euler(r) * Basis.from_scale(sc)
		var nb := bs.inverse().transposed()
		var si: int = slots[slot] if slot is String else int(slot)
		var c := Color(si / div, 0, 0, 1)
		var off := 0.0
		if slot is String and slot == "dc": off = 0.018
		for i in geo.v.size():
			var nn := (nb * geo.n[i]).normalized()
			v.append(bs * geo.v[i] + p + nn * off); nr.append(nn); uv.append(geo.uv[i]); col.append(c)
		return self
	func translate_all(d: Vector3) -> void:
		for i in v.size(): v[i] += d
	func child(name: String, p: Vector3 = Vector3.ZERO, r: Vector3 = Vector3.ZERO) -> N:
		var n := N.new(name); n.slots = slots; n.div = div
		n.g.position = p; n.g.basis = Geo.euler(r)
		g.add_child(n.g); kids.append(n); return n
	func attach(n: N, p = null, r = null) -> N:
		if p != null: n.g.position = p
		if r != null: n.g.basis = Geo.euler(r)
		g.add_child(n.g); kids.append(n); return n
	func mount(name: String, p: Vector3 = Vector3.ZERO, r: Vector3 = Vector3.ZERO) -> Node3D:
		var o := Node3D.new(); o.name = name; o.position = p; o.basis = Geo.euler(r)
		g.add_child(o); m[name] = o; return o
	## Funde a geometria acumulada em uma malha (um material) e repete nos filhos.
	func bake(mat: Material, shadow: bool = true) -> Node3D:
		if v.size() > 0:
			# inverte a ordem dos vértices: o Godot considera horário como face frontal
			for i in range(0, v.size(), 3):
				var t := v[i + 1]; v[i + 1] = v[i + 2]; v[i + 2] = t
				var tn := nr[i + 1]; nr[i + 1] = nr[i + 2]; nr[i + 2] = tn
				var tu := uv[i + 1]; uv[i + 1] = uv[i + 2]; uv[i + 2] = tu
			var arr := []; arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = nr; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_COLOR] = col
			var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			am.surface_set_material(0, mat)
			var mi := MeshInstance3D.new(); mi.mesh = am; mi.name = "mesh"
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(mi)
			v = PackedVector3Array(); nr = PackedVector3Array(); uv = PackedVector2Array(); col = PackedColorArray()
		for k in kids: k.bake(mat, shadow)
		return g

# ───────── detalhes reutilizáveis ─────────
static func vent(n: N, slot, p: Vector3, w: float, h: float, count: int, tilt: float = 0.5, axis: String = "z") -> void:
	var st := h / count
	for i in count:
		var y := p.y - h / 2.0 + st * (i + 0.5)
		if axis == "z": n.put(slot, bx(w, st * 0.45, 0.14, 0.01), Vector3(p.x, y, p.z), Vector3(tilt, 0, 0))
		else: n.put(slot, bx(0.14, st * 0.45, w, 0.01), Vector3(p.x, y, p.z), Vector3(0, 0, tilt))

static func bolts(n: N, slot, pts: Array, r: float = 0.05, axis: String = "z") -> void:
	for q in pts:
		var gg := cyl_z(r, r, 0.08, 6) if axis == "z" else (cyl_x(r, 0.08, 6) if axis == "x" else cyl(r, r, 0.08, 6))
		n.put(slot, gg, q)

static func rod(n: N, slot, a: Vector3, b: Vector3, r: float = 0.06, seg: int = 8) -> void:
	var len := a.distance_to(b)
	if len < 1e-4: return
	var gg := cyl(r, r, len, seg)
	var dir := (b - a) / len
	var axis := Vector3.UP.cross(dir)
	var bs := Basis.IDENTITY
	if axis.length() > 1e-5: bs = Basis(axis.normalized(), acos(clampf(Vector3.UP.dot(dir), -1, 1)))
	elif dir.y < 0: bs = Basis(Vector3.RIGHT, PI)
	_xf(gg, bs)
	n.put(slot, gg, (a + b) * 0.5)

static func piston(n: N, a: Vector3, b: Vector3, r: float = 0.09) -> void:
	var mm := a.lerp(b, 0.55)
	rod(n, "c", a, mm, r * 1.5); rod(n, "d", mm, b, r)

# ───────── atlas de decalques (gerado em tempo de execução) ─────────
const DEC_SIZE := 1024
static var DEC := {}
static func dec_rect(name: String, px: float, py: float, w: float, h: float) -> void:
	DEC[name] = [px / DEC_SIZE, py / DEC_SIZE, (px + w) / DEC_SIZE, (py + h) / DEC_SIZE]
static func dec_layout() -> void:
	if not DEC.is_empty(): return
	for i in 10: dec_rect("n%d" % i, (i % 5) * 96, floor(i / 5.0) * 128, 96, 128)
	var ks := ["QF", "HB", "TSK", "MRS", "NLE"]
	for i in ks.size(): dec_rect("mk" + ks[i], 480 + (i % 2) * 272, floor(i / 2.0) * 110, 256, 100)
	dec_rect("warn", 0, 270, 256, 120); dec_rect("step", 0, 400, 256, 60); dec_rect("arrow", 270, 270, 120, 120)
	dec_rect("bar", 0, 470, 256, 56); dec_rect("lift", 270, 400, 150, 60); dec_rect("band", 0, 540, 512, 40); dec_rect("tick", 0, 590, 256, 40)
static func decal(n: N, name: String, p: Vector3, r: Vector3, w: float, h: float) -> void:
	dec_layout(); n.put("dc", plane(w, h, DEC[name]), p, r)
