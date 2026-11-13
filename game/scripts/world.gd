## Mundo de combate: projéteis, mísseis, explosões, drones, raios e colisão entre carcaças.
class_name World extends Node3D

var arena: Arena
var mods := {}
var fx: FX
var mechs: Array = []
var projs: Array = []
var drones: Array = []
var events: Array = []
var time := 0.0
var cam_pos := Vector3.ZERO

func setup(a: Arena, m: Dictionary) -> void:
	arena = a; mods = m; add_child(a)
	if mods.get("lowgrav", false): arena.grav = 0.45
	fx = FX.new(); add_child(fx); fx.setup()

func emit(e: Dictionary) -> void: events.append(e)
func add(m: Mech) -> Mech: mechs.append(m); return m

func shoot(p: Dictionary) -> Dictionary:
	p.merge({ "st": null, "spl": 0.0, "grav": 0.0, "rng": 400.0, "target": null, "mk": "", "sub": 0, "charged": false, "seed": 0.0, "vsShield": 0, "turn": 0.0, "spd": 0.0, "def": {} }, false)
	p.travel = 0.0; p.life = p.get("life", 5.0); p.trail = p.get("trail", 14.0); p.t = 0.0; p.smoke_t = 0.0; p.dead = false
	var c: Color = p.get("col", Color("#ffd9a0")); p.col = Color(c.r, c.g, c.b, 1.0)
	projs.append(p); return p

## Raio contra as zonas de acerto das carcaças de outra equipe.
func ray_mechs(o: Vector3, d: Vector3, max_d: float, team: int, skip):
	var best = null; var bt := max_d
	for m in mechs:
		if not m.alive or m.team == team or m == skip: continue
		var cc: Vector3 = Vector3(m.pos.x, m.pos.y + m.height * 0.5, m.pos.z) - o
		var proj := cc.dot(d); var R: float = m.height * 0.75 + 2
		if proj < -R or proj > bt + R: continue
		if (cc - d * proj).length_squared() > R * R: continue
		for z in m.model.hz:
			if z.part != "legs" and z.part != "core" and m.parts[z.part].state == 2: continue
			var zc: Vector3 = m.pos + (z.o * m.scale).rotated(Vector3.UP, m.yaw); var r: float = z.r * m.scale
			var oc := o - zc; var b := oc.dot(d); var c := oc.length_squared() - r * r; var disc := b * b - c
			if disc < 0: continue
			var t := -b - sqrt(disc)
			if t < 0:
				if c < 0: t = 0
				else: continue
			if t < bt: bt = t; best = { "t": t, "mech": m, "part": z.part }
	return best

func hitscan(o: Vector3, d: Vector3, max_d: float, team: int) -> Dictionary:
	var t: float = arena.ray(o, d, max_d); var ob = arena.hit_ob
	var mh = ray_mechs(o, d, minf(max_d, t), team, null)
	if mh != null: return { "t": mh.t, "mech": mh.mech, "part": mh.part, "ob": null }
	return { "t": minf(t, max_d), "mech": null, "part": "", "ob": ob if t < max_d else null }

func damage_obstacle(ob, dmg: float, owner) -> void:
	if not (ob is Dictionary) or not ob.has("hp") or not ob.alive: return
	ob.hp -= dmg
	if ob.hp <= 0:
		ob.alive = false
		if ob.has("node") and is_instance_valid(ob.node): ob.node.visible = false
		var c: Vector3 = (ob.min + ob.max) * 0.5
		if ob.has("explosive"):
			explode(c, ob.explosive.r, ob.explosive.dmg, "x", ob.explosive.imp, null, { "heat": 60 }, -1, true)
			fx.spawn_debris(c, 16, Color("#d6d2c6"), 40, 1.4)

func explode(p: Vector3, r: float, dmg: float, dt: String, imp: float, owner, st, team: int, big := false, skip = null) -> void:
	var col := Color("#ffb060")
	if dt == "e": col = Color(owner.model.mat.get_shader_parameter("glow")) if owner != null else Color("#8fe6ff")
	fx.explosion(p, r, col, big or r > 12)
	Sfx.play("bigexplosion" if r > 12 else "explosion", p, clampf(r / 9.0, 0.5, 1.3))
	fx.add_shake(clampf(r * 3.5 / (12 + p.distance_to(cam_pos)), 0, 0.8))
	for m in mechs:
		if not m.alive or m.team == team or m == skip: continue
		var bd := 1e9; var bp := "core"
		for z in m.model.hz:
			var dd: float = m.part_pos(z.part).distance_to(p) - z.r * m.scale
			if dd < bd: bd = dd; bp = z.part
		if bd > r: continue
		if not arena.los(Vector3(p.x, maxf(p.y, 1.5), p.z), m.center()): continue
		var f := 1 - 0.65 * maxf(0.0, bd) / r
		m.take_hit({ "dmg": dmg * f, "dt": dt, "imp": imp * f, "part": bp, "from": p, "owner": owner, "st": st, "quiet": true })
		if m.alive:
			var pd: Vector3 = m.pos - p; pd.y = 0
			m.vel += pd.normalized() * clampf(dmg * f / m.weight * 0.9, 0, 26)
	for o in arena.obstacles:
		if o.alive and o.has("hp"):
			var cx: float = (o.min.x + o.max.x) / 2; var cz: float = (o.min.z + o.max.z) / 2
			if Vector2(cx - p.x, cz - p.z).length() < r + 5: damage_obstacle(o, dmg, owner)

func clear_projectiles_near(c: Vector3, r: float, team: int) -> void:
	for p in projs:
		if p.team != team and p.pos.distance_to(c) < r: p.dead = true; fx.sparks(p.pos, 4, Color("#9fe0ff"), 10)

func flare(m: Mech) -> void:
	var c := m.center()
	for i in 10:
		var a := randf() * TAU; fx.emit_add(c + Vector3(0, 3, 0), Vector3(cos(a) * 26, 14 + randf() * 12, sin(a) * 26), 1.6 + randf(), 3.0, 1.0, Color(1, 0.8, 0.47), 3.0, 1.2, 16.0)
	fx.light(c, Color("#ffe0a0"), 80, 0.5)
	for p in projs:
		if p.pk == "missile" and p.get("target") == m and p.get("mk") != "guided" and randf() < 0.8 and p.pos.distance_to(c) < 160: p.target = null; p.vel.y += 20

func emp(m: Mech, d: Dictionary) -> void:
	var c := m.center(); fx.orb(c, Color("#9fe8ff"), d.rad, 0.5); fx.ring(c, Color("#9fe8ff"), d.rad, 0.5); fx.sparks(c, 50, Color("#bfe8ff"), 50); Sfx.play("emp", c, 1); fx.light(c, Color("#9fe8ff"), 150, 0.4)
	for e in mechs:
		if e.team == m.team or not e.alive: continue
		if e.center().distance_to(c) < d.rad + e.radius:
			e.take_hit({ "dmg": d.dmg, "dt": "e", "imp": 200, "part": "core", "from": c, "owner": m, "vsShield": 5 }); e.add_status("shock", d.shock)
	clear_projectiles_near(c, d.rad * 0.7, m.team)

func spawn_drone(owner: Mech, tgt: Mech, def: Dictionary, p: Vector3, i: int) -> void:
	var mesh := Builder.build_drone(owner.model.mat); add_child(mesh); mesh.position = p
	drones.append({ "owner": owner, "target": tgt, "def": def, "mesh": mesh, "pos": p, "vel": Vector3((randf() - 0.5) * 20, 30, (randf() - 0.5) * 20), "life": float(def.life), "cd": 0.8 + i * 0.25, "ang": i * 2.1 + randf(), "rad": 26.0 + i * 5, "h": 11.0 + i * 3, "dir": 1.0 if i % 2 else -1.0 })

func tick(dt: float) -> void:
	time += dt
	for m in mechs: m.update(dt)
	# separação entre carcaças
	for i in mechs.size():
		for j in range(i + 1, mechs.size()):
			var a: Mech = mechs[i]; var b: Mech = mechs[j]
			if not a.alive or not b.alive: continue
			var dx := b.pos.x - a.pos.x; var dz := b.pos.z - a.pos.z; var d := sqrt(dx * dx + dz * dz); var mn := a.radius + b.radius
			if d >= mn or absf(a.pos.y - b.pos.y) > maxf(a.height, b.height) * 0.8: continue
			var nx := dx / d if d > 0.01 else 1.0; var nz := dz / d if d > 0.01 else 0.0; var push := mn - d; var wa := b.weight / (a.weight + b.weight)
			a.pos.x -= nx * push * wa; a.pos.z -= nz * push * wa; b.pos.x += nx * push * (1 - wa); b.pos.z += nz * push * (1 - wa)
	# projéteis
	var i := projs.size() - 1
	while i >= 0:
		var p = projs[i]; p.t += dt; p.life -= dt
		if p.dead or p.life <= 0:
			if p.spl and not p.dead and p.pk != "missile": explode(p.pos, p.spl, p.dmg, p.dt, p.imp, p.owner, p.st, p.team)
			projs.remove_at(i); i -= 1; continue
		if p.pk == "missile": steer(p, dt)
		if p.grav: p.vel.y -= p.grav * dt
		var sp: float = p.vel.length(); var len := sp * dt; var dir: Vector3 = p.vel / maxf(1e-6, sp)
		var tA: float = arena.ray(p.pos, dir, len); var ob = arena.hit_ob
		var mh = ray_mechs(p.pos, dir, minf(len, tA), p.team, null)
		var prox := false
		var tg = p.get("target")
		if mh == null and p.spl and tg != null and tg.alive and p.pk == "missile":
			if tg.center().distance_to(p.pos) < 3.2 + tg.radius * 0.6: prox = true
		if p.get("sub", 0) and tg != null and tg.alive and p.t > 0.6 and tg.center().distance_to(p.pos) < 60:
			split(p); projs.remove_at(i); i -= 1; continue
		if mh != null or prox:
			var pt: Vector3 = p.pos + dir * (mh.t if mh != null else 0.0)
			var fall := 1.0 if (p.pk == "missile" or p.spl) else (1.0 if p.travel <= p.rng else maxf(0.35, 1 - (p.travel - p.rng) / (p.rng * 0.8)))
			if mh != null: mh.mech.take_hit({ "dmg": p.dmg * fall, "dt": p.dt, "imp": p.imp * (fall * 0.6 if fall < 1 else 1.0), "part": mh.part, "from": p.owner.pos if p.owner != null else p.pos, "owner": p.owner, "st": p.st, "point": pt, "vsShield": p.get("vsShield", 0) })
			if p.spl: explode(pt, p.spl, p.dmg * 0.6, p.dt, p.imp * 0.5, p.owner, p.st, p.team, false, mh.mech if mh != null else null)
			else:
				fx.sparks(pt, 3 if fall < 1 else 7, Color("#aaaaaa") if fall < 1 else (p.col if p.dt == "e" else Color("#ffd28a")), 22, -dir * 0.4)
				if p.dmg > 500: fx.explosion(pt, 3, Color("#ffd28a"))
			projs.remove_at(i); i -= 1; continue
		if tA != INF:
			var pt: Vector3 = p.pos + dir * tA
			if p.spl: explode(pt, p.spl, p.dmg, p.dt, p.imp, p.owner, p.st, p.team)
			else:
				fx.sparks(pt, 5, Color("#ffd28a"), 16, -dir * 0.3)
				if typeof(ob) == TYPE_STRING and ob == "ground": fx.dust(pt, 1, 2.5, arena.dust)
				if ob is Dictionary and ob.has("hp"): damage_obstacle(ob, p.dmg, p.owner)
				if randf() < 0.3: Sfx.play("hit", pt, 0.4)
			projs.remove_at(i); i -= 1; continue
		p.pos += dir * len; p.travel += len
		if (p.pk != "missile" and not p.spl and p.travel > p.rng * 2.2) or absf(p.pos.x) > arena.size + 30 or absf(p.pos.z) > arena.size + 30 or p.pos.y > 400:
			projs.remove_at(i); i -= 1; continue
		# rastro
		var pc: Color = p.col
		match p.pk:
			"missile":
				p.smoke_t -= dt
				if p.smoke_t <= 0:
					p.smoke_t = 0.03; var s: float = p.w
					fx.emit_smoke(p.pos, Vector3((randf() - 0.5) * 3, (randf() - 0.5) * 3, (randf() - 0.5) * 3), 0.9, 1.2 * s, 4.0 * s, Color(0.75, 0.75, 0.75, 0.35), 1.0, -1.0)
					fx.emit_add(p.pos - dir * 1.2, Vector3.ZERO, 0.06, 3.0 * s, 1.0, Color(1.0, 0.6, 0.25), 2.6)
			"plasma":
				fx.emit_add(p.pos, Vector3.ZERO, 0.07, 6.0, 3.0, pc, 2.0); fx.emit_add(p.pos, Vector3((randf() - 0.5) * 8, (randf() - 0.5) * 8, (randf() - 0.5) * 8), 0.3, 2.5, 0.4, Color(pc.r, pc.g, pc.b, 0.7), 2.0)
			"glob":
				fx.emit_add(p.pos, Vector3.ZERO, 0.07, 4.0, 2.0, Color(0.35, 1.0, 0.18), 2.2); fx.emit_smoke(p.pos, Vector3(0, -2, 0), 0.5, 1.5, 3.0, Color(0.45, 0.65, 0.2, 0.5))
			"shell", "grenade":
				p.smoke_t -= dt
				if p.smoke_t <= 0: p.smoke_t = 0.03; fx.emit_smoke(p.pos, Vector3.ZERO, 0.6, 1.0, 3.0, Color(0.6, 0.6, 0.6, 0.3), 1.0, -1.0)
			_:
				if p.def.get("rail", 0) and p.get("charged", false): fx.emit_add(p.pos, Vector3.ZERO, 0.35, 2.0, 0.3, Color(pc.r, pc.g, pc.b, 0.6), 2.0)
		i -= 1
	# drones
	i = drones.size() - 1
	while i >= 0:
		var D = drones[i]; D.life -= dt; var t: Mech = D.target
		if D.life <= 0 or t == null or not t.alive or not D.owner.alive:
			fx.sparks(D.pos, 12, Color("#ffd28a"), 14); fx.puff(D.pos, 3, 2, Color("#444444"), 0.5, 2, 1, 1); D.mesh.queue_free(); drones.remove_at(i); i -= 1; continue
		D.ang += D.dir * dt * 1.1; var tc := t.center()
		var goal := Vector3(tc.x + cos(D.ang) * D.rad, maxf(tc.y + D.h, arena.ground_at(D.pos.x, D.pos.z, 1e9, 2) + 6), tc.z + sin(D.ang) * D.rad)
		D.vel += (goal - D.pos) * 6.0 * dt; D.vel *= maxf(0.0, 1 - 2.2 * dt); D.pos += D.vel * dt
		D.mesh.position = D.pos
		if D.pos.distance_to(tc) > 0.5: D.mesh.look_at(tc, Vector3.UP, true)
		D.cd -= dt
		if D.cd <= 0:
			D.cd = 1.0 / D.def.rof
			var to = tc - D.pos; var dist = to.length(); to /= dist; to.x += (randf() - 0.5) * 0.06; to.y += (randf() - 0.5) * 0.06; to = to.normalized()
			var h := hitscan(D.pos, to, dist + 20, D.owner.team); var end: Vector3 = D.pos + to * h.t
			fx.beam(D.pos, end, Color(D.owner.model.mat.get_shader_parameter("glow")), 0.14, 0.1); Sfx.play("pulse", D.pos, 0.5)
			if h.mech != null: h.mech.take_hit({ "dmg": D.def.dmg, "dt": "e", "imp": D.def.imp, "part": h.part, "from": D.pos, "owner": D.owner, "point": end })
		i -= 1
	fx.draw_projectiles(projs)
	fx.tick(dt, func(x, z): return arena.ground_at(x, z, 1e9, 0))

func steer(p: Dictionary, dt: float) -> void:
	var sp: float = p.vel.length(); var tgt = null; var has := false
	var T = p.get("target")
	if p.mk == "guided":
		if p.owner != null and p.owner.alive: tgt = p.owner.input.aimPoint; has = true
	elif T != null and T.alive and not T.cloaked:
		tgt = T.center(); has = true
		if p.mk == "vertical":
			if p.t < 0.75: has = false
			else: tgt.y += T.height * 0.45
		if has:
			var d: float = tgt.distance_to(p.pos); tgt += T.vel * minf(0.7, d / maxf(40.0, sp) * 0.6)
			if p.mk == "swarm" and d > 40:
				tgt.x += sin(p.t * 4 + p.seed) * 14; tgt.y += cos(p.t * 3 + p.seed * 2) * 9 + 6; tgt.z += cos(p.t * 4 + p.seed) * 14
			if p.mk == "direct" and d > 60: tgt.y += 5
	elif p.mk == "vertical" and p.t > 0.9 and not p.get("lost", false): p.lost = true; p.vel.y = -sp * 0.6
	var nsp := minf(p.spd * (1.6 if (p.mk == "vertical" and p.t > 0.75) else 1.25), sp + p.spd * 1.8 * dt)
	if has:
		var want: Vector3 = (tgt - p.pos).normalized(); var cur: Vector3 = p.vel / sp
		var ang := acos(clampf(want.dot(cur), -1, 1)); var turn: float = p.turn * (2.2 if (p.mk == "vertical" and p.t > 0.75 and p.t < 1.5) else 1.0) * dt
		if T != null and T.stats.ecm: turn *= 1 - T.stats.ecm
		if ang > 1e-4: cur = cur.lerp(want, minf(1.0, turn / ang)).normalized()
		p.vel = cur * nsp
	else: p.vel *= nsp / sp

func split(p: Dictionary) -> void:
	fx.sparks(p.pos, 20, Color("#ffd28a"), 20); fx.puff(p.pos, 5, 3, Color("#999999"), 0.4, 3, 1, 1); Sfx.play("missile", p.pos, 0.9)
	var base: Vector3 = p.vel.normalized()
	for k in int(p.sub):
		var v := base + Vector3((randf() - 0.5) * 0.5, (randf() - 0.5) * 0.3, (randf() - 0.5) * 0.5)
		shoot({ "owner": p.owner, "team": p.team, "def": p.def, "pos": p.pos, "vel": v.normalized() * p.spd * 1.1, "dmg": p.dmg, "imp": p.imp, "dt": p.dt, "pk": "missile", "mk": "direct", "spl": p.spl, "target": p.target, "turn": p.turn * 1.5, "spd": p.spd * 1.3, "vis": "m", "w": 0.6, "life": 3.5, "seed": randf() * 10, "st": null, "rng": 400.0 })

func dispose() -> void:
	for m in mechs: m.dispose()
	mechs.clear(); projs.clear()
	queue_free()
