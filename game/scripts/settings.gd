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
	env.volumetric_fog_enabled = false

static func apply_sun(sun: DirectionalLight3D) -> void:
	sun.shadow_enabled = quality >= 1 or compat()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality >= 1 else DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 220.0 if quality >= 2 else 160.0

static func apply_viewport(vp: Viewport) -> void:
	var c := compat()
	vp.msaa_3d = Viewport.MSAA_2X if (quality >= 2 or (c and quality >= 1)) else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if (quality < 2 and not c) else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.scaling_3d_scale = 1.0 if quality >= 1 else 0.8
	RenderingServer.directional_shadow_atlas_set_size(4096 if quality >= 2 else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if quality >= 2 else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
