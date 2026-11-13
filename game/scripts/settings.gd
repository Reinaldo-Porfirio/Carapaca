## Preferências de gráficos, áudio e controle (aplicadas ao ambiente, ao sol e à viewport).
class_name Settings

static var quality := 2      # 0 leve · 1 médio · 2 alto
static var sens := 1.0
static var inv_y := false
static var vol := 0.8
static var music := 0.5

static func compat() -> bool: return RenderingServer.get_current_rendering_method() == "gl_compatibility"

static func apply_env(env: Environment) -> void:
	var c := compat()
	env.ssao_enabled = quality >= 1 and not c
	env.ssao_radius = 1.4; env.ssao_intensity = 1.8; env.ssao_power = 1.4; env.ssao_detail = 0.5
	env.ssil_enabled = quality >= 2 and not c
	env.ssil_intensity = 0.7
	env.glow_enabled = quality >= 1
	env.sdfgi_enabled = false
	# névoa volumétrica (raios de luz) só no Alto e no Forward+; a densidade vem de cada cena (meta "vfog")
	var vd: float = env.get_meta("vfog", 0.0)
	env.volumetric_fog_enabled = quality >= 2 and not c and vd > 0.0
	if env.volumetric_fog_enabled:
		env.volumetric_fog_density = vd; env.volumetric_fog_albedo = env.get_meta("vfog_col", Color(0.8, 0.8, 0.8))
		env.volumetric_fog_length = 140.0; env.volumetric_fog_detail_spread = 2.0; env.volumetric_fog_gi_inject = 0.2
		env.volumetric_fog_anisotropy = 0.45; env.volumetric_fog_sky_affect = 0.0
	env.ssr_enabled = quality >= 2 and not c and env.get_meta("ssr", false)
	env.ssr_max_steps = 48; env.ssr_fade_in = 0.15; env.ssr_fade_out = 2.0; env.ssr_depth_tolerance = 0.4

static func apply_sun(sun: DirectionalLight3D) -> void:
	sun.shadow_enabled = quality >= 1 or compat()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality >= 2 else (DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality >= 1 else DirectionalLight3D.SHADOW_ORTHOGONAL)
	sun.directional_shadow_max_distance = 240.0 if quality >= 2 else 160.0
	# cascatas: a primeira bem curta para sombras nítidas nas carcaças perto da câmera
	sun.directional_shadow_split_1 = 0.06; sun.directional_shadow_split_2 = 0.18; sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = quality >= 2
	sun.shadow_normal_bias = 1.6 if quality >= 2 else 2.6

static func apply_viewport(vp: Viewport) -> void:
	var c := compat()
	vp.msaa_3d = Viewport.MSAA_2X if (quality >= 2 or (c and quality >= 1)) else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if (quality < 2 and not c) else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.scaling_3d_scale = 1.0 if quality >= 1 else 0.8
	RenderingServer.directional_shadow_atlas_set_size(4096 if quality >= 2 else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if quality >= 2 else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
