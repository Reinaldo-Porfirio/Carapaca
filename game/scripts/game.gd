## Partida: arena, entrada do jogador, câmera, ondas do modo infinito e condição de vitória.
class_name Match extends Node3D

var app
var cfg: Dictionary
var rng
var arena: Arena
var world: World
var cam: Camera3D
var player: Mech
var ais: Array = []
var queue: Array = []
var wave := 0
var score := 0
var kills := 0
var perks := {}
var earned := 0
var cam_yaw := 0.0
var cam_pitch := 0.08
var state := "intro"
var t := 0.0
var time := 0.0
var time_scale := 1.0
var paused := false
var fov := 62.0
var breaches := 0
var last_count := 4
var win := false
var auto: AI = null
var pivot := Vector3.ZERO
var pivot_ok := false

func _init(a, c: Dictionary) -> void:
	app = a; cfg = c; name = "match"

func start() -> void:
	rng = D.Rng.new(int(cfg.get("seed", 1)) * 31 + 7)
	arena = Arena.new(); arena.build(cfg.arena, int(cfg.get("seed", 1)), { "fog": cfg.get("mods", {}).get("fog", false) })
	world = World.new(); add_child(world); world.setup(arena, cfg.get("mods", {}))
	cam = Camera3D.new(); cam.fov = 62; cam.near = 0.5; cam.far = 2400; add_child(cam); cam.current = true
	Settings.apply_viewport(get_viewport())
	player = world.add(Mech.new(world, cfg.playerBuild, { "team": 0, "player": true, "name": cfg.playerBuild.get("name", "") }))
	player.pos = arena.spawn_p; player.yaw = 0; player.input.yaw = 0
	var al: Array = cfg.get("allies", [])
	for i in al.size(): spawn(al[i], 0, i)
	queue = cfg.get("enemies", []).duplicate()
	if cfg.get("endless", false): next_wave()
	elif cfg.get("sequence", false): spawn(queue.pop_front(), 1, 0)
	else:
		var all := queue.duplicate(); queue.clear()
		for i in all.size(): spawn(all[i], 1, i, all.size())
	if cfg.has("autopilot"): auto = AI.new(player, cfg.autopilot)
	Sfx.set_music(1.0)
	app.hud.begin(self)
	update_camera(0.016, true)

func spawn(spec: Dictionary, team: int, i: int, n := 1) -> Mech:
	var w := world; var A := arena
	var m := w.add(Mech.new(w, spec.build, { "team": team, "name": spec.get("name", ""), "call": spec.get("call", ""), "hpMul": spec.get("hpMul", 1.0), "scale": spec.get("scale", 1.0) }))
	var base := A.spawn_p if team == 0 else A.spawn_e; var off := (i - (n - 1) / 2.0) * 30 + (-24.0 if team == 0 else 0.0)
	m.pos = Vector3(base.x + off, 0, base.z + (-6.0 if team == 0 else 0.0)); m.pos = A.clamp_pos(m.pos, m.radius + 4)
	m.pos.y = A.ground_at(m.pos.x, m.pos.z, 1e9, m.radius); m.yaw = 0.0 if team == 0 else PI; m.input.yaw = m.yaw
	var ai := AI.new(m, spec.get("ai", {})); ais.append(ai); m.spec = spec
	if state == "fight":
		w.fx.orb(m.center(), Color("#ffd9a0"), 14, 0.5); w.fx.ring(m.pos + Vector3(0, 0.5, 0), Color("#ffd9a0"), 16, 0.6); Sfx.play("emp", m.pos, 0.6)
	return m

# ───────── modo infinito ─────────
func next_wave() -> void:
	wave += 1; var n := wave; var boss := n % 5 == 0
	var tier := mini(5, int(floor((n - 1) / 2.2))); var skill := clampf(0.1 + n * 0.045, 0, 0.95)
	var count := (2 if n >= 10 else 1) if boss else mini(4, 1 + n / 3)
	var keep := []
	for m in world.mechs:
		if m.alive or m == player: keep.append(m)
		else: m.dispose()
	world.mechs = keep
	ais = ais.filter(func(a): return a.m.alive)
	for i in count:
		var is_boss := boss and i == 0
		var arch: String = rng.pick(["fortress", "brawler", "energy"]) if is_boss else rng.pick(Stats.ARCH.keys())
		var b := Stats.random_build(rng, mini(5, tier + 1) if is_boss else tier, arch)
		var ai_traits: Dictionary = b._ai.duplicate(); ai_traits.skill = minf(1.0, skill + 0.15) if is_boss else skill
		var spec := { "build": b, "call": rng.pick(D.CALLSIGNS), "name": rng.pick(D.MECHNAMES), "ai": ai_traits,
			"hpMul": (1.7 + n * 0.05) if is_boss else clampf(0.5 + n * 0.035, 0.5, 1.2) / (1.25 if count > 2 else 1.0), "scale": 1.28 if is_boss else (0.88 if count > 2 else 1.0), "boss": is_boss }
		var m := spawn(spec, 1, i, count)
		var a: float = rng.rf() * TAU; var d := arena.size * 0.7
		m.pos = arena.clamp_pos(Vector3(cos(a) * d, 0, sin(a) * d), m.radius + 6); m.pos.y = 40 + i * 6; m.grounded = false
	app.hud.banner(("ONDA %d — ALVO PRIORITÁRIO" % n) if boss else ("ONDA %d" % n), "Estrutura reforçada. Recompensa dobrada." if boss else ("%d %s" % [count, "adversários" if count > 1 else "adversário"]))
	Sfx.play("alert")

func perk_choices() -> Array:
	var pool := D.PERKS.filter(func(p): return perks.get(p.id, 0) < p.max); var out := []
	while out.size() < 3 and pool.size(): out.append(pool.pop_at(rng.ri(0, pool.size() - 1)))
	return out

func apply_perk(id: String) -> void:
	var p := player; var k := p.perk; perks[id] = perks.get(id, 0) + 1
	match id:
		"kdmg": k.k += 0.18
		"edmg": k.e += 0.18
		"xdmg": k.x += 0.18
		"rof": k.rof += 0.12
		"imp": k.imp += 0.25
		"ammo":
			for s in p.weapons: p.weapons[s].refill(1.2)
		"kit": p.kits += 1
		"plate": p.restore_parts()
		"struct": var add := p.st_max * 0.12; p.st_max += add; p.st += add
		"en": k.en += 0.25
		"qb": k.qb *= 0.78
		"salvage": k.salvage += 1
		"stab": k.stab += 0.25
		"missile": k.missile += 2
		"direct": k.direct += 0.3
		"shockr": k.shock += 1
		"burn": k.burn += 1
		"speed": k.speed += 0.1
	Sfx.play("buy")

# ───────── laço ─────────
func step(raw_dt: float) -> void:
	if paused: return
	var w := world; var p := player; t += raw_dt
	var dt := raw_dt * time_scale
	if state == "intro":
		var c := 3 - int(floor(t / 0.8))
		if c != last_count and c > 0: last_count = c; app.hud.count(c); Sfx.play("count")
		if t > 2.4: state = "fight"; app.hud.count(0); Sfx.play("go"); Ctl.frame()
	var fighting := state == "fight"
	if fighting:
		time += dt
		if auto: auto.update(dt, w); cam_yaw = p.input.yaw; cam_pitch = p.pitch
		else: control(raw_dt)
		for a in ais: a.update(dt, w)
	elif state != "perk":
		for mm in w.mechs:
			var J: Dictionary = mm.input; J.mx = 0.0; J.mz = 0.0; J.jump = false; J.qb = false; J.ab = false; J.jumpP = false; J.util = false; J.repair = false
			for k in J.fire: J.fire[k] = false
	if state != "perk": w.tick(dt)
	update_camera(raw_dt)
	arena.tick(dt, cam.global_position)
	for e in w.events:
		if e.type == "kill":
			if e.mech == p:
				if state == "fight": finish(false)
			elif e.mech.team != 0:
				kills += 1; score += 100 * maxi(wave, 1) * (5 if e.mech.spec.get("boss", false) else 1)
		if e.type == "breach" and e.mech != p and e.mech.team != 0: breaches += 1
	app.hud.tick(self, raw_dt, w.events); w.events.clear()
	if fighting:
		var left := 0
		for mm in w.mechs:
			if mm.team != 0 and mm.alive: left += 1
		if left == 0:
			if cfg.get("sequence", false) and queue.size():
				spawn(queue.pop_front(), 1, 0); app.hud.banner("PRÓXIMO ADVERSÁRIO", "Restam %d" % (queue.size() + 1))
			elif cfg.get("endless", false):
				state = "clear"; t = 0; var pay := 1500 + 500 * wave * (2 if wave % 5 == 0 else 1); earned += pay; score += 250 * wave
				app.hud.banner("ONDA %d LIMPA" % wave, "+%s CR" % UI.fmt(pay)); Sfx.play("ok")
			else: finish(true)
	elif state == "clear" and t > 1.8:
		state = "perk"; Ctl.capture(false); p.st = minf(p.st_max, p.st + p.st_max * 0.15); p.en = p.en_max; Sfx.set_boost(0)
		if auto:
			var ch := perk_choices(); if ch.size(): apply_perk(ch[0].id)
			state = "fight"; next_wave()
		else:
			app.ui.show_perks(perk_choices(), self, func(id):
				if id: apply_perk(id)
				state = "fight"; next_wave(); Ctl.capture(true))
	elif state == "over":
		time_scale = lerpf(time_scale, 0.3, minf(1.0, raw_dt * 4))
		if t > 3.0: state = "done"; end()
	Sfx.set_listener(cam.global_position)
	var spd := Vector2(p.vel.x, p.vel.z).length()
	Sfx.set_boost(clampf((1.6 if p.ab_on else (1.5 if p.qb_fx > 0 else spd / 50.0)) + (0.5 if p.ascending else 0.0), 0, 1.6) if (p.alive and state != "perk") else 0.0)

func finish(won: bool) -> void:
	if state == "over" or state == "done": return
	state = "over"; t = 0; win = won; player.hard_lock = false
	app.hud.banner("ADVERSÁRIO NEUTRALIZADO" if won else "CARCAÇA PERDIDA", "" if won else ("Onda %d" % wave if cfg.get("endless", false) else ""), true)
	Sfx.play("win" if won else "lose"); Sfx.set_music(0.2)

func end() -> void:
	var p := player; Sfx.set_boost(0)
	cfg.onEnd.call({ "win": win, "time": time, "dealt": roundi(p.dmg_dealt), "taken": roundi(p.dmg_taken), "kills": kills, "wave": wave, "score": score, "earned": earned, "breaches": breaches, "left": roundi(p.st / p.st_max * 100), "perks": perks })

# ───────── controle do jogador ─────────
func control(dt: float) -> void:
	var p := player; var I: Dictionary = p.input; var g := Ctl.pad()
	var dx := Ctl.mdx; var dy := Ctl.mdy
	if g: dx += g.rx * 900 * dt; dy += g.ry * 600 * dt
	var s := 0.0022 * Settings.sens
	if not p.hard_lock or p.target == null:
		cam_yaw -= dx * s; cam_pitch = clampf(cam_pitch - dy * s * (-1.0 if Settings.inv_y else 1.0), -1.1, 1.25)
	if Ctl.pressed(KEY_T) or Ctl.mouse_pressed(MOUSE_BUTTON_MIDDLE) or (g and g.p[8]):
		if p.hard_lock: p.hard_lock = false
		elif p.target != null: p.hard_lock = true; Sfx.play("lock")
		else: cycle_target(1, true)
	if Ctl.pressed(KEY_TAB) or Ctl.wheel != 0 or (g and g.p[14]): cycle_target(-1 if Ctl.wheel < 0 else 1, false)
	if p.hard_lock and p.target != null:
		var a := p.target.center() - Vector3(p.pos.x, p.pos.y + p.height * 0.8, p.pos.z)
		var ty := atan2(a.x, a.z); var tp := atan2(a.y, Vector2(a.x, a.z).length()) + 0.07
		var d := Mech.ang_diff(ty, cam_yaw); var k := minf(1.0, 12 * dt)
		cam_yaw += d * k; cam_pitch += (clampf(tp, -1.1, 1.25) - cam_pitch) * k
	var mx := (1.0 if Ctl.key(KEY_D) else 0.0) - (1.0 if Ctl.key(KEY_A) else 0.0)
	var mz := (1.0 if Ctl.key(KEY_W) else 0.0) - (1.0 if Ctl.key(KEY_S) else 0.0)
	if g: mx += g.lx; mz -= g.ly
	I.mx = clampf(mx, -1, 1); I.mz = clampf(mz, -1, 1)
	I.jump = Ctl.key(KEY_SPACE) or (g and g.b[0]); I.jumpP = Ctl.pressed(KEY_SPACE) or (g and g.p[0])
	I.qb = Ctl.pressed(KEY_SHIFT) or (g and g.p[2])
	I.ab = Ctl.pressed(KEY_CTRL) or Ctl.pressed(KEY_C) or (g and g.p[7])
	I.fire.handL = Ctl.mouse(MOUSE_BUTTON_LEFT) or (g and g.b[9]); I.fire.handR = Ctl.mouse(MOUSE_BUTTON_RIGHT) or (g and g.b[10])
	I.fire.backL = Ctl.key(KEY_Q) or (g and g.lt); I.fire.backR = Ctl.key(KEY_E) or (g and g.rt)
	I.fire.shoulder = Ctl.key(KEY_R) or (g and g.b[11]); I.util = Ctl.pressed(KEY_F) or (g and g.p[12]); I.repair = Ctl.pressed(KEY_G) or (g and g.p[3])
	I.yaw = cam_yaw

func cycle_target(dir: int, nearest: bool) -> void:
	var p := player; var w := world; var c := p.center()
	var list := w.mechs.filter(func(m): return m.alive and m.team != 0 and not m.cloaked and m.center().distance_to(c) < p.lock_range and w.arena.los(c, m.center()))
	if list.is_empty() or p.status.shock.t > 0 or p.parts.head.state == 2: Sfx.play("error", null, 0.5); return
	var ang := func(m) -> float: var dv: Vector3 = m.pos - p.pos; return Mech.ang_diff(atan2(dv.x, dv.z), cam_yaw)
	if nearest: list.sort_custom(func(a, b): return absf(ang.call(a)) < absf(ang.call(b)))
	else: list.sort_custom(func(a, b): return ang.call(a) < ang.call(b))
	var i := 0
	if not nearest: i = (list.find(p.target) + dir + list.size()) % list.size()
	p.target = list[maxi(0, i)]; p.lock_prog = 0; p.trk.ok = false; p.hard_lock = true; Sfx.play("lock")

func update_camera(dt: float, snap := false) -> void:
	var p := player; var w := world
	var cy := cos(cam_yaw); var sy := sin(cam_yaw); var cp := cos(cam_pitch); var sp := sin(cam_pitch)
	var fwd := Vector3(sy * cp, sp, cy * cp); var right := Vector3(-cy, 0, sy)
	var dist := p.height * 2.15 + 3; var yaw_off := 0.0
	if state == "intro": var k := 1.0 - clampf(t / 2.2, 0, 1); yaw_off = k * k * 2.6; dist += k * 10
	if state == "over" and not win: dist += minf(18.0, t * 6)
	var pv := Vector3(p.pos.x, p.pos.y + p.height * 0.8, p.pos.z)
	if not pivot_ok or snap: pivot = pv; pivot_ok = true
	pivot = pivot.lerp(pv, minf(1.0, 18 * dt))
	var f2 := Vector3(sin(cam_yaw + yaw_off) * cp, sp, cos(cam_yaw + yaw_off) * cp)
	var want := pivot - f2 * dist + right * p.radius * 1.25 * (0.0 if yaw_off != 0.0 else 1.0) + Vector3(0, 1.6, 0)
	var dv := want - pivot; var len := dv.length(); dv /= len
	var tt := w.arena.ray(pivot, dv, len)
	if tt != INF and tt < len: want = pivot + dv * maxf(2.0, tt - 1.2)
	if want.y < 1.2: want.y = 1.2
	want = w.arena.clamp_pos(want, -2)
	var sh := w.fx.shake
	if sh > 0: want += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * sh * 1.6
	cam.global_position = want
	cam.look_at(want + f2 * 100, Vector3.UP)
	var tf := 76.0 if p.ab_on else (68.0 if p.qb_fx > 0 else 62.0); fov = lerpf(fov, tf, minf(1.0, 6 * dt))
	if absf(cam.fov - fov) > 0.05: cam.fov = fov
	w.cam_pos = want
	var I: Dictionary = p.input; I.aimDir = fwd; p.aim_origin = want
	if p.target == null:
		var o := want + fwd * (dist + 4)
		var d := w.arena.ray(o, fwd, 600)
		var mh = w.ray_mechs(o, fwd, minf(600.0, d), 0, null)
		if mh != null: d = mh.t
		if d == INF: d = 400
		I.aimPoint = o + fwd * maxf(12.0, d)

func dispose() -> void:
	app.hud.end(); Sfx.set_boost(0)
	if world: world.dispose()
	queue_free()
