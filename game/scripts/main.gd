## Inicialização, laço principal e fluxo entre hangar e combate.
extends Node

var hangar: Hangar
var hud: HUD
var ui: UI
var match_node: Match = null
var last_cfg: Dictionary = {}
var pending_end = null
var args := {}
var canvas: CanvasLayer

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Mats.init_base()
	Save.load_save()
	if args.has("view"):
		await Mats.build_decals(self)
		var v = load("res://scripts/devview.gd").new(); add_child(v); v.setup(args); return
	Sfx.set_volume(Settings.vol, Settings.music)
	await Mats.build_decals(self)
	get_window().title = "Carcaça — Circuito Fornalha"
	hangar = Hangar.new(); add_child(hangar); hangar.setup()
	canvas = CanvasLayer.new(); add_child(canvas)
	hud = HUD.new(); canvas.add_child(hud)
	ui = UI.new(); canvas.add_child(ui); ui.setup(self)
	apply_quality()
	hangar.cam.current = true
	if args.has("sim"): _run_sims(); return
	if args.has("shots"): _run_shots(); return
	ui.go("title")

func apply_quality() -> void:
	Settings.apply_viewport(get_viewport())
	if OS.get_name() == "Web": get_viewport().scaling_3d_scale = 1.0 if Settings.quality >= 2 else (0.85 if Settings.quality == 1 else 0.7)

func _input(e: InputEvent) -> void:
	Ctl.on_event(e)
	if match_node != null:
		if e is InputEventKey and e.pressed and not e.echo and (e.physical_keycode == KEY_ESCAPE or e.physical_keycode == KEY_P):
			if match_node.paused: resume()
			else: pause()
			get_viewport().set_input_as_handled()
		elif e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_START:
			if match_node.paused: resume()
			else: pause()
		elif e is InputEventMouseButton and e.pressed and not match_node.paused and match_node.state != "perk" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Ctl.capture(true)

func _unhandled_input(e: InputEvent) -> void:
	if match_node != null or hangar == null: return
	if e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT: hangar.drag(e.relative.x, e.relative.y)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: hangar.zoom(-1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: hangar.zoom(1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and match_node != null: pause()

func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	if match_node != null:
		if match_node.state == "fight" and not match_node.paused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and match_node.auto == null and _had_capture: pause()
		_had_capture = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		match_node.step(dt)
		if pending_end != null: var f = pending_end; pending_end = null; f.call()
	elif hangar: hangar.tick(dt)
	Ctl.frame()
var _had_capture := false

# ───────── fluxo ─────────
func start_match(cfg: Dictionary) -> void:
	if not Stats.compute(Save.data.build).valid and not cfg.has("playerBuild"):
		Sfx.play("error"); ui.toast("Montagem irregular: corrija na garagem antes de sair."); return
	last_cfg = cfg; ui.hide_ui(); Sfx.play("ok")
	var full := cfg.duplicate()
	full.playerBuild = cfg.get("playerBuild", Save.data.build).duplicate(true)
	full.onEnd = func(res): pending_end = func(): finish_match(cfg, res)
	hangar.visible = false; hangar.process_mode = Node.PROCESS_MODE_DISABLED
	match_node = Match.new(self, full); add_child(match_node); match_node.start()
	if not cfg.has("autopilot"): Ctl.capture(true)
	_had_capture = false

func pause() -> void:
	var m := match_node
	if m == null or m.paused or m.state in ["perk", "over", "done"]: return
	m.paused = true; Sfx.set_boost(0); Ctl.capture(false); ui.show_pause(m)

func resume() -> void:
	if match_node == null: return
	ui.close_overlay(); match_node.paused = false; Ctl.capture(true); _had_capture = false

func abandon() -> void:
	var m := match_node
	if m == null: return
	ui.close_overlay(); m.paused = false; m.win = false; m.state = "done"; m.end()

func finish_match(cfg: Dictionary, res: Dictionary) -> void:
	var s: Dictionary = Save.data; var before := D.tier_for_rank(Save.player_rank()); var reward := 0.0; var note := ""; var headline := ""; var subline := ""; var record := false; var won: bool = res.win
	match cfg.kind:
		"league":
			var v: Dictionary = cfg.rival
			if res.win:
				var first: bool = not (v.rank in s.beaten); reward = v.prize if first else v.prize * 0.25; note = "prêmio da posição" if first else "revanche paga 25%"
				if first: s.beaten.append(v.rank)
				headline = ("Campeã do Circuito" if v.rank == 1 else "%dº lugar conquistado" % v.rank) if first else "Revanche vencida"; subline = "%s está fora de combate." % v.call; s.wins += 1
			else: headline = "Carcaça perdida"; subline = "%s mantém a posição. A seguradora cobre o conserto." % v.call; s.losses += 1
		"contract":
			var c: Dictionary = cfg.contract
			if res.win: reward = c.pay; headline = "Contrato cumprido"; s.wins += 1
			else: reward = c.pay * 0.1; note = "taxa de comparecimento"; headline = "Contrato perdido"; s.losses += 1
			s.contractSeed = int(s.contractSeed) + 1
		"endless":
			reward = res.earned; won = res.wave > 1; headline = ("Caiu na onda %d" % res.wave) if res.wave > 1 else "Caiu na primeira onda"; subline = "Os créditos das ondas limpas são seus."
			if res.wave - 1 > s.bestWave: s.bestWave = res.wave - 1
			if res.score > s.bestScore: s.bestScore = res.score; record = true
		_: headline = "Alvo destruído" if res.win else "Teste encerrado"; subline = "Sem recompensa no campo de testes."
	s.credits += roundi(reward); Save.persist()
	var after := D.tier_for_rank(Save.player_rank())
	match_node.dispose(); match_node = null; Ctl.capture(false); ui.close_overlay()
	hangar.visible = true; hangar.process_mode = Node.PROCESS_MODE_INHERIT; hangar.cam.current = true; Sfx.set_music(0)
	var r := res.duplicate(); r.merge({ "win": won, "title": cfg.title, "headline": headline, "subline": subline, "reward": roundi(reward), "rewardNote": note, "record": record, "unlock": D.TIERCLS[after] if after > before else "",
		"retry": cfg.kind == "endless" or cfg.kind == "test" or (cfg.kind == "league" and not res.win) }, true)
	ui.go("results", r)

# ───────── testes automáticos (somente com argumentos de linha de comando) ─────────
func _run_sims() -> void:
	var list := []
	var which: String = args.get("sim", "1")
	for rk in [18, 10, 6, 1]:
		var v: Dictionary = D.rival(rk)
		list.append({ "kind": "test", "title": "espelho " + v.call, "arena": v.arena, "seed": rk, "mods": {}, "playerBuild": v.build, "autopilot": { "skill": 0.85, "agg": v.ai.agg, "air": v.ai.air }, "enemies": [{ "build": v.build, "call": v.call, "name": v.mech, "ai": { "skill": 0.85, "agg": v.ai.agg, "air": v.ai.air }, "hpMul": v.get("hpMul", 1.0) }], "max": 150 })
	Save.data.contractSeed = 1234; var cs := ui.gen_contracts()
	for c in cs: list.append({ "kind": "test", "title": "contrato " + c.type + " " + ",".join(c.mods.keys()), "arena": c.arena, "seed": c.seed, "mods": c.mods.duplicate(), "enemies": c.enemies, "allies": c.allies, "sequence": c.sequence, "playerBuild": D.RIVALS[8].build, "autopilot": { "skill": 0.7, "agg": 0.6, "air": 0.3 }, "max": 200 })
	for a in ["doca", "boreal"]: list.append({ "kind": "test", "endless": true, "title": "infinito " + a, "arena": a, "seed": 77, "mods": {}, "enemies": [], "playerBuild": D.RIVALS[9].build, "autopilot": { "skill": 0.8, "agg": 0.6, "air": 0.3 }, "max": 300 })
	if which != "1": list = list.filter(func(c): return which in c.title)
	for cfg in list:
		var t0 := Time.get_ticks_msec()
		start_match(cfg)
		var m := match_node; var n := 0; var maxn := int(cfg.max * 30)
		while match_node == m and n < maxn:
			m.step(1.0 / 30.0)
			if pending_end != null: var f = pending_end; pending_end = null; f.call(); break
			n += 1
		var line := "%s t=%.0f venceu=%s ms=%d" % [cfg.title, m.time, str(m.win) if m.state in ["done", "over"] else "-", Time.get_ticks_msec() - t0]
		if match_node == m:
			line += " jog=%d%% inim=%s onda=%d" % [roundi(m.player.st / m.player.st_max * 100), str(m.world.mechs.slice(1).map(func(x): return roundi(x.st / x.st_max * 100))), m.wave]
			match_node.dispose(); match_node = null
		printerr(line)
	get_tree().quit()

func _run_shots() -> void:
	var out: String = args.get("out", "/tmp")
	var shoot := func(name: String):
		for i in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png"); printerr("shot ", name)
	var which: String = args.get("shots", "1")
	if which == "1" or "menu" in which:
		ui.go("title"); await shoot.call("g_title")
		ui.go("menu"); await shoot.call("g_menu")
		ui.go("garage"); await shoot.call("g_garage")
		ui.sel.cat = "back"; ui.sel.item = "hb_bc3"; ui.go("shop"); await shoot.call("g_shop")
		ui.go("league"); await shoot.call("g_league")
		ui.go("contracts"); await shoot.call("g_contracts")
	if which == "1" or "fight" in which:
		var rv: Dictionary = D.rival(int(args.get("rival", 1)))
		start_match({ "kind": "test", "title": "CIRCUITO · %dº LUGAR" % rv.rank, "arena": args.get("arena", rv.arena), "seed": 5, "mods": {}, "playerBuild": D.rival(int(args.get("me", 4))).build, "autopilot": { "skill": 0.9, "agg": 0.8, "air": 0.3 }, "enemies": [{ "build": rv.build, "call": rv.call, "name": rv.mech, "ai": rv.ai }] })
		var m := match_node
		for i in int(float(args.get("secs", 9)) * 30): m.step(1.0 / 30.0)
		m.paused = true
		await shoot.call("g_fight_" + str(args.get("arena", rv.arena)))
	get_tree().quit()
