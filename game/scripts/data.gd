## Catálogo do jogo (peças, rivais, arenas…) carregado de data.json.
extends Node

var MAKERS: Dictionary
var SLOTS: Array
var CATS: Dictionary
var DT: Dictionary
var LEGTYPE: Dictionary
var PARTS: Array
var PART := {}
var STARTER_BUILD: Dictionary
var STARTER_OWNED: Array
var RIVALS: Array
var CLASS_TIER: Dictionary
var ARENAS: Dictionary
var MODIFIERS: Dictionary
var CONTRACT_TYPES: Dictionary
var PERKS: Array
var CALLSIGNS: Array
var MECHNAMES: Array
const TIERCLS := ["E", "D", "C", "B", "A", "S"]
const BUILD_SLOTS := ["head", "core", "arms", "legs", "gen", "booster", "fcs", "handR", "handL", "backR", "backL", "shoulder", "util"]

func _init() -> void:
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data.json"))
	for k in j: set(k, j[k])
	for p in PARTS:
		if p.has("tier"): p.tier = int(p.tier)
		PART[p.id] = p
	for r in RIVALS: r.rank = int(r.rank)

func tier_for_rank(rank: int) -> int:
	if rank <= 3: return 5
	if rank <= 6: return 4
	if rank <= 10: return 3
	if rank <= 13: return 2
	if rank <= 16: return 1
	return 0

func rival(rank: int) -> Dictionary:
	for r in RIVALS:
		if r.rank == rank: return r
	return {}

func copy_build(b: Dictionary) -> Dictionary: return b.duplicate(true)

## Gerador pseudoaleatório com semente (para contratos e arenas reproduzíveis).
class Rng:
	var r := RandomNumberGenerator.new()
	func _init(s: int = 0) -> void: r.seed = s
	func rf() -> float: return r.randf()
	func rr(a: float, b: float) -> float: return r.randf_range(a, b)
	func ri(a: int, b: int) -> int: return r.randi_range(a, b)
	func pick(a: Array): return a[r.randi_range(0, a.size() - 1)]
	func chance(p: float) -> bool: return r.randf() < p
