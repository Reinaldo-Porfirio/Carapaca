## (desenvolvimento) Renderiza uma fileira de carcaças e salva PNG.
extends Node3D
var out := ""
var frames := 0
func setup(args: Dictionary) -> void:
	out = args.get("out", "/tmp/view.png")
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
	if args.get("mode", "mechs") == "mechs":
		var all := [D.STARTER_BUILD]
		for r in D.RIVALS: all.append(r.build)
		list = all.slice(from, from + n)
		for i in list.size():
			var m := Builder.build_mech(list[i]); m.mat.set_shader_parameter("debug_mode", int(args.get("dbg", 0))); m.root.position.x = (i - (list.size() - 1) / 2.0) * 11; m.root.rotation.y = ang; add_child(m.root)
		var cam := Camera3D.new(); cam.fov = 30; cam.near = 0.5; cam.far = 1500; add_child(cam); cam.position = Vector3(float(args.get("cx", 0)), 9, float(args.get("cz", 10 + list.size() * 7.2))); cam.look_at(Vector3(float(args.get("cx", 0)), 4.6, 0))
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
func _process(_d: float) -> void:
	frames += 1
	if frames == 6:
		get_viewport().get_texture().get_image().save_png(out)
		printerr("saved ", out)
		get_tree().quit()
