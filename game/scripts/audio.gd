## Áudio 100% sintetizado: efeitos (gerados na primeira vez que tocam), laço do propulsor e trilha generativa.
extends Node

const SR := 22050
var cache := {}
var last := {}
var pool3d: Array = []
var pool2d: Array = []
var i3 := 0
var i2 := 0
var listener_pos := Vector3.ZERO
var boost_player: AudioStreamPlayer
var music_level := 0.0
var music_on := false
var step := 0
var next_t := 0.0
var clock := 0.0
var warm_queue: Array = []
var bus_sfx := 0
var bus_mus := 0

const RATE := { "hit": 0.04, "flame": 0.09, "saw": 0.08, "pulse": 0.05, "smg": 0.045, "gatling": 0.04, "step": 0.12, "explosion": 0.05, "hover": 0.03, "rifle": 0.05, "missile": 0.06, "laser": 0.04, "hitself": 0.06, "shieldhit": 0.06 }

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.add_bus(); bus_sfx = AudioServer.bus_count - 1; AudioServer.set_bus_name(bus_sfx, "SFX"); AudioServer.set_bus_send(bus_sfx, "Master")
	AudioServer.add_bus(); bus_mus = AudioServer.bus_count - 1; AudioServer.set_bus_name(bus_mus, "Music"); AudioServer.set_bus_send(bus_mus, "Master")
	var comp := AudioEffectCompressor.new(); comp.threshold = -14; comp.ratio = 6; comp.attack_us = 3000; comp.release_ms = 180
	AudioServer.add_bus_effect(0, comp)
	var lim := AudioEffectLimiter.new(); AudioServer.add_bus_effect(0, lim)
	for i in 20:
		var p := AudioStreamPlayer3D.new(); p.bus = "SFX"; p.unit_size = 34.0; p.max_distance = 600.0; p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE; p.panning_strength = 0.9
		add_child(p); pool3d.append(p)
	for i in 10:
		var p := AudioStreamPlayer.new(); p.bus = "SFX"; add_child(p); pool2d.append(p)
	set_volume(Settings.vol, Settings.music)
	warm_queue = ["ui", "hover", "ok", "rifle", "hit", "hitself", "qb", "step", "explosion", "missile", "lock", "alert", "count", "go", "jump", "land", "pistol", "shotgun", "laser", "swing", "meleehit", "stagger", "break", "warn", "equip", "buy", "error", "repair", "charge", "heavy", "smg", "gatling", "plasma", "pulse", "flame", "bigexplosion", "clank", "hook", "shield", "shieldhit", "emp", "flare", "rail", "arc", "saw", "biglaser", "win", "lose"]

func set_volume(v: float, m: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_volume_db(bus_mus, linear_to_db(maxf(m * 0.55, 0.0001)))

# ───────── síntese ─────────
class Buf:
	var d: PackedFloat32Array
	func _init(dur: float) -> void: d = PackedFloat32Array(); d.resize(int(dur * 22050) + 8)

static func _wave(kind: int, ph: float) -> float:
	match kind:
		0: return sin(ph * TAU)
		1: return 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		2: return fmod(ph, 1.0) * 2.0 - 1.0
		_: var f := fmod(ph, 1.0); return 4.0 * f - 1.0 if f < 0.5 else 3.0 - 4.0 * f

const W := { "sine": 0, "square": 1, "sawtooth": 2, "triangle": 3 }
static func tone(b: Buf, t0: float, dur: float, f0: float, f1: float, vol: float, type := "sine", attack := 0.002) -> void:
	var k := W[type] as int; var s0 := int(t0 * SR); var n := int(dur * SR); var ph := 0.0
	var lr := log(maxf(f1, 20.0) / f0)
	var dec := log(0.001)
	for i in n:
		var tt := float(i) / n
		var f := f0 * exp(lr * tt)
		ph += f / SR
		var env := (float(i) / (attack * SR)) * vol if i < attack * SR else vol * exp(dec * (float(i) - attack * SR) / maxf(1.0, n - attack * SR))
		var idx := s0 + i
		if idx < b.d.size(): b.d[idx] += _wave(k, ph) * env

static func noise(b: Buf, t0: float, dur: float, f0: float, f1: float, q: float, vol: float, type := "bandpass") -> void:
	var s0 := int(t0 * SR); var n := int(dur * SR)
	var lr := log(maxf(f1, 30.0) / f0); var dec := log(0.001)
	var x1 := 0.0; var x2 := 0.0; var y1 := 0.0; var y2 := 0.0
	var b0 := 0.0; var b1 := 0.0; var b2 := 0.0; var a1 := 0.0; var a2 := 0.0
	for i in n:
		if i % 32 == 0:
			var f := clampf(f0 * exp(lr * float(i) / n), 30.0, SR * 0.45)
			var w0 := TAU * f / SR; var alpha := sin(w0) / (2.0 * maxf(q, 0.05)); var cs := cos(w0); var a0 := 1.0 + alpha
			if type == "lowpass": b0 = (1.0 - cs) / 2.0 / a0; b1 = (1.0 - cs) / a0; b2 = b0
			else: b0 = alpha / a0; b1 = 0.0; b2 = -alpha / a0
			a1 = -2.0 * cs / a0; a2 = (1.0 - alpha) / a0
		var x := randf() * 2.0 - 1.0
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = x; y2 = y1; y1 = y
		var idx := s0 + i
		if idx < b.d.size(): b.d[idx] += y * vol * exp(dec * float(i) / n) * (2.0 if type != "lowpass" else 1.0)

static func to_stream(b: Buf, gain := 0.5, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray(); bytes.resize(b.d.size() * 2)
	for i in b.d.size():
		bytes.encode_s16(i * 2, int(clampf(b.d[i] * gain, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new(); s.format = AudioStreamWAV.FORMAT_16_BITS; s.mix_rate = SR; s.stereo = false; s.data = bytes
	if loop: s.loop_mode = AudioStreamWAV.LOOP_FORWARD; s.loop_end = b.d.size()
	return s

## Receitas (portadas da versão web).
func make(name: String) -> AudioStreamWAV:
	var b: Buf
	match name:
		"rifle": b = Buf.new(0.15); noise(b, 0, 0.12, 2400, 500, 0.8, 0.9); tone(b, 0, 0.09, 190, 60, 0.7, "square")
		"smg": b = Buf.new(0.09); noise(b, 0, 0.07, 3200, 900, 0.9, 0.7); tone(b, 0, 0.05, 260, 90, 0.4, "square")
		"shotgun": b = Buf.new(0.3); noise(b, 0, 0.26, 1500, 220, 0.6, 1.2); tone(b, 0, 0.2, 120, 40, 0.9, "sawtooth")
		"pistol": b = Buf.new(0.2); noise(b, 0, 0.18, 1800, 300, 0.8, 1.0); tone(b, 0, 0.16, 150, 45, 0.9, "square")
		"heavy": b = Buf.new(0.55); noise(b, 0, 0.5, 900, 90, 0.5, 1.4, "lowpass"); tone(b, 0, 0.45, 90, 28, 1.2, "sawtooth"); noise(b, 0, 0.08, 4000, 1200, 1, 0.6)
		"gatling": b = Buf.new(0.07); noise(b, 0, 0.06, 2000, 700, 1.2, 0.8); tone(b, 0, 0.05, 140, 70, 0.6, "sawtooth")
		"laser": b = Buf.new(0.25); tone(b, 0, 0.22, 1900, 300, 0.5, "sawtooth"); tone(b, 0, 0.22, 2850, 460, 0.25, "square"); noise(b, 0, 0.12, 6000, 2000, 2, 0.25)
		"biglaser": b = Buf.new(0.95); tone(b, 0, 0.9, 900, 70, 0.9, "sawtooth"); tone(b, 0, 0.9, 1360, 110, 0.5, "square"); noise(b, 0, 0.8, 3000, 200, 0.7, 0.8)
		"pulse": b = Buf.new(0.08); tone(b, 0, 0.07, 1400, 700, 0.35, "square"); noise(b, 0, 0.05, 5000, 3000, 3, 0.2)
		"plasma": b = Buf.new(0.42); tone(b, 0, 0.4, 320, 80, 0.7, "sawtooth"); noise(b, 0, 0.4, 800, 200, 1.5, 0.7); tone(b, 0, 0.3, 1100, 500, 0.2)
		"arc": b = Buf.new(0.25)
		"rail": b = Buf.new(0.55); tone(b, 0, 0.35, 3200, 120, 0.7, "sawtooth"); noise(b, 0, 0.5, 6000, 300, 0.6, 1.1); tone(b, 0, 0.5, 70, 30, 1.0)
		"missile": b = Buf.new(0.62); noise(b, 0, 0.6, 500, 2600, 1.2, 0.55); tone(b, 0, 0.3, 140, 300, 0.3, "sawtooth", 0.05)
		"explosion": b = Buf.new(0.75); noise(b, 0, 0.7, 700, 50, 0.4, 1.5, "lowpass"); tone(b, 0, 0.55, 75, 24, 1.3); noise(b, 0, 0.15, 3000, 600, 0.7, 0.6)
		"bigexplosion": b = Buf.new(1.65); noise(b, 0, 1.6, 500, 30, 0.4, 2.0, "lowpass"); tone(b, 0, 1.3, 60, 18, 1.8); noise(b, 0, 0.3, 2400, 300, 0.6, 1.0); noise(b, 0.25, 1.2, 240, 40, 0.5, 0.9, "lowpass")
		"hit": b = Buf.new(0.08); noise(b, 0, 0.06, 3600, 1500, 2.5, 0.5); tone(b, 0, 0.07, 1100, 320, 0.22, "triangle")
		"hitself": b = Buf.new(0.13); noise(b, 0, 0.12, 900, 200, 1, 0.9); tone(b, 0, 0.12, 180, 60, 0.7, "square")
		"qb": b = Buf.new(0.4); noise(b, 0, 0.38, 300, 4200, 0.9, 0.9); noise(b, 0, 0.3, 2000, 300, 0.6, 0.5, "lowpass")
		"jump": b = Buf.new(0.32); noise(b, 0, 0.3, 400, 1600, 0.8, 0.5)
		"step": b = Buf.new(0.15); noise(b, 0, 0.14, 260, 60, 0.6, 0.9, "lowpass"); tone(b, 0, 0.1, 70, 35, 0.6)
		"land": b = Buf.new(0.32); noise(b, 0, 0.3, 400, 50, 0.5, 1.2, "lowpass"); tone(b, 0, 0.22, 60, 26, 1.0)
		"lock": b = Buf.new(0.15); tone(b, 0, 0.05, 1500, 1500, 0.22, "square"); tone(b, 0.07, 0.07, 2000, 2000, 0.22, "square")
		"alert": b = Buf.new(0.26); tone(b, 0, 0.1, 880, 880, 0.3, "square"); tone(b, 0.14, 0.1, 880, 880, 0.3, "square")
		"warn": b = Buf.new(0.17); tone(b, 0, 0.16, 520, 400, 0.35, "sawtooth")
		"ui": b = Buf.new(0.04); tone(b, 0, 0.035, 1250, 900, 0.16, "square")
		"hover": b = Buf.new(0.025); tone(b, 0, 0.02, 2100, 2100, 0.05)
		"ok": b = Buf.new(0.18); tone(b, 0, 0.06, 660, 660, 0.2, "square"); tone(b, 0.07, 0.1, 990, 990, 0.2, "square")
		"buy": b = Buf.new(0.27); tone(b, 0, 0.05, 1200, 1200, 0.2, "triangle"); tone(b, 0.06, 0.05, 1500, 1500, 0.2, "triangle"); tone(b, 0.12, 0.14, 2000, 2000, 0.2, "triangle"); noise(b, 0, 0.2, 5000, 4000, 4, 0.12)
		"error": b = Buf.new(0.33); tone(b, 0, 0.14, 160, 130, 0.35, "sawtooth"); tone(b, 0.16, 0.16, 130, 110, 0.35, "sawtooth")
		"equip": b = Buf.new(0.18); noise(b, 0, 0.09, 1200, 300, 1, 0.5); tone(b, 0.05, 0.1, 220, 110, 0.4, "square"); noise(b, 0.12, 0.05, 4000, 2500, 3, 0.25)
		"charge": b = Buf.new(0.92); tone(b, 0, 0.9, 220, 1700, 0.22, "sawtooth", 0.4)
		"swing": b = Buf.new(0.23); noise(b, 0, 0.22, 600, 5000, 1.4, 0.8); tone(b, 0, 0.2, 900, 240, 0.3, "sawtooth")
		"meleehit": b = Buf.new(0.32); noise(b, 0, 0.3, 2400, 150, 0.6, 1.5); tone(b, 0, 0.3, 140, 34, 1.2, "square"); tone(b, 0, 0.2, 1600, 400, 0.4, "triangle")
		"stagger": b = Buf.new(0.52); tone(b, 0, 0.5, 1300, 120, 0.5, "sawtooth"); noise(b, 0, 0.4, 3000, 200, 1, 0.9); tone(b, 0, 0.4, 80, 40, 0.9)
		"break": b = Buf.new(0.47); noise(b, 0, 0.4, 2600, 120, 0.7, 1.3); tone(b, 0, 0.3, 480, 70, 0.6, "square"); tone(b, 0.05, 0.4, 1900, 500, 0.3, "triangle")
		"repair": b = Buf.new(0.52); tone(b, 0, 0.5, 300, 900, 0.3, "sine", 0.1); noise(b, 0, 0.5, 2000, 6000, 3, 0.2)
		"hook": b = Buf.new(0.27); noise(b, 0, 0.2, 3000, 800, 2, 0.6); tone(b, 0, 0.25, 600, 1500, 0.25, "sawtooth")
		"clank": b = Buf.new(0.18); tone(b, 0, 0.16, 1100, 500, 0.4, "triangle"); noise(b, 0, 0.1, 2500, 800, 2, 0.6)
		"shield": b = Buf.new(0.32); tone(b, 0, 0.3, 500, 1100, 0.3, "sine", 0.05); tone(b, 0, 0.3, 755, 1650, 0.15, "sine", 0.05)
		"shieldhit": b = Buf.new(0.15); tone(b, 0, 0.14, 2200, 900, 0.3); noise(b, 0, 0.08, 6000, 3000, 3, 0.3)
		"emp": b = Buf.new(0.62); tone(b, 0, 0.6, 2400, 60, 0.6, "sawtooth"); noise(b, 0, 0.6, 5000, 100, 0.8, 1.0)
		"flare": b = Buf.new(0.32); noise(b, 0, 0.3, 2500, 5000, 1.5, 0.5)
		"count": b = Buf.new(0.14); tone(b, 0, 0.12, 440, 440, 0.3, "square")
		"go": b = Buf.new(0.52); tone(b, 0, 0.5, 880, 880, 0.35, "square"); tone(b, 0, 0.5, 1320, 1320, 0.2, "square")
		"win": b = Buf.new(0.95)
		"lose": b = Buf.new(1.4)
		"flame": b = Buf.new(0.15); noise(b, 0, 0.14, 700, 1400, 0.5, 0.5)
		"saw": b = Buf.new(0.13); tone(b, 0, 0.12, 150, 120, 0.4, "sawtooth"); noise(b, 0, 0.1, 3500, 2500, 2, 0.35)
		_: b = Buf.new(0.05)
	if name == "arc":
		for i in 5: noise(b, i * 0.035, 0.04, 5000 - i * 500, 1500, 3, 0.7)
		tone(b, 0, 0.2, 100, 50, 0.6, "sawtooth")
	elif name == "win":
		var fs := [392, 494, 587, 784]
		for i in 4: tone(b, i * 0.13, 0.5, fs[i], fs[i], 0.25, "triangle", 0.01)
	elif name == "lose":
		var fs := [392, 349, 294, 196]
		for i in 4: tone(b, i * 0.2, 0.7, fs[i], fs[i] * 0.97, 0.25, "sawtooth", 0.02)
	return to_stream(b, 0.42)

func get_stream(name: String) -> AudioStreamWAV:
	if not cache.has(name): cache[name] = make(name)
	return cache[name]

## Toca um efeito; pos = posição no mundo (null = sem espacialização).
func play(name: String, pos = null, vol := 1.0) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if t - last.get(name, -1.0) < RATE.get(name, 0.02): return
	last[name] = t
	var s := get_stream(name)
	if pos == null:
		var p: AudioStreamPlayer = pool2d[i2]; i2 = (i2 + 1) % pool2d.size()
		p.stream = s; p.volume_db = linear_to_db(maxf(vol, 0.001)) - 4.0; p.play()
	else:
		if (pos as Vector3).distance_to(listener_pos) > 600: return
		var p: AudioStreamPlayer3D = pool3d[i3]; i3 = (i3 + 1) % pool3d.size()
		p.stream = s; p.global_position = pos; p.volume_db = linear_to_db(maxf(vol, 0.001)) + 2.0; p.play()

func set_listener(pos: Vector3) -> void: listener_pos = pos

# ───────── laço do propulsor ─────────
func set_boost(level: float) -> void:
	if boost_player == null:
		var b := Buf.new(2.0); noise(b, 0, 2.0, 380, 380, 0.7, 0.9)
		for i in b.d.size(): b.d[i] = b.d[i] / 0.001 * 0.0 + b.d[i] # mantém (envelope plano abaixo)
		var bb := Buf.new(2.0)
		var x1 := 0.0; var y1 := 0.0
		for i in bb.d.size():
			var x := randf() * 2.0 - 1.0; y1 = y1 + 0.12 * (x - y1); bb.d[i] = y1 * 2.2
		# cruzamento suave no ponto do laço
		for i in 400:
			var k := i / 400.0; bb.d[i] = bb.d[i] * k + bb.d[bb.d.size() - 400 + i] * (1.0 - k)
		boost_player = AudioStreamPlayer.new(); boost_player.bus = "SFX"; boost_player.stream = to_stream(bb, 0.6, true); boost_player.volume_db = -80; add_child(boost_player); boost_player.play()
	var target := linear_to_db(clampf(level * 0.32, 0.0001, 0.5))
	boost_player.volume_db = lerpf(boost_player.volume_db, target, 0.15)
	boost_player.pitch_scale = lerpf(boost_player.pitch_scale, 0.7 + level * 0.9, 0.1)

# ───────── trilha generativa ─────────
var mus_players: Array = []
var mi := 0
const SCALE := [73.42, 87.31, 98.0, 110.0, 130.81, 146.83]
const BASS := [0, 0, 3, 0, 0, 5, 3, 1, 0, 0, 3, 0, 4, 3, 1, 2]

func set_music(level: float) -> void: music_level = level; music_on = true

func _mus_stream(name: String) -> AudioStreamWAV:
	if cache.has("m_" + name): return cache["m_" + name]
	var b: Buf
	if name == "kick": b = Buf.new(0.25); tone(b, 0, 0.22, 110, 34, 0.9); noise(b, 0, 0.03, 2500, 800, 1, 0.2)
	elif name == "snare": b = Buf.new(0.16); noise(b, 0, 0.14, 1900, 900, 1.2, 0.4)
	elif name == "hat": b = Buf.new(0.04); noise(b, 0, 0.03, 8000, 6000, 3, 0.14)
	elif name == "drone":
		b = Buf.new(4.0)
		var ph1 := 0.0; var ph2 := 0.0; var y := 0.0
		for i in b.d.size():
			ph1 += 36.71 / SR; ph2 += 36.95 / SR
			var x := (_wave(2, ph1) + _wave(2, ph2)) * 0.5; y += 0.05 * (x - y); b.d[i] = y * 1.2
		for i in 800:
			var k := i / 800.0; b.d[i] = b.d[i] * k + b.d[b.d.size() - 800 + i] * (1.0 - k)
		var s := to_stream(b, 0.5, true); cache["m_drone"] = s; return s
	elif name.begins_with("bass"):
		var f: float = SCALE[int(name.substr(4))]
		b = Buf.new(0.2)
		var ph := 0.0; var y := 0.0
		for i in b.d.size():
			ph += f / SR; var tt := float(i) / b.d.size(); var cut := 0.25 * exp(-tt * 3.0) + 0.03
			y += cut * (_wave(2, ph) - y); b.d[i] = y * 0.42 * exp(log(0.002) * tt)
	elif name.begins_with("pad"):
		b = Buf.new(4.8)
		var fs := [146.83, 220.0, 261.63 if name == "pad2" else 293.66]
		for f in fs:
			var ph := 0.0
			for i in b.d.size():
				ph += f / SR; var tt := float(i) / b.d.size()
				b.d[i] += _wave(3, ph) * 0.09 * minf(1.0, tt * 4.0) * (1.0 - tt)
	elif name == "bell": b = Buf.new(1.4); tone(b, 0, 1.4, 587.0, 587.0, 0.05, "sine", 0.3)
	else: b = Buf.new(0.1)
	var st := to_stream(b, 0.5); cache["m_" + name] = st; return st

func _mplay(name: String, vol := 1.0) -> void:
	if mus_players.is_empty():
		for i in 12:
			var p := AudioStreamPlayer.new(); p.bus = "Music"; add_child(p); mus_players.append(p)
	var p: AudioStreamPlayer = mus_players[mi]; mi = (mi + 1) % mus_players.size()
	p.stream = _mus_stream(name); p.volume_db = linear_to_db(maxf(vol, 0.001)); p.play()

var drone_player: AudioStreamPlayer
func _process(dt: float) -> void:
	# pré-gera sons aos poucos para não engasgar na primeira vez
	if not warm_queue.is_empty():
		get_stream(warm_queue.pop_front())
	if not music_on: return
	if drone_player == null:
		drone_player = AudioStreamPlayer.new(); drone_player.bus = "Music"; drone_player.stream = _mus_stream("drone"); drone_player.volume_db = -8; add_child(drone_player); drone_player.play()
	clock += dt
	var spb := 60.0 / 104.0 / 4.0
	while next_t <= clock:
		var s := step % 64; var b := step % 16; var I := music_level
		if I > 0.5:
			if b % 4 == 0: _mplay("kick", 0.9)
			if b % 8 == 4: _mplay("snare", 0.8)
			if b % 2 == 1: _mplay("hat", 0.7 + (0.4 if b % 4 == 3 else 0.0))
			if b % 2 == 0 or b == 7 or b == 15: _mplay("bass%d" % BASS[(s >> 1) % 16], 1.0)
			if I > 0.8 and s % 32 == 12: _mplay("bell", 1.0)
		if s % 32 == 0: _mplay("pad2" if s == 32 else "pad", 0.7 + I * 0.3)
		if I <= 0.5 and s % 16 == 8 and randf() < 0.6: _mplay("bell", 0.6)
		next_t += spb; step += 1
