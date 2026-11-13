## Hangar: cenário dos menus, garagem e vitrine da loja.
class_name Hangar extends Node3D

var cam: Camera3D
var pivot: Node3D
var model = null
var part_node: Node3D = null
var yaw := 0.6
var pitch := 0.12
var dist := 34.0
var t_dist := 34.0
var focus_y := 5.2
var shift := 0.0
var t_shift := 0.0
var idle := 0.0
var swing := 0.0
var dragging := false
var env: Environment

func setup() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color("#0b0c0d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color("#646a72"); env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_AGX; env.tonemap_exposure = 1.15
	env.glow_enabled = true; env.glow_intensity = 0.5; env.glow_hdr_threshold = 1.2; env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true; env.fog_light_color = Color("#0b0c0d"); env.fog_density = 0.008
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.adjustment_enabled = true; env.adjustment_contrast = 1.08
	env.set_meta("vfog", 0.006); env.set_meta("vfog_col", Color("#8a8a8a"))
	Settings.apply_env(env)
	var mat := ShaderMaterial.new(); mat.shader = Arena.env_shader; mat.set_shader_parameter("noise_tex", Mats.noise); mat.set_shader_parameter("lamp_col", Color("#fff2dc"))
	var n := Geo.N.new("hangar"); n.slots = Arena.ENV_SLOTS; n.div = 32.0
	n.put("dark", Geo.bx(160, 1, 160, 0.05), Vector3(0, -0.5, 0))
	n.put("dark", Geo.cyl(9.5, 9.8, 0.5, 40), Vector3(0, 0.25, 0)); n.put("hz", Geo.cyl(10.4, 10.6, 0.3, 40), Vector3(0, 0.15, 0))
	n.put("dark", Geo.bx(160, 60, 2, 0.05), Vector3(0, 30, -34))
	for i in range(-5, 6):
		n.put("stl", Geo.bx(1.6, 60, 2.4, 0.1), Vector3(i * 14, 30, -32.5)); n.put("lamp", Geo.bx(0.4, 22, 0.3, 0.02), Vector3(i * 14 + 7, 20, -32.8))
	for k in 4: n.put("stl", Geo.bx(160, 1.2, 2.6, 0.1), Vector3(0, 8 + k * 12, -32.4))
	for s in [-1.0, 1.0]:
		n.put("stl", Geo.bx(2, 26, 2, 0.15), Vector3(s * 15, 13, -12)); n.put("stl", Geo.bx(2, 26, 2, 0.15), Vector3(s * 15, 13, -22)); n.put("stl", Geo.bx(2.4, 1.6, 14, 0.1), Vector3(s * 15, 24, -17)); n.put("hz", Geo.bx(2.6, 0.8, 14.2, 0.05), Vector3(s * 15, 12, -17))
		n.put("stl", Geo.bx(8, 1, 1.4, 0.1), Vector3(s * 11, 16, -12)); n.put("dark", Geo.bx(2.4, 2.4, 2.4, 0.2), Vector3(s * 7.6, 15.4, -12)); n.put("lampw", Geo.bx(0.5, 0.5, 0.5, 0.05), Vector3(s * 15, 26.6, -12))
		n.put("dark", Geo.bx(6, 5, 9, 0.2), Vector3(s * 26, 2.5, -22)); n.put("dark", Geo.bx(5, 3, 5, 0.2), Vector3(s * 25, 6.5, -23)); n.put("hz", Geo.bx(6.2, 0.6, 9.2, 0.05), Vector3(s * 26, 0.5, -22))
		n.put("k%d" % (3 if s > 0 else 1), Geo.bx(13, 5.3, 5.2, 0.12), Vector3(s * 34, 2.65, -6), Vector3(0, s * 0.3, 0))
	n.put("stl", Geo.bx(34, 1.6, 2, 0.1), Vector3(0, 27, -12)); n.put("lamp", Geo.bx(12, 0.3, 1.2, 0.02), Vector3(0, 25.9, -12))
	add_child(n.bake(mat))
	var key := DirectionalLight3D.new(); key.light_color = Color("#fff0dc"); key.light_energy = 1.1; key.shadow_enabled = true; key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL; key.directional_shadow_max_distance = 80; key.shadow_bias = 0.06; key.shadow_normal_bias = 2.0
	add_child(key); key.look_at_from_position(Vector3(14, 30, 22), Vector3.ZERO)
	var rim := DirectionalLight3D.new(); rim.light_color = Color("#f2a22c"); rim.light_energy = 0.5; add_child(rim); rim.look_at_from_position(Vector3(-20, 12, -20), Vector3.ZERO)
	var fill := DirectionalLight3D.new(); fill.light_color = Color("#8796ad"); fill.light_energy = 0.3; add_child(fill); fill.look_at_from_position(Vector3(-16, 8, 20), Vector3.ZERO)
	var spot := SpotLight3D.new(); spot.light_color = Color("#ffeed6"); spot.light_energy = 5.0; spot.spot_range = 48; spot.spot_angle = 26; spot.spot_angle_attenuation = 1.4; spot.shadow_enabled = true; spot.shadow_bias = 0.04; spot.light_volumetric_fog_energy = 1.2; add_child(spot)
	var probe := ReflectionProbe.new(); probe.size = Vector3(90, 50, 70); probe.position = Vector3(0, 12, -2); probe.interior = true; probe.box_projection = true; probe.update_mode = ReflectionProbe.UPDATE_ONCE; probe.intensity = 0.8; add_child(probe); spot.look_at_from_position(Vector3(0, 26, -12), Vector3(0, 0, 0))
	pivot = Node3D.new(); add_child(pivot)
	# ambiente na própria câmera: não disputa com o WorldEnvironment da arena durante as lutas
	cam = Camera3D.new(); cam.fov = 32; cam.near = 0.5; cam.far = 400; cam.environment = env; add_child(cam)

func clear() -> void:
	if model: model.root.queue_free(); model = null
	if part_node: part_node.queue_free(); part_node = null

func show_mech(build: Dictionary) -> void:
	clear()
	model = Builder.build_mech(build); pivot.add_child(model.root); model.root.position = Vector3(0, 0.5, 0)
	focus_y = model.height * 0.52 + 0.5; t_dist = 31 + model.radius * 1.4

func show_part(id: String, paint: Dictionary) -> void:
	clear()
	var g := Builder.build_part_preview(id, paint)
	var holder := Node3D.new(); holder.add_child(g); pivot.add_child(holder)
	var aabb := AABB(); var first := true
	for mi in g.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = mi.transform * mi.get_aabb()
		var par: Node = mi.get_parent()
		while par != g and par != null: bb = (par as Node3D).transform * bb; par = par.get_parent()
		aabb = bb if first else aabb.merge(bb); first = false
	g.position = -aabb.get_center(); holder.scale = Vector3.ONE * 9.0 / maxf(0.5, maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)))
	holder.position.y = 6.5; part_node = holder; focus_y = 6.5; t_dist = 30

func view(s: float, d := 0.0) -> void:
	t_shift = s
	if d > 0: t_dist = d

func drag(dx: float, dy: float) -> void:
	yaw -= dx * 0.006; pitch = clampf(pitch + dy * 0.004, -0.15, 0.9); idle = 0

func zoom(z: int) -> void: t_dist = clampf(t_dist + z * 3, 16, 60)

func tick(dt: float) -> void:
	idle += dt
	if idle > 2.5:
		swing += dt; yaw += (0.45 + sin(swing * 0.22) * 0.85 - yaw) * minf(1.0, dt * 0.8)
	yaw = clampf(yaw, -2.2, 2.2)
	dist = lerpf(dist, t_dist, minf(1.0, 5 * dt)); shift = lerpf(shift, t_shift, minf(1.0, 5 * dt))
	var cp := cos(pitch)
	cam.position = Vector3(sin(yaw) * cp * dist, focus_y + sin(pitch) * dist, cos(yaw) * cp * dist)
	cam.look_at(Vector3(0, focus_y, 0))
	var aspect := get_viewport().get_visible_rect().size.aspect()
	cam.h_offset = -shift * 2.0 * dist * tan(deg_to_rad(cam.fov) / 2.0) * aspect
	if model:
		for f in model.flames: f.m.visible = false
