## Menus: título, hangar, Circuito, contratos, modo infinito, garagem, loja, opções, resultados e sobreposições.
class_name UI extends Control

const INK := Color("#d9d5c7")
const DIM := Color("#8f8c80")
const FAINT := Color("#5a584f")
const LINE := Color("#35362f")
const AMB := Color("#f2a22c")
const RED := Color("#e5482d")
const CY := Color("#74d3d9")
const OK := Color("#a6d06c")
const PANEL := Color(0.047, 0.051, 0.051, 0.92)
const BLACK := Color("#0b0c0d")

var app
var screen := ""
var sel := {}
var contract_list: Array = []
var contract_seed := -1
var root: Control
var overlay: Control
var toast_lbl: Label
var toast_t := 0.0
var perk_cb: Callable
var garage_refs := {}
var shop_refs := {}

static func fmt(n) -> String:
	var s := str(absi(roundi(n))); var out := ""
	while s.length() > 3: out = "." + s.substr(s.length() - 3) + out; s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
static func cr(n) -> String: return fmt(n) + " CR"
static func f1(n: float) -> String: return ("%.1f" % n).replace(".", ",")

func setup(a) -> void:
	app = a; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _make_theme()
	root = Control.new(); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay = Control.new(); overlay.visible = false; add_child(overlay); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_lbl = Label.new(); toast_lbl.visible = false; add_child(toast_lbl)
	var ts := StyleBoxFlat.new(); ts.bg_color = INK; ts.content_margin_left = 18; ts.content_margin_right = 18; ts.content_margin_top = 8; ts.content_margin_bottom = 8
	toast_lbl.add_theme_stylebox_override("normal", ts); toast_lbl.add_theme_color_override("font_color", BLACK); toast_lbl.add_theme_font_size_override("font_size", 18)

func _process(dt: float) -> void:
	if toast_t > 0:
		toast_t -= dt
		toast_lbl.position = Vector2((size.x - toast_lbl.size.x) / 2, size.y - 70)
		if toast_t <= 0: toast_lbl.visible = false

# ───────── tema e componentes ─────────
func _sb(bg: Color, border := Color(0, 0, 0, 0), bw := 0, pad := Vector4(10, 6, 10, 6)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border
	s.border_width_left = bw; s.border_width_right = bw; s.border_width_top = bw; s.border_width_bottom = bw
	s.content_margin_left = pad.x; s.content_margin_top = pad.y; s.content_margin_right = pad.z; s.content_margin_bottom = pad.w
	return s

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Mats.fonts.disp; t.default_font_size = 17
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("normal", "Button", _sb(Color(0, 0, 0, 0.25), INK, 1, Vector4(22, 9, 22, 9)))
	t.set_stylebox("hover", "Button", _sb(INK, INK, 1, Vector4(22, 9, 22, 9)))
	t.set_stylebox("pressed", "Button", _sb(INK, INK, 1, Vector4(22, 9, 22, 9)))
	t.set_stylebox("disabled", "Button", _sb(Color(0, 0, 0, 0.2), Color(INK, 0.3), 1, Vector4(22, 9, 22, 9)))
	t.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), AMB, 2, Vector4(22, 9, 22, 9)))
	t.set_color("font_color", "Button", INK); t.set_color("font_hover_color", "Button", BLACK); t.set_color("font_pressed_color", "Button", BLACK); t.set_color("font_disabled_color", "Button", Color(INK, 0.35))
	t.set_font("font", "Button", Mats.fonts.bold); t.set_font_size("font_size", "Button", 17)
	t.set_stylebox("panel", "PanelContainer", _sb(PANEL, LINE, 1, Vector4(16, 16, 16, 14)))
	t.set_stylebox("normal", "LineEdit", _sb(Color("#131413"), LINE, 1, Vector4(8, 5, 8, 5)))
	t.set_stylebox("focus", "LineEdit", _sb(Color("#131413"), AMB, 1, Vector4(8, 5, 8, 5)))
	t.set_font("font", "LineEdit", Mats.fonts.bold); t.set_color("font_color", "LineEdit", INK)
	var gr := StyleBoxFlat.new(); gr.bg_color = Color("#2a2b25"); gr.content_margin_top = 3; gr.content_margin_bottom = 3
	var gf := StyleBoxFlat.new(); gf.bg_color = AMB; gf.content_margin_top = 3; gf.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", gr); t.set_stylebox("grabber_area", "HSlider", gf); t.set_stylebox("grabber_area_highlight", "HSlider", gf)
	var vs := StyleBoxFlat.new(); vs.bg_color = Color(INK, 0.18); vs.content_margin_left = 3; vs.content_margin_right = 3
	var vg := StyleBoxFlat.new(); vg.bg_color = Color(INK, 0.45); vg.content_margin_left = 3; vg.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", vs); t.set_stylebox("grabber", "VScrollBar", vg); t.set_stylebox("grabber_highlight", "VScrollBar", vg); t.set_stylebox("grabber_pressed", "VScrollBar", vg)
	return t

func lbl(text: String, size_px := 17, col := INK, font := "disp", wrap := false) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", size_px); l.add_theme_color_override("font_color", col)
	l.add_theme_font_override("font", Mats.fonts.get(font, Mats.fonts.disp))
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
func cap(text: String) -> Label: return lbl(text.to_upper(), 12, DIM, "bold")

func btn(text: String, cb: Callable, primary := false, disabled := false) -> Button:
	var b := Button.new(); b.text = text; b.disabled = disabled; b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", _sb(AMB, AMB, 1, Vector4(22, 10, 22, 10))); b.add_theme_stylebox_override("hover", _sb(Color("#ffc35a"), Color("#ffc35a"), 1, Vector4(22, 10, 22, 10)))
		b.add_theme_stylebox_override("pressed", _sb(Color("#ffc35a"), Color("#ffc35a"), 1, Vector4(22, 10, 22, 10))); b.add_theme_stylebox_override("disabled", _sb(Color(AMB, 0.3), Color(AMB, 0.3), 1, Vector4(22, 10, 22, 10)))
		b.add_theme_color_override("font_color", BLACK); b.add_theme_color_override("font_disabled_color", Color(BLACK, 0.6))
	b.pressed.connect(func(): Sfx.play("ui"); cb.call())
	b.mouse_entered.connect(func(): Sfx.play("hover"))
	return b

func panel(min_w := 0.0) -> PanelContainer:
	var p := Pnl.new(); p.custom_minimum_size.x = min_w; p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

## Painel com a faixa âmbar no canto superior esquerdo.
class Pnl extends PanelContainer:
	var accent := Color("#f2a22c")
	var full := false
	func _draw() -> void: draw_rect(Rect2(0, 0, size.x if full else 28.0, 3), accent)

func vb(sep := 8) -> VBoxContainer: var v := VBoxContainer.new(); v.add_theme_constant_override("separation", sep); return v
func hb(sep := 8) -> HBoxContainer: var h := HBoxContainer.new(); h.add_theme_constant_override("separation", sep); return h
func spacer(expand := true) -> Control: var c := Control.new(); c.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else 0; c.size_flags_vertical = Control.SIZE_EXPAND_FILL if expand else 0; c.mouse_filter = Control.MOUSE_FILTER_IGNORE; return c
func sep_line() -> ColorRect: var r := ColorRect.new(); r.color = LINE; r.custom_minimum_size = Vector2(0, 1); r.mouse_filter = Control.MOUSE_FILTER_IGNORE; return r

## Linha clicável com destaque (listas).
class Row extends PanelContainer:
	var cb: Callable
	var hover_cb: Callable
	var on := false
	var dim_row := false
	func _init(c: Callable, hc := Callable()) -> void:
		cb = c; hover_cb = hc; mouse_filter = Control.MOUSE_FILTER_STOP; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _style(true); Sfx.play("hover"); if hover_cb.is_valid(): hover_cb.call())
		mouse_exited.connect(func(): _style(false))
		_style(false)
	func set_on(v: bool) -> void: on = v; _style(false)
	func _style(h: bool) -> void:
		var s := StyleBoxFlat.new(); s.bg_color = Color(0.95, 0.64, 0.17, 0.12) if (h or on) else Color(0, 0, 0, 0)
		s.border_color = Color("#f2a22c") if on else Color("#22231d"); s.border_width_left = 3 if on else 0; s.border_width_bottom = 1
		s.content_margin_left = 12 if on else 10; s.content_margin_right = 10; s.content_margin_top = 5; s.content_margin_bottom = 5
		add_theme_stylebox_override("panel", s)
		modulate = Color(1, 1, 1, 0.45 if dim_row else 1.0)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: cb.call()

## Área de desenho de silhueta.
class SilBox extends Control:
	var sil: Array
	func _init(s: Array, sz: Vector2) -> void: sil = s; custom_minimum_size = sz; mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void: HUD.sil_static(self, sil, Rect2(Vector2.ZERO, size))

## Medidor segmentado.
class Meter extends Control:
	var r := 0.0
	var col := Color("#d9d5c7")
	func _init(ratio: float, c: Color) -> void: r = ratio; col = c; custom_minimum_size = Vector2(0, 7); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var n := int(size.x / 7)
		for i in n:
			var on := float(i) / n < r
			draw_rect(Rect2(i * 7, 0, 5, size.y), col if on else Color("#2a2b25"))

func mk_tag(p: Dictionary) -> Label:
	var c := Color(D.MAKERS[p.mk].color)
	var l := lbl(p.mk, 10, c, "mono"); var s := _sb(Color(0, 0, 0, 0), c, 1, Vector4(4, 0, 4, 0)); l.add_theme_stylebox_override("normal", s); return l

func clear_root() -> void:
	for c in root.get_children(): c.queue_free()
	garage_refs = {}; shop_refs = {}

func hide_ui() -> void: clear_root(); root.visible = false; close_overlay(); screen = ""

func go(name: String, arg = null) -> void:
	screen = name; root.visible = true; close_overlay(); clear_root()
	call("scr_" + name, arg)

func gutter() -> MarginContainer:
	var m := MarginContainer.new()
	for k in ["left", "right"]: m.add_theme_constant_override("margin_" + k, 24)
	m.add_theme_constant_override("margin_top", 16); m.add_theme_constant_override("margin_bottom", 18); m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(m); m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); return m

func topbar(title: String, sub := "") -> HBoxContainer:
	var s: Dictionary = Save.data; var r := Save.player_rank()
	var h := hb(22)
	var back := btn("◂ HANGAR", func(): go("menu")); back.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(back)
	var tt := vb(0); tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tt.add_child(lbl(title, 40, INK, "black")); if sub: tt.add_child(lbl(sub, 15, DIM))
	h.add_child(tt)
	var wal := GridContainer.new(); wal.columns = 2; wal.add_theme_constant_override("h_separation", 12)
	wal.add_child(cap("SALDO")); var cl := lbl(cr(s.credits), 18, INK, "mono"); cl.name = "credits"; wal.add_child(cl)
	wal.add_child(cap("POSIÇÃO")); wal.add_child(lbl("S/R" if r > 18 else "%dº" % r, 18, INK, "mono"))
	h.add_child(wal); var pad := Control.new(); pad.custom_minimum_size.x = 6; h.add_child(pad)
	return h

func spec_table(rows: Array, big := false) -> GridContainer:
	var g := GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 14); g.add_theme_constant_override("v_separation", 2)
	for r in rows:
		var a := lbl(r[0], 16 if big else 15, DIM); a.size_flags_horizontal = Control.SIZE_EXPAND_FILL; g.add_child(a)
		var b := lbl(str(r[1]), 14 if big else 13, INK, "mono"); b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; g.add_child(b)
	return g

# ───────── fichas de peças ─────────
const BONUS := { "cap": "Reserva de EN", "out": "Saída de EN", "rech": "Recarga de EN", "delay": "Retomada da recarga", "scan": "Alcance de trava", "lock": "Tempo de trava", "radar": "Radar", "ecm": "Desvio de mísseis inimigos",
	"thrust": "Empuxo", "qb": "Força do impulso rápido", "qbReload": "Espera do impulso rápido", "up": "Subida", "armArms": "Blindagem dos braços", "armCore": "Blindagem do tronco", "armLegs": "Blindagem das pernas",
	"def": "Defesa C / E / X", "stab": "Estabilidade", "ammo": "Munição", "kits": "Kits de reparo", "kitArmor": "Blindagem por kit", "heatRes": "Resistência a calor", "shockRes": "Resistência a choque", "cool": "Resfriamento de armas" }
const WT := { "proj": "Projétil", "beam": "Feixe", "cone": "Contato contínuo", "melee": "Corpo a corpo", "shield": "Escudo", "missile": "Míssil", "drone": "Drones", "passive": "Passivo", "active": "Ativo" }
const MK := { "direct": "direto", "vertical": "vertical em arco", "swarm": "enxame", "guided": "teleguiado", "cluster": "fragmentação" }
static func pct(v: float) -> String: return ("+" if v > 0 else "") + str(roundi(v * 100)) + "%"

static func spec_rows(p: Dictionary) -> Dictionary:
	var r := []; var add := func(a, b): r.append([a, b])
	if p.has("arm"): add.call("Blindagem (cada)" if p.slot == "arms" else "Blindagem", fmt(p.arm)); add.call("Estrutura", fmt(p.ap)); add.call("Defesa C / E / X", "%d / %d / %d" % [p.def[0], p.def[1], p.def[2]])
	match p.slot:
		"head": add.call("Estabilidade", int(p.stab)); add.call("Alcance de trava", "×%.2f" % p.scan); add.call("Radar", "%d m" % p.radar)
		"core": add.call("Estabilidade", int(p.stab)); add.call("Baias de módulo", int(p.slots)); add.call("Saída do gerador", "×%.2f" % p.out); add.call("Classe", { "light": "Leve", "medium": "Média", "heavy": "Pesada" }[p.cls])
		"arms":
			add.call("Tipo", "Com mãos" if p.kind == "hand" else "Braços-arma")
			if p.kind == "hand": add.call("Carga dos braços", "%d t" % p.load); add.call("Corpo a corpo", "×%.2f" % p.melee)
			add.call("Rastreio", "%.2f" % p.track)
		"legs":
			add.call("Tipo", D.LEGTYPE[p.type]); add.call("Capacidade de carga", "%d t" % p.load); add.call("Estabilidade", int(p.stab)); add.call("Velocidade no solo", "%d km/h" % roundi(p.speed * 3.6)); add.call("Salto", int(p.jump))
			if p.has("boost"): add.call("Propulsor", "Embutido")
		"gen": add.call("Reserva de EN", fmt(p.cap)); add.call("Saída de EN", fmt(p.out)); add.call("Recarga", fmt(p.rech) + " /s"); add.call("Retomada", f1(p.delay) + " s"); if p.get("eb", 0): add.call("Armas de energia", pct(p.eb))
		"booster": add.call("Empuxo", "%.2f" % p.thrust); add.call("Impulso rápido", "%.2f" % p.qb); add.call("Custo do impulso", "%d EN" % p.qbCost); add.call("Espera do impulso", "%.2f s" % p.qbReload); add.call("Subida", "%.2f" % p.up); add.call("Sobreimpulso", "%.2f" % p.ab)
		"fcs": add.call("Alcance de trava", "%d m" % p.range); add.call("Tempo de trava", "×%.2f" % p.lock); add.call("Precisão curta / média / longa", "%.1f / %.1f / %.1f" % [p.near, p.mid, p.far])
	var w: Dictionary = D.PART[p.wa] if (p.slot == "arms" and p.has("wa")) else p
	if w.has("wt") or p.has("wa"):
		add.call("Arma", WT.get(w.get("wt", ""), "") + (" " + MK[w.mk2] if w.has("mk2") else "") + (" — " + w.name if p.has("wa") else ""))
		if w.has("dmg"):
			var mult := ""
			if w.get("pel", 0): mult += " ×%d" % w.pel
			if w.get("n", 1) > 1: mult += " ×%d" % w.n
			if w.get("sub", 0): mult += " ×%d" % w.sub
			if w.get("burst", 0): mult += " ×%d" % w.burst
			add.call("Dano", fmt(w.dmg) + mult + " · " + D.DT[w.dt]); add.call("Impacto", fmt(w.get("imp", 0))); add.call("Dano por segundo", fmt(Stats.weapon_dps(w)))
		if w.get("rof", 0): add.call("Cadência", (f1(w.rof) + " /s") if w.rof >= 1 else (f1(1.0 / w.rof) + " s por tiro"))
		if w.get("mag", 0) > 1: add.call("Pente / recarga", "%d / %s s" % [w.mag, f1(w.rel)])
		elif w.get("rel", 0) and w.wt != "proj": add.call("Recarga", f1(w.rel) + " s")
		if w.get("cd", 0) and w.wt == "melee": add.call("Intervalo", f1(w.cd) + " s")
		if w.get("ammo", 0): add.call("Munição", int(w.ammo))
		elif w.get("enc", 0): add.call("Munição", "Ilimitada (usa EN)")
		if w.get("rng", 0): add.call("Alcance", "%d m" % w.rng)
		if w.get("lunge", 0): add.call("Avanço", "%d m" % w.lunge)
		if w.get("spd", 0): add.call("Velocidade do projétil", "%d m/s" % w.spd)
		if w.get("enc", 0): add.call("EN por disparo", int(w.enc))
		if w.get("ht", 0): add.call("Calor por disparo", "%s%%" % str(w.ht))
		if w.has("chg"): add.call("Carga", f1(w.chg.t) + " s" + ((" → ×%s" % str(w.chg.mul)) if w.chg.mul > 1 else "") + (" (obrigatória)" if w.chg.get("req", 0) else ""))
		if w.get("spl", 0): add.call("Raio da explosão", "%d m" % w.spl)
		if w.get("lockT", 0): add.call("Travamento", f1(w.lockT) + " s")
		if w.has("st"):
			var parts := []
			for k in w.st: parts.append({ "heat": "calor", "shock": "choque", "corr": "corrosão" }[k] + " " + str(int(w.st[k])))
			add.call("Acúmulo de status", ", ".join(parts))
		if w.get("heavy", 0): add.call("Arma pesada", "Bípedes ancoram para disparar")
		if w.has("block"): add.call("Bloqueio / aparo", "%d%% / %d%%" % [roundi(w.block * 100), roundi(w.parry * 100)])
	if p.has("act") and p.slot == "util":
		if p.get("cd", 0): add.call("Espera", f1(p.cd) + " s")
		if p.get("rng", 0): add.call("Alcance", "%d m" % p.rng)
		if p.get("hp", 0): add.call("Absorção", fmt(p.hp))
		if p.get("dur", 0): add.call("Duração", f1(p.dur) + " s")
		if p.get("charges", 0): add.call("Cargas", int(p.charges))
		if p.get("dmg", 0): add.call("Dano", fmt(p.dmg))
		if p.get("rad", 0): add.call("Raio", "%d m" % p.rad)
	if p.slot == "shoulder" and p.has("act"):
		add.call("Espera", f1(p.cd) + " s")
		if p.get("rad", 0): add.call("Raio", "%d m" % p.rad)
		if p.get("charges", 0): add.call("Cargas", int(p.charges))
	if p.has("bonus"):
		for k in p.bonus:
			var v = p.bonus[k]; var vs := ""
			match k:
				"cap", "out": vs = fmt(v)
				"delay": vs = f1(v) + " s"
				"radar": vs = "+%d m" % v
				"armArms", "armCore", "armLegs", "stab", "kits": vs = "+" + str(int(v))
				"def": vs = "+%d / +%d / +%d" % [v[0], v[1], v[2]]
				_: vs = pct(v)
			add.call(BONUS.get(k, k), vs)
	add.call("Peso", f1(p.w) + " t"); add.call("Carga de EN", int(p.get("en", 0)))
	var lim := []
	if p.get("wide", 0): lim.append("Unidade larga: não convive com saias de ombro")
	if p.get("noWide", 0): lim.append("Bloqueia unidades dorsais largas")
	if p.has("notLegs"): lim.append("Não cabe em: " + ", ".join(p.notLegs.map(func(t): return str(D.LEGTYPE[t]).to_lower())))
	if p.has("notCore"): lim.append("Exige tronco médio ou pesado")
	if p.get("needHand", 0): lim.append("Exige braços com mão")
	if p.has("conflicts"): lim.append("Interfere com: " + ", ".join(p.conflicts.map(func(c): return D.PART[c].name)))
	if p.get("kind", "") == "weapon": lim.append("Sem mãos: impede armas de mão")
	if p.slot == "legs" and p.has("boost"): lim.append("Impede propulsor externo")
	if p.has("mount"): lim.append("Ponto de fixação: " + { "chest": "peito", "legs": "pernas", "hip": "quadril", "arms": "antebraços", "backtop": "dorso superior", "waist": "cintura", "hipback": "lombar", "coat": "revestimento", "mast": "mastro" }[p.mount])
	return { "rows": r, "lim": lim }

func spec_box(p: Dictionary) -> VBoxContainer:
	var v := vb(4); var s := spec_rows(p)
	v.add_child(spec_table(s.rows))
	for l in s.lim:
		var h := hb(8); var bar := ColorRect.new(); bar.color = AMB; bar.custom_minimum_size = Vector2(3, 0); h.add_child(bar)
		var t := lbl(l, 14, Color("#ffd699"), "disp", true); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(t); v.add_child(h)
	return v

# ═════════════ TELAS ═════════════
func scr_title(_a) -> void:
	app.hangar.show_mech(Save.data.build); app.hangar.view(0.16, 36)
	_left_shade()
	var m := gutter()
	var v := vb(10); v.size_flags_vertical = Control.SIZE_SHRINK_END; v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; v.custom_minimum_size.x = 560
	var mm := MarginContainer.new(); mm.add_theme_constant_override("margin_left", 80); mm.add_theme_constant_override("margin_bottom", 60); mm.mouse_filter = Control.MOUSE_FILTER_IGNORE; m.add_child(mm); mm.add_child(v)
	v.add_child(lbl("CIRCUITO FORNALHA  —  TEMPORADA 31  —  LICENÇA DE OPERADOR Nº 0-7731", 13, AMB, "bold"))
	v.add_child(lbl("CARCAÇA", 150, INK, "black"))
	var p := lbl("Combate de arena entre carcaças blindadas montadas peça por peça. Cada tonelada pesa nas pernas, cada arma puxa do gerador, cada placa que cai deixa algo exposto.", 20, INK, "med", true); p.custom_minimum_size.x = 540; v.add_child(p)
	var b := btn("ENTRAR NO HANGAR", func(): Sfx.set_music(0); go("menu"), true); b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; v.add_child(b)
	v.add_child(lbl("Teclado e mouse, ou controle. Progresso salvo neste dispositivo.", 13, DIM))

func _left_shade() -> void:
	var gt := GradientTexture2D.new(); var gr := Gradient.new()
	gr.set_color(0, Color(0.03, 0.035, 0.035, 0.94)); gr.set_color(1, Color(0.03, 0.035, 0.035, 0)); gr.add_point(0.55, Color(0.03, 0.035, 0.035, 0.78))
	gt.gradient = gr; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0.62, 0)
	var r := TextureRect.new(); r.texture = gt; r.stretch_mode = TextureRect.STRETCH_SCALE; r.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(r); r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func scr_menu(_a) -> void:
	var s: Dictionary = Save.data; var r := Save.player_rank(); var st := Stats.compute(s.build); var tier := D.tier_for_rank(r)
	app.hangar.show_mech(s.build); app.hangar.view(0.17)
	_left_shade()
	var m := gutter()
	var v := vb(4); v.size_flags_vertical = Control.SIZE_SHRINK_END; v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; v.custom_minimum_size.x = 440
	var mm := MarginContainer.new(); mm.add_theme_constant_override("margin_left", 70); mm.add_theme_constant_override("margin_bottom", 40); mm.mouse_filter = Control.MOUSE_FILTER_IGNORE; m.add_child(mm); mm.add_child(v)
	v.add_child(lbl("CARCAÇA", 78, INK, "black")); v.add_child(lbl("CIRCUITO FORNALHA · T31", 12, AMB, "bold"))
	v.add_child(spacer(false))
	var nx: Dictionary = D.rival(r - 1)
	var items := [["CIRCUITO", "Você é a campeã da temporada" if r <= 1 else ("%s · próximo: %s" % ["Sem posição" if r > 18 else "%dº lugar" % r, nx.call]), func(): go("league"), false],
		["CONTRATOS", "Quatro no mural · regras e pagamento variam", func(): go("contracts"), false],
		["MODO INFINITO", ("Recorde: onda %d · %s pts" % [s.bestWave, fmt(s.bestScore)]) if s.bestWave else "Ondas sem fim, melhorias entre elas", func(): go("endless"), false],
		["CAMPO DE TESTES", "Adversário passivo, sem recompensa", func(): start_test(), false], null,
		["GARAGEM", "%s · %s" % [s.build.name, "pronta para combate" if st.valid else "montagem irregular"], func(): go("garage"), not st.valid],
		["LOJA", "Catálogo classe %s liberado" % D.TIERCLS[tier], func(): go("shop"), false],
		["OPÇÕES", "Áudio, mira, gráficos, controles", func(): go("options"), false]]
	if OS.get_name() != "Web": items.append(["SAIR", "Fechar o jogo", func(): app.shutdown(); get_tree().quit(), false])
	for it in items:
		if it == null: v.add_child(sep_line()); continue
		var row := Row.new(it[2]); var c := vb(0)
		c.add_child(lbl(it[0], 32, INK, "bold")); c.add_child(lbl(it[1], 14, RED if it[3] else DIM))
		row.add_child(c); v.add_child(row)
	var plate := vb(2); plate.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); plate.position = Vector2(-290, -150); plate.custom_minimum_size.x = 260; plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN; plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(plate); plate.offset_left = -290; plate.offset_top = -150; plate.offset_right = -24; plate.offset_bottom = -20
	plate.add_child(sep_line())
	for row in [["OPERADOR", "Nº 0-7731"], ["SALDO", cr(s.credits)], ["CARCAÇA", s.build.name], ["HISTÓRICO", "%d V · %d D" % [s.wins, s.losses]]]:
		var h := hb(); var a := cap(row[0]); a.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(a); h.add_child(lbl(row[1], 15, INK, "mono")); plate.add_child(h)
	plate.add_child(lbl("Arraste para girar · roda do mouse aproxima", 12, FAINT))

func _cols(left_w: float, right_w: float) -> Array:
	var m := gutter(); var v := vb(10); m.add_child(v)
	return [m, v]

# ───────── Circuito ─────────
func scr_league(_a) -> void:
	var s: Dictionary = Save.data; var r := Save.player_rank()
	if not sel.has("rival"): sel.rival = maxi(1, r - 1)
	var m := gutter(); var v := vb(10); m.add_child(v)
	v.add_child(topbar("CIRCUITO", "Dezoito pilotos entre você e o topo. Cada vitória inédita paga o prêmio cheio e pode liberar uma classe da loja."))
	var h := hb(16); h.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(h)
	var lp := panel(440); lp.size_flags_vertical = Control.SIZE_EXPAND_FILL; h.add_child(lp)
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; lp.add_child(sc)
	var list := vb(0); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(list)
	var rows := {}
	for i in range(D.RIVALS.size() - 1, -1, -1): pass
	for rv in D.RIVALS:
		var beaten: bool = rv.rank in s.beaten; var open: bool = rv.rank >= r - 1
		var row := Row.new(func(): sel.rival = rv.rank; for k in rows: rows[k].set_on(k == rv.rank); _rival_detail())
		row.dim_row = not open; row._style(false)
		var rh := hb(10)
		rh.add_child(lbl("%02d" % rv.rank, 15, DIM, "mono")); rh.add_child(lbl(rv.cls, 18, AMB, "black"))
		var nm := vb(0); nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var call_l := lbl(rv.call, 19, DIM if beaten else INK, "bold"); nm.add_child(call_l); nm.add_child(lbl(rv.mech, 12, DIM)); rh.add_child(nm)
		rh.add_child(lbl("VENCIDO" if beaten else (cr(rv.prize) if open else "BLOQUEADO"), 12, OK if beaten else INK, "mono"))
		row.add_child(rh); list.add_child(row); rows[rv.rank] = row
		row.set_on(rv.rank == sel.rival)
	h.add_child(spacer())
	var dp := panel(400); dp.size_flags_vertical = Control.SIZE_EXPAND_FILL; h.add_child(dp)
	var dv := vb(10); dp.add_child(dv); sel.detail_box = dv
	_rival_detail()

func _rival_detail() -> void:
	var dv: VBoxContainer = sel.detail_box
	for c in dv.get_children(): c.queue_free()
	var s: Dictionary = Save.data; var r := Save.player_rank(); var v: Dictionary = D.rival(sel.rival); var st := Stats.compute(v.build); var p := Stats.parts_of(v.build)
	var beaten: bool = v.rank in s.beaten; var open: bool = v.rank >= r - 1; var me := Stats.compute(s.build)
	app.hangar.show_mech(v.build); app.hangar.view(-0.02)
	dv.add_child(cap("%dº LUGAR · CLASSE %s" % [v.rank, v.cls])); dv.add_child(lbl(v.call.to_upper(), 36, INK, "black")); dv.add_child(lbl("%s — carcaça “%s”" % [v.pilot, v.mech], 15, DIM))
	var q := hb(12); var bar := ColorRect.new(); bar.color = AMB; bar.custom_minimum_size = Vector2(2, 0); q.add_child(bar)
	var ql := lbl(v.quote, 18, INK, "med", true); ql.size_flags_horizontal = Control.SIZE_EXPAND_FILL; q.add_child(ql); dv.add_child(q)
	var g := hb(14); g.add_child(SilBox.new(HUD.silhouette(v.build), Vector2(96, 120)))
	var tb := spec_table([["Estrutura", fmt(st.structure * v.get("hpMul", 1.0))], ["Peso", f1(st.weight) + " t"], ["Pernas", D.LEGTYPE[st.legType]], ["Impulso", "%d km/h" % roundi(st.boostSpeed * 3.6)], ["Arena", D.ARENAS[v.arena].name]])
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; g.add_child(tb); dv.add_child(g)
	dv.add_child(cap("ARMAMENTO DECLARADO"))
	for k in ["handR", "handL", "backR", "backL", "shoulder", "util"]:
		if p[k]: var h := hb(6); h.add_child(mk_tag(p[k])); h.add_child(lbl(p[k].name, 15)); dv.add_child(h)
	if p.arms.kind == "weapon": var h := hb(6); h.add_child(mk_tag(p.arms)); h.add_child(lbl(p.arms.name, 15)); dv.add_child(h)
	dv.add_child(spacer()); dv.add_child(sep_line())
	if not me.valid: dv.add_child(_err("Sua montagem está irregular. Corrija na garagem."))
	var pay := hb(10); pay.add_child(cap("PRÊMIO")); pay.add_child(lbl(cr(v.prize * 0.25 if beaten else v.prize), 24, AMB, "mono")); if beaten: pay.add_child(lbl("revanche", 13, DIM))
	dv.add_child(pay)
	dv.add_child(btn("DESAFIAR" if open else "VENÇA O ANTERIOR PRIMEIRO", func(): app.start_match({ "kind": "league", "rival": v, "title": "CIRCUITO · %dº LUGAR" % v.rank, "arena": v.arena, "seed": v.rank * 13 + s.wins + s.losses, "mods": {}, "enemies": [{ "build": v.build, "call": v.call, "name": v.mech, "ai": v.ai, "hpMul": v.get("hpMul", 1.0) }] }), true, not (open and me.valid)))

func _err(t: String) -> Control:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", _sb(Color(0.9, 0.28, 0.18, 0.12), Color(0, 0, 0, 0), 0, Vector4(12, 6, 10, 6)))
	var l := lbl(t, 14, Color("#ffb5a4"), "disp", true); p.add_child(l); return p
func _wrn(t: String) -> Control:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", _sb(Color(0.95, 0.64, 0.17, 0.1), Color(0, 0, 0, 0), 0, Vector4(12, 6, 10, 6)))
	var l := lbl(t, 14, Color("#ffd699"), "disp", true); p.add_child(l); return p

# ───────── contratos ─────────
func gen_contracts() -> Array:
	var s: Dictionary = Save.data; var rank := Save.player_rank(); var tier := D.tier_for_rank(rank); var rng = D.Rng.new(int(s.contractSeed)); var out := []
	var types := ["duel", "duel", "ambush", "squad", "hunt", "gauntlet"]; var mk: Array = D.MODIFIERS.keys(); var ak: Array = D.ARENAS.keys()
	var base_skill := clampf(0.18 + (19 - rank) * 0.036, 0.15, 0.9)
	for i in 4:
		var type: String = "duel" if i == 0 else rng.pick(types); var arena: String = rng.pick(ak); var mods := {}
		for k in rng.ri(0, 2) + (1 if i == 3 else 0): mods[rng.pick(mk)] = true
		var mk_e := func(t: int, hp: float, scl: float, sk: float, boss := false) -> Dictionary:
			var b := Stats.random_build(rng, clampi(t, 0, 5), rng.pick(Stats.ARCH.keys()))
			var ai: Dictionary = b._ai.duplicate(); ai.skill = clampf(base_skill + sk + rng.rr(-0.05, 0.08), 0.05, 1)
			return { "build": b, "call": rng.pick(D.CALLSIGNS), "name": rng.pick(D.MECHNAMES), "ai": ai, "hpMul": hp, "scale": scl, "boss": boss }
		var enemies := []; var allies := []; var mul := 1.0; var seq := false
		match type:
			"duel": enemies = [mk_e.call(tier, 1.0, 1.0, 0.05)]
			"ambush": enemies = [mk_e.call(tier - 1, 0.8, 1.0, -0.05), mk_e.call(tier - 1, 0.8, 1.0, -0.05)]; mul = 1.5
			"squad": enemies = [mk_e.call(tier - 1, 0.7, 0.92, -0.08), mk_e.call(tier - 1, 0.7, 0.92, -0.08), mk_e.call(tier, 0.8, 1.0, 0.0)]; allies = [mk_e.call(tier, 1.0, 1.0, 0.1)]; mul = 1.6
			"hunt": enemies = [mk_e.call(tier + 1, 2.3, 1.3, 0.1, true)]; mul = 1.8
			_: enemies = [mk_e.call(tier - 1, 0.85, 1.0, -0.05), mk_e.call(tier, 0.85, 1.0, 0.0), mk_e.call(tier, 0.95, 1.0, 0.05)]; seq = true; mul = 2.0
		var pay := (11000.0 + tier * 9000) * mul
		for k in mods: pay *= D.MODIFIERS[k].pay
		out.append({ "i": i, "type": type, "arena": arena, "mods": mods, "enemies": enemies, "allies": allies, "sequence": seq, "pay": roundi(pay / 500) * 500, "seed": int(s.contractSeed) * 10 + i })
	return out

func scr_contracts(_a) -> void:
	var s: Dictionary = Save.data
	if contract_seed != int(s.contractSeed): contract_list = gen_contracts(); contract_seed = int(s.contractSeed)
	app.hangar.show_mech(s.build); app.hangar.view(-0.2)
	var me := Stats.compute(s.build)
	var m := gutter(); var v := vb(10); m.add_child(v)
	v.add_child(topbar("CONTRATOS", "O mural muda a cada combate aceito. Modificadores pagam mais."))
	var h := hb(0); h.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(h); h.add_child(spacer())
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; sc.custom_minimum_size.x = 740; h.add_child(sc)
	var g := GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 14); g.add_theme_constant_override("v_separation", 14); sc.add_child(g)
	for c in contract_list:
		var p := panel(350); var cv := vb(6); p.add_child(cv)
		cv.add_child(cap(D.ARENAS[c.arena].name)); cv.add_child(lbl(D.CONTRACT_TYPES[c.type].name.to_upper(), 24, INK, "black")); cv.add_child(lbl(D.CONTRACT_TYPES[c.type].desc, 14, DIM))
		var og := GridContainer.new(); og.columns = 2; og.add_theme_constant_override("h_separation", 10)
		for e in c.enemies + c.allies:
			var oh := hb(6); oh.add_child(SilBox.new(HUD.silhouette(e.build), Vector2(26, 34)))
			var ov := vb(0); ov.add_child(lbl(e.call, 15, CY if e in c.allies else INK, "bold")); ov.add_child(lbl("aliado" if e in c.allies else (e.name + (" · superpesado" if e.boss else "")), 11, DIM)); oh.add_child(ov); og.add_child(oh)
		cv.add_child(og)
		if c.mods.is_empty(): cv.add_child(lbl("Sem modificadores", 13, FAINT))
		for k in c.mods:
			var mh := hb(8); var bar := ColorRect.new(); bar.color = AMB; bar.custom_minimum_size = Vector2(3, 0); mh.add_child(bar)
			var mv := vb(0); mv.add_child(lbl(D.MODIFIERS[k].name, 14, Color("#ffd699"), "bold")); var dl := lbl(D.MODIFIERS[k].desc, 13, DIM, "disp", true); dl.custom_minimum_size.x = 290; mv.add_child(dl); mh.add_child(mv); cv.add_child(mh)
		cv.add_child(spacer()); cv.add_child(sep_line())
		var ph := hb(10); ph.add_child(cap("PAGAMENTO")); ph.add_child(lbl(cr(c.pay), 22, AMB, "mono")); cv.add_child(ph)
		var cc: Dictionary = c
		cv.add_child(btn("ACEITAR", func(): app.start_match({ "kind": "contract", "contract": cc, "title": "CONTRATO · " + D.CONTRACT_TYPES[cc.type].name.to_upper(), "arena": cc.arena, "seed": cc.seed, "mods": cc.mods.duplicate(), "enemies": cc.enemies, "allies": cc.allies, "sequence": cc.sequence }), true, not me.valid))
		g.add_child(p)
	var foot := hb(14); foot.alignment = BoxContainer.ALIGNMENT_END; v.add_child(foot)
	if not me.valid: foot.add_child(_err("Sua montagem está irregular. Corrija na garagem."))
	foot.add_child(btn("TROCAR O MURAL — 2.000 CR", func():
		if s.credits >= 2000: s.credits -= 2000; s.contractSeed = int(s.contractSeed) + 1; Save.persist(); Sfx.play("buy"); go("contracts"), false, s.credits < 2000))

func scr_endless(_a) -> void:
	var s: Dictionary = Save.data; var me := Stats.compute(s.build)
	app.hangar.show_mech(s.build); app.hangar.view(-0.14)
	var m := gutter(); var v := vb(10); m.add_child(v)
	v.add_child(topbar("MODO INFINITO", "A Fornalha não fecha."))
	var h := hb(0); h.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(h); h.add_child(spacer())
	var p := panel(470); h.add_child(p); var dv := vb(10); p.add_child(dv)
	dv.add_child(cap("REGRAS")); dv.add_child(lbl("ONDAS SEM FIM", 36, INK, "black"))
	for rule in ["Cada onda traz mais adversários, com peças de classe mais alta e pilotos melhores.", "A cada cinco ondas entra um alvo prioritário superpesado, que paga em dobro.",
		"Entre ondas você recupera 15% da estrutura e escolhe uma de três melhorias de campo. Elas valem até a carcaça cair.", "Munição não volta sozinha: armas de energia, reabastecimento e corpo a corpo seguram as ondas longas.",
		"Os créditos das ondas limpas são seus mesmo quando você perde."]:
		var rh := hb(10); var bar := ColorRect.new(); bar.color = LINE; bar.custom_minimum_size = Vector2(2, 0); rh.add_child(bar)
		var rl := lbl(rule, 16, INK, "disp", true); rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rh.add_child(rl); dv.add_child(rh)
	var rec := hb(28)
	for kv in [["MELHOR ONDA", str(s.bestWave) if s.bestWave else "—"], ["MELHOR PONTUAÇÃO", fmt(s.bestScore) if s.bestScore else "—"]]:
		var rv := vb(0); rv.add_child(cap(kv[0])); rv.add_child(lbl(kv[1], 30, INK, "mono")); rec.add_child(rv)
	dv.add_child(rec); dv.add_child(spacer()); dv.add_child(sep_line())
	if not me.valid: dv.add_child(_err("Sua montagem está irregular. Corrija na garagem."))
	dv.add_child(btn("DESCER À ARENA", func(): app.start_match({ "kind": "endless", "endless": true, "title": "MODO INFINITO", "arena": D.ARENAS.keys()[randi() % 5], "seed": randi() % 100000, "mods": {}, "enemies": [] }), true, not me.valid))

func start_test() -> void:
	var rv: Dictionary = D.RIVALS[5]
	app.start_match({ "kind": "test", "title": "CAMPO DE TESTES", "arena": "coliseu", "seed": 3, "mods": {}, "enemies": [{ "build": rv.build, "call": "Alvo", "name": "BONECO DE PROVA", "ai": { "passive": true, "skill": 0.0 }, "hpMul": 4.0 }] })

# ───────── garagem ─────────
const STATROWS := [
	["Estrutura", "structure", "n", 1], ["Blindagem somada", "armor", "n", 1], ["Defesa cinética", "d0", "n", 1], ["Defesa de energia", "d1", "n", 1], ["Defesa explosiva", "d2", "n", 1], ["Estabilidade", "stab", "n", 1], null,
	["Peso total", "weight", "t", -1], ["Reserva de EN", "enCap", "n", 1], ["Recarga de EN", "enRech", "s", 1], ["Retomada da recarga", "enDelay", "sec", -1], null,
	["Velocidade de impulso", "bs", "kmh", 1], ["Impulso rápido", "qs", "kmh", 1], ["Espera do impulso", "qbReload", "sec2", -1], ["Salto", "jump", "f", 1], null,
	["Alcance de trava", "lockRange", "m", 1], ["Tempo de trava", "lockTime", "x", -1], ["Rastreio dos braços", "track", "f2", 1], ["Kits de reparo", "kits", "n", 1]]
static func _sv(s: Dictionary, k: String) -> float:
	match k:
		"armor": return s.partArmor.head + s.partArmor.core + s.partArmor.armR * 2 + s.partArmor.legs
		"d0": return s.defAvg[0]
		"d1": return s.defAvg[1]
		"d2": return s.defAvg[2]
		"bs": return s.boostSpeed * 3.6
		"qs": return s.qbSpeed * 3.6
	return float(s[k])
static func _sf(v: float, f: String) -> String:
	match f:
		"t": return f1(v) + " t"
		"s": return fmt(v) + " /s"
		"sec": return f1(v) + " s"
		"sec2": return "%.2f s" % v
		"kmh": return fmt(v) + " km/h"
		"f": return f1(v)
		"f2": return "%.2f" % v
		"m": return fmt(v) + " m"
		"x": return "×%.2f" % v
	return fmt(v)

func slot_list() -> Array:
	var b: Dictionary = Save.data.build; var core = D.PART.get(b.core); var l := []
	for x in D.SLOTS: l.append(x.duplicate())
	for i in (int(core.slots) if core else 2): l.append({ "k": "mod%d" % i, "label": "Módulo %d" % (i + 1), "cat": "mod" })
	return l
func slot_part(k: String):
	var b: Dictionary = Save.data.build
	if k.begins_with("mod"):
		var i := int(k.substr(3)); return D.PART[b.mods[i]] if i < b.mods.size() else null
	return D.PART.get(b[k]) if b.get(k) else null

func scr_garage(_a) -> void:
	var s: Dictionary = Save.data
	if not sel.has("slot"): sel.slot = "head"
	if not sel.has("tab"): sel.tab = "parts"
	app.hangar.show_mech(s.build); app.hangar.view(0.09)
	var m := gutter(); var v := vb(10); m.add_child(v)
	v.add_child(topbar("GARAGEM", "Monte dentro dos limites de carga e energia. Peças fora da regra impedem a saída."))
	var h := hb(12); h.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(h)
	var sp := panel(250); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL; h.add_child(sp)
	var ssc := ScrollContainer.new(); ssc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; sp.add_child(ssc); var slots_box := vb(0); slots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ssc.add_child(slots_box)
	var cp := panel(330); cp.size_flags_vertical = Control.SIZE_EXPAND_FILL; h.add_child(cp)
	var csc := ScrollContainer.new(); csc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; cp.add_child(csc); var cat_box := vb(6); cat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; csc.add_child(cat_box)
	h.add_child(spacer())
	var shp := panel(340); shp.size_flags_vertical = Control.SIZE_EXPAND_FILL; h.add_child(shp)
	var shsc := ScrollContainer.new(); shsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; shp.add_child(shsc); var sheet_box := vb(4); sheet_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; shsc.add_child(sheet_box)
	garage_refs = { "slots": slots_box, "cat": cat_box, "sheet": sheet_box }
	garage_slots(); garage_cat(); garage_sheet()

func garage_slots() -> void:
	var box: VBoxContainer = garage_refs.slots; for c in box.get_children(): c.queue_free()
	var b: Dictionary = Save.data.build; var is_tank: bool = D.PART[b.legs].type == "tank"; var wa: bool = D.PART[b.arms].kind == "weapon"
	var tabs := hb(0)
	for tb in [["parts", "PEÇAS"], ["paint", "PINTURA"]]:
		var bt := btn(tb[1], func(): sel.tab = tb[0]; garage_slots(); garage_cat())
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if sel.tab == tb[0]: bt.add_theme_stylebox_override("normal", _sb(INK, INK, 1, Vector4(10, 6, 10, 6))); bt.add_theme_color_override("font_color", BLACK)
		tabs.add_child(bt)
	box.add_child(tabs)
	for sl in slot_list():
		var p = slot_part(sl.k); var blocked: bool = (sl.k == "booster" and is_tank) or ((sl.k == "handR" or sl.k == "handL") and wa)
		var k: String = sl.k
		var row := Row.new(func(): sel.slot = k; sel.tab = "parts"; garage_slots(); garage_cat(); garage_sheet())
		var rv := vb(0); rv.add_child(cap(sl.label))
		var nm = ("embutido nas esteiras" if sl.k == "booster" else "braços-arma") if blocked else (p.name if p else "— vazio —")
		rv.add_child(lbl(nm, 16, FAINT if blocked else INK, "bold")); row.add_child(rv); box.add_child(row)
		row.set_on(sel.slot == sl.k and sel.tab == "parts")

func garage_cat() -> void:
	var box: VBoxContainer = garage_refs.cat; for c in box.get_children(): c.queue_free()
	var s: Dictionary = Save.data; var b: Dictionary = s.build
	if sel.tab == "paint":
		var pt: Dictionary = b.paint
		box.add_child(cap("IDENTIFICAÇÃO"))
		var le := LineEdit.new(); le.text = b.name; le.max_length = 20; le.text_changed.connect(func(t): b.name = t.to_upper() if t else "SEM NOME"; Save.persist()); box.add_child(le)
		box.add_child(cap("ESQUEMA DE CORES"))
		for kv in [["a", "Blindagem principal"], ["b", "Placas secundárias"], ["c", "Estrutura"], ["glow", "Sensores e emissores"]]:
			var rh := hb(10); var l := lbl(kv[1], 15); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rh.add_child(l)
			var cpb := ColorPickerButton.new(); cpb.color = Color(pt[kv[0]]); cpb.custom_minimum_size = Vector2(54, 28); cpb.edit_alpha = false
			var key: String = kv[0]
			cpb.color_changed.connect(func(c): pt[key] = "#" + c.to_html(false); _repaint())
			rh.add_child(cpb); box.add_child(rh)
		var wh := hb(10); var wl := lbl("Desgaste", 15); wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; wh.add_child(wl)
		var sl := HSlider.new(); sl.min_value = 0; sl.max_value = 1; sl.step = 0.05; sl.value = pt.get("wear", 0.5); sl.custom_minimum_size.x = 160; sl.value_changed.connect(func(x): pt.wear = x; _repaint()); wh.add_child(sl); box.add_child(wh)
		box.add_child(cap("ESQUEMAS DE FÁBRICA"))
		var g := GridContainer.new(); g.columns = 5; g.add_theme_constant_override("h_separation", 6); g.add_theme_constant_override("v_separation", 6)
		for sw in [["#8a8f86", "#c9541e", "#2b2e30", "#ff9a3c"], ["#d9d5c8", "#3d6e8c", "#26292c", "#8fd3ff"], ["#2a2a2c", "#7a1c16", "#131314", "#ff2e1f"], ["#c9a227", "#2d2d2d", "#191919", "#ff5a1f"], ["#4a4f45", "#8c8a7c", "#1c1d1b", "#ffa53a"], ["#e8e6df", "#c22a1f", "#1e1f22", "#ff3b2f"], ["#1f4a5e", "#e6e1cf", "#16242c", "#59c9ff"], ["#5c3d52", "#cfc8bb", "#1d1a1e", "#ff8ad0"], ["#3a2420", "#d9731f", "#141211", "#ffb02e"], ["#6b6f72", "#1f3f5c", "#1a1c1e", "#ffb347"]]:
			var swc: Array = sw
			var r := Row.new(func(): pt.a = swc[0]; pt.b = swc[1]; pt.c = swc[2]; pt.glow = swc[3]; Sfx.play("equip"); _repaint(true); garage_cat())
			var sh := hb(0); sh.custom_minimum_size = Vector2(52, 22)
			for i in 4: var cr2 := ColorRect.new(); cr2.color = Color(swc[i]); cr2.custom_minimum_size = Vector2(22 if i == 0 else 10, 22); cr2.mouse_filter = Control.MOUSE_FILTER_IGNORE; sh.add_child(cr2)
			r.add_child(sh); g.add_child(r)
		box.add_child(g)
		return
	var sl2 = null
	for x in slot_list():
		if x.k == sel.slot: sl2 = x
	if sl2 == null: sl2 = slot_list()[0]
	var cur = slot_part(sl2.k)
	var hh := hb(); var hl := cap("%s NO ESTOQUE" % D.CATS[sl2.cat]); hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hh.add_child(hl)
	var cat: String = sl2.cat
	var bl := LinkButton.new(); bl.text = "COMPRAR MAIS ▸"; bl.add_theme_color_override("font_color", AMB); bl.add_theme_font_size_override("font_size", 13); bl.pressed.connect(func(): sel.cat = cat; go("shop")); hh.add_child(bl); box.add_child(hh)
	var optional: bool = not (sl2.k in ["head", "core", "arms", "legs", "gen", "fcs"])
	if optional:
		var r := Row.new(func(): equip(""), func(): _hover_part(null)); r.add_child(lbl("— deixar vazio —", 16, INK, "bold")); r.set_on(cur == null); box.add_child(r)
	for p in D.PARTS:
		if p.slot != cat or not s.owned.has(p.id): continue
		var free: int = int(s.owned[p.id]) - Save.used_count(b, p.id); var is_cur: bool = cur != null and cur.id == p.id
		var pid: String = p.id
		var r := Row.new(func(): equip(pid), func(): _hover_part(D.PART[pid]))
		var rv := vb(0); var r1 := hb(6); r1.add_child(mk_tag(p)); var nl := lbl(p.name, 16, DIM if (not is_cur and free <= 0) else INK, "bold"); nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; r1.add_child(nl)
		if is_cur: r1.add_child(lbl("INSTALADA", 11, AMB, "mono"))
		elif free <= 0: r1.add_child(lbl("EM USO", 11, AMB, "mono"))
		elif s.owned[p.id] > 1: r1.add_child(lbl("×%d" % s.owned[p.id], 11, AMB, "mono"))
		rv.add_child(r1)
		var info := "%s t · %d EN" % [f1(p.w), int(p.get("en", 0))]
		if p.has("dmg") or p.has("wa"): info += " · %s DPS" % fmt(Stats.weapon_dps(D.PART[p.wa] if p.has("wa") else p))
		if p.has("arm"): info += " · bl. %d" % p.arm
		rv.add_child(lbl(info, 12, DIM, "mono")); r.add_child(rv); r.set_on(is_cur); box.add_child(r)
	var desc := vb(6); desc.name = "desc"; box.add_child(sep_line()); box.add_child(desc); garage_refs.desc = desc
	_part_desc(cur)

func _part_desc(p) -> void:
	var box: VBoxContainer = garage_refs.get("desc")
	if box == null or not is_instance_valid(box): return
	for c in box.get_children(): c.queue_free()
	if p == null: box.add_child(lbl("Passe o cursor sobre uma peça para ver a ficha e a diferença na carcaça.", 14, DIM, "disp", true)); return
	var h := hb(6); h.add_child(mk_tag(p)); h.add_child(lbl(p.name, 19, INK, "bold")); box.add_child(h)
	box.add_child(lbl(D.MAKERS[p.mk].name, 12, DIM)); box.add_child(lbl(p.get("desc", ""), 15, INK, "disp", true)); box.add_child(spec_box(p))

func _hover_part(p) -> void:
	_part_desc(p if p != null else slot_part(sel.slot))
	var cur = slot_part(sel.slot)
	var id: String = p.id if p != null else ""
	if (cur.id if cur else "") != id: garage_sheet(candidate(id))
	else: garage_sheet()

func garage_sheet(alt = null) -> void:
	var box: VBoxContainer = garage_refs.get("sheet")
	if box == null or not is_instance_valid(box): return
	for c in box.get_children(): c.queue_free()
	var s: Dictionary = Save.data; var cur := Stats.compute(s.build); var nw = Stats.compute(alt) if alt != null else null
	var show_s: Dictionary = nw if (nw != null and nw.has("structure")) else cur
	var hh := hb(); var hl := cap("FICHA TÉCNICA" + (" — COM A PEÇA" if alt != null else "")); hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hh.add_child(hl)
	var stamp := lbl("APTA" if show_s.valid else "IRREGULAR", 13, OK if show_s.valid else RED, "black"); stamp.add_theme_stylebox_override("normal", _sb(Color(0, 0, 0, 0), OK if show_s.valid else RED, 2, Vector4(8, 1, 8, 1))); hh.add_child(stamp); box.add_child(hh)
	if show_s.has("structure"):
		var meter := func(label: String, v: float, mx: float, unit: String):
			var r := v / mx if mx > 0 else 0.0
			var mh := hb(); var ml := lbl(label, 14); ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mh.add_child(ml)
			mh.add_child(lbl(("%s / %s %s" % [f1(v), f1(mx), unit]) if unit == "t" else ("%s / %s %s" % [fmt(v), fmt(mx), unit]), 12, RED if r > 1 else INK, "mono")); box.add_child(mh)
			box.add_child(Meter.new(minf(1.0, r), RED if r > 1 else (AMB if r > 0.9 else INK)))
		meter.call("Carga nas pernas", show_s.carried, show_s.legLoad, "t")
		if not show_s.armsWeapon: meter.call("Carga nos braços", show_s.armWeight, show_s.armLoad, "t")
		meter.call("Consumo de EN", show_s.enLoad, show_s.enOut, "EN")
		var mh := hb(); var ml := lbl("Módulos", 14); ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mh.add_child(ml); mh.add_child(lbl("%d / %d" % [(alt if alt != null else s.build).mods.size(), show_s.slots], 12, INK, "mono")); box.add_child(mh)
	for e in show_s.errors: box.add_child(_err(e))
	for e in show_s.warns: box.add_child(_wrn(e))
	if not cur.has("structure"): return
	var g := GridContainer.new(); g.columns = 3; g.add_theme_constant_override("h_separation", 8); g.add_theme_constant_override("v_separation", 1)
	for R in STATROWS:
		if R == null:
			for i in 3: var sp := Control.new(); sp.custom_minimum_size.y = 6; g.add_child(sp)
			continue
		var a := _sv(cur, R[1]); var bv := _sv(nw, R[1]) if (nw != null and nw.has("structure")) else a; var dd := bv - a; var good: bool = dd * R[3] > 0
		var l1 := lbl(R[0], 14, DIM); l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; g.add_child(l1)
		var l2 := lbl(_sf(bv, R[2]), 13, INK, "mono"); l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; g.add_child(l2)
		g.add_child(lbl("" if absf(dd) < 1e-6 else ("▲" if dd > 0 else "▼"), 10, OK if good else RED, "mono"))
	box.add_child(g)

func candidate(id: String) -> Dictionary:
	var b: Dictionary = Save.data.build.duplicate(true); var k: String = sel.slot
	if k.begins_with("mod"):
		var i := int(k.substr(3))
		if id:
			if i < b.mods.size(): b.mods[i] = id
			else: b.mods.append(id)
		elif i < b.mods.size(): b.mods.remove_at(i)
	else: b[k] = id if id else null
	normalize(b); return b

func normalize(b: Dictionary) -> void:
	var s: Dictionary = Save.data; var legs = D.PART.get(b.legs); var arms = D.PART.get(b.arms); var core = D.PART.get(b.core)
	if legs and legs.type == "tank": b.booster = null
	elif not b.get("booster"):
		for p in D.PARTS:
			if p.slot == "booster" and s.owned.has(p.id): b.booster = p.id; break
	if arms and arms.kind == "weapon": b.handR = null; b.handL = null
	if core and b.mods.size() > int(core.slots): b.mods.resize(int(core.slots))

func equip(id: String) -> void:
	var s: Dictionary = Save.data; var k: String = sel.slot; var cur = slot_part(k)
	if id and cur and cur.id == id: return
	if id and int(s.owned.get(id, 0)) - Save.used_count(s.build, id) <= 0: Sfx.play("error"); toast("Essa unidade já está instalada em outro ponto. Compre outra na loja."); return
	if not id and k in ["head", "core", "arms", "legs", "gen", "fcs"]: return
	s.build = candidate(id); Save.persist(); Sfx.play("equip")
	app.hangar.show_mech(s.build); garage_slots(); garage_cat(); garage_sheet()

var _repaint_t := 0
func _repaint(now := false) -> void:
	Save.persist()
	_repaint_t += 1; var my := _repaint_t
	if not now: await get_tree().create_timer(0.15).timeout
	if my == _repaint_t: app.hangar.show_mech(Save.data.build)

# ───────── loja ─────────
func scr_shop(_a) -> void:
	if not sel.has("cat"): sel.cat = "hand"
	var m := gutter(); var v := vb(10); m.add_child(v)
	v.add_child(topbar("LOJA", "Peças novas liberam conforme você sobe no Circuito. Revenda devolve 60%."))
	var tabs := hb(0); v.add_child(tabs); shop_refs.tabs = {}
	for k in D.CATS:
		var kk: String = k
		var bt := btn(D.CATS[k].to_upper(), func(): sel.cat = kk; sel.item = ""; _shop_tabs(); shop_list())
		bt.add_theme_font_size_override("font_size", 13); tabs.add_child(bt); shop_refs.tabs[k] = bt
	var h := hb(16); h.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(h)
	var lp := panel(360); lp.size_flags_vertical = Control.SIZE_EXPAND_FILL; h.add_child(lp)
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; lp.add_child(sc); var list := vb(0); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(list)
	h.add_child(spacer())
	var dp := panel(400); dp.size_flags_vertical = Control.SIZE_EXPAND_FILL; h.add_child(dp)
	var dsc := ScrollContainer.new(); dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; dp.add_child(dsc); var det := vb(10); det.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dsc.add_child(det)
	shop_refs.list = list; shop_refs.det = det; shop_refs.top = v.get_child(0)
	_shop_tabs(); shop_list()

func _shop_tabs() -> void:
	for k in shop_refs.tabs:
		var bt: Button = shop_refs.tabs[k]
		if k == sel.cat: bt.add_theme_stylebox_override("normal", _sb(INK, INK, 1, Vector4(12, 6, 12, 6))); bt.add_theme_color_override("font_color", BLACK)
		else: bt.add_theme_stylebox_override("normal", _sb(PANEL, LINE, 1, Vector4(12, 6, 12, 6))); bt.add_theme_color_override("font_color", DIM)

func shop_list() -> void:
	var list: VBoxContainer = shop_refs.list; for c in list.get_children(): c.queue_free()
	var s: Dictionary = Save.data; var tier := D.tier_for_rank(Save.player_rank())
	var items := D.PARTS.filter(func(p): return p.slot == sel.cat)
	items.sort_custom(func(a, b): return a.tier < b.tier if a.tier != b.tier else a.price < b.price)
	if not items.any(func(p): return p.id == sel.get("item", "")): sel.item = items[0].id
	var rows := {}
	for p in items:
		var locked: bool = p.tier > tier; var pid: String = p.id
		var r := Row.new(func(): sel.item = pid; for k in rows: rows[k].set_on(k == pid); shop_detail())
		r.dim_row = locked; r._style(false)
		var rv := vb(0); var r1 := hb(6); r1.add_child(mk_tag(p)); var nl := lbl(p.name, 16, INK, "bold"); nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; r1.add_child(nl)
		if s.owned.has(p.id): r1.add_child(lbl("TEM %d" % s.owned[p.id], 11, AMB, "mono"))
		rv.add_child(r1); rv.add_child(lbl("LIBERA NA CLASSE " + D.TIERCLS[p.tier] if locked else (cr(p.price) if p.price else "EQUIPAMENTO INICIAL"), 12, DIM, "mono"))
		r.add_child(rv); list.add_child(r); rows[p.id] = r; r.set_on(p.id == sel.item)
	shop_detail()

func shop_detail() -> void:
	var det: VBoxContainer = shop_refs.det; for c in det.get_children(): c.queue_free()
	var s: Dictionary = Save.data; var p: Dictionary = D.PART[sel.item]; var tier := D.tier_for_rank(Save.player_rank()); var locked: bool = p.tier > tier
	var own: int = int(s.owned.get(p.id, 0)); var used := Save.used_count(s.build, p.id)
	app.hangar.show_part(p.id, s.build.paint); app.hangar.view(0.02, 30)
	det.add_child(cap("%s · %s" % [D.MAKERS[p.mk].name, D.MAKERS[p.mk].sub])); det.add_child(lbl(p.name.to_upper(), 34, INK, "black")); det.add_child(lbl("Classe %s · %s" % [D.TIERCLS[p.tier], D.CATS[p.slot]], 15, DIM))
	det.add_child(lbl(p.desc, 16, INK, "disp", true)); det.add_child(spec_box(p)); det.add_child(sep_line())
	var ph := hb(10); ph.add_child(cap("PREÇO")); ph.add_child(lbl(cr(p.price) if p.price else "—", 24, AMB, "mono")); ph.add_child(lbl("você tem %d%s" % [own, (", %d em uso" % used) if used else ""], 13, DIM)); det.add_child(ph)
	var can: bool = not locked and s.credits >= p.price and p.price > 0; var sell: bool = own > used and p.price > 0
	var bh := hb(10)
	var sb := btn("VENDER " + (cr(p.price * 0.6) if p.price else ""), func():
		if int(s.owned.get(p.id, 0)) <= Save.used_count(s.build, p.id): return
		s.owned[p.id] = int(s.owned[p.id]) - 1
		if s.owned[p.id] <= 0: s.owned.erase(p.id)
		s.credits += roundi(p.price * 0.6); Save.persist(); Sfx.play("buy"); _wallet(); shop_list(), false, not sell)
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bh.add_child(sb)
	var bb := btn("BLOQUEADA" if locked else ("INICIAL" if not p.price else ("SALDO INSUFICIENTE" if s.credits < p.price else "COMPRAR")), func():
		if s.credits < p.price: Sfx.play("error"); return
		s.credits -= p.price; s.owned[p.id] = int(s.owned.get(p.id, 0)) + 1; Save.persist(); Sfx.play("buy"); toast("%s entregue no hangar." % p.name); _wallet(); shop_list(), true, not can)
	bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bh.add_child(bb); det.add_child(bh)

func _wallet() -> void:
	var l = root.find_child("credits", true, false)
	if l: l.text = cr(Save.data.credits)

# ───────── opções ─────────
func scr_options(_a) -> void:
	var st: Dictionary = Save.data.settings
	app.hangar.show_mech(Save.data.build); app.hangar.view(-0.14)
	var m := gutter(); var v := vb(10); m.add_child(v)
	v.add_child(topbar("OPÇÕES"))
	var h := hb(0); h.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(h); h.add_child(spacer())
	var p := panel(500); p.size_flags_vertical = Control.SIZE_EXPAND_FILL; h.add_child(p)
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; p.add_child(sc); var dv := vb(8); dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(dv)
	dv.add_child(cap("ÁUDIO E MIRA"))
	for row in [["Volume geral", "vol", 0.0, 1.0, 0.05], ["Trilha", "music", 0.0, 1.0, 0.05], ["Sensibilidade do mouse", "sens", 0.3, 2.5, 0.05]]:
		var rh := hb(10); var l := lbl(row[0], 15); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rh.add_child(l)
		var sl := HSlider.new(); sl.min_value = row[2]; sl.max_value = row[3]; sl.step = row[4]; sl.value = st[row[1]]; sl.custom_minimum_size.x = 240
		var key: String = row[1]
		sl.value_changed.connect(func(x): st[key] = x; Save.persist(); Sfx.set_volume(Settings.vol, Settings.music)); rh.add_child(sl); dv.add_child(rh)
	var ih := hb(10); var il := lbl("Inverter eixo vertical", 15); il.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ih.add_child(il)
	var cb := CheckBox.new(); cb.button_pressed = st.invY; cb.toggled.connect(func(x): st.invY = x; Save.persist()); ih.add_child(cb); dv.add_child(ih)
	dv.add_child(cap("GRÁFICOS"))
	var qh := hb(0)
	var names := ["LEVE", "MÉDIO", "ALTO"]
	for i in 3:
		var qi := i
		var bt := btn(names[i], func(): st.quality = qi; Save.persist(); app.apply_quality(); go("options"))
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if int(st.quality) == i: bt.add_theme_stylebox_override("normal", _sb(INK, INK, 1, Vector4(10, 7, 10, 7))); bt.add_theme_color_override("font_color", BLACK)
		qh.add_child(bt)
	dv.add_child(qh)
	dv.add_child(lbl("Renderizador: %s." % ("Compatibilidade (OpenGL)" if Settings.compat() else "Avançado (Vulkan/D3D12)"), 13, DIM))
	dv.add_child(cap("CONTROLES"))
	dv.add_child(spec_table([["W A S D", "Mover"], ["Mouse", "Mirar"], ["Espaço", "Saltar · segurar para subir"], ["Shift", "Impulso rápido"], ["Ctrl ou C", "Sobreimpulso (liga/desliga)"], ["Botão esquerdo / direito", "Arma da mão esquerda / direita"],
		["Q / E", "Unidade dorsal esquerda / direita"], ["R", "Ombros"], ["F", "Utilitário (gancho, barreira…)"], ["G", "Kit de reparo"], ["T ou botão do meio", "Trava fixa no alvo"], ["Tab ou roda", "Trocar de alvo"], ["Esc", "Pausa"]]))
	dv.add_child(lbl("Controle: analógicos movem e miram; LB/RB mãos, LT/RT dorso, A salto, X impulso, Y reparo, L3 sobreimpulso, R3 trava, Start pausa.", 13, DIM, "disp", true))
	dv.add_child(cap("PROGRESSO"))
	var wb := btn("APAGAR PROGRESSO", func(): pass)
	wb.pressed.connect(func():
		if wb.has_meta("sure"): Save.wipe(); sel = {}; contract_seed = -1; Sfx.play("ok"); go("menu")
		else: wb.set_meta("sure", true); wb.text = "CONFIRMAR: APAGAR TUDO"; wb.add_theme_color_override("font_color", RED); Sfx.play("warn"))
	dv.add_child(wb)

# ───────── resultados ─────────
func scr_results(r: Dictionary) -> void:
	app.hangar.show_mech(Save.data.build); app.hangar.view(-0.14)
	var m := gutter(); var h := hb(0); m.add_child(h); h.add_child(spacer())
	var p := panel(470); h.add_child(p); var dv := vb(10); p.add_child(dv)
	p.accent = OK if r.win else RED; p.full = true
	dv.add_child(cap(r.title)); dv.add_child(lbl(r.headline.to_upper(), 36, INK, "black")); if r.subline: dv.add_child(lbl(r.subline, 15, DIM, "disp", true))
	var tm := int(r.time)
	var rows := [["Tempo de combate", "%02d:%02d" % [tm / 60, tm % 60]], ["Dano causado", fmt(r.dealt)], ["Dano sofrido", fmt(r.taken)], ["Partes rompidas no adversário", str(r.breaches)]]
	if r.wave: rows += [["Ondas limpas", str(r.wave - 1)], ["Abates", str(r.kills)], ["Pontuação", fmt(r.score) + (" — recorde" if r.record else "")]]
	else: rows.append(["Estrutura restante", "%d%%" % r.left])
	dv.add_child(spec_table(rows, true)); dv.add_child(spacer()); dv.add_child(sep_line())
	var ph := hb(10); ph.add_child(cap("CRÉDITOS")); ph.add_child(lbl("+" + cr(r.reward), 24, AMB, "mono")); if r.rewardNote: ph.add_child(lbl(r.rewardNote, 13, DIM))
	dv.add_child(ph)
	if r.unlock:
		var u := PanelContainer.new(); u.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0), OK, 1, Vector4(10, 6, 10, 6))); u.add_child(lbl("Catálogo classe %s liberado na loja." % r.unlock, 15, OK)); dv.add_child(u)
	var bh := hb(10)
	if r.retry: var rb := btn("REPETIR", func(): app.start_match(app.last_cfg)); rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bh.add_child(rb)
	var mb := btn("VOLTAR AO HANGAR", func(): go("menu"), true); mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bh.add_child(mb)
	dv.add_child(bh)

# ───────── sobreposições ─────────
func _overlay_bg() -> Control:
	close_overlay(); overlay.visible = true
	var bg := ColorRect.new(); bg.color = Color(0.024, 0.027, 0.027, 0.72); overlay.add_child(bg); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cc := CenterContainer.new(); overlay.add_child(cc); cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return cc

func show_pause(m) -> void:
	var cc := _overlay_bg(); var p := panel(420); cc.add_child(p); var v := vb(14); p.add_child(v)
	v.add_child(cap("COMBATE SUSPENSO")); v.add_child(lbl("PAUSA", 36, INK, "black"))
	v.add_child(btn("CONTINUAR", func(): app.resume(), true))
	v.add_child(btn("ABANDONAR" + (" E RECEBER" if m.cfg.get("endless", false) else ""), func(): app.abandon()))
	var t := lbl("WASD mover · Espaço saltar/subir · Shift impulso · Ctrl sobreimpulso · botões do mouse mãos · Q/E dorso · R ombros · F utilitário · G reparo · T trava fixa · Tab troca de alvo", 14, DIM, "disp", true)
	t.custom_minimum_size.x = 380; v.add_child(t)

func show_perks(choices: Array, m, cb: Callable) -> void:
	perk_cb = cb
	var cc := _overlay_bg(); var v := vb(18); v.custom_minimum_size.x = 900; cc.add_child(v)
	var t1 := cap("ONDA %d LIMPA · ESTRUTURA +15%%" % m.wave); t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t1)
	var t2 := lbl("ESCOLHA UMA MELHORIA DE CAMPO", 34, INK, "black"); t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t2)
	var h := hb(14); v.add_child(h)
	for p in choices:
		var pid: String = p.id
		var r := Row.new(func(): close_overlay(); var c := perk_cb; perk_cb = Callable(); c.call(pid))
		r.custom_minimum_size = Vector2(290, 170); r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_theme_stylebox_override("panel", _sb(PANEL, LINE, 1, Vector4(18, 18, 18, 18)))
		var pv := vb(8); pv.add_child(cap(("NÍVEL %d" % (m.perks[p.id] + 1)) if m.perks.has(p.id) else "NOVA")); pv.add_child(lbl(p.name.to_upper(), 27, INK, "black", true)); pv.add_child(lbl(p.desc, 16, INK, "disp", true))
		r.add_child(pv); h.add_child(r)
	if choices.is_empty(): v.add_child(btn("SEGUIR", func(): close_overlay(); perk_cb.call(""), true))

func close_overlay() -> void:
	for c in overlay.get_children(): c.queue_free()
	overlay.visible = false

func toast(t: String) -> void:
	toast_lbl.text = t; toast_lbl.visible = true; toast_t = 3.2; toast_lbl.reset_size()
