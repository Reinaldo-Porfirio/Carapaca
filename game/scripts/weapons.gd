## Armas: cadência, pente, recarga, calor, carga, travamento de mísseis e disparo.
class_name Weapon extends RefCounted

const SND := { "rifle": "rifle", "smg": "smg", "shotgun": "shotgun", "pistol": "pistol", "flamer": "flame", "glauncher": "pistol", "bazooka": "heavy", "pulsegun": "pulse", "sprayer": "pistol", "saw": "saw", "lrifle": "laser", "arcgun": "arc", "plasma": "plasma", "linear": "rail", "cannon": "heavy", "gatling": "gatling", "lcannon": "biglaser", "pmortar": "plasma", "railgun": "rail", "none": "rifle" }
const COL := { "k": "#ffd9a0", "e": "#8fe6ff", "x": "#ffb070" }

var mech: Mech
var def: Dictionary
var slot := ""
var ammo_max := INF
var ammo := INF
var mag := 0
var cd := 0.0
var rel := 0.0
var heat := 0.0
var over := false
var chg := 0.0
var held := false
var spin_v := 0.0
var queue: Array = []
var since_shot := 9.0
var mz_idx := 0
var charges := 0
var snd := "rifle"
var col := Color.WHITE
var note_t := 0.0

func _init(m: Mech, d: Dictionary, s: String) -> void:
	mech = m; def = d; slot = s
	var scarce := 0.5 if (m.is_player and m.world.mods.get("scarce", false)) else 1.0
	if d.get("ammo", 0): ammo_max = maxf(1.0, roundf(d.ammo * m.stats.ammoMul * scarce)); ammo = ammo_max
	if d.get("mag", 0): mag = int(minf(d.mag, ammo))
	charges = int(d.get("charges", 0))
	snd = "missile" if d.wt == "missile" else SND.get(d.m.k, "laser" if d.wt == "beam" else "rifle")
	if d.id == "wa_laser": snd = "pulse"
	if d.id == "wa_autocannon": snd = "pistol"
	if d.get("dt", "k") == "e": col = Color("#bfe8ff") if d.get("fx", "") == "arc" else Color(m.model.mat.get_shader_parameter("glow"))
	else: col = Color(COL.get(d.get("dt", "k"), "#ffffff"))

func refill(mul := 1.0) -> void:
	if def.get("ammo", 0):
		ammo_max = roundf(ammo_max * mul); ammo = ammo_max
		if def.get("mag", 0): mag = int(minf(def.mag, ammo))
		rel = 0
	if def.get("charges", 0): charges = int(def.charges)

func interrupt() -> void: chg = 0; held = false; queue.clear()

var arm_ok: bool:
	get: return mech.arm_state(slot) < 2

func can_fire() -> bool:
	var d := def; var m := mech
	if not arm_ok or over or rel > 0: return false
	if d.get("ammo", 0) and ammo <= 0: return false
	if d.get("mag", 0) and mag <= 0: return false
	if d.get("enc", 0) and (m.en_lock or m.en < d.enc * 0.4): return false
	if d.get("heavy", 0) and (m.leg_type == "biped" or m.leg_type == "reverse") and not m.grounded:
		if m.is_player and note_t <= 0 and held: note_t = 1.5; m.world.emit({ "type": "note", "text": "ARMA PESADA: ANCORE NO CHÃO" })
		return false
	return true

func update(dt: float, trig: bool) -> void:
	var d := def; var m := mech; var w = m.world
	cd -= dt; since_shot += dt; note_t -= dt
	if not arm_ok: held = false; return
	if rel > 0:
		rel -= dt
		if rel <= 0:
			mag = int(minf(d.mag, ammo))
			if m.is_player: Sfx.play("equip", null, 0.5)
	if d.get("ht", 0):
		if since_shot > 0.4: heat = maxf(0.0, heat - d.cool * m.stats.cool * (0.6 if w.mods.get("heat", false) else 1.0) * (1.4 if over else 1.0) * dt)
		if over and heat <= 20: over = false
	var i := queue.size() - 1
	while i >= 0:
		var q = queue[i]; q.t -= dt
		if q.t <= 0: queue.remove_at(i); q.fn.call()
		i -= 1
	var edge := trig and not held; var released := not trig and held; held = trig
	var arm_st := m.arm_state(slot); var rof_mul: float = m.perk.rof * (0.7 if arm_st else 1.0)
	match d.wt:
		"proj", "beam":
			if d.get("spin", 0):
				spin_v = clampf(spin_v + (dt / d.spin if trig else -dt * 1.5), 0, 1)
				if spin_v < 1: return
			if d.has("chg"):
				if trig and cd <= 0 and can_fire():
					if chg == 0: Sfx.play("charge", m.pos, 0.6 if m.is_player else 0.4)
					chg += dt; m.fire_t[slot] = 0
					var k := minf(1.0, chg / d.chg.t); var mzp := m.muzzle(slot)
					w.fx.emit_add(mzp, Vector3.ZERO, 0.05, (0.6 + k * 2.0) * (1.7 if d.get("big", 0) else 1.0), 0.4, Color(0.6, 0.75, 1.0, 0.8), 2.4)
				elif released or (chg > 0 and not trig):
					var full: bool = chg >= d.chg.t
					if (full or not d.chg.get("req", 0)) and cd <= 0 and can_fire(): fire(d.chg.mul if full else 1.0, full)
					chg = 0
				elif not trig: chg = 0
			elif trig and cd <= 0 and can_fire():
				var n := int(d.get("burst", 1)); fire(1.0, false)
				for b in range(1, n):
					queue.append({ "t": b * 0.16, "fn": func():
						if m.alive and not m.staggered: fire(1.0, false, true) })
		"missile":
			if cd > 0 or ammo <= 0: return
			var guided: bool = d.mk2 == "guided"; var need: float = d.lockT * m.lock_time_mul
			var locked: bool = m.target != null and m.lock_prog >= need
			if (trig and (locked or guided)) or (edge and m.target == null): launch(m.target if locked else null)
		"cone":
			if trig and can_fire():
				m.fire_t[slot] = 0; cone_fx()
				if cd <= 0:
					cd = 1.0 / (d.rof * rof_mul); cone_tick()
					if d.get("mag", 0):
						mag -= 1; ammo -= 1
						if mag <= 0 and ammo > 0: rel = d.rel
		"melee":
			if m.melee != null or cd > 0: chg = 0; return
			if d.get("enc", 0) and (m.en_lock or m.en < d.enc * 0.5): return
			if d.has("chg"):
				if trig:
					if chg == 0: Sfx.play("charge", m.pos, 0.5)
					chg += dt
				elif chg > 0:
					var full: bool = chg >= d.chg.t; cd = d.cd; m.start_melee(self, d.chg.mul if full else 1.0); chg = 0
			elif edge: cd = d.cd; m.start_melee(self, 1.0)
		"shield":
			if trig and not m.en_lock and m.en > 50:
				m.shield_w = self; m.spend(d.drain * dt, true); m.fire_t[slot] = 0
				if edge: Sfx.play("shield", m.pos, 0.7)
				shield_fx()
		"drone":
			if edge and cd <= 0 and m.target != null:
				cd = d.rel; m.fire_t[slot] = 0
				for k in int(d.n): w.spawn_drone(m, m.target, d, m.muzzle(slot), k)
				Sfx.play("missile", m.pos, 0.8)
		"active":
			if not edge or cd > 0: return
			if d.act == "flare":
				if charges <= 0: return
				charges -= 1; cd = 1.2
				if charges <= 0: cd = d.cd; charges = int(d.charges)
				w.flare(m); Sfx.play("flare", m.pos, 1)
			elif d.act == "emp": cd = d.cd; w.emp(m, d)

func spread_dir(dir: Vector3, deg: float) -> Vector3:
	var s := deg * PI / 180.0
	if s <= 0: return dir
	var x := dir.cross(Vector3.UP)
	if x.length_squared() < 1e-4: x = Vector3.RIGHT
	x = x.normalized(); var y := x.cross(dir)
	var a := randf() * TAU; var r := sqrt(randf()) * tan(s)
	return (dir + x * cos(a) * r + y * sin(a) * r).normalized()

func fire(mult := 1.0, charged := false, in_burst := false) -> void:
	var d := def; var m := mech; var w = m.world; var A = w.arena
	var arm_st := m.arm_state(slot); var rof_mul: float = m.perk.rof * (0.7 if arm_st else 1.0)
	if not in_burst:
		cd = 1.0 / (d.rof * rof_mul)
		if d.get("mag", 0):
			mag -= 1
			if mag <= 0 and ammo > 1: rel = d.get("rel", 0) if d.get("rel", 0) else cd
		if d.get("ammo", 0): ammo -= 1
		if d.get("mag", 0) and d.get("rel", -1) == 0: mag = int(minf(d.mag, ammo))
	if d.get("enc", 0): m.spend(d.enc * (1.6 if charged else 1.0))
	if d.get("ht", 0):
		heat += d.ht * (1.8 if charged else 1.0)
		if heat >= 100:
			over = true; heat = 100
			if m.is_player: w.emit({ "type": "note", "text": "ARMA SUPERAQUECIDA" }); Sfx.play("warn")
	since_shot = 0; m.fire_t[slot] = 0
	if slot == "handR": m.recoil.R = minf(1.0, m.recoil.R + 0.25 + d.dmg * mult / 1500.0)
	if slot == "handL": m.recoil.L = minf(1.0, m.recoil.L + 0.25 + d.dmg * mult / 1500.0)
	if d.get("heavy", 0) and (m.leg_type == "biped" or m.leg_type == "reverse"): m.anchor_t = 0.6 * m.stats.anchorMul; m.vel.x *= 0.1; m.vel.z *= 0.1
	var mzp := m.muzzle(slot)
	var grav: float = 30.0 * d.grav * A.grav if d.get("grav", 0) else 0.0; var spd: float = d.get("spd", 0.0)
	var tp := m.aim_for(mzp, 0.0 if d.wt == "beam" else spd * (1.8 if (d.get("rail", 0) and charged) else 1.0), grav)
	var dir := tp - mzp
	if dir.length_squared() < 9: dir = Vector3(sin(m.yaw), 0, cos(m.yaw))
	dir = dir.normalized()
	var fwd := Vector3(sin(m.yaw), 0, cos(m.yaw))
	if dir.x * fwd.x + dir.z * fwd.z < 0.15: dir = Vector3(fwd.x, sin(m.pitch), fwd.z).normalized()
	var base := dir
	var spr_mul := (2.3 if arm_st else 1.0) * (1.6 if (m.stats.armOver and slot.begins_with("hand")) else 1.0) * (2.5 if m.status.shock.t > 0 else 1.0) * (0.4 if charged else 1.0) * (0.6 if (m.target == null and m.is_player) else 1.0)
	var dmg: float = d.dmg * mult; var imp: float = d.imp * (sqrt(mult) * 1.3 if charged else 1.0)
	var big: bool = d.get("heavy", 0) or d.dmg * mult > 600
	Sfx.play("biglaser" if (charged and d.wt == "beam") else snd, mzp, 1.0 if m.is_player else 0.8)
	if d.wt == "beam":
		var bd := spread_dir(base, 0.25 * spr_mul); var range_v: float = d.rng * 1.25
		var hit: Dictionary = w.hitscan(mzp, bd, range_v, m.team)
		var end: Vector3 = mzp + bd * hit.t
		var wd := (1.3 if d.get("big", 0) else (0.14 if d.get("cont", 0) else 0.3)) * (2.2 if (charged and not d.get("big", 0)) else 1.0)
		w.fx.beam(mzp, end, col, wd, 0.09 if d.get("cont", 0) else (0.5 if d.get("big", 0) else 0.18)); w.fx.beam(mzp, end, Color.WHITE, wd * 0.35, 0.07 if d.get("cont", 0) else (0.4 if d.get("big", 0) else 0.14))
		w.fx.light(mzp, col, 80.0 if (big or charged) else 26.0, 0.12)
		if d.get("fx", "") == "arc":
			for k in range(1, 6): w.fx.sparks(mzp.lerp(end, k / 6.0), 3, Color("#bfe8ff"), 9)
		if hit.mech != null: hit.mech.take_hit({ "dmg": dmg, "dt": d.dt, "imp": imp, "part": hit.part, "from": m.pos, "owner": m, "point": end, "st": d.get("st") })
		elif hit.ob != null and hit.ob is Dictionary and hit.ob.has("hp"): w.damage_obstacle(hit.ob, dmg, m)
		if hit.t < range_v:
			w.fx.sparks(end, 3 if d.get("cont", 0) else 14, col, 20)
			if d.get("big", 0) or charged:
				w.fx.explosion(end, 7.0 if d.get("big", 0) else 3.5, col)
				if d.get("big", 0): w.fx.add_shake(0.3)
		return
	var n := int(d.get("pel", 1)); var pk: String = d.pk
	for k in n:
		var pd := spread_dir(base, d.spr * spr_mul)
		var v: float = spd * (1.8 if (d.get("rail", 0) and charged) else 1.0)
		w.shoot({ "owner": m, "team": m.team, "def": d, "pos": mzp, "vel": pd * v, "dmg": dmg, "imp": imp, "dt": d.dt, "pk": pk, "spl": d.get("spl", 0.0), "st": d.get("st"), "grav": grav, "rng": d.rng * (1.4 if charged else 1.0),
			"vis": "t" if pk in ["bullet", "pulse", "shell"] else ("m" if pk == "grenade" else "p"),
			"w": 0.5 if pk == "shell" else ((0.5 if charged else 0.26) if d.get("rail", 0) else (0.3 if pk == "pulse" else (1.2 if pk == "grenade" else 0.16 + minf(0.2, d.dmg / 1200.0)))),
			"trail": 7.0 if pk == "shell" else ((80.0 if charged else 40.0) if d.get("rail", 0) else (5.0 if pk == "pulse" else 16.0)), "col": col, "vsShield": d.get("vsShield", 0), "charged": charged })
	w.fx.muzzle(mzp, base, col if d.dt == "e" else Color("#ffd9a0"), 2.4 if big else (1.6 if d.get("pel", 0) else 0.9 + minf(0.8, d.dmg / 400.0)))
	if big:
		w.fx.puff(mzp, 5, 3, Color("#555555"), 0.4, 4, 2, 1.2)
		if m.is_player: w.fx.add_shake(0.3)
		if m.grounded: w.fx.dust(m.pos, 6, 5, A.dust)

func launch(tgt) -> void:
	var d := def; var m := mech; var w = m.world
	var n = int(d.n) + (m.perk.missile if (d.mk2 != "guided" and d.mk2 != "cluster") else 0)
	cd = d.rel; m.fire_t[slot] = 0; ammo = maxf(0.0, ammo - n)
	for k in n:
		queue.append({ "t": k * (0.045 if d.mk2 == "swarm" else 0.09), "fn": func():
			if not m.alive: return
			var mzp := m.muzzle(slot, mz_idx); mz_idx += 1
			var f := Vector3(sin(m.yaw) * cos(m.pitch), sin(m.pitch), cos(m.yaw) * cos(m.pitch))
			var v: Vector3
			if d.mk2 == "vertical": v = Vector3(f.x * 0.25 + (randf() - 0.5) * 0.3, 1, f.z * 0.25 + (randf() - 0.5) * 0.3).normalized()
			elif d.mk2 == "cluster": v = Vector3(f.x, 0.9, f.z).normalized()
			elif d.mk2 == "swarm": v = spread_dir(Vector3(f.x, f.y + 0.45, f.z).normalized(), 24)
			else: v = spread_dir(Vector3(f.x, f.y + 0.08, f.z).normalized(), 0.0 if d.mk2 == "guided" else 7.0)
			w.shoot({ "owner": m, "team": m.team, "def": d, "pos": mzp, "vel": v * d.spd * 0.55, "dmg": d.dmg, "imp": d.imp, "dt": d.dt, "pk": "missile", "mk": d.mk2, "spl": d.spl, "target": tgt, "turn": d.turn, "spd": d.spd, "vis": "m",
				"w": 1.7 if (d.mk2 == "guided" or d.mk2 == "cluster") else (0.6 if (d.mk2 == "swarm" or slot == "shoulder") else 1.0), "life": 7.0, "sub": d.get("sub", 0), "seed": randf() * 10 })
			Sfx.play("missile", mzp, 0.8 if m.is_player else 0.6); w.fx.puff(mzp, 2, 2, Color("#888888"), 0.4, 2, 1, 0.8); w.fx.light(mzp, Color("#ffb070"), 20, 0.1) })

func cone_tick() -> void:
	var d := def; var m := mech; var w = m.world; var mzp := m.muzzle(slot)
	var dir: Vector3 = (m.input.aimPoint - mzp).normalized()
	if m.target != null: dir = (m.target.center() - mzp).normalized()
	var fwd := Vector3(sin(m.yaw), 0, cos(m.yaw))
	if dir.x * fwd.x + dir.z * fwd.z < 0.2: dir = fwd
	Sfx.play(snd, mzp, 0.7)
	var rng: float = d.rng * m.scale
	for e in w.mechs:
		if e.team == m.team or not e.alive: continue
		var c: Vector3 = e.center(); var to: Vector3 = c - mzp; var dist := to.length()
		if dist - e.radius > rng: continue
		to /= dist
		var ang := acos(clampf(to.dot(dir), -1, 1)); var lim: float = d.ang * PI / 180.0 + atan2(e.radius, dist)
		if ang > lim or not w.arena.los(mzp, c): continue
		var part: String = "core" if randf() < 0.55 else ["armR", "armL", "legs", "head"][randi() % 4]
		e.take_hit({ "dmg": d.dmg, "dt": d.dt, "imp": d.imp, "part": part, "from": m.pos, "owner": m, "st": d.get("st"), "armorMul": d.get("armorMul", 1.0), "quiet": true, "point": e.part_pos(part) })
		if d.get("fx", "") == "saw": w.fx.sparks(e.part_pos(part), 8, Color("#ffd28a"), 26)

func cone_fx() -> void:
	var d := def; var m := mech; var w = m.world; var mzp := m.muzzle(slot)
	var dir: Vector3 = (m.input.aimPoint - mzp).normalized()
	if m.target != null: dir = (m.target.center() - mzp).normalized()
	if d.get("fx", "") == "flame":
		for k in 4:
			var s := 55.0 + randf() * 30.0
			w.fx.emit_add(mzp, dir * s + Vector3((randf() - 0.5) * 12, (randf() - 0.5) * 12 + 3, (randf() - 0.5) * 12), d.rng / 70.0 * (0.7 + randf() * 0.5), 1.0, 5.0, Color(1.0, 0.45 + randf() * 0.25, 0.1, 0.75), 2.6, 0.8, -6.0)
		if randf() < 0.3:
			var sp = mzp + dir * d.rng * 0.7
			w.fx.emit_smoke(sp, Vector3(dir.x * 8, 5, dir.z * 8), 1.2, 4, 10, Color(0.1, 0.1, 0.1, 0.4), 1.0, -1.0)
		w.fx.light(mzp + dir * 12, Color("#ff8a30"), 50, 0.08)
	elif randf() < 0.5:
		var wn = m.model.wn.get(slot)
		if wn and wn.m.has("tip"): w.fx.sparks(wn.m.tip.global_position, 2, Color("#ffd28a"), 12)

func shield_fx() -> void:
	var m := mech; var w = m.world
	if randf() > 0.6: return
	var c := m.center() + Vector3(sin(m.yaw), 0, cos(m.yaw)) * (m.radius + 1.5)
	var x := Vector3(cos(m.yaw), 0, -sin(m.yaw)); var a := randf() * TAU; var r := 3.2 * m.scale
	w.fx.emit_add(c + x * cos(a) * r + Vector3(0, sin(a) * r, 0), Vector3.ZERO, 0.18, 1.6, 0.4, Color(0.3, 0.75, 1.0, 1.0 if m.shield_t < 0.3 else 0.5), 2.4)

## Estado para o HUD.
func hud() -> Dictionary:
	var d := def; var ring := 1.0; var state := "ok"; var txt := ""
	if not arm_ok: state = "off"; ring = 0; txt = "DESTRUÍDA"
	elif d.wt == "passive": state = "passive"; txt = "PASSIVO"
	elif over: state = "heat"; ring = 1 - heat / 100.0; txt = "CALOR"
	elif rel > 0: state = "reload"; ring = 1 - rel / maxf(0.01, d.get("rel", 1.0)); txt = "RECARGA"
	elif d.get("ammo", 0) and ammo <= 0: state = "empty"; ring = 0; txt = "VAZIA"
	elif chg > 0 and d.has("chg"): state = "charge"; ring = minf(1.0, chg / d.chg.t)
	elif cd > 0.25:
		var tot: float = d.rel if (d.wt == "missile" or d.wt == "drone") else (d.get("cd", 0.0) if d.get("cd", 0.0) else 1.0 / d.get("rof", 1.0))
		state = "cool"; ring = 1 - clampf(cd / tot, 0, 1)
	elif d.get("ht", 0):
		ring = 1 - heat / 100.0 * 0.999; state = "warm" if heat > 70 else "ok"
	var am := ""
	if d.wt == "melee" or d.wt == "shield" or (d.wt == "cone" and not d.get("mag", 0)): am = "—"
	elif d.wt == "active": am = str(charges) if d.get("charges", 0) else "∞"
	elif not d.get("ammo", 0): am = "∞"
	elif d.get("mag", 0) > 1: am = "%d/%d" % [mag, maxf(0, ammo - mag)]
	else: am = str(int(ammo))
	var lock := 0.0
	if d.wt == "missile" and d.get("lockT", 0) and mech.target != null: lock = clampf(mech.lock_prog / (d.lockT * mech.lock_time_mul), 0, 1)
	return { "ring": ring, "state": state, "txt": txt, "ammo": am, "lock": lock }
