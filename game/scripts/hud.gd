## HUD de combate: silhueta de dano, arcos de estrutura/EN/impacto, retículo, travamento, radar e alertas.
class_name HUD extends Control

const INK := Color("#d9d5c7")
const DIM := Color("#8f8c80")
const FAINT := Color("#5a584f")
const AMB := Color("#f2a22c")
const RED := Color("#e5482d")
const CY := Color("#74d3d9")
const OK := Color("#a6d06c")
const BG := Color(0.043, 0.047, 0.051, 0.78)
const KEYLBL := { "handL": "BTN ESQ", "handR": "BTN DIR", "backL": "Q", "backR": "E", "shoulder": "R", "util": "F" }
const SLOTLBL := { "handL": "MÃO E", "handR": "MÃO D", "backL": "DORSO E", "backR": "DORSO D", "shoulder": "OMBROS", "util": "UTIL" }

var match_ref = null
var alerts: Array = []
var banner_t := 0.0
var banner_txt := ["", ""]
var count_txt := ""
var count_t := 0.0
var hit_t := 0.0
var hit_kind := ""
var dmg_arcs: Array = []
var help_t := 0.0
var warn_t := 0.0
var warn_on := false
var me_sil: Array = []
var tg_sil: Array = []
var tg_ref = null
var vig: TextureRect
var stat: ColorRect
var stat_mat: ShaderMaterial
var info_title := ""
var info_sub := ""
var info_mods: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gt := GradientTexture2D.new(); gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5); gt.width = 256; gt.height = 256
	var gr := Gradient.new(); gr.set_color(0, Color(1, 1, 1, 0)); gr.set_color(1, Color(1, 1, 1, 1)); gr.add_point(0.6, Color(1, 1, 1, 0)); gt.gradient = gr
	vig = TextureRect.new(); vig.texture = gt; vig.stretch_mode = TextureRect.STRETCH_SCALE; vig.mouse_filter = Control.MOUSE_FILTER_IGNORE; vig.modulate = Color(0, 0, 0, 0); add_child(vig); vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stat = ColorRect.new(); stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat_mat = ShaderMaterial.new(); var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float amt = 0.0;\nfloat h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }\nvoid fragment(){ vec2 px = floor(FRAGCOORD.xy / 2.0); float n = h(px + floor(TIME * 24.0)); float line = step(0.5, fract(FRAGCOORD.y / 3.0)); COLOR = vec4(vec3(0.55, 0.85, 0.9) * n, (n * 0.16 + line * 0.06) * amt); }\n"
	stat_mat.shader = sh; stat.material = stat_mat; stat.visible = false; add_child(stat); stat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func begin(m) -> void:
	match_ref = m; visible = true; alerts.clear(); banner_t = 0; count_t = 0; tg_ref = null; dmg_arcs.clear()
	me_sil = silhouette(m.player.build)
	info_title = m.cfg.get("title", ""); info_sub = m.arena.def.name
	info_mods = []
	for k in m.cfg.get("mods", {}): info_mods.append(D.MODIFIERS[k].name)
	help_t = 14.0 if (Save.data.wins + Save.data.losses) < 3 else 5.0

func end() -> void: visible = false; match_ref = null

func count(n: int) -> void: count_txt = str(n) if n > 0 else "COMBATE"; count_t = 0.8 if n > 0 else 0.9
func banner(tt: String, s := "", hold := false) -> void: banner_txt = [tt, s]; banner_t = 99.0 if hold else 2.6
func alert(text: String, kind := "") -> void:
	alerts.push_front({ "text": text, "t": 2.4, "kind": kind })
	while alerts.size() > 4: alerts.pop_back()

func tick(m, dt: float, events: Array) -> void:
	var p: Mech = m.player
	for e in events:
		match e.type:
			"hit": hit_t = 0.22; hit_kind = "sh" if e.get("shield", false) else ("crit" if e.get("crit", false) else "")
			"dmg":
				if e.get("from") != null:
					var dv: Vector3 = e.from - p.pos
					dmg_arcs.append({ "ang": Mech.ang_diff(atan2(dv.x, dv.z), m.cam_yaw), "t": 0.9 })
					if dmg_arcs.size() > 6: dmg_arcs.pop_front()
			"note": alert(e.text)
			"alert": alert(e.text, "red")
			"status":
				if e.mech == p: alert(e.text, "red")
				elif e.mech.team != 0: alert("ALVO: " + e.text, "amb")
			"breach":
				if e.mech == p: alert("%s: BLINDAGEM ROMPIDA" % Mech.PART_PT[e.part].to_upper(), "red"); Sfx.play("alert")
				elif e.mech.team != 0: alert("ALVO: %s ROMPIDO" % Mech.PART_PT[e.part].to_upper(), "amb")
			"destroy":
				if e.mech == p: alert("%s DESTRUÍDO" % Mech.PART_PT[e.part].to_upper(), "red")
				elif e.mech.team != 0: alert("ALVO: %s DESTRUÍDO" % Mech.PART_PT[e.part].to_upper(), "amb")
			"stagger":
				if e.mech == p: alert("POSTURA QUEBRADA", "red")
				elif e.mech.team != 0: alert("ALVO ATORDOADO — DANO DIRETO", "amb")
	for i in range(alerts.size() - 1, -1, -1):
		alerts[i].t -= dt
		if alerts[i].t <= 0: alerts.remove_at(i)
	if banner_t < 90: banner_t -= dt
	count_t -= dt; help_t -= dt; hit_t -= dt
	for a in dmg_arcs: a.t -= dt
	# avisos de míssil
	var warn := false
	for pr in m.world.projs:
		if pr.pk == "missile" and pr.team != 0 and pr.get("target") == p and pr.pos.distance_to(p.pos) < 170: warn = true
	warn_on = warn
	if warn:
		warn_t -= dt
		if warn_t <= 0: warn_t = 0.45; Sfx.play("alert", null, 0.6)
	# vinheta e estática
	var sr := clampf(p.st / p.st_max, 0, 1)
	if sr < 0.3: vig.modulate = Color(0.9, 0.28, 0.18, 0.45 + 0.2 * sin(Time.get_ticks_msec() / 160.0))
	elif p.status.heat.t > 0: vig.modulate = Color(1.0, 0.48, 0.16, 0.4)
	else: vig.modulate = Color(0, 0, 0, 0.35)
	var st_amt := 1.0 if p.status.shock.t > 0 else (0.45 if p.parts.head.state == 2 else 0.0)
	stat.visible = st_amt > 0; stat_mat.set_shader_parameter("amt", st_amt)
	queue_redraw()

# ───────── desenho ─────────
func _f(kind := "disp") -> Font: return Mats.fonts.get(kind, ThemeDB.fallback_font)
func txt(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, font := "disp", w := -1.0) -> void:
	var f := _f(font)
	var ww := w
	if align != HORIZONTAL_ALIGNMENT_LEFT and ww < 0: ww = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x; pos.x -= ww if align == HORIZONTAL_ALIGNMENT_RIGHT else ww / 2.0
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.55))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## arco em graus "de relógio" (0 = topo, horário), segmentado
static func ang(deg: float) -> float: return deg_to_rad(deg - 90.0)
func seg_arc(c: Vector2, r: float, a0: float, a1: float, fill: float, w: float, col: Color, segs: int, trk := Color(0.85, 0.84, 0.78, 0.16)) -> void:
	var step := (a1 - a0) / segs
	var gap := signf(step) * minf(absf(step) * 0.28, 1.6)
	for i in segs:
		var s0 := a0 + step * i; var s1 := s0 + step - gap
		var on := float(i) < fill * segs - 0.001
		draw_arc(c, r, ang(minf(s0, s1)), ang(maxf(s0, s1)), 4, col if on else trk, w, true)

func _draw() -> void:
	var m = match_ref
	if m == null: return
	var p: Mech = m.player; var S := size; var C := S / 2.0
	var sc := minf(S.y * 0.78, 620.0) / 440.0
	# ── retículo ──
	var R := 190.0 * sc
	var fcs_r := tan(0.17) / tan(deg_to_rad(m.fov) / 2.0) * (S.y / 2.0)
	for i in 48:
		var a0 := TAU * i / 48.0
		draw_arc(C, fcs_r, a0, a0 + TAU / 48.0 * 0.4, 2, Color(INK, 0.22), 1.0)
	draw_circle(C, 2.2, INK)
	for d in [Vector2(-16, 0), Vector2(16, 0), Vector2(0, -16), Vector2(0, 16)]: draw_line(C + d, C + d * 0.44, INK, 1.3)
	var en := p.en / p.en_max
	var en_col := RED if p.en_lock else (AMB if en < 0.25 else CY)
	if p.en_lock and int(Time.get_ticks_msec() / 150) % 2 == 0: en_col = Color(RED, 0.35)
	seg_arc(C, R, 215, 325, en, 6, en_col, 40)
	var imp := clampf(p.impact / p.stab_max, 0, 1)
	var imp_col := RED if p.staggered else (AMB if imp > 0.7 else INK)
	seg_arc(C, R, 145, 35, imp, 6, imp_col, 40)
	txt(C + Vector2(-R * 1.05, R * 0.5), "EN", 12, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	txt(C + Vector2(-R * 1.05, R * 0.5 + 16), str(int(p.en)), 14, INK, HORIZONTAL_ALIGNMENT_RIGHT, "mono")
	txt(C + Vector2(R * 1.05, R * 0.5), "IMPACTO", 12, DIM)
	txt(C + Vector2(R * 1.05, R * 0.5 + 16), "ATORDOADO" if p.staggered else "%d%%" % int(imp * 100), 14, imp_col if p.staggered else INK, HORIZONTAL_ALIGNMENT_LEFT, "mono")
	txt(C + Vector2(-R * 1.05, -R * 0.52), "%d km/h" % int(p.vel.length() * 3.6), 12, DIM, HORIZONTAL_ALIGNMENT_RIGHT, "mono")
	txt(C + Vector2(R * 1.05, -R * 0.52), "ALT %d m" % int(p.pos.y), 12, DIM, HORIZONTAL_ALIGNMENT_LEFT, "mono")
	var qtxt := "EN ESGOTADA — AGUARDE" if p.en_lock else ("SOBREIMPULSO" if p.ab_on else ("ANCORADO" if p.anchor_t > 0 else ""))
	if qtxt: txt(C + Vector2(0, R * 0.8), qtxt, 13, AMB, HORIZONTAL_ALIGNMENT_CENTER)
	if hit_t > 0:
		var hc := CY if hit_kind == "sh" else (AMB if hit_kind == "crit" else INK); var hw := 3.4 if hit_kind == "crit" else 2.0
		hc.a = minf(1.0, hit_t / 0.1)
		for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]: draw_line(C + d * 5, C + d * 12, hc, hw)
	for a in dmg_arcs:
		if a.t <= 0: continue
		var deg := -rad_to_deg(a.ang)
		draw_arc(C, 130 * sc, ang(deg - 16), ang(deg + 16), 10, Color(RED, a.t / 0.9), 7)
	# ── alvo travado ──
	var t: Mech = p.target
	if t != null and t.alive:
		var tc := t.center()
		if not m.cam.is_position_behind(tc):
			var sp = m.cam.unproject_position(tc)
			var rot := deg_to_rad(45.0 if p.hard_lock else fmod(m.t * 60.0, 360.0)); var bs := 34.0 * (0.82 if p.hard_lock else 1.0)
			var lc := RED if p.hard_lock else AMB
			for q in 4:
				var base := Vector2(-bs, -bs).rotated(rot + q * PI / 2)
				var e1 := Vector2(0, 20).rotated(rot + q * PI / 2); var e2 := Vector2(20, 0).rotated(rot + q * PI / 2)
				draw_polyline(PackedVector2Array([sp + base + e1, sp + base, sp + base + e2]), lc, 3.0 if p.hard_lock else 2.2)
			var ts := clampf(t.st / t.st_max, 0, 1); var ti := clampf(t.impact / t.stab_max, 0, 1)
			draw_arc(sp, 46, ang(200), ang(340), 16, Color(INK, 0.2), 3); draw_arc(sp, 46, ang(200), ang(200 + 140 * ts), 16, INK, 3)
			draw_arc(sp, 46, ang(20), ang(160), 16, Color(INK, 0.2), 3)
			if ti > 0: draw_arc(sp, 46, ang(160 - 140 * ti), ang(160), 16, RED if t.staggered else AMB, 3)
			var ml := 0.0
			for k in p.weapons:
				var d: Dictionary = p.weapons[k].def
				if d.wt == "missile" and d.get("lockT", 0): ml = maxf(ml, clampf(p.lock_prog / (d.lockT * p.lock_time_mul), 0, 1))
			if ml > 0: draw_arc(sp, 26, ang(0), ang(360 * ml), 24, RED if ml >= 1 else CY, 2.4 if ml >= 1 else 1.6)
			txt(sp + Vector2(44, 34), "%d m" % int(t.pos.distance_to(p.pos)), 12, AMB, HORIZONTAL_ALIGNMENT_LEFT, "mono")
		# painel do alvo
		if tg_ref != t: tg_ref = t; tg_sil = silhouette(t.build)
		var pc := Vector2(C.x, 50)
		draw_rect(Rect2(pc.x - 230, 14, 460, 70), Color(0.043, 0.047, 0.051, 0.7))
		txt(pc + Vector2(-40, -4), t.call if t.call else "ALVO", 24, INK, HORIZONTAL_ALIGNMENT_RIGHT, "black")
		txt(pc + Vector2(-40, 16), t.name, 12, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		draw_sil(tg_sil, t, Rect2(pc.x - 22, 18, 44, 58))
		txt(pc + Vector2(40, 0), str(maxi(0, int(t.st))), 22, INK, HORIZONTAL_ALIGNMENT_LEFT, "mono")
		var flag := "ATORDOADO" if t.staggered else ("BARREIRA" if t.barrier.t > 0 else ("EM CHAMAS" if t.status.heat.t > 0 else ("EM CURTO" if t.status.shock.t > 0 else ("CORROÍDO" if t.status.corr.t > 0 else ("TRAVA FIXA" if p.hard_lock else "TRAVA LIVRE")))))
		txt(pc + Vector2(40, 18), flag, 12, AMB)
	else: tg_ref = null
	# ── minha carcaça ──
	var mc := Vector2(22 + 126, S.y - 16 - 126)
	draw_circle(mc, 120, Color(0.03, 0.035, 0.04, 0.55))
	var sr := clampf(p.st / p.st_max, 0, 1)
	seg_arc(mc, 113, 225, 495, sr, 11, RED if sr < 0.25 else (AMB if sr < 0.5 else INK), 70)
	draw_arc(mc, 101, ang(200), ang(520), 48, Color(INK, 0.13), 1)
	var sk := ["heat", "shock", "corr"]; var scol := [Color("#ff7a2a"), CY, OK]
	for i in 3:
		var s = p.status[sk[i]]; var on: bool = s.t > 0
		var a0 := 196.0 - i * 16; var a1 := 184.0 - i * 16
		draw_arc(mc, 124, ang(a1), ang(a0), 6, Color(INK, 0.13), 5)
		var fl: float = 1.0 if on else s.v / 100.0
		if fl > 0.01 and (not on or int(Time.get_ticks_msec() / 125) % 2 == 0): draw_arc(mc, 124, ang(a0 - (a0 - a1) * fl), ang(a0), 6, scol[i], 5)
	draw_sil(me_sil, p, Rect2(mc.x - 54, mc.y - 70, 108, 135))
	var lbl := { "head": Vector2(30, -88), "armL": Vector2(-100, -20), "armR": Vector2(72, -20), "core": Vector2(30, -6), "legs": Vector2(36, 50) }
	for k in Mech.PARTS5:
		var P2 = p.parts[k]; var c := INK
		var tx := "DESTR." if P2.state == 2 else ("ROMP." if P2.state == 1 else "%d%%" % int(P2.a / P2.max * 100))
		if P2.state > 0: c = RED
		elif P2.a / P2.max < 0.4: c = AMB
		txt(mc + lbl[k], tx, 11, c, HORIZONTAL_ALIGNMENT_LEFT, "mono")
	txt(mc + Vector2(0, 96), "ESTRUTURA", 10, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	txt(mc + Vector2(0, 120), str(maxi(0, int(p.st))), 26, INK, HORIZONTAL_ALIGNMENT_CENTER, "mono")
	var kx := mc.x + 136; var ky := mc.y + 64
	txt(Vector2(kx, ky + 12), "REPARO [G]", 10, DIM)
	for i in maxi(p.kits, 3):
		var r := Rect2(kx + 74 + i * 17, ky, 12, 16)
		if i < p.kits: draw_rect(r, OK)
		else: draw_rect(r, DIM, false, 1)
	# ── armas ──
	var slots := ["backL", "backR", "handL", "handR", "shoulder", "util"]
	var gx := S.x - 22 - 404; var gy := S.y - 16 - 3 * 51
	for i in slots.size():
		var k: String = slots[i]; var r := Rect2(gx + (i % 2) * 204, gy + int(i / 2) * 51, 196, 46)
		var d = p.P.util if k == "util" else (p.weapons[k].def if p.weapons.has(k) else null)
		draw_rect(r, Color(0.043, 0.047, 0.051, 0.82))
		if d == null:
			draw_rect(Rect2(r.position, Vector2(2, r.size.y)), Color(INK, 0.15))
			txt(r.position + Vector2(10, 16), KEYLBL[k], 10, Color(DIM, 0.5), HORIZONTAL_ALIGNMENT_LEFT, "mono")
			txt(r.position + Vector2(10, 34), "— %s vazio —" % SLOTLBL[k], 13, Color(DIM, 0.5)); continue
		var h: Dictionary
		if k == "util":
			var u = p.P.util; var tot: float = u.get("cd", 1.0)
			h = { "ring": 1.0 if u.act == "passive" else 1 - clampf(p.util_cd / maxf(tot, 0.01), 0, 1), "state": "passive" if u.act == "passive" else ("cool" if p.util_cd > 0 else "ok"), "ammo": str(p.util_charges) if u.get("charges", 0) else (str(int(p.barrier.hp)) if (u.act == "barrier" and p.barrier.t > 0) else ""), "lock": 0.0 }
		else: h = p.weapons[k].hud()
		var firing: bool = k != "util" and p.input.fire[k]
		draw_rect(Rect2(r.position, Vector2(2, r.size.y)), AMB if firing else Color(INK, 0.2))
		if firing: draw_rect(r, Color(AMB, 0.14))
		var rc := r.position + Vector2(24, 23)
		draw_arc(rc, 15, 0, TAU, 32, Color(INK, 0.16), 4)
		var col := INK
		match h.state:
			"reload", "cool": col = DIM
			"heat", "empty": col = RED
			"warm", "charge": col = AMB
		if h.ring > 0.005: draw_arc(rc, 15, ang(0), ang(360 * h.ring), 32, col, 4)
		if h.lock > 0: draw_arc(rc, 9, ang(0), ang(360 * h.lock), 24, RED if h.lock >= 1 else CY, 2.4)
		txt(r.position + Vector2(46, 17), KEYLBL[k], 10, DIM, HORIZONTAL_ALIGNMENT_LEFT, "mono")
		var nm: String = d.name
		var sp_i := nm.find(" "); if sp_i > 0: nm = nm.substr(sp_i + 1)
		txt(r.position + Vector2(46, 36), nm, 15, Color(INK, 0.55) if h.state == "off" else INK, HORIZONTAL_ALIGNMENT_LEFT, "bold")
		txt(r.position + Vector2(188, 30), h.ammo, 15, RED if h.state in ["heat", "empty"] else INK, HORIZONTAL_ALIGNMENT_RIGHT, "mono")
	# ── informação da partida ──
	txt(Vector2(22, 36), info_title, 20, INK, HORIZONTAL_ALIGNMENT_LEFT, "black")
	txt(Vector2(22, 56), info_sub.to_upper(), 12, DIM)
	var tm := int(m.time); var ts := "%02d:%02d" % [tm / 60, tm % 60]
	var left := 0
	for mm in m.world.mechs:
		if mm.team != 0 and mm.alive: left += 1
	var line2 := ("ONDA %d · %s PTS · %d VIVOS · %s" % [m.wave, UI.fmt(m.score), left, ts]) if m.cfg.get("endless", false) else ("%d %s · %s" % [left, "ADVERSÁRIO" if left == 1 else "ADVERSÁRIOS", ts])
	txt(Vector2(22, 76), line2, 12, INK, HORIZONTAL_ALIGNMENT_LEFT, "mono")
	for i in info_mods.size():
		draw_rect(Rect2(22, 88 + i * 18, 3, 14), AMB); txt(Vector2(30, 100 + i * 18), info_mods[i].to_upper(), 12, Color("#ffd699"))
	# ── radar ──
	var rcn := Vector2(S.x - 22 - 75, 16 + 75)
	draw_circle(rcn, 74, Color(0.043, 0.047, 0.051, 0.62)); draw_arc(rcn, 74, 0, TAU, 48, Color(INK, 0.45), 1); draw_arc(rcn, 37, 0, TAU, 32, Color(INK, 0.16), 0.7)
	draw_line(rcn + Vector2(0, -74), rcn + Vector2(0, 74), Color(INK, 0.16), 0.7); draw_line(rcn + Vector2(-74, 0), rcn + Vector2(74, 0), Color(INK, 0.16), 0.7)
	draw_colored_polygon(PackedVector2Array([rcn + Vector2(0, -7), rcn + Vector2(5, 6), rcn + Vector2(-5, 6)]), INK)
	var r_off: bool = p.parts.head.state > 0 or p.status.shock.t > 0
	var rr: float = p.stats.radar
	txt(rcn + Vector2(0, -60), "%d m" % int(rr), 10, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	if r_off: txt(rcn + Vector2(0, 4), "SEM SINAL", 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var cy := cos(m.cam_yaw); var sy := sin(m.cam_yaw)
		for mm in m.world.mechs:
			if mm == p or not mm.alive or mm.cloaked: continue
			var dx: float = mm.pos.x - p.pos.x; var dz: float = mm.pos.z - p.pos.z
			var v2 := Vector2(-(dx * cy - dz * sy), -(dx * sy + dz * cy)) / rr * 72.0
			var far := v2.length() > 72
			if far: v2 = v2.normalized() * 72
			var bc := CY if mm.team == 0 else (AMB if mm == t else RED)
			if far: bc.a = 0.5
			draw_circle(rcn + v2, 4.0 if mm.pos.y - p.pos.y > 12 else 3.0, bc)
		for pr in m.world.projs:
			if pr.pk != "missile" or pr.team == 0 or pr.pos.distance_to(p.pos) > rr: continue
			var dx: float = pr.pos.x - p.pos.x; var dz: float = pr.pos.z - p.pos.z
			draw_circle(rcn + Vector2(-(dx * cy - dz * sy), -(dx * sy + dz * cy)) / rr * 72.0, 1.6, Color.WHITE)
	# ── alertas, aviso, faixa, contagem, ajuda ──
	for i in alerts.size():
		var a = alerts[i]; var col := INK; var bar := INK
		if a.kind == "red": col = Color("#ffb5a4"); bar = RED
		elif a.kind == "amb": col = Color("#ffd699"); bar = AMB
		var al := clampf(a.t / 0.4, 0, 1)
		var f := _f("bold"); var wv := f.get_string_size(a.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 24
		var ar := Rect2(C.x - wv / 2, S.y * 0.21 + i * 26, wv, 22)
		draw_rect(ar, Color(0.043, 0.047, 0.051, 0.78 * al)); draw_rect(Rect2(ar.position, Vector2(3, 22)), Color(bar, al))
		txt(ar.position + Vector2(14, 16), a.text, 15, Color(col, al), HORIZONTAL_ALIGNMENT_LEFT, "bold")
	if warn_on and int(Time.get_ticks_msec() / 150) % 2 == 0:
		var wr := Rect2(C.x - 70, S.y * 0.15 - 14, 140, 26); draw_rect(wr, RED); txt(Vector2(C.x, S.y * 0.15 + 5), "M Í S S I L", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, "black")
	if banner_t > 0:
		var bsz := int(clampf(S.x * 0.042, 34, 68))
		txt(Vector2(C.x, S.y * 0.3 + bsz * 0.4), banner_txt[0], bsz, INK, HORIZONTAL_ALIGNMENT_CENTER, "black")
		if banner_txt[1]: txt(Vector2(C.x, S.y * 0.3 + bsz * 0.4 + 30), banner_txt[1].to_upper(), 18, AMB, HORIZONTAL_ALIGNMENT_CENTER, "bold")
	if count_t > 0:
		var k := clampf(count_t / 0.8, 0, 1); var csz := int(clampf(S.x * 0.1, 80, 190) * (1.0 + (k - 0.6) * 0.5 if k > 0.6 else 1.0))
		txt(Vector2(C.x, S.y * 0.34 + csz * 0.4), count_txt, csz, Color(INK, minf(1.0, count_t * 3)), HORIZONTAL_ALIGNMENT_CENTER, "black")
	if help_t > 0 and S.x > 1180:
		txt(Vector2(C.x, S.y - 14), "WASD mover · ESPAÇO saltar/subir · SHIFT impulso · CTRL sobreimpulso · BOTÕES mãos · Q/E dorso · R ombros · F utilitário · G reparo · T travar · TAB trocar · ESC pausa", 12, Color(DIM, clampf(help_t, 0, 1)), HORIZONTAL_ALIGNMENT_CENTER)

# ───────── silhueta (vista de trás; braço direito à direita) ─────────
static func silhouette(build: Dictionary) -> Array:
	var p := Stats.parts_of(build); var out := []
	var mir := func(pts: Array) -> Array:
		var o := []
		for q in pts: o.append(Vector2(120 - q.x, q.y))
		return o
	var poly := func(part: String, pts: Array): out.append({ "part": part, "pts": pts })
	var V := func(a: Array) -> Array:
		var o := []
		for i in range(0, a.size(), 2): o.append(Vector2(a[i], a[i + 1]))
		return o
	var lt: String = p.legs.type
	if lt == "biped": var a: Array = V.call([45, 86, 58, 86, 57, 112, 61, 140, 43, 140, 46, 112]); poly.call("legs", a); poly.call("legs", mir.call(a))
	elif lt == "reverse": var a: Array = V.call([47, 86, 58, 86, 53, 104, 60, 122, 55, 134, 60, 142, 42, 142, 49, 122, 42, 104]); poly.call("legs", a); poly.call("legs", mir.call(a))
	elif lt == "quad":
		var a: Array = V.call([44, 88, 24, 98, 12, 140, 24, 140, 31, 108, 48, 100]); var b: Array = V.call([50, 98, 45, 120, 40, 142, 51, 142, 55, 120, 58, 100])
		poly.call("legs", a); poly.call("legs", mir.call(a)); poly.call("legs", b); poly.call("legs", mir.call(b)); poly.call("legs", V.call([46, 86, 74, 86, 72, 100, 48, 100]))
	else: var a: Array = V.call([14, 104, 42, 104, 44, 142, 12, 142]); poly.call("legs", a); poly.call("legs", mir.call(a)); poly.call("legs", V.call([40, 90, 80, 90, 84, 130, 36, 130]))
	var cc: String = p.core.cls
	poly.call("core", V.call([49, 44, 71, 44, 67, 84, 53, 84]) if cc == "light" else (V.call([40, 40, 80, 40, 77, 86, 43, 86]) if cc == "heavy" else V.call([44, 42, 76, 42, 72, 84, 48, 84])))
	var hk: String = p.head.m.k
	if hk == "fin" or hk == "fox": poly.call("head", V.call([60, 16, 69, 29, 66, 38, 54, 38, 51, 29]))
	elif hk == "dome" or hk == "facet":
		var c := []
		for i in 12: c.append(Vector2(60, 29) + Vector2(9.5, 0).rotated(TAU * i / 12.0))
		poly.call("head", c)
	elif hk == "bunker": poly.call("head", V.call([49, 26, 71, 26, 71, 38, 49, 38]))
	else: poly.call("head", V.call([52, 20, 68, 20, 68, 38, 52, 38]))
	var ax := 4.0 if cc == "heavy" else (-3.0 if cc == "light" else 0.0)
	for side in ["armR", "armL"]:
		var sh: Array = V.call([82 + ax, 40, 98 + ax, 40, 98 + ax, 55, 82 + ax, 55])
		var lo: Array = V.call([83 + ax, 57, 97 + ax, 57, 98 + ax, 102, 93 + ax, 102, 93 + ax, 108, 87 + ax, 108, 87 + ax, 102, 82 + ax, 102]) if p.arms.kind == "weapon" else V.call([84 + ax, 57, 96 + ax, 57, 95 + ax, 92, 85 + ax, 92])
		if side == "armL": sh = mir.call(sh); lo = mir.call(lo)
		poly.call(side, sh); poly.call(side, lo)
	if p.backR: poly.call("x", V.call([66, 22, 78, 22, 78, 38, 70, 38]))
	if p.backL: poly.call("x", mir.call(V.call([66, 22, 78, 22, 78, 38, 70, 38])))
	return out

func draw_sil(sil: Array, mech: Mech, r: Rect2) -> void:
	var k := minf(r.size.x / 120.0, r.size.y / 150.0)
	var o := r.position + (r.size - Vector2(120, 150) * k) / 2.0
	for s in sil:
		var pts := PackedVector2Array()
		for q in s.pts: pts.append(o + q * k)
		var col := Color(INK, 0.86)
		if s.part == "x": col = Color(INK, 0.34)
		else:
			var P2 = mech.parts[s.part]
			if P2.state == 2: col = Color("#191a19")
			elif P2.state == 1: col = RED
			elif P2.a / P2.max < 0.4: col = AMB
		draw_colored_polygon(pts, col)
		var cl := pts.duplicate(); cl.append(pts[0])
		draw_polyline(cl, RED if (s.part != "x" and mech.parts[s.part].state == 2) else Color(0.04, 0.045, 0.05), 1.2)

## Desenho estático (sem carcaça viva) para os menus.
static func sil_static(ci: CanvasItem, sil: Array, r: Rect2, col := Color(0.85, 0.84, 0.78, 0.86)) -> void:
	var k := minf(r.size.x / 120.0, r.size.y / 150.0)
	var o := r.position + (r.size - Vector2(120, 150) * k) / 2.0
	for s in sil:
		var pts := PackedVector2Array()
		for q in s.pts: pts.append(o + q * k)
		ci.draw_colored_polygon(pts, Color(col, col.a * (0.4 if s.part == "x" else 1.0)))
