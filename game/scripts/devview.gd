## (desenvolvimento) Renderiza uma fileira de carcaças e salva PNG.
extends Node3D
var out := ""
var frames := 0
func setup(args: Dictionary) -> void:
	out = args.get("out", "/tmp/view.png")
	if args.get("mode", "") == "timing":
		var t0 := Time.get_ticks_usec(); var cnt := 0
		for r in D.RIVALS:
			var md: Dictionary = Builder.build_mech(r.build); md.root.free(); cnt += 1
		printerr("ms por carcaça: ", (Time.get_ticks_usec() - t0) / 1000.0 / cnt); get_tree().quit(); return
	if args.get("mode", "") == "dump":
		# exporta triângulos de cada peça (para análise de faces sobrepostas/invertidas)
		var f := FileAccess.open(out, FileAccess.WRITE)
		var items := []
		if args.get("what", "") == "assembly":
			# combinações: cada tronco × cada unidade dorsal × cabeças/braços/ombros/utilitários em rodízio
			var by := {}
			for pp in D.PARTS: by[pp.slot] = by.get(pp.slot, []) + [pp.id]
			var base: Dictionary = D.STARTER_BUILD.duplicate(true)
			var i := 0
			for c in by.core:
				for bk in by.back + [null]:
					for h in by.head:
						var b := base.duplicate(true); b.core = c; b.head = h; b.backR = bk; b.backL = bk
						b.arms = by.arms[i % by.arms.size()]; b.shoulder = (by.shoulder + [null])[i % (by.shoulder.size() + 1)]
						b.util = by.util[i % by.util.size()]; b.handR = by.hand[i % by.hand.size()]; b.handL = by.hand[(i * 7 + 3) % by.hand.size()]
						b.mods = [by.mod[i % by.mod.size()], by.mod[(i * 5 + 2) % by.mod.size()]]
						items.append({ "id": "%s|%s|%s|%s|%s|%s|%s" % [c, str(bk), h, b.arms, str(b.shoulder), b.util, ",".join(b.mods)], "b": b }); i += 1
		elif args.get("what", "") == "mechs":
			items.append({ "id": "starter", "b": D.STARTER_BUILD })
			for r in D.RIVALS: items.append({ "id": "rv%d" % r.rank, "b": r.build })
		else:
			for p in D.PARTS: items.append({ "id": p.id })
		for p in items:
			var g: Node3D
			if p.has("b"):
				var md: Dictionary = Builder.build_mech(p.b); g = md.root
				# pose das unidades dorsais: recolhida (repouso) ou apontada para frente (combate)
				for key in ["backR", "backL"]:
					var wn = md.wn.get(key)
					if wn != null and wn.pv != null and not wn.fixed:
						wn.pv.rotation.x = 0.0 if args.get("pose", "stow") == "act" else -(wn.stow if wn.stow else 0.22)
			else: g = Builder.build_part_preview(p.id, D.STARTER_BUILD.paint)
			add_child(g)
			var k := 0
			for mi in g.find_children("*", "MeshInstance3D", true, false):
				var m: Mesh = (mi as MeshInstance3D).mesh
				if m == null or m.get_surface_count() == 0: continue
				var xf: Transform3D = (mi as MeshInstance3D).global_transform
				var arr := m.surface_get_arrays(0)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]; var c = arr[Mesh.ARRAY_COLOR]; var idx = arr[Mesh.ARRAY_INDEX]
				var line := PackedStringArray([p.id, str(k), str(g.get_path_to(mi)).replace(" ", "_")])
				var n: int = idx.size() if idx != null and idx.size() > 0 else v.size()
				for i in n:
					var j: int = idx[i] if idx != null and idx.size() > 0 else i
					var q: Vector3 = xf * v[j]; var sl := -1.0
					if c != null and c.size() > j: sl = c[j].r
					line.append("%.4f,%.4f,%.4f,%.4f" % [q.x, q.y, q.z, sl])
				f.store_line(" ".join(line)); k += 1
			g.queue_free()
		f.close(); printerr("dumped"); get_tree().quit(); return
	if args.get("mode", "") == "arena":
		var ar := Arena.new(); add_child(ar); ar.build(args.get("arena", "coliseu"), int(args.get("seed", 1)))
		var m := Builder.build_mech(D.RIVALS[int(args.get("r", 9))].build); add_child(m.root); m.root.position = ar.spawn_p + Vector3(0, ar.ground_at(ar.spawn_p.x, ar.spawn_p.z), 0)
		var cam := Camera3D.new(); cam.fov = 62; cam.near = 0.5; cam.far = 2400; add_child(cam)
		cam.position = m.root.position + Vector3(4, 10, -22); cam.look_at(m.root.position + Vector3(0, 7, 30))
		Settings.apply_viewport(get_viewport())
		if args.has("seq"):
			seq_n = int(args.seq); seq_cam = cam; seq_step = Vector3(float(args.get("dx", 0.0)), 0, float(args.get("dz", 0.12)))
			if args.has("cy"): cam.position.y = float(args.cy); cam.look_at(m.root.position + Vector3(0, 0, 60))
		return
	var env := WorldEnvironment.new(); var e := Environment.new()
	var sky := Sky.new(); var ps := ProceduralSkyMaterial.new(); ps.sky_top_color = Color("#3a4250"); ps.sky_horizon_color = Color("#8a8f96"); ps.ground_bottom_color = Color("#2a2826"); ps.ground_horizon_color = Color("#6a6a6a"); sky.sky_material = ps
	e.background_mode = Environment.BG_SKY; e.sky = sky; e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES; e.glow_enabled = true; e.ssao_enabled = true
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.light_color = Color("#fff4e0"); sun.light_energy = 2.2; sun.shadow_enabled = args.get("shadow", "1") == "1"; sun.shadow_bias = float(args.get("bias", 0.1)); sun.shadow_normal_bias = float(args.get("nbias", 2.0)); sun.rotation = Vector3(-0.9, 0.6, 0); add_child(sun)
	var fl := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(400, 400); fl.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("#55585c"); fm.roughness = 0.9; fl.material_override = fm; add_child(fl)
	var list := []
	var from := int(args.get("from", 0)); var n := int(args.get("n", 5)); var ang := float(args.get("a", 0.6))
	if args.get("mode", "mechs") == "mechs" or args.get("mode", "") == "custom":
		var all := [D.STARTER_BUILD]
		for r in D.RIVALS: all.append(r.build)
		list = all.slice(from, from + n)
		if args.get("mode", "") == "custom":
			# --set=core:x;backR:y;... sobre a montagem inicial (vários mechas separados por "/")
			list = []
			for spec in String(args.get("set", "")).split("/"):
				var b: Dictionary = D.STARTER_BUILD.duplicate(true)
				for kv in spec.split(";"):
					var pr := kv.split(":")
					if pr.size() == 2: b[pr[0]] = (Array(pr[1].split(",")) if pr[0] == "mods" else (null if pr[1] == "-" else pr[1]))
				list.append(b)
		for i in list.size():
			var m := Builder.build_mech(list[i]); m.mat.set_shader_parameter("debug_mode", int(args.get("dbg", 0))); m.root.position.x = (i - (list.size() - 1) / 2.0) * float(args.get("sp", 11)); m.root.rotation.y = ang; add_child(m.root)
			for key in ["backR", "backL"]:
				var wn = m.wn.get(key)
				if wn != null and wn.pv != null and not wn.fixed: wn.pv.rotation.x = 0.0 if args.get("pose", "stow") == "act" else -(wn.stow if wn.stow else 0.22)
		var cam := Camera3D.new(); cam.fov = 30; cam.near = 0.5; cam.far = 1500; add_child(cam); cam.position = Vector3(float(args.get("cx", 0)), float(args.get("cy", 9)), float(args.get("cz", 10 + list.size() * 7.2))); cam.look_at(Vector3(float(args.get("cx", 0)), float(args.get("ty", 4.6)), 0))
	else:
		var cat: String = args.get("cat", "hand")
		for p in D.PARTS:
			if p.slot == cat: list.append(p)
		list = list.slice(from, from + n)
		var cols := int(ceil(sqrt(list.size() * 1.8)))
		for i in list.size():
			var g := Builder.build_part_preview(list[i].id, D.STARTER_BUILD.paint)
			var holder := Node3D.new(); holder.add_child(g); add_child(holder)
			var aabb := AABB(); var first := true
			for mi in g.find_children("*", "MeshInstance3D", true, false):
				var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
				aabb = bb if first else aabb.merge(bb); first = false
			g.position = -aabb.get_center(); holder.scale = Vector3.ONE * 6.0 / maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
			holder.position = Vector3((i % cols - (cols - 1) / 2.0) * 9, 4, -floor(i / float(cols)) * 10); holder.rotation.y = ang
		var cam := Camera3D.new(); cam.fov = 30; cam.near = 0.5; cam.far = 1500; add_child(cam); cam.position = Vector3(0, 16, 46); cam.look_at(Vector3(0, 3, -6))
var seq_n := 0
var seq_cam: Camera3D
var seq_step := Vector3.ZERO
func _process(_d: float) -> void:
	frames += 1
	if seq_n > 0:
		if frames >= 6:
			var k := frames - 6
			get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%02d.png" % k))
			if k + 1 >= seq_n: get_tree().quit()
		seq_cam.position += seq_cam.global_transform.basis * seq_step
		return
	if frames == 6:
		get_viewport().get_texture().get_image().save_png(out)
		printerr("saved ", out)
		get_tree().quit()
