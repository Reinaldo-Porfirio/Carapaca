## Progresso salvo em user:// (arquivo no desktop; IndexedDB na versão web).
class_name Save

const PATH := "user://carcaca_save.json"
static var data := {}

static func fresh() -> Dictionary:
	var owned := {}
	for id in D.STARTER_OWNED: owned[id] = 1
	return { "credits": 30000, "owned": owned, "build": D.STARTER_BUILD.duplicate(true), "beaten": [], "bestWave": 0, "bestScore": 0, "contractSeed": randi() % 1000000, "wins": 0, "losses": 0,
		"settings": { "vol": 0.8, "music": 0.5, "sens": 1.0, "invY": false, "quality": 2 if OS.get_name() != "Web" else 1 } }

static func load_save() -> void:
	data = fresh()
	if FileAccess.file_exists(PATH):
		var j = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if j is Dictionary:
			for k in j: data[k] = j[k]
			var st: Dictionary = fresh().settings; st.merge(j.get("settings", {}), true); data.settings = st
	var b: Dictionary = data.build
	for k in D.BUILD_SLOTS:
		if b.get(k) and not D.PART.has(b[k]): b[k] = D.STARTER_BUILD.get(k)
	b.mods = b.get("mods", []).filter(func(id): return D.PART.has(id))
	if not b.has("paint"): b.paint = D.STARTER_BUILD.paint.duplicate()
	for k in data.owned.keys(): data.owned[k] = int(data.owned[k])
	data.beaten = data.beaten.map(func(x): return int(x))
	_sync()

static func _sync() -> void:
	var s: Dictionary = data.settings
	Settings.vol = s.vol; Settings.music = s.music; Settings.sens = s.sens; Settings.inv_y = s.invY; Settings.quality = int(s.quality)

static func persist() -> void:
	_sync()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data)); f.close()

static func wipe() -> void: data = fresh(); persist()

static func player_rank() -> int:
	if data.beaten.is_empty(): return 19
	return int(data.beaten.min())

static func used_count(build: Dictionary, id: String) -> int:
	var n := 0
	for k in D.BUILD_SLOTS:
		if build.get(k) == id: n += 1
	for mm in build.get("mods", []):
		if mm == id: n += 1
	return n
