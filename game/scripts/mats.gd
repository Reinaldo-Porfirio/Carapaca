## Recursos compartilhados: textura de ruído, atlas de decalques, shaders, malha de chama, fontes e tema.
class_name Mats

static var noise: ImageTexture
static var decal_tex: Texture2D
static var mech_shader: Shader = preload("res://shaders/mech.gdshader")
static var flame_shader: Shader = preload("res://shaders/flame.gdshader")
static var _flame_mesh: ArrayMesh
static var fonts := {}
static var theme: Theme
static var ready := false

static func init_base() -> void:
	if noise: return
	# três camadas de ruído (grosso, médio, fino) empacotadas nos canais R, G e B
	var S := 256
	var imgs := []
	var cfg := [[FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 5, 11], [FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.035, 3, 23], [FastNoiseLite.TYPE_SIMPLEX, 0.06, 4, 37]]
	for c in cfg:
		var fn := FastNoiseLite.new(); fn.noise_type = c[0]; fn.frequency = c[1]; fn.fractal_octaves = c[2]; fn.seed = c[3]
		var im: Image = fn.get_seamless_image(S, S, false, false, 0.1, true)
		im.convert(Image.FORMAT_L8); imgs.append(im.get_data())
	var out := PackedByteArray(); out.resize(S * S * 3)
	var r: PackedByteArray = imgs[0]; var g: PackedByteArray = imgs[1]; var b: PackedByteArray = imgs[2]
	for i in S * S:
		out[i * 3] = r[i]; out[i * 3 + 1] = g[i]; out[i * 3 + 2] = b[i]
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGB8, out)
	img.generate_mipmaps()
	noise = ImageTexture.create_from_image(img)
	var blank := Image.create(4, 4, false, Image.FORMAT_RGBA8); blank.fill(Color(0, 0, 0, 0))
	decal_tex = ImageTexture.create_from_image(blank)
	_load_fonts()

static func _load_fonts() -> void:
	for k in ["SairaCondensed-Medium", "SairaCondensed-SemiBold", "SairaCondensed-Bold", "SairaCondensed-ExtraBold", "IBMPlexMono-Regular", "IBMPlexMono-Medium"]:
		var f = load("res://fonts/%s.ttf" % k)
		if f: fonts[k] = f
	fonts.disp = fonts.get("SairaCondensed-SemiBold", ThemeDB.fallback_font)
	fonts.bold = fonts.get("SairaCondensed-Bold", fonts.disp)
	fonts.black = fonts.get("SairaCondensed-ExtraBold", fonts.bold)
	fonts.med = fonts.get("SairaCondensed-Medium", fonts.disp)
	fonts.mono = fonts.get("IBMPlexMono-Medium", ThemeDB.fallback_font)
	fonts.mono_r = fonts.get("IBMPlexMono-Regular", fonts.mono)

static func lum(c: Color) -> float: return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

static func mech_material(paint: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = mech_shader
	var a := Color(paint.get("a", "#8a8f86"))
	m.set_shader_parameter("paint_a", a)
	m.set_shader_parameter("paint_b", Color(paint.get("b", "#c9541e")))
	m.set_shader_parameter("paint_c", Color(paint.get("c", "#2b2e30")))
	m.set_shader_parameter("glow", Color(paint.get("glow", "#ff9a3c")))
	m.set_shader_parameter("wear", float(paint.get("wear", 0.5)))
	m.set_shader_parameter("decal_ink", Color("#1a1b1d") if lum(a) > 0.32 else Color("#e8e4d8"))
	m.set_shader_parameter("noise_tex", noise)
	m.set_shader_parameter("decal_tex", decal_tex)
	return m

static func flame_material(col: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = flame_shader
	m.set_shader_parameter("col", col)
	return m

## Cone aberto com a base na origem, apontando para -Z (comprimento 1).
static func flame_mesh() -> ArrayMesh:
	if _flame_mesh: return _flame_mesh
	var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.5; cm.height = 1.0; cm.radial_segments = 12; cm.rings = 1; cm.cap_top = false; cm.cap_bottom = false
	var arr := cm.get_mesh_arrays()
	var xf := Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0))
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i in vs.size(): vs[i] = xf * vs[i]; ns[i] = xf.basis * ns[i]
	arr[Mesh.ARRAY_VERTEX] = vs; arr[Mesh.ARRAY_NORMAL] = ns; arr[Mesh.ARRAY_TANGENT] = null
	_flame_mesh = ArrayMesh.new(); _flame_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _flame_mesh

## Gera o atlas de decalques desenhando texto num SubViewport (precisa de um quadro renderizado).
static func build_decals(host: Node) -> void:
	if DisplayServer.get_name() == "headless": return
	Geo.dec_layout()
	var vp := SubViewport.new(); vp.size = Vector2i(Geo.DEC_SIZE, Geo.DEC_SIZE); vp.transparent_bg = true; vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cv := DecalCanvas.new(); cv.size = Vector2(Geo.DEC_SIZE, Geo.DEC_SIZE)
	vp.add_child(cv); host.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty(): return
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	decal_tex = t

class DecalCanvas extends Control:
	func _draw() -> void:
		var W := Color(1, 1, 1)
		var stencil: Font = Mats.fonts.get("SairaCondensed-Bold", ThemeDB.fallback_font)
		var thin: Font = Mats.fonts.get("SairaCondensed-SemiBold", stencil)
		var mono: Font = Mats.fonts.get("IBMPlexMono-Medium", stencil)
		var R := func(name) -> Rect2:
			var q: Array = Geo.DEC[name]; return Rect2(q[0] * Geo.DEC_SIZE, q[1] * Geo.DEC_SIZE, (q[2] - q[0]) * Geo.DEC_SIZE, (q[3] - q[1]) * Geo.DEC_SIZE)
		var ctext := func(f: Font, s: String, r: Rect2, size: int, dy := 0.0):
			var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
			draw_string(f, Vector2(r.position.x + (r.size.x - sz.x) / 2, r.position.y + r.size.y / 2 + size * 0.36 + dy), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, W)
		for i in 10:
			var r: Rect2 = R.call("n%d" % i)
			ctext.call(stencil, str(i), r, 118, 4)
			draw_rect(Rect2(r.position.x, r.position.y + r.size.y / 2 - 3, r.size.x, 5), Color(0, 0, 0, 0))
		var logos := { "QF": ["QF", "QUARESMA & FILHOS"], "HB": ["H·B", "HALDANE-BRÄCK"], "TSK": ["燕", "TSUBAME KŌKI"], "MRS": ["MRS", "MERIDIANO S.A."], "NLE": ["NLE", "NORDLYS ENERGI"] }
		var li := 0
		for k in logos:
			var r: Rect2 = R.call("mk" + k)
			draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), W, false, 5)
			ctext.call(stencil, logos[k][0], Rect2(r.position, Vector2(118, r.size.y)), 60, 2)
			draw_rect(Rect2(r.position.x + 118, r.position.y + 16, 4, r.size.y - 32), W)
			draw_string(thin, r.position + Vector2(132, r.size.y / 2 - 4), logos[k][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, W)
			draw_string(mono, r.position + Vector2(132, r.size.y / 2 + 20), "LOTE %d-B" % (4100 + li * 173), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, W)
			li += 1
		var r: Rect2 = R.call("warn")
		draw_polyline(PackedVector2Array([r.position + Vector2(50, 16), r.position + Vector2(90, 96), r.position + Vector2(10, 96), r.position + Vector2(50, 16)]), W, 6)
		ctext.call(stencil, "!", Rect2(r.position + Vector2(30, 40), Vector2(40, 50)), 54)
		draw_string(stencil, r.position + Vector2(106, 46), "PERIGO", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, W)
		draw_string(thin, r.position + Vector2(106, 72), "ALTA TENSÃO · 6,6 kV", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, W)
		draw_string(thin, r.position + Vector2(106, 94), "NÃO ABRIR EM CARGA", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, W)
		r = R.call("step"); draw_rect(Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 6)), W, false, 4); ctext.call(stencil, "NÃO PISE", r, 34)
		r = R.call("arrow")
		for i in 3:
			var o := r.position + Vector2(0, i * 30)
			draw_colored_polygon(PackedVector2Array([o + Vector2(20, 24), o + Vector2(60, 4), o + Vector2(100, 24), o + Vector2(100, 40), o + Vector2(60, 20), o + Vector2(20, 40)]), W)
		r = R.call("bar")
		var rng := RandomNumberGenerator.new(); rng.seed = 4
		var px := 6.0
		while px < 150:
			var bw := rng.randi_range(1, 5); draw_rect(Rect2(r.position.x + px, r.position.y + 6, bw, r.size.y - 12), W); px += bw + rng.randi_range(1, 4)
		draw_string(mono, r.position + Vector2(160, 22), "CF-07731", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, W)
		draw_string(mono, r.position + Vector2(160, 42), "REV. 4", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, W)
		r = R.call("lift"); ctext.call(thin, "PONTO DE IÇAMENTO", Rect2(r.position, Vector2(r.size.x, 30)), 20)
		draw_arc(r.position + Vector2(r.size.x / 2, 42), 11, 0, TAU, 20, W, 3)
		draw_line(r.position + Vector2(r.size.x / 2, 26), r.position + Vector2(r.size.x / 2, 58), W, 3); draw_line(r.position + Vector2(r.size.x / 2 - 16, 42), r.position + Vector2(r.size.x / 2 + 16, 42), W, 3)
		r = R.call("band"); draw_rect(Rect2(r.position.x, r.position.y + 6, r.size.x, 28), W)
		r = R.call("tick")
		for i in 20: draw_rect(Rect2(r.position.x + 6 + i * 12.4, r.position.y + (4 if i % 5 == 0 else 14), 3, 32 if i % 5 == 0 else 18), W)
