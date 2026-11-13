## Regras de montagem: peso, energia, conflitos, atributos derivados e gerador de montagens.
class_name Stats

static func parts_of(b: Dictionary) -> Dictionary:
	var o := {}
	for k in D.BUILD_SLOTS:
		var id = b.get(k)
		o[k] = D.PART.get(id) if id else null
	var mods := []
	for id in b.get("mods", []):
		if D.PART.has(id): mods.append(D.PART[id])
	o.mods = mods
	return o

static func weapon_defs(b: Dictionary) -> Dictionary:
	var p := parts_of(b)
	var wa = D.PART[p.arms.wa] if p.arms and p.arms.kind == "weapon" else null
	return { "handR": wa if wa else p.handR, "handL": wa if wa else p.handL, "backR": p.backR, "backL": p.backL, "shoulder": p.shoulder }

static func compute(b: Dictionary) -> Dictionary:
	var p := parts_of(b)
	var errors := []; var warns := []
	for k in ["head", "core", "arms", "legs", "gen", "fcs"]:
		if p[k] == null: errors.append("Falta %s." % ({"gen": "gerador", "fcs": "FCS"}.get(k, k)))
	if errors.size(): return { "valid": false, "errors": errors, "warns": warns }
	var is_tank: bool = p.legs.type == "tank"
	var bo = p.legs.boost if is_tank else p.booster
	if not is_tank and p.booster == null: errors.append("Sem propulsor instalado.")
	if is_tank and p.booster != null: errors.append("Chassi de esteira já tem propulsor embutido: remova o propulsor externo.")
	var arms_weapon: bool = p.arms.kind == "weapon"
	if arms_weapon and (p.handR or p.handL): errors.append("Braços-arma não têm mãos: remova as armas de mão.")
	var all := []
	for k in D.BUILD_SLOTS:
		if p[k]: all.append(p[k])
	all.append_array(p.mods)
	var bn := { "cap": 0.0, "out": 0.0, "rech": 0.0, "delay": 0.0, "scan": 0.0, "lock": 0.0, "radar": 0.0, "ecm": 0.0, "thrust": 0.0, "qb": 0.0, "qbReload": 0.0, "up": 0.0,
		"armArms": 0.0, "armCore": 0.0, "armLegs": 0.0, "armHead": 0.0, "def": [0.0, 0.0, 0.0], "stab": 0.0, "ammo": 0.0, "kits": 0.0, "kitArmor": 0.0, "heatRes": 0.0, "shockRes": 0.0, "cool": 0.0 }
	for it in all:
		if not it.has("bonus"): continue
		for k in it.bonus:
			if k == "def":
				for i in 3: bn.def[i] += it.bonus.def[i]
			else: bn[k] += it.bonus[k]
	if p.mods.size() > int(p.core.slots): errors.append("O tronco tem %d baias de módulo; há %d instalados." % [int(p.core.slots), p.mods.size()])
	var mounts := {}
	var ids := []
	for m in p.mods:
		if mounts.has(m.mount): errors.append("%s e %s disputam o mesmo ponto de fixação." % [m.name, mounts[m.mount].name])
		mounts[m.mount] = m
		if m.has("notLegs") and p.legs.type in m.notLegs: errors.append("%s não cabe em pernas do tipo %s." % [m.name, str(D.LEGTYPE[p.legs.type]).to_lower()])
		if m.has("notCore") and p.core.cls in m.notCore: errors.append("%s exige tronco médio ou pesado." % m.name)
		if m.has("needHand") and arms_weapon: errors.append("%s só serve em braços com mão." % m.name)
		for c in m.get("conflicts", []):
			for o in p.mods:
				if o.id == c and m.id < c: errors.append("%s interfere com %s." % [m.name, D.PART[c].name])
		ids.append(m.id)
	var seen := {}
	for id in ids:
		if seen.has(id): errors.append("Módulo repetido.")
		seen[id] = 1
	if p.shoulder and p.shoulder.has("noWide"):
		for bk in [p.backR, p.backL]:
			if bk and bk.has("wide"): errors.append("%s interfere com %s (unidade dorsal larga)." % [p.shoulder.name, bk.name])
	var weight := 0.0
	for it in all: weight += it.w
	var leg_load: float = p.legs.load
	var carried: float = weight - p.legs.w
	if carried > leg_load: errors.append("Sobrecarga: as pernas suportam %.1f t e carregam %.1f t." % [leg_load, carried])
	var arm_weight: float = (p.handR.w if p.handR else 0.0) + (p.handL.w if p.handL else 0.0)
	var arm_load: float = p.arms.load
	var arm_over := not arms_weapon and arm_weight > arm_load
	if arm_over: warns.append("Braços sobrecarregados (%.1f/%d t): mira e recuo piores." % [arm_weight, int(arm_load)])
	var en_load := 0.0
	for it in all: en_load += it.get("en", 0)
	var en_out := roundf(p.gen.out * p.core.out + bn.out)
	if en_load > en_out: errors.append("Falta energia: consumo %d EN, saída do gerador %d EN." % [int(en_load), int(en_out)])
	var en_cap: float = p.gen.cap + bn.cap
	var surplus := clampf((en_out - en_load) / en_out, 0.0, 0.6)
	var en_rech: float = p.gen.rech * (1.0 + bn.rech) * (0.8 + surplus * 1.2)
	var en_delay := maxf(0.3, p.gen.delay + bn.delay)
	var part_armor := { "head": p.head.arm + bn.armHead, "core": p.core.arm + bn.armCore, "armR": p.arms.arm + bn.armArms, "armL": p.arms.arm + bn.armArms, "legs": p.legs.arm + bn.armLegs }
	var structure: float = p.head.ap + p.core.ap + p.arms.ap + p.legs.ap
	var dz := func(part): return [part.def[0] + bn.def[0], part.def[1] + bn.def[1], part.def[2] + bn.def[2]]
	var defs := { "head": dz.call(p.head), "core": dz.call(p.core), "armR": dz.call(p.arms), "armL": dz.call(p.arms), "legs": dz.call(p.legs) }
	var def_avg := []
	for i in 3: def_avg.append(roundf(defs.head[i] * 0.1 + defs.core[i] * 0.4 + defs.armR[i] * 0.2 + defs.legs[i] * 0.3))
	var stab: float = p.head.stab + p.core.stab + p.legs.stab + bn.stab
	var load_ratio := carried / leg_load
	var wf := clampf(1.36 - weight / 200.0, 0.55, 1.2) * (0.94 if load_ratio > 0.9 else 1.0)
	var thrust: float = bo.thrust * (1.0 + bn.thrust) if bo else 0.5
	var lock_range: float = p.fcs.range * p.head.scan * (1.0 + bn.scan)
	return {
		"valid": errors.is_empty(), "errors": errors, "warns": warns,
		"weight": weight, "carried": carried, "legLoad": leg_load, "armWeight": arm_weight, "armLoad": arm_load, "armOver": arm_over, "enLoad": en_load, "enOut": en_out, "enCap": en_cap, "enRech": en_rech, "enDelay": en_delay,
		"partArmor": part_armor, "structure": structure, "def": defs, "defAvg": def_avg, "stab": stab,
		"boostSpeed": 36.0 * thrust * wf, "groundSpeed": p.legs.speed * (0.75 + wf * 0.3),
		"qbSpeed": 92.0 * (bo.qb if bo else 0.6) * (1.0 + bn.qb) * (0.7 + 0.3 * wf), "qbCost": bo.qbCost if bo else 700.0, "qbReload": maxf(0.25, (bo.qbReload if bo else 1.2) * (1.0 + bn.qbReload)),
		"upThrust": (bo.up if bo else 0.5) * (1.0 + bn.up) * (0.75 + 0.35 * wf), "abSpeed": 74.0 * (bo.ab if bo else 0.6) * (0.75 + 0.3 * wf), "jump": p.legs.jump * (0.8 + 0.25 * wf),
		"lockRange": lock_range, "lockTime": maxf(0.2, p.fcs.lock * (1.0 + bn.lock)), "radar": p.head.radar + bn.radar, "track": p.arms.track * (0.6 if arm_over else 1.0), "melee": p.arms.melee, "fcs": p.fcs, "eb": p.gen.get("eb", 0.0),
		"kits": 3 + int(bn.kits), "kitArmor": bn.kitArmor, "ammoMul": 1.0 + bn.ammo, "heatRes": bn.heatRes, "shockRes": bn.shockRes, "cool": 1.0 + bn.cool, "ecm": bn.ecm,
		"legType": p.legs.type, "isTank": is_tank, "armsWeapon": arms_weapon, "slots": int(p.core.slots), "cls": p.core.cls,
		"anchorMul": 0.5 if p.legs.id == "hb_l2" else 1.0,
	}

static func weapon_dps(w) -> float:
	if w == null or not w.has("dmg"): return 0.0
	if w.wt == "melee": return w.dmg / w.cd
	if w.wt == "missile": return w.dmg * w.n * w.get("sub", 1) / w.rel
	if w.wt == "drone": return w.dmg * w.n * w.rof * w.life / (w.rel + w.life)
	var per: float = w.dmg * w.get("pel", 1) * w.get("burst", 1)
	if w.get("mag", 0) and w.get("rel", 0):
		var t: float = w.mag / w.rof + w.rel
		return per * w.mag / t
	return per * w.rof

# ───────── gerador de montagens (contratos / modo infinito) ─────────
const ARCH := {
	"striker": { "legs": ["biped", "reverse"], "cls": ["light", "medium"], "hands": ["rifle", "smg", "shotgun", "pistol", "pulse", "melee"], "backs": ["missile"], "agg": 0.8, "air": 0.4 },
	"brawler": { "legs": ["biped", "tank"], "cls": ["medium", "heavy"], "hands": ["shotgun", "flame", "melee", "pistol", "saw", "bazooka"], "backs": ["gatling", "missile"], "agg": 1.0, "air": 0.1 },
	"missile": { "legs": ["quad", "biped", "reverse"], "cls": ["medium"], "hands": ["rifle", "smg"], "backs": ["missile", "missile"], "agg": 0.35, "air": 0.5, "keep": 180 },
	"sniper": { "legs": ["quad", "biped", "reverse"], "cls": ["light", "medium"], "hands": ["brifle", "linear", "laser"], "backs": ["heavy", "missile"], "agg": 0.2, "air": 0.3, "keep": 240 },
	"fortress": { "legs": ["tank", "quad"], "cls": ["heavy", "medium"], "hands": ["bazooka", "rifle", "brifle", "shotgun"], "backs": ["heavy", "gatling", "missile"], "agg": 0.5, "air": 0.0 },
	"energy": { "legs": ["biped", "quad", "reverse"], "cls": ["medium", "light"], "hands": ["laser", "plasma", "pulse", "arc", "melee"], "backs": ["energy", "drone"], "agg": 0.55, "air": 0.45 },
}
const HANDTAG := { "qf_r0": "rifle", "qf_k0": "melee", "tsk_m1": "smg", "qf_f1": "flame", "qf_s2": "shotgun", "hb_h1": "pistol", "hb_r3": "brifle", "tsk_k2": "melee", "qf_g3": "bazooka", "mrs_e2": "shield", "hb_b5": "bazooka", "mrs_p1": "pulse", "qf_x3": "bazooka", "qf_k1": "saw", "nle_l2": "laser", "hb_k4": "melee", "nle_s5": "arc", "nle_p4": "plasma", "mrs_r6": "linear" }
const BACKTAG := { "qf_bm0": "missile", "mrs_bv2": "missile", "mrs_bg3": "none", "hb_bg5": "gatling", "hb_bc3": "heavy", "mrs_bs4": "missile", "tsk_bd3": "drone", "nle_bp5": "energy", "nle_bl4": "energy", "mrs_bc6": "missile", "hb_br6": "heavy", "nle_bb1": "none", "mrs_br2": "none", "tsk_bj4": "none" }
const PAINTS := [
	["#6e7468", "#c9541e", "#22252a", "#ff9a3c"], ["#3a4a57", "#d8d2bd", "#1c2126", "#7fd0ff"], ["#7a2e24", "#d6c9a8", "#1e1b1a", "#ff6a3a"],
	["#c9c4b4", "#30343a", "#24262a", "#ffd27a"], ["#44503a", "#b9a05a", "#1c1f1a", "#d8ff7a"], ["#2b2b30", "#8a8f96", "#141416", "#ff4433"],
	["#8c7a55", "#3b3a36", "#22211f", "#ffb347"], ["#d0cdc2", "#b02a22", "#25272a", "#ff5540"], ["#1f3a4a", "#c8a23a", "#131c22", "#6ff3e0"],
	["#55595e", "#e0b23a", "#1b1c1e", "#ffe08a"], ["#5c3d52", "#cfc8bb", "#1d1a1e", "#ff8ad0"],
]

static func _pool(slot: String, tier: int, f: Callable = Callable()) -> Array:
	var out := []
	for p in D.PARTS:
		if p.slot == slot and p.get("tier", 9) <= tier and (not f.is_valid() or f.call(p)): out.append(p)
	return out

static func _pick_best(rng, arr: Array):
	if arr.is_empty(): return null
	var tot := 0.0
	for p in arr: tot += 1.0 + p.get("tier", 0) * 1.5
	var s = tot * rng.rf()
	for p in arr:
		s -= 1.0 + p.get("tier", 0) * 1.5
		if s <= 0: return p
	return arr[-1]

static func random_build(rng, tier: int, arch_name: String = "") -> Dictionary:
	var A: Dictionary = ARCH.get(arch_name, ARCH[rng.pick(ARCH.keys())])
	for tries in 60:
		var legs = _pick_best(rng, _pool("legs", tier, func(p): return p.type in A.legs))
		if legs == null: legs = _pick_best(rng, _pool("legs", tier))
		var core = _pick_best(rng, _pool("core", tier, func(p): return p.cls in A.cls))
		if core == null: core = _pick_best(rng, _pool("core", tier))
		var arms_all := _pool("arms", tier, func(p): return tries < 30 or p.kind == "hand")
		var arms = _pick_best(rng, arms_all.filter(func(p): return p.kind == "hand")) if rng.chance(0.82) else _pick_best(rng, arms_all)
		var b := { "name": "", "head": _pick_best(rng, _pool("head", tier)).id, "core": core.id, "arms": arms.id, "legs": legs.id, "gen": _pick_best(rng, _pool("gen", tier)).id,
			"booster": null if legs.type == "tank" else _pick_best(rng, _pool("booster", tier)).id, "fcs": _pick_best(rng, _pool("fcs", tier)).id,
			"handR": null, "handL": null, "backR": null, "backL": null, "shoulder": null, "util": null, "mods": [] }
		if arms.kind == "hand":
			var hp := _pool("hand", tier, func(p): return HANDTAG.get(p.id, "") in A.hands)
			var guns := hp.filter(func(p): return p.wt != "melee" and p.wt != "shield")
			b.handR = _pick_best(rng, guns if guns.size() else _pool("hand", tier, func(p): return p.wt == "proj")).id
			if rng.chance(0.85 - tries * 0.01): b.handL = _pick_best(rng, hp if hp.size() else _pool("hand", tier)).id
		var bp := _pool("back", tier, func(p): return BACKTAG.get(p.id, "") in A.backs)
		if bp.size() and rng.chance(0.9 - tries * 0.01): b.backR = _pick_best(rng, bp).id
		if bp.size() and rng.chance(0.6 - tries * 0.01) and tier >= 1: b.backL = _pick_best(rng, bp).id
		if tier >= 1 and rng.chance(0.45):
			var sp := _pool("shoulder", tier, func(p): return not p.has("noWide"))
			if sp.size(): b.shoulder = _pick_best(rng, sp).id
		if tier >= 2 and rng.chance(0.5):
			var up := _pool("util", tier, func(p): return p.act != "hook")
			if up.size(): b.util = _pick_best(rng, up).id
		var mp := _pool("mod", tier, func(p): return not (legs.type in p.get("notLegs", [])) and not (core.cls in p.get("notCore", [])) and not (p.has("needHand") and arms.kind != "hand"))
		var used := {}
		for i in int(core.slots):
			if mp.is_empty() or not rng.chance(0.55): continue
			var m = rng.pick(mp)
			if used.has(m.mount): continue
			var clash := false
			for x in b.mods:
				if m.id in D.PART[x].get("conflicts", []): clash = true
			if clash: continue
			used[m.mount] = 1; b.mods.append(m.id)
		var pc: Array = rng.pick(PAINTS)
		b.paint = { "a": pc[0], "b": pc[1], "c": pc[2], "glow": pc[3], "wear": rng.rr(0.3, 0.9) }
		if compute(b).valid:
			b._ai = { "agg": clampf(A.agg + rng.rr(-0.15, 0.15), 0, 1), "air": clampf(A.air + rng.rr(-0.15, 0.2), 0, 1), "keep": A.get("keep", 0) }
			return b
	return { "name": "", "head": "qf_h0", "core": "qf_c0", "arms": "qf_a0", "legs": "qf_l0", "gen": "qf_g0", "booster": "qf_b0", "fcs": "qf_f0", "handR": "qf_r0", "handL": null, "backR": null, "backL": null, "shoulder": null, "util": null, "mods": [],
		"paint": { "a": "#6e7468", "b": "#c9541e", "c": "#22252a", "glow": "#ff9a3c", "wear": 0.6 }, "_ai": { "agg": 0.5, "air": 0.2, "keep": 0 } }
