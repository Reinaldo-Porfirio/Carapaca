## Pilotos controlados pelo jogo: posicionamento, esquiva, disciplina de tiro e uso de utilitários.
class_name AI extends RefCounted

var m: Mech
var t := {}
var strafe := 1.0
var strafe_t := 1.0
var air_t := 1.0
var jump_hold := 0.0
var burst_t := 0.0
var burst_on := true
var react := 0.0
var scan_t := 0.0
var dodge_t := 0.0
var heavy_t := 0.0
var heavy_ok := false
var melee_t := 0.0
var melee_ok := false
var no_los := 0.0
var ch := {}
var avoid_t := 0.0
var ev_t := 2.0
var qb_queued := 0
var target_t := 0.0
var tgt: Mech = null
var threat := false
var pr := 140.0

func _init(mech: Mech, traits := {}) -> void:
	m = mech; t = { "agg": 0.5, "skill": 0.5, "air": 0.3 }; t.merge(traits, true)
	var s: float = t.skill; m.aim_skill = 0.3 + 0.7 * s
	strafe = 1.0 if randf() < 0.5 else -1.0; strafe_t = 1 + randf() * 2; air_t = 1 + randf() * 3; ev_t = 2 + randf() * 3
	m.kits = mini(m.kits, int(floor(s * 2.4)))
	var tot := 0.0; var n := 0; var has_melee := false
	for k in ["handR", "handL"]:
		if not m.weapons.has(k): continue
		var d: Dictionary = m.weapons[k].def
		if d.wt == "melee": has_melee = true; continue
		if d.wt == "shield": continue
		tot += d.rng * 0.7 if d.wt == "cone" else (d.rng * 0.55 if d.get("pel", 0) else minf(200.0, d.rng * 0.5)); n += 1
	pr = float(t.get("keep", 0)) if t.get("keep", 0) else (tot / n if n else (30.0 if has_melee else 140.0))
	if has_melee and t.get("melee", 0): pr = minf(pr, 45.0)
	pr = clampf(pr, 22, 260)

func pick_target(w) -> Mech:
	var best: Mech = null; var bd := 1e9
	for e in w.mechs:
		if not e.alive or e.team == m.team: continue
		var d: float = e.pos.distance_to(m.pos)
		if e.cloaked: d += 400
		if e == m.last_dmg_from: d *= 0.6
		if d < bd: bd = d; best = e
	return best

func update(dt: float, w) -> void:
	var I := m.input; var s: float = t.skill
	I.qb = false; I.ab = false; I.jumpP = false; I.util = false; I.repair = false
	if not m.alive: return
	if t.get("passive", false):
		I.mx = 0.0; I.mz = 0.0; I.jump = false
		for k in I.fire: I.fire[k] = false
		if w.mechs.size() > 0: var pl: Mech = w.mechs[0]; I.yaw = atan2(pl.pos.x - m.pos.x, pl.pos.z - m.pos.z)
		return
	target_t -= dt
	if target_t <= 0 or tgt == null or not tgt.alive:
		target_t = 1.2; var nt := pick_target(w)
		if nt != tgt: tgt = nt; react = 0.7 - 0.5 * s
	var T := tgt
	if T == null:
		for k in I.fire: I.fire[k] = false
		I.mx = 0.0; I.mz = 0.0; I.jump = false; return
	var c := m.center(); var tc := T.center(); var to := tc - c; var dist := to.length()
	var los: bool = w.arena.los(c, tc)
	no_los = 0.0 if los else no_los + dt
	I.yaw = atan2(to.x, to.z)
	if los and dist < m.lock_range and not T.cloaked and m.status.shock.t <= 0:
		if m.target != T: m.target = T; m.lock_prog = 0; m.trk.ok = false
	elif m.target != null and (not los or T.cloaked): m.target = null
	react -= dt
	var t_stag := T.staggered
	strafe_t -= dt
	if strafe_t <= 0 or m.blocked > 0.2: strafe = -strafe; strafe_t = 1.0 + randf() * 2.6
	var prr := pr
	if t_stag and t.agg > 0.5: prr = minf(prr, 60.0)
	var mz := 1.0 if dist > prr * 1.2 else (-1.0 if dist < prr * 0.65 else (dist - prr) / prr)
	var mx := strafe * (0.55 + 0.45 * s)
	if no_los > 1.0: mz = 1.0; mx *= 0.6
	if m.st < m.st_max * 0.25 and t.agg < 0.6: mz = minf(mz, -0.4)
	avoid_t -= dt
	if avoid_t <= 0:
		avoid_t = 0.22; var fy := sin(I.yaw); var fc := cos(I.yaw)
		var mv := Vector3(fy * mz - fc * mx, 0, fc * mz + fy * mx)
		if mv.length_squared() > 0.01:
			mv = mv.normalized(); var d: float = w.arena.ray(c, mv, 18)
			var hob = w.arena.hit_ob
			if d != INF and hob is Dictionary:
				var top: float = hob.max.y - m.pos.y
				if top < 18 and m.en > m.en_max * 0.4 and not m.en_lock: jump_hold = maxf(jump_hold, 0.4 + top * 0.06)
				else: strafe = -strafe
		if m.grounded and w.arena.in_hazard(m.pos.x, m.pos.z) != null: jump_hold = maxf(jump_hold, 0.6)
	air_t -= dt
	if air_t <= 0:
		air_t = 1.6 + randf() * 3.4
		if randf() < t.air and m.en > m.en_max * 0.55: jump_hold = 0.5 + randf() * 1.8 * t.air
		if no_los > 0.8: jump_hold = 1.2
	if jump_hold > 0:
		jump_hold -= dt; I.jump = true
		if m.grounded: I.jumpP = true
		if m.en < m.en_max * 0.15: jump_hold = 0
	else: I.jump = false
	I.mx = mx; I.mz = mz
	scan_t -= dt; dodge_t -= dt
	if scan_t <= 0:
		scan_t = 0.1; threat = false
		for p in w.projs:
			if p.team == m.team or p.get("ai_seen") == m: continue
			if p.pk != "missile" and p.dmg < 240: continue
			var bv: Vector3 = c - p.pos; var d := bv.length()
			if d > 90: continue
			var spd: float = p.vel.length()
			if d / spd > 0.55: continue
			if (bv / d).dot(p.vel / spd) < 0.94: continue
			p.ai_seen = m; threat = true
			if dodge_t <= 0 and randf() < s * 0.8 + 0.05: qb_queued = 1; dodge_t = 0.5; strafe = 1.0 if randf() < 0.5 else -1.0; break
	ev_t -= dt
	if ev_t <= 0:
		ev_t = 1.5 + randf() * (4.5 - s * 2.5)
		if m.last_hit_t < 1.2 and randf() < 0.3 + s * 0.5: qb_queued = 1
		elif dist > prr * 1.7 and randf() < t.agg: qb_queued = 2
		elif t_stag and dist > prr and randf() < t.agg: qb_queued = 2
	if qb_queued and m.qb_t <= 0 and not m.en_lock and m.en > m.stats.qbCost * 0.6:
		if qb_queued == 2: I.mx = 0.0; I.mz = 1.0
		else: I.mx = strafe; I.mz = mz * 0.3
		I.qb = true; qb_queued = 0
	if not m.ab_on and dist > maxf(prr * 2.2, 170.0) and t.agg > 0.55 and m.en > m.en_max * 0.75 and los and randf() < dt * 0.8: I.ab = true
	if m.ab_on and dist < prr * 1.3: I.ab = true
	I.aimDir = to / dist
	burst_t -= dt
	if burst_t <= 0:
		burst_on = not burst_on
		burst_t = (0.7 + s * 1.8 + randf() * 0.5) if burst_on else maxf(0.15, 1.2 - s * 0.9) * (0.6 + randf() * 0.8)
	heavy_t -= dt
	if heavy_t <= 0: heavy_t = 1.6; heavy_ok = randf() < 0.22 + (1 - s) * 0.35
	melee_t -= dt
	if melee_t <= 0: melee_t = 0.6; melee_ok = randf() < 0.25 + t.agg * 0.45
	var can: bool = react <= 0 and los and m.target == T
	for k in m.weapons:
		var wp: Weapon = m.weapons[k]; var d := wp.def; var f := false
		var en_ok: bool = not d.get("enc", 0) or (not m.en_lock and m.en > m.en_max * 0.22)
		if can and en_ok:
			match d.wt:
				"proj", "beam":
					var in_r: bool = dist < d.rng * 1.12 and (d.get("pk", "") != "grenade" or dist > 22)
					var heavy: bool = d.dmg * d.get("pel", 1) * d.get("burst", 1) > 620
					var ok: bool = in_r and (not heavy or t_stag or heavy_ok)
					if d.has("chg") and (d.chg.get("req", 0) or s > 0.45):
						if not ch.has(k): ch[k] = 0.0
						if ok and wp.cd <= 0 and wp.can_fire():
							ch[k] += dt; f = ch[k] < d.chg.t + 0.1
							if not f: ch[k] = 0.0
						else: ch[k] = 0.0
					elif d.has("chg"): f = ok and burst_on and not I.fire[k]
					else: f = ok and (burst_on or heavy or t_stag)
				"missile": f = dist > 24 and dist < d.rng * 1.25 and (d.mk2 == "guided" or m.lock_prog >= d.lockT * m.lock_time_mul)
				"cone": f = dist - T.radius < d.rng * 0.95
				"melee":
					var in_r: bool = dist < d.lunge * 1.15 + T.radius + m.radius
					if d.has("chg"):
						if not ch.has(k): ch[k] = 0.0
						if in_r and wp.cd <= 0 and m.melee == null and (t_stag or melee_ok):
							ch[k] += dt; f = ch[k] < d.chg.t + 0.08
							if not f: ch[k] = 0.0
						else: ch[k] = 0.0
					else: f = in_r and wp.cd <= 0 and m.melee == null and (t_stag or melee_ok) and not I.fire[k]
				"shield": f = (m.last_hit_t < 0.7 or threat) and m.en > m.en_max * 0.5 and not m.en_lock and s > 0.3
				"drone": f = wp.cd <= 0 and not I.fire[k]
				"active": f = wp.cd <= 0 and not I.fire[k] and (threat if d.act == "flare" else dist < d.get("rad", 30) * 0.85)
		I.fire[k] = f
	var u = m.P.util
	if u != null and m.util_cd <= 0 and react <= 0:
		match u.act:
			"hook": if los and dist > 70 and dist < u.rng and t.agg > 0.5 and randf() < dt * 0.5: I.util = true
			"barrier": if m.last_hit_t < 0.5 and m.st < m.st_max * 0.8: I.util = true
			"cloak": if m.last_hit_t < 0.5 and randf() < dt * 2: I.util = true
			"burst": if dist < u.rad * 0.7 and m.util_charges > 0 and not m.staggered and randf() < dt * 3: I.util = true
	if m.kits > 0 and m.st < m.st_max * 0.34 and m.kit_cd <= 0: I.repair = true
