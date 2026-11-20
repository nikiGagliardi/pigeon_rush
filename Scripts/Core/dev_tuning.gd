class_name DevTuning
extends RefCounted
## Parametri di sviluppo per tarare la difficoltà provando sul telefono (Settings → DEVELOPER).
## Il pannello è sempre visibile nelle build di debug; in quelle di rilascio (test interno su Play) si sblocca
## toccando 7 volte la versione in fondo alle impostazioni. Salvati in user://dev_tuning.json, separati dai
## salvataggi del gioco. Con valori diversi da quelli di default le partite non vanno in classifica.

const FILE_PATH := "user://dev_tuning.json"
const DEFAULT_RAMP_KM := 12.0
const DEFAULT_CURVE := 0.8
const DEFAULT_MIN_DIFFICULTY := 0.0
const DEFAULT_TRAFFIC := 1.0

## Metri a cui la difficoltà arriva al massimo.
static var ramp_km: float = DEFAULT_RAMP_KM
## Esponente della curva: < 1 cresce in fretta all'inizio e poi rallenta, > 1 il contrario.
static var curve: float = DEFAULT_CURVE
## Difficoltà già alla partenza (0..1).
static var min_difficulty: float = DEFAULT_MIN_DIFFICULTY
## Moltiplica la densità delle file di traffico di tutte le tratte.
static var traffic: float = DEFAULT_TRAFFIC
## Riga in alto a sinistra con difficoltà, traffico e tratta durante la partita.
static var show_overlay: bool = false
## Pannello sbloccato nelle build di rilascio.
static var unlocked: bool = false

static var _loaded: bool = false


## 0..1 ai metri percorsi: minimo + (1 - minimo) × (metri / rampa)^curva.
static func difficulty_at(distance: float) -> float:
	_ensure_loaded()
	var x := clampf(distance / (ramp_km * 1000.0), 0.0, 1.0)
	return lerpf(min_difficulty, 1.0, pow(x, curve))


static func traffic_multiplier() -> float:
	_ensure_loaded()
	return traffic


static func panel_available() -> bool:
	_ensure_loaded()
	return OS.is_debug_build() or unlocked


static func is_default() -> bool:
	_ensure_loaded()
	return is_equal_approx(ramp_km, DEFAULT_RAMP_KM) and is_equal_approx(curve, DEFAULT_CURVE) \
		and is_equal_approx(min_difficulty, DEFAULT_MIN_DIFFICULTY) and is_equal_approx(traffic, DEFAULT_TRAFFIC)


## Prova automatica: sempre i valori di default, qualunque cosa ci sia nel file.
static func use_defaults() -> void:
	_loaded = true
	ramp_km = DEFAULT_RAMP_KM
	curve = DEFAULT_CURVE
	min_difficulty = DEFAULT_MIN_DIFFICULTY
	traffic = DEFAULT_TRAFFIC
	show_overlay = false


static func reset() -> void:
	ramp_km = DEFAULT_RAMP_KM
	curve = DEFAULT_CURVE
	min_difficulty = DEFAULT_MIN_DIFFICULTY
	traffic = DEFAULT_TRAFFIC
	save()


## "1 km 14%  •  4 km 42%  •  6 km 57%  •  12 km 100%": anteprima della curva nel pannello.
static func preview() -> String:
	var parts := PackedStringArray()
	for km: float in [1.0, 4.0, 6.0, 9.0, 12.0]:
		parts.append("%d km %d%%" % [int(km), roundi(difficulty_at(km * 1000.0) * 100.0)])
	return "  •  ".join(parts)


static func save() -> void:
	var file := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"ramp_km": ramp_km, "curve": curve, "min_difficulty": min_difficulty, "traffic": traffic,
		"show_overlay": show_overlay, "unlocked": unlocked,
	}, "\t"))


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(FILE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE_PATH))
	if not parsed is Dictionary:
		return
	var d := parsed as Dictionary
	ramp_km = clampf(_num(d, "ramp_km", DEFAULT_RAMP_KM), 2.0, 30.0)
	curve = clampf(_num(d, "curve", DEFAULT_CURVE), 0.3, 2.0)
	min_difficulty = clampf(_num(d, "min_difficulty", DEFAULT_MIN_DIFFICULTY), 0.0, 0.9)
	traffic = clampf(_num(d, "traffic", DEFAULT_TRAFFIC), 0.3, 2.0)
	show_overlay = d.get("show_overlay", false) == true
	unlocked = d.get("unlocked", false) == true


static func _num(d: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = d.get(key, fallback)
	if value is float or value is int:
		return float(value)
	return fallback
