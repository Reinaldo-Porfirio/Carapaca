## Carcaça em combate: movimento, energia, travamento, dano por partes, status, utilitários e animação.
class_name Mech extends RefCounted

const PARTS5 := ["head", "core", "armR", "armL", "legs"]
const PART_PT := { "head": "Cabeça", "core": "Tronco", "armR": "Braço D", "armL": "Braço E", "legs": "Pernas" }
const UP := Vector3.UP

var world
var build: Dictionary
var team := 1
var is_player := false
var name := ""
var call := ""
var spec := {}
var scale := 1.0
var hp_mul := 1.0
var stats: Dictionary
var P: Dictionary
var model: Dictionary
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var leg_yaw := 0.0
var grounded := true
var air_t := 0.0
var alive := true
var dead_t := 0.0
var perk := { "k": 1.0, "e": 1.0, "x": 1.0, "rof": 1.0, "imp": 1.0, "en": 1.0, "qb": 1.0, "salvage": 0, "stab": 1.0, "missile": 0, "direct": 0.0, "shock": 0, "burn": 0, "speed": 1.0 }
var st_max := 1.0
var st := 1.0
var parts := {}
var en_max := 1.0
var en := 1.0
var en_wait := 0.0
var en_lock := false
var qb_t := 0.0
var qb_fx := 0.0
var qb_dir := Vector3.FORWARD
var ab_on := false
var ascending := false
var anchor_t := 0.0
var impact := 0.0
var impact_t := 9.0
var stagger_t := 0.0
var stagger_imm := 0.0
var status := { "heat": { "v": 0.0, "t": 0.0, "idle": 9.0 }, "shock": { "v": 0.0, "t": 0.0, "idle": 9.0 }, "corr": { "v": 0.0, "t": 0.0, "idle": 9.0 } }
var kits := 3
var kit_cd := 0.0
var input := {}
var target: Mech = null
var lock_prog := 0.0
var hard_lock := false
var trk := { "p": Vector3.ZERO, "v": Vector3.ZERO, "ok": false }
var aim_err := Vector3.ZERO
var aim_err_t := 0.0
var aim_skill := 1.0
var melee = null
var hook = null
var barrier := { "t": 0.0, "hp": 0.0, "max": 1.0 }
var cloak_t := 0.0
var shield_w = null
var shield_t := 0.0
var util_cd := 0.0
var util_charges := 0
var phase := 0.0
var step_side := 0
var recoil := { "R": 0.0, "L": 0.0 }
var fire_t := { "handR": 9.0, "handL": 9.0, "backR": 9.0, "backL": 9.0, "shoulder": 9.0 }
var last_hit_t := 9.0
var last_dmg_from: Mech = null
var dmg_taken := 0.0
var dmg_dealt := 0.0
var weapons := {}
var height := 8.0
var radius := 2.5
var aim_y := 6.0
var is_tank := false
var leg_type := "biped"
var blocked := 0.0
var land_t := 0.0
var crouch_s := 0.0
var amp_s := 0.0
var thr_t := 0.0
var cable: MeshInstance3D
var hook_head: Node3D
var barrier_mesh: MeshInstance3D
var barrier_mat: ShaderMaterial
var aim_origin := Vector3.ZERO

func _init(w, b: Dictionary, o := {}) -> void:
	world = w; build = b; team = o.get("team", 1); is_player = o.get("player", false); name = o.get("name", b.get("name", "CARCAÇA")); call = o.get("call", "")
	scale = o.get("scale", 1.0); hp_mul = o.get("hpMul", 1.0)
	stats = Stats.compute(b); P = Stats.parts_of(b)
	model = Builder.build_mech(b)
	model.root.scale = Vector3.ONE * scale
	w.add_child(model.root)
	perk.e = 1.0 + stats.eb
	var wm: Dictionary = w.mods
	st_max = stats.structure * hp_mul; st = st_max
	for k in PARTS5:
		var a: float = stats.partArmor[k] * (1.4 if (team != 0 and wm.get("hardened", false)) else 1.0) * ((1.0 + (hp_mul - 1.0) * 0.6) if hp_mul > 1.0 else 1.0)
		parts[k] = { "a": a, "max": a, "integ": a * 0.6, "state": 0, "smoke_t": 0.0 }
	en_max = stats.enCap; en = en_max
	kits = 0 if (is_player and wm.get("norepair", false)) else int(o.get("kits", stats.kits))
	input = { "mx": 0.0, "mz": 0.0, "jump": false, "jumpP": false, "qb": false, "ab": false, "fire": { "handR": false, "handL": false, "backR": false, "backL": false, "shoulder": false },
		"util": false, "repair": false, "yaw": 0.0, "aimDir": Vector3.FORWARD, "aimPoint": Vector3.ZERO }
	if P.util and P.util.has("charges"): util_charges = int(P.util.charges)
	var wd := Stats.weapon_defs(b)
	for k in ["handR", "handL", "backR", "backL", "shoulder"]:
		if wd[k]: weapons[k] = Weapon.new(self, wd[k], k)
	height = model.height * scale; radius = model.radius * scale; aim_y = model.aimY * scale
	is_tank = stats.isTank; leg_type = stats.legType

var staggered: bool:
	get: return stagger_t > 0
var cloaked: bool:
	get: return cloak_t > 0
var weight: float:
	get: return stats.weight * scale
var stab_max: float:
	get: return stats.stab * perk.stab * (1.3 if hp_mul > 1 else 1.0)

func center() -> Vector3: return Vector3(pos.x, pos.y + aim_y, pos.z)
func part_pos(part: String) -> Vector3:
	for z in model.hz:
		if z.part == part: return pos + (z.o * scale).rotated(UP, yaw)
	return center()
func muzzle(slot: String, idx := 0) -> Vector3:
	var m = model.mz.get(slot)
	if m is Array:
		if m.is_empty(): return center()
		m = m[idx % m.size()]
	if m and is_instance_valid(m) and m.is_inside_tree(): return m.global_position
	return center()

var lock_range: float:
	get:
		var h: int = parts.head.state
		return stats.lockRange * (0.3 if h == 2 else (0.55 if h == 1 else 1.0)) * (0.5 if world.mods.get("emstorm", false) else 1.0)
var lock_time_mul: float:
	get: return stats.lockTime * (1.8 if parts.head.state else 1.0)
var speed_mul: float:
	get:
		var l: int = parts.legs.state
		return (0.45 if l == 2 else (0.72 if l == 1 else 1.0)) * (1.35 if cloaked else 1.0) * perk.speed
func arm_state(slot: String) -> int:
	if slot == "handR": return parts.armR.state
	if slot == "handL": return parts.armL.state
	return 0

static func ang_diff(a: float, b: float) -> float:
	var d := a - b
	while d > PI: d -= TAU
	while d < -PI: d += TAU
	return d

# ═════════════ atualização ═════════════
func update(dt: float) -> void:
	var w = world; var I := input; var S := stats; var A = w.arena
	if not alive: update_dead(dt); return
	qb_t -= dt; qb_fx -= dt; kit_cd -= dt; util_cd -= dt; last_hit_t += dt; impact_t += dt; anchor_t -= dt; stagger_imm -= dt
	if stagger_t > 0:
		stagger_t -= dt
		if stagger_t <= 0: impact = 0
	elif impact_t > 2.2: impact = maxf(0.0, impact - stab_max * 0.35 * dt)
	for k in status:
		var s = status[k]; s.idle += dt
		if s.t > 0: s.t -= dt
		elif s.idle > 2: s.v = maxf(0.0, s.v - 10 * dt)
	if status.heat.t > 0:
		damage_raw(52 * dt, null)
		if randf() < dt * 14: w.fx.thrust(center() + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * Vector3(4, 5, 4), UP, Color("#ff7a20"), 2.2, 6)
	if status.corr.t > 0 and randf() < dt * 8: w.fx.puff(center(), 1, 2.4, Color("#7aa838"), 0.35, 2.5, 1, 1)
	if cloak_t > 0:
		cloak_t -= dt
		if cloak_t <= 0: set_cloak(false)
	if barrier.t > 0:
		barrier.t -= dt
		if barrier.t <= 0: drop_barrier(false)
	var hz = A.in_hazard(pos.x, pos.z) if grounded else null
	if hz == "heat": add_status("heat", 48 * dt); damage_raw(24 * dt, null)
	if w.mods.get("acid", false) and vel.length_squared() < 30 and A.ground_at(pos.x, pos.z, 1e9, 0) <= pos.y + 1: add_status("corr", 9 * dt)
	var stg := staggered
	if not alive: return
	# reparo
	if I.repair and kits > 0 and kit_cd <= 0 and not stg and st < st_max:
		kits -= 1; kit_cd = 1.6; st = minf(st_max, st + st_max * 0.38)
		if S.kitArmor:
			for k in PARTS5:
				var p = parts[k]
				if p.state < 2:
					p.a = minf(p.max, p.a + p.max * S.kitArmor)
					if p.state == 1 and p.a > 0: p.state = 0
		status.heat.t = 0; status.corr.t = 0
		Sfx.play("repair", pos); w.fx.ring(pos + Vector3(0, 1, 0), Color("#7dffb0"), radius * 3.5, 0.6)
		for i in 16: w.fx.thrust(center() + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * Vector3(6, 8, 6), UP, Color("#7dffb0"), 1.6, 8)
		if is_player: w.emit({ "type": "note", "text": "REPARO APLICADO" })
	# orientação
	var turn := (4.5 if is_tank else 8.0) * (0.0 if stg else 1.0)
	if melee == null: yaw += clampf(ang_diff(I.yaw, yaw), -turn * dt, turn * dt)
	# movimento
	var g: float = 30.0 * A.grav; var sp: float = S.boostSpeed * speed_mul
	var wx := 0.0; var wz := 0.0
	var can_move: bool = not stg and anchor_t <= 0 and melee == null and not (hook != null and hook.phase == "pull")
	if can_move:
		var fy := sin(I.yaw); var fc := cos(I.yaw)
		wx = fy * I.mz - fc * I.mx; wz = fc * I.mz + fy * I.mx
		var l := sqrt(wx * wx + wz * wz)
		if l > 1: wx /= l; wz /= l
	var wish_len := sqrt(wx * wx + wz * wz)
	var can_en := not en_lock and en > 0
	if I.qb and qb_t <= 0 and can_move and can_en and parts.legs.state < 2:
		var dx := wx; var dz := wz
		if wish_len < 0.1: dx = sin(yaw); dz = cos(yaw)
		else: dx /= wish_len; dz /= wish_len
		var q: float = S.qbSpeed * speed_mul; vel.x = dx * q; vel.z = dz * q
		if not grounded and vel.y < 0: vel.y *= 0.3
		spend(S.qbCost * perk.qb * (1.3 if parts.legs.state else 1.0)); qb_t = S.qbReload * (0.8 if perk.qb < 1 else 1.0); qb_fx = 0.28; qb_dir = Vector3(dx, 0, dz)
		ab_on = false; Sfx.play("qb", pos, 1.0 if is_player else 0.7)
		if grounded: w.fx.dust(pos + Vector3(0, 0.5, 0), 8, 4, A.dust)
		for i in 14: w.fx.thrust(center() + Vector3((randf() - 0.5) * 3, (randf() - 0.5) * 3 - 1, (randf() - 0.5) * 3), Vector3(-dx, 0.05, -dz), model.flameCol, 3, 40 + randf() * 40)
		w.fx.light(center(), model.flameCol, 40, 0.2)
		if is_player: w.fx.add_shake(0.12)
	if I.ab and can_move:
		if ab_on: ab_on = false
		elif can_en and en > en_max * 0.2: ab_on = true; Sfx.play("qb", pos, 0.8)
	if ab_on:
		if not can_en or stg or I.mz < -0.5 or melee != null: ab_on = false
		else:
			spend(430 * dt, true)
			var ad: Vector3 = I.aimDir
			if grounded and ad.y < 0.1: ad.y = 0.1
			ad = ad.normalized() * S.abSpeed * speed_mul
			vel = vel.lerp(ad, minf(1.0, 5 * dt)); grounded = false
	if hook != null: update_hook(dt)
	var pulling: bool = hook != null and hook.phase == "pull"
	if not ab_on and not pulling and not (melee != null and melee.phase == "lunge"):
		var hv := Vector2(vel.x, vel.z).length()
		var tx := wx * sp; var tz := wz * sp
		if hv > sp * 1.05:
			var dd := maxf(0.0, 1 - 3.4 * dt); vel.x *= dd; vel.z *= dd
			if wish_len > 0.1: vel.x += wx * 30 * dt; vel.z += wz * 30 * dt
		else:
			var acc := (95.0 if grounded else 60.0) * (0.4 if stg else 1.0) * dt
			var ddx := tx - vel.x; var ddz := tz - vel.z; var dl := sqrt(ddx * ddx + ddz * ddz)
			if dl > acc: vel.x += ddx / dl * acc; vel.z += ddz / dl * acc
			else: vel.x = tx; vel.z = tz
		ascending = false
		if I.jumpP and grounded and can_move:
			vel.y = S.jump * (0.5 if parts.legs.state == 2 else 1.0) * (1.25 if A.grav < 1 else 1.0); grounded = false; air_t = 0
			Sfx.play("jump", pos, 0.7); w.fx.dust(pos, 6, 4, A.dust)
		elif I.jump and not grounded and air_t > 0.12 and can_en and can_move:
			var cost := 300.0 if leg_type == "quad" else 520.0; spend(cost * dt, true)
			var max_up: float = 21.0 * S.upThrust
			if vel.y < max_up: vel.y = minf(max_up, vel.y + (g + 62 * S.upThrust) * dt)
			ascending = true
		vel.y -= g * dt
		if vel.y < -58: vel.y = -58
		if leg_type == "quad" and not grounded and vel.y < -9 and I.jump and can_en: vel.y = -9
	# integração e colisão
	pos += vel * dt
	var r := radius
	for o in A.obstacles:
		if not o.alive or pos.y >= o.max.y - 1.3 or pos.y + height * 0.8 <= o.min.y: continue
		var cx := clampf(pos.x, o.min.x, o.max.x); var cz := clampf(pos.z, o.min.z, o.max.z)
		var dx := pos.x - cx; var dz := pos.z - cz; var d2 := dx * dx + dz * dz
		if d2 >= r * r: continue
		if d2 > 1e-6:
			var d := sqrt(d2); dx /= d; dz /= d; pos.x = cx + dx * r; pos.z = cz + dz * r
		else:
			var pl: float = pos.x - o.min.x; var pr: float = o.max.x - pos.x; var pb: float = pos.z - o.min.z; var pf: float = o.max.z - pos.z; var m := minf(minf(pl, pr), minf(pb, pf))
			if m == pl: pos.x = o.min.x - r; dx = -1; dz = 0
			elif m == pr: pos.x = o.max.x + r; dx = 1; dz = 0
			elif m == pb: pos.z = o.min.z - r; dx = 0; dz = -1
			else: pos.z = o.max.z + r; dx = 0; dz = 1
		var vn := vel.x * dx + vel.z * dz
		if vn < 0: vel.x -= dx * vn; vel.z -= dz * vn
		blocked = 0.25
		if pulling: end_hook(true)
	pos = A.clamp_pos(pos, r)
	if A.clamped:
		blocked = 0.25
		if pulling: end_hook(true)
	blocked -= dt
	if pos.y > A.ceiling: pos.y = A.ceiling; vel.y = minf(vel.y, 0.0)
	var gy: float = A.ground_at(pos.x, pos.z, pos.y, r * 0.55)
	if pos.y <= gy and vel.y <= 0:
		if not grounded:
			if vel.y < -16:
				Sfx.play("land", pos, 0.9); w.fx.dust(pos, 10, 5, A.dust)
				if is_player: w.fx.add_shake(0.2)
			land_t = 0.25
		pos.y = gy; vel.y = 0; grounded = true; air_t = 0
	elif pos.y > gy + 0.08: grounded = false; air_t += dt
	# energia
	en_wait -= dt
	if en_wait <= 0 and en < en_max:
		var rate: float = S.enRech * perk.en * (1.6 if w.mods.get("overclock", false) else 1.0) * (1.0 if grounded else 0.55) * (0.6 if parts.core.state else 1.0) * (0.5 if status.heat.t > 0 else 1.0) * (1.25 if en_lock else 1.0)
		en = minf(en_max, en + rate * dt)
	if en_lock and en >= en_max * 0.32: en_lock = false
	update_aim(dt)
	if melee != null: update_melee(dt)
	shield_w = null
	for k in weapons:
		fire_t[k] += dt; weapons[k].update(dt, not stg and I.fire[k])
	if shield_w != null: shield_t += dt
	else: shield_t = 0
	if I.util and not stg: use_util()
	for k in PARTS5:
		var p = parts[k]
		if not p.state: continue
		p.smoke_t -= dt
		if p.smoke_t <= 0:
			p.smoke_t = 0.07 if p.state == 2 else 0.16
			var pp := part_pos(k); w.fx.puff(pp, 1, 2.2, Color("#141312") if p.state == 2 else Color("#3a3836"), 0.5, 1, 4, 1.4)
			if randf() < 0.25: w.fx.sparks(pp, 3, Color("#ffd28a"), 10)
	update_model(dt)

func spend(v: float, cont := false) -> void:
	en -= v; en_wait = maxf(en_wait, stats.enDelay * (0.6 if cont else 1.0))
	if en <= 0:
		en = 0
		if not en_lock:
			en_lock = true; en_wait = stats.enDelay * 1.8; ab_on = false
			if is_player: world.emit({ "type": "alert", "text": "EN ESGOTADA" }); Sfx.play("warn")

# ═════════════ travamento ═════════════
func update_aim(dt: float) -> void:
	var w = world; var I := input
	var shocked: bool = status.shock.t > 0
	var t: Mech = target
	if t != null and (not t.alive or t.cloaked or shocked): t = null
	var c := center()
	if is_player:
		var rng := lock_range
		var valid := func(m: Mech) -> bool: return m.alive and not m.cloaked and m.team != team and m.center().distance_to(c) < rng and w.arena.los(c, m.center())
		if t != null and not (hard_lock and valid.call(t)): t = null
		if t == null and not shocked:
			var best := 0.09 if parts.head.state == 2 else 0.17; var bm: Mech = null
			for m in w.mechs:
				if m == self or not valid.call(m): continue
				var dv: Vector3 = (m.center() - aim_origin).normalized()
				var ang := acos(clampf(dv.dot(I.aimDir), -1, 1))
				if ang < best: best = ang; bm = m
			t = bm
			if hard_lock and t == null: hard_lock = false
	elif t != null:
		if t.center().distance_to(c) > lock_range * 1.25 or not w.arena.los(c, t.center()): t = null
	if t != target:
		lock_prog = 0; trk.ok = false
		if t != null and is_player: Sfx.play("lock")
	target = t
	if t != null:
		lock_prog += dt
		var tp := t.center(); var dist := tp.distance_to(c); var F: Dictionary = stats.fcs
		var acc: float
		if dist < 110: acc = F.near
		elif dist < 220: acc = lerpf(F.near, F.mid, (dist - 110) / 110)
		elif dist < 330: acc = lerpf(F.mid, F.far, (dist - 220) / 110)
		else: acc = F.far
		var k: float = 9.0 * stats.track * acc * aim_skill * (0.6 if (arm_state("handR") and arm_state("handL")) else 1.0)
		if not trk.ok: trk.p = tp; trk.v = t.vel; trk.ok = true
		trk.p += trk.v * dt
		trk.p = trk.p.lerp(tp, 1 - exp(-k * dt)); trk.v = trk.v.lerp(t.vel, 1 - exp(-k * 0.55 * dt))
		aim_err_t -= dt
		if aim_err_t <= 0:
			aim_err_t = 0.5 + randf() * 0.6
			var e := (1 - aim_skill) * dist * 0.035 + (dist * 0.08 if shocked else 0.0)
			aim_err = Vector3((randf() - 0.5) * e, (randf() - 0.5) * e * 0.6, (randf() - 0.5) * e)
		I.aimPoint = trk.p + aim_err
		var d: Vector3 = I.aimPoint - c; pitch = atan2(d.y, Vector2(d.x, d.z).length())
	else:
		lock_prog = 0; trk.ok = false
		if not is_player: I.aimPoint = c + Vector3(sin(yaw), 0, cos(yaw)) * 100
		var d: Vector3 = I.aimPoint - c; pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 1.2)

## Ponto de mira com predição para um projétil de velocidade spd.
func aim_for(from: Vector3, spd: float, grav := 0.0) -> Vector3:
	if target == null or not trk.ok: return input.aimPoint
	var out: Vector3 = trk.p + aim_err
	if spd > 0:
		var tt := minf(out.distance_to(from) / spd, 2.5)
		out += trk.v * tt
		var d2 := out.distance_to(from) / spd
		out = trk.p + aim_err + trk.v * minf(d2, 2.5)
		if grav: out.y += 0.5 * grav * d2 * d2
	out.y = maxf(out.y, 1.5)
	return out

# ═════════════ dano ═════════════
func add_status(k: String, v: float) -> void:
	var s = status[k]
	if s.t > 0 or not alive: return
	var res: float = stats.heatRes if k == "heat" else (stats.shockRes if k == "shock" else 0.0)
	s.v += v * (1 - res); s.idle = 0
	if s.v >= 100:
		s.v = 0; s.t = 6.0 if k == "heat" else (3.6 if k == "shock" else 9.0)
		var txt: String = { "heat": "SUPERAQUECIMENTO", "shock": "FCS EM CURTO", "corr": "BLINDAGEM CORROÍDA" }[k]
		world.emit({ "type": "status", "mech": self, "k": k, "text": txt }); Sfx.play("emp" if k == "shock" else "warn", pos, 0.8)
		if k == "shock": target = null; hard_lock = false; world.fx.sparks(center(), 30, Color("#9fe8ff"), 30)

func damage_raw(v: float, owner) -> void:
	if not alive: return
	st -= v
	if st <= 0: die(owner)

## h: { dmg, dt, imp, part, from, owner, st, point, armorMul, vsShield, quiet, melee }
func take_hit(h: Dictionary) -> float:
	if not alive: return 0.0
	var w = world; var own = h.get("owner")
	var dmg: float = h.dmg * (1.0 if h.get("melee", false) else 1.35) * (1.35 if w.mods.get("glass", false) else 1.0); var imp: float = h.get("imp", 0.0)
	if own != null and own is Mech: dmg *= own.perk.get(h.dt, 1.0); imp *= own.perk.imp
	var pt: Vector3 = h.get("point", center())
	if barrier.t > 0:
		barrier.hp -= dmg * h.get("vsShield", 1.0); w.fx.sparks(pt, 5, Color("#8fd8ff"), 16); Sfx.play("shieldhit", pt, 0.7)
		if barrier_mat: barrier_mat.set_shader_parameter("energy", 1.6)
		if barrier.hp <= 0: drop_barrier(true)
		if own != null and own is Mech and own.is_player: w.emit({ "type": "hit", "shield": true })
		return 0.0
	var mul := 1.0
	if shield_w != null and h.has("from"):
		var dv: Vector3 = h.from - pos
		var ang := absf(ang_diff(atan2(dv.x, dv.z), yaw))
		if ang < 1.25:
			var d: Dictionary = shield_w.def; var bk: float = d.parry if shield_t < 0.3 else d.block
			if h.get("vsShield", 0): bk *= 0.45
			mul *= 1 - bk; imp *= 1 - bk; spend(dmg * 0.25, true); w.fx.sparks(pt, 6, Color("#8fd8ff"), 18); Sfx.play("shieldhit", pt, 0.7)
			if shield_t < 0.3 and is_player: w.emit({ "type": "note", "text": "APARADO" })
	var i := 0 if h.dt == "k" else (1 if h.dt == "e" else 2)
	var part: String = h.get("part", "core")
	var def: float = stats.def[part][i] - (16.0 if status.corr.t > 0 else 0.0)
	mul *= clampf(1 - def / 100.0, 0.3, 1.3)
	var stg := staggered
	if stg: mul *= 1.4 + (own.perk.direct if (own != null and own is Mech) else 0.0)
	dmg *= mul
	var Pp = parts[part]; var sd: float
	if Pp.a > 0:
		Pp.a -= dmg * h.get("armorMul", 1.0); sd = dmg * 0.5
		if Pp.a <= 0: Pp.a = 0; breach(part)
	else:
		sd = dmg * (1.3 if part == "core" else 1.15)
		if part != "core" and Pp.state < 2:
			Pp.integ -= dmg
			if Pp.integ <= 0: destroy_part(part)
	st -= sd; dmg_taken += sd; last_hit_t = 0; last_dmg_from = own if own is Mech else null
	if own != null and own is Mech: own.dmg_dealt += sd
	if not stg and stagger_imm <= 0 and imp > 0:
		impact += imp * (0.82 if (grounded and (leg_type == "tank" or leg_type == "quad")) else 1.0) * (0.6 if anchor_t > 0 else 1.0); impact_t = 0
		if impact >= stab_max: stagger(own)
	if h.has("st") and h.st:
		for k in h.st: add_status(k, h.st[k])
	if own != null and own is Mech:
		if own.perk.shock: add_status("shock", dmg * 0.03 * own.perk.shock)
		if own.perk.burn: add_status("heat", dmg * 0.04 * own.perk.burn)
	if w.mods.get("heat", false) and h.dt == "e": add_status("heat", dmg * 0.05)
	if is_player:
		w.emit({ "type": "dmg", "from": h.get("from"), "amt": sd }); Sfx.play("hitself", null, clampf(sd / 300, 0.3, 1)); w.fx.add_shake(clampf(sd / 900, 0.04, 0.5))
	elif own != null and own is Mech and own.is_player: w.emit({ "type": "hit", "crit": stg, "part": part, "amt": sd, "pos": pt })
	if not h.get("quiet", false): Sfx.play("hit", pt, 0.8)
	if st <= 0: die(own)
	return sd

func breach(part: String) -> void:
	var Pp = parts[part]
	if Pp.state > 0: return
	Pp.state = 1
	var w = world; var p := part_pos(part)
	w.fx.sparks(p, 26, Color("#ffd28a"), 26); w.fx.spawn_debris(p, 6, Color(build.paint.get("b", "#777777")), 18, 0.7 * scale); w.fx.puff(p, 5, 3, Color("#2a2826"), 0.6, 3, 3, 1.4); w.fx.light(p, Color("#ffb060"), 50, 0.25)
	Sfx.play("break", p, 1)
	if stagger_imm <= 0 and not staggered:
		impact += stab_max * 0.25
		if impact >= stab_max: stagger(null)
	w.emit({ "type": "breach", "mech": self, "part": part })

func destroy_part(part: String) -> void:
	var Pp = parts[part]
	if Pp.state == 2: return
	Pp.state = 2; Pp.integ = 0
	var w = world; var p := part_pos(part)
	w.fx.explosion(p, 4 * scale, Color("#ffb060")); w.fx.spawn_debris(p, 10, Color(build.paint.get("a", "#777777")), 26, 0.9 * scale); Sfx.play("explosion", p, 1)
	if part == "head": model.head.visible = false; hard_lock = false
	if part == "armR": model.arm.R.el.visible = false
	if part == "armL": model.arm.L.el.visible = false
	damage_raw(st_max * 0.04, null)
	w.emit({ "type": "destroy", "mech": self, "part": part })

func restore_parts() -> void:
	for k in PARTS5:
		var p = parts[k]; p.a = p.max; p.integ = p.max * 0.6; p.state = 0
	model.head.visible = true; model.arm.R.el.visible = true; model.arm.L.el.visible = true

func stagger(by) -> void:
	stagger_t = 1.75; stagger_imm = 1.75 + 2.4; impact = stab_max; ab_on = false; melee = null
	if hook != null: end_hook(false)
	for k in weapons: weapons[k].interrupt()
	var w = world; Sfx.play("stagger", pos, 1); w.fx.sparks(center(), 34, Color("#ffe9a0"), 34); w.fx.ring(Vector3(pos.x, pos.y + aim_y, pos.z), Color("#ffd070"), radius * 4, 0.4)
	w.emit({ "type": "stagger", "mech": self, "by": by })

func die(by) -> void:
	if not alive: return
	alive = false; st = 0; dead_t = 0; ab_on = false; melee = null
	if hook != null: end_hook(false)
	drop_barrier(false)
	for k in weapons: weapons[k].interrupt()
	if by != null and by is Mech and by.alive and by.perk.salvage: by.st = minf(by.st_max, by.st + by.st_max * 0.06 * by.perk.salvage)
	world.emit({ "type": "kill", "mech": self, "by": by })

var _exploded := false
func update_dead(dt: float) -> void:
	var w = world; dead_t += dt
	if _exploded: return
	vel.y -= 30 * dt; vel.x *= 0.97; vel.z *= 0.97; pos += vel * dt
	var gy: float = w.arena.ground_at(pos.x, pos.z, pos.y, 1)
	if pos.y < gy: pos.y = gy; vel = Vector3.ZERO
	model.root.position = pos; model.body.rotation.x = minf(0.5, dead_t * 0.6); model.body.rotation.z = sin(dead_t * 30) * 0.03
	if randf() < dt * 9:
		var p := center() + Vector3((randf() - 0.5) * 5, (randf() - 0.5) * 6, (randf() - 0.5) * 5); w.fx.explosion(p, 3 + randf() * 3, Color("#ffb060")); Sfx.play("explosion", p, 0.7)
	for f in model.flames: f.m.visible = false
	if dead_t > 1.3:
		var c := center(); w.fx.explosion(c, 15 * scale, Color("#ffc070"), true)
		w.fx.spawn_debris(c, 30, Color(build.paint.get("a", "#777777")), 38, 1.2 * scale); w.fx.spawn_debris(c, 14, Color(build.paint.get("b", "#555555")), 30, 0.9 * scale)
		Sfx.play("bigexplosion", c, 1.2); w.fx.add_shake(clampf(60 / (10 + c.distance_to(w.cam_pos)), 0.1, 0.9)); w.fx.mark(pos, 12)
		model.root.visible = false; _exploded = true
		if cable: cable.visible = false

# ═════════════ corpo a corpo ═════════════
func start_melee(wp, mult := 1.0) -> void:
	var d: Dictionary = wp.def; ab_on = false
	melee = { "w": wp, "phase": "lunge", "t": 0.0, "mult": mult, "hit": false, "side": "L" if wp.slot == "handL" else "R" }
	if target != null:
		if target.pos.distance_to(pos) > d.lunge * 1.6: melee.phase = "swing"
	else: melee.phase = "swing"
	if d.get("enc", 0): spend(d.enc)
	Sfx.play("swing", pos, 0.9)
	var wn = model.wn.get(wp.slot)
	if wn and wn.blade: wn.blade.visible = true

func update_melee(dt: float) -> void:
	var M = melee; var d: Dictionary = M.w.def; var w = world; var t := target; M.t += dt
	if t != null and t.alive:
		var dv := t.pos - pos; yaw += clampf(ang_diff(atan2(dv.x, dv.z), yaw), -12 * dt, 12 * dt)
	if M.phase == "lunge":
		var dist := Vector2(t.pos.x - pos.x, t.pos.z - pos.z).length() if t != null else 0.0
		var reach: float = d.reach * scale + (t.radius if t != null else 0.0)
		if t == null or dist < reach * 0.8 or M.t > 0.5 or blocked > 0.2:
			M.phase = "swing"; M.t = 0.0; vel *= 0.35
		else:
			var dir := (t.center() - center()).normalized(); var spd := maxf(70.0, d.lunge * 2.6)
			vel = Vector3(dir.x * spd, dir.y * spd * 0.8, dir.z * spd)
			if randf() < dt * 60: w.fx.thrust(center(), -dir, model.flameCol, 3, 30)
	elif M.phase == "swing":
		if not M.hit and M.t > (0.1 if d.get("thrust", 0) else 0.13):
			M.hit = true; var any := false
			var reach: float = d.reach * scale + radius
			for m in w.mechs:
				if m.team == team or not m.alive: continue
				var dv: Vector3 = m.pos - pos; var dist = Vector2(dv.x, dv.z).length() - m.radius
				if dist > reach or absf(m.pos.y - pos.y) > 12: continue
				if absf(ang_diff(atan2(dv.x, dv.z), yaw)) > 1.15: continue
				var part := "core" if randf() < 0.6 else ("armR" if randf() < 0.5 else ("armL" if randf() < 0.5 else "head"))
				var mm: float = stats.melee * M.mult * (0.6 if arm_state(M.w.slot) else 1.0)
				var pp: Vector3 = m.part_pos(part)
				m.take_hit({ "dmg": d.dmg * mm, "dt": d.dt, "imp": d.imp * M.mult, "part": part, "from": pos, "owner": self, "point": pp, "quiet": true, "melee": true })
				w.fx.sparks(pp, 40, Color(model.mat.get_shader_parameter("glow")) if d.dt == "e" else Color("#ffd28a"), 34); w.fx.light(pp, Color("#fff0c0"), 90, 0.2); any = true
				var hd := Vector3(dv.x, 0, dv.z).normalized(); m.vel += hd * 26.0 * clampf(weight / m.weight, 0.4, 1.6)
			Sfx.play("meleehit" if any else "swing", pos, 1)
			if any: w.fx.add_shake(0.45 if is_player else 0.15)
			var wn = model.wn.get(M.w.slot)
			if wn and wn.m.has("tip"): w.fx.sparks(wn.m.tip.global_position, 10, Color("#ffc070"), 18)
		if M.t > 0.34: M.phase = "rec"; M.t = 0.0
	elif M.t > 0.3:
		var wn = model.wn.get(M.w.slot)
		if wn and wn.blade: wn.blade.visible = false
		melee = null

# ═════════════ utilitários ═════════════
func use_util() -> void:
	var u = P.util; var w = world
	if u == null or util_cd > 0 or u.act == "passive": return
	if u.act == "hook":
		if hook != null: return
		var from := muzzle("util")
		var to: Vector3 = target.center() if target != null else input.aimPoint
		var dir := (to - from).normalized()
		hook = { "phase": "out", "p": from, "dir": dir, "dist": 0.0, "t": 0.0, "mech": null, "def": u, "off": Vector3.ZERO, "drag": false }
		util_cd = u.cd; Sfx.play("hook", pos, 0.9)
		if cable == null:
			var cm := CylinderMesh.new(); cm.top_radius = 0.06; cm.bottom_radius = 0.06; cm.height = 1; cm.radial_segments = 5
			cable = MeshInstance3D.new(); cable.mesh = FX._xform_mesh(cm, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, 0.5)))
			var cmat := StandardMaterial3D.new(); cmat.albedo_color = Color("#2a2a2c"); cmat.metallic = 0.9; cmat.roughness = 0.4; cable.material_override = cmat
			hook_head = Builder.build_hook_head(model.mat, int(u.m.v)); w.add_child(cable); w.add_child(hook_head)
		cable.visible = true; hook_head.visible = true
		if model.util and model.util.claw: model.util.claw.visible = false
	elif u.act == "barrier":
		barrier.t = u.dur; barrier.hp = u.hp; barrier.max = u.hp; util_cd = u.cd; Sfx.play("shield", pos, 1)
		if barrier_mesh == null:
			barrier_mesh = MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 1; sm.height = 2; sm.radial_segments = 24; sm.rings = 12; barrier_mesh.mesh = sm
			barrier_mat = ShaderMaterial.new(); barrier_mat.shader = FX.fxadd_shader; barrier_mat.set_shader_parameter("radial", true); barrier_mat.set_shader_parameter("col", Color("#58c8ff")); barrier_mat.set_shader_parameter("energy", 0.6); barrier_mat.render_priority = 3
			barrier_mesh.material_override = barrier_mat; barrier_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; w.add_child(barrier_mesh)
		barrier_mesh.visible = true; barrier_mesh.scale = Vector3.ONE * height * 0.75
	elif u.act == "cloak": cloak_t = u.dur; util_cd = u.cd; set_cloak(true); Sfx.play("shield", pos, 0.8)
	elif u.act == "burst":
		if util_charges <= 0: return
		util_charges -= 1; util_cd = 1.5
		var c := center(); w.fx.orb(c, Color("#9fe0ff"), u.rad, 0.45); w.fx.explosion(c, 10, Color("#9fe0ff"), true); w.fx.add_shake(0.6); Sfx.play("emp", c, 1.2); Sfx.play("bigexplosion", c, 0.8)
		for m in w.mechs:
			if m.team == team or not m.alive: continue
			var d: float = m.center().distance_to(c)
			if d < u.rad + m.radius:
				var f: float = 1 - 0.5 * d / u.rad
				m.take_hit({ "dmg": u.dmg * f, "dt": "e", "imp": u.imp * f, "part": "core", "from": c, "owner": self, "vsShield": 4 })
				var pd: Vector3 = (m.pos - pos); pd.y = 0; m.vel += pd.normalized() * 40
		w.clear_projectiles_near(c, u.rad, team)

func set_cloak(on: bool) -> void:
	model.mat.set_shader_parameter("cloak", 0.86 if on else 0.0)
	if on: world.fx.puff(center(), 8, 4, Color("#99aabb"), 0.3, 4, 1, 0.8)

func drop_barrier(broken: bool) -> void:
	if barrier.t <= 0 and not broken:
		if barrier_mesh: barrier_mesh.visible = false
		return
	barrier.t = 0
	if barrier_mesh: barrier_mesh.visible = false
	if broken:
		var c := center(); world.fx.ring(c, Color("#58c8ff"), height, 0.4); world.fx.sparks(c, 40, Color("#8fd8ff"), 40); Sfx.play("break", c, 0.9)
		if stagger_imm <= 0: impact += stab_max * 0.4

func update_hook(dt: float) -> void:
	var H = hook; var w = world; var u: Dictionary = H.def; H.t += dt
	if H.phase == "out":
		var step := 300.0 * dt
		var d: float = w.arena.ray(H.p, H.dir, step)
		var mh = w.ray_mechs(H.p, H.dir, minf(step, d), team, null)
		if mh != null:
			H.p += H.dir * mh.t; H.mech = mh.mech; H.off = H.p - mh.mech.pos; H.phase = "pull"; H.t = 0.0; Sfx.play("clank", H.p, 1); w.fx.sparks(H.p, 14, Color("#ffd28a"), 16)
			if u.get("harpoon", 0):
				mh.mech.take_hit({ "dmg": u.dmg, "dt": "k", "imp": u.imp, "part": mh.part, "from": pos, "owner": self, "point": H.p })
				H.drag = mh.mech.weight < weight * 1.15
		elif d != INF:
			H.p += H.dir * d; H.phase = "pull"; H.t = 0.0; Sfx.play("clank", H.p, 1); w.fx.sparks(H.p, 14, Color("#ffd28a"), 16)
		else:
			H.p += H.dir * step; H.dist += step
			w.arena.clamp_pos(H.p, 0)
			if H.dist > u.rng or w.arena.clamped: H.phase = "back"
	elif H.phase == "pull":
		if H.mech != null:
			if not H.mech.alive: end_hook(false); return
			H.p = H.mech.pos + H.off
		var c := center(); var to: Vector3 = H.p - c; var dist := to.length(); to /= maxf(0.01, dist)
		if H.drag and H.mech != null:
			H.mech.vel = to * (-u.pull * 0.8); H.mech.grounded = false; vel *= 0.9
			if dist < radius + H.mech.radius + 6 or H.t > 1.4: H.mech.vel *= 0.2; end_hook(false)
		else:
			var spd: float = u.pull * (0.6 + minf(0.4, H.t * 1.5)); vel = to * spd; grounded = false
			if dist < 9 + (H.mech.radius if H.mech != null else 0.0) or H.t > 1.8 or staggered: end_hook(true)
	else:
		var m := muzzle("util")
		H.p = H.p.lerp(m, minf(1.0, 14 * dt))
		if (H.t > 0.25 and H.p.distance_to(m) < 4) or H.t > 1.2:
			hook = null; cable.visible = false; hook_head.visible = false
			if model.util and model.util.claw: model.util.claw.visible = true
			return
	if hook == null: return
	var m2 := muzzle("util")
	cable.global_position = m2
	var dl: float = m2.distance_to(H.p)
	if dl > 0.05:
		var dd: Vector3 = (H.p - m2) / dl
		cable.look_at(H.p, Vector3.UP if absf(dd.y) < 0.98 else Vector3.RIGHT, true); cable.scale = Vector3(1, 1, dl)
	hook_head.global_position = H.p
	if H.dir.length() > 0.1: hook_head.look_at(H.p + H.dir, Vector3.UP if absf(H.dir.y) < 0.98 else Vector3.RIGHT, true)

func end_hook(keep_momentum: bool) -> void:
	if hook == null: return
	if hook.phase == "pull" and keep_momentum:
		vel *= 0.62
		if vel.y < 14: vel.y += 8
	hook.phase = "back"; hook.t = 0.0; hook.mech = null

# ═════════════ animação ═════════════
func update_model(dt: float) -> void:
	var M := model; var w = world; var I := input; var S := stats
	M.root.position = pos; M.root.rotation.y = yaw
	var sy := sin(yaw); var cy := cos(yaw)
	var lf := vel.x * sy + vel.z * cy; var ls := vel.x * cy - vel.z * sy; var hs := Vector2(vel.x, vel.z).length()
	var stg := staggered
	var bxr := 0.38 + sin(w.time * 40) * 0.02 if stg else clampf(lf * 0.0065, -0.3, 0.34) + (0.12 if anchor_t > 0 else 0.0)
	M.body.rotation.x = lerpf(M.body.rotation.x, bxr, minf(1.0, 9 * dt)); M.body.rotation.z = lerpf(M.body.rotation.z, clampf(-ls * 0.0065, -0.3, 0.3), minf(1.0, 9 * dt))
	var ly := 0.0
	if hs > 3:
		ly = ang_diff(atan2(vel.x, vel.z), yaw)
		if absf(ly) > PI / 2: ly = ang_diff(ly + PI, 0)
		ly = clampf(ly, -1.1, 1.1)
	leg_yaw = lerpf(leg_yaw, ly, minf(1.0, (4.0 if is_tank else 7.0) * dt)); M.legsG.rotation.y = leg_yaw; M.legsG.rotation.x = -M.body.rotation.x * 0.7; M.legsG.rotation.z = -M.body.rotation.z * 0.7
	var walk_sp: float = S.groundSpeed * 1.2; var glide := hs > walk_sp
	if grounded and hs > 1:
		phase += minf(hs, walk_sp * 1.2) * dt * 0.62
		var sgn := int(floor(phase / PI))
		if sgn != step_side and not glide and M.anim.type != "tank": step_side = sgn; Sfx.play("step", pos, 0.55 if is_player else 0.4)
	var amp := 0.0 if not grounded else (0.12 if glide else clampf(hs / walk_sp, 0, 1))
	var crouch := 0.5 if not grounded else (0.55 if glide else (0.8 if land_t > 0 else (0.7 if anchor_t > 0 else 0.0)))
	land_t -= dt
	crouch_s = lerpf(crouch_s, crouch, minf(1.0, 10 * dt)); amp_s = lerpf(amp_s, amp, minf(1.0, 8 * dt))
	Builder.pose_legs(M, phase, amp_s, crouch_s)
	if M.anim.type == "tank":
		var sc: float = M.mat.get_shader_parameter("track_scroll"); M.mat.set_shader_parameter("track_scroll", sc - lf * dt * 0.16 * 3.0)
		M.body.position.y = sin(w.time * 30) * 0.03 if (grounded and hs > 2) else 0.0
	for e in [["R", "handR"], ["L", "handL"]]:
		var k: String = e[0]; var slot: String = e[1]; var A = M.arm[k]
		recoil[k] = maxf(0.0, recoil[k] - dt * 5)
		var active: bool = fire_t[slot] < 1.6 or target != null or is_player
		var ex := -pitch if active else 0.4; var sx := 0.0; var syw := 0.0
		if melee != null and melee.side == k:
			var m = melee; var d: Dictionary = m.w.def
			if d.get("thrust", 0):
				if m.phase == "lunge": sx = 0.5; ex = -0.2
				elif m.phase == "swing": sx = -0.7 * minf(1.0, m.t / 0.1); ex = 0.3
				var spk = M.wn[slot].spike if M.wn.has(slot) else null
				if spk: spk.position.z = 1.4 + minf(1.0, m.t / 0.08) * 1.6 if m.phase == "swing" else 1.4
			elif m.phase == "lunge": sx = -1.5; ex = -0.5; syw = 0.5 if k == "L" else -0.5
			elif m.phase == "swing":
				var tt := minf(1.0, m.t / 0.22); sx = -1.5 + tt * 2.0; ex = -0.5 + tt * 0.7; syw = (1.0 if k == "L" else -1.0) * (0.5 - tt * 1.5)
			else: sx = 0.5 - m.t; ex = 0.2
		if weapons.has(slot) and weapons[slot].def.wt == "shield" and shield_w == weapons[slot]: ex = -0.3; syw = -0.7 if k == "L" else 0.7
		ex -= recoil[k] * 0.5
		if stg: ex = 0.9; sx = 0.2
		A.el.rotation.x = lerpf(A.el.rotation.x, ex, minf(1.0, 14 * dt)); A.sh.rotation.x = lerpf(A.sh.rotation.x, sx, minf(1.0, 16 * dt)); A.sh.rotation.y = lerpf(A.sh.rotation.y, syw, minf(1.0, 16 * dt))
	for slot in ["backR", "backL"]:
		var n = M.wn.get(slot)
		if n == null or n.pv == null or n.fixed: continue
		var act: bool = fire_t[slot] < 2.2 or I.fire[slot] or (weapons.has(slot) and weapons[slot].chg > 0)
		n.pv.rotation.x = lerpf(n.pv.rotation.x, -clampf(pitch, -0.3, 0.9) if act else -(n.stow if n.stow else 0.22), minf(1.0, (10.0 if act else 3.0) * dt))
	for s in M.spin:
		var wp = weapons.get(s.key)
		s.g.rotation.z += (wp.spin_v if wp else 0.0) * 40 * dt
	for s in M.spinY: s.rotation.y += dt * 1.6
	M.head.rotation.x = lerpf(M.head.rotation.x, clampf(-pitch * 0.6, -0.5, 0.5), minf(1.0, 8 * dt))
	# chamas
	var moving: bool = Vector2(I.mx, I.mz).length() > 0.1 and hs > 4; var qb := qb_fx > 0
	var base := 5.5 if ab_on else (6.5 if qb else (2.2 + randf() * 0.5 if moving else (2.6 if ascending else 0.0)))
	for f in M.flames:
		var L := 0.0
		if f.up: L = 3.2 + randf() if (ascending or ab_on) else 0.0
		elif f.qb: L = 5.0 if (qb and (qb_dir.x * cy - qb_dir.z * sy) * f.qb < -0.2) else 0.0
		else: L = base
		if stg: L = 0
		f.L = lerpf(f.L, L, minf(1.0, 18 * dt))
		if f.L > 0.08: f.m.visible = true; f.m.scale = Vector3(f.r * 1.5, f.r * 1.5, f.L * (0.9 + randf() * 0.2))
		else: f.m.visible = false
	thr_t -= dt
	if thr_t <= 0 and (base > 0 or ascending) and M.flames.size() > 0:
		thr_t = 0.035
		var f = M.flames[randi() % M.flames.size()]
		if f.m.visible:
			var o: Node3D = f.o
			w.fx.thrust(o.global_position, -o.global_transform.basis.z.normalized(), M.flameCol, 2.2 * scale, 26 + base * 6)
		if grounded and hs > 14 and randf() < 0.5: w.fx.dust(pos + Vector3(0, 0.4, 0), 1, 3.5, w.arena.dust)
	if barrier_mesh and barrier_mesh.visible:
		barrier_mesh.global_position = center(); barrier_mesh.rotation.y += dt * 0.6
		var e: float = barrier_mat.get_shader_parameter("energy"); barrier_mat.set_shader_parameter("energy", lerpf(e, 0.25 + 0.45 * barrier.hp / barrier.max, minf(1.0, 6 * dt)))
	M.mat.set_shader_parameter("heat", lerpf(float(M.mat.get_shader_parameter("heat")), 0.6 if status.heat.t > 0 else 0.0, minf(1.0, 3 * dt)))

func dispose() -> void:
	if is_instance_valid(model.root): model.root.queue_free()
	for o in [cable, hook_head, barrier_mesh]:
		if o and is_instance_valid(o): o.queue_free()
	# quebra ciclos de referência (carcaça ↔ armas ↔ alvo), senão nada disso é liberado
	for k in weapons:
		var wp = weapons[k]; wp.mech = null; wp.queue.clear()
	weapons.clear(); target = null; last_dmg_from = null; world = null
