class_name SaveData
extends RefCounted
## Salvataggio locale in JSON con numero di versione (funziona uguale su PC e mobile).
## Scrittura su file temporaneo + rinomina: un'uscita a metà non corrompe il salvataggio.
## Al primo avvio importa il record dal vecchio file .cfg.

const VERSION := 1
const FILE_PATH := "user://save.json"
const TEMP_PATH := "user://save.json.tmp"
const LEGACY_PATH := "user://pigeon_rush.cfg"

var best_score: int = 0
var best_distance: int = 0
var runs_played: int = 0

# impostazioni
var sfx_volume: float = 1.0
var vibration: bool = true


static func load_or_default() -> SaveData:
	if FileAccess.file_exists(FILE_PATH):
		var text := FileAccess.get_file_as_string(FILE_PATH)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			return from_dict(parsed as Dictionary)
		push_warning("SaveData: %s illeggibile, si riparte dai valori iniziali" % FILE_PATH)
		return SaveData.new()

	var data := SaveData.new()
	if data._import_legacy():
		data.save()
	return data


func save() -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveData: impossibile scrivere %s (%s)" % [TEMP_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()

	if DirAccess.rename_absolute(TEMP_PATH, FILE_PATH) == OK:
		return true
	# alcuni sistemi non sovrascrivono con la rinomina: si toglie prima il vecchio
	DirAccess.remove_absolute(FILE_PATH)
	return DirAccess.rename_absolute(TEMP_PATH, FILE_PATH) == OK


## Aggiorna i record con la partita appena finita. Restituisce true se il punteggio è un nuovo record.
func record_run(score: int, distance: int) -> bool:
	runs_played += 1
	best_distance = maxi(best_distance, distance)
	if score <= best_score:
		return false
	best_score = score
	return true


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"best_score": best_score,
		"best_distance": best_distance,
		"runs_played": runs_played,
		"settings": {
			"sfx_volume": sfx_volume,
			"vibration": vibration,
		},
	}


static func from_dict(d: Dictionary) -> SaveData:
	d = _migrate(d)
	var data := SaveData.new()
	data.best_score = maxi(0, _int(d, "best_score", 0))
	data.best_distance = maxi(0, _int(d, "best_distance", 0))
	data.runs_played = maxi(0, _int(d, "runs_played", 0))

	var raw_settings: Variant = d.get("settings", {})
	if raw_settings is Dictionary:
		var settings := raw_settings as Dictionary
		data.sfx_volume = clampf(_float(settings, "sfx_volume", 1.0), 0.0, 1.0)
		data.vibration = _bool(settings, "vibration", true)
	return data


## Porta un salvataggio vecchio alla versione attuale (un passo per versione).
static func _migrate(d: Dictionary) -> Dictionary:
	var version := _int(d, "version", 0)
	if version > VERSION:
		push_warning("SaveData: versione %d più recente del gioco (%d), letta come %d" % [version, VERSION, VERSION])
	# esempio per il futuro: if version < 2: d["golden_crumbs"] = 0
	return d


func _import_legacy() -> bool:
	if not FileAccess.file_exists(LEGACY_PATH):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(LEGACY_PATH) != OK:
		return false
	var best: Variant = cfg.get_value("records", "best_score", 0)
	if best is int:
		best_score = maxi(0, best as int)
	return true


# JSON restituisce i numeri come float: conversioni tolleranti con valore di riserva

static func _int(d: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = d.get(key, fallback)
	if value is int:
		return value as int
	if value is float:
		return int(value as float)
	return fallback


static func _float(d: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = d.get(key, fallback)
	if value is float:
		return value as float
	if value is int:
		return float(value as int)
	return fallback


static func _bool(d: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = d.get(key, fallback)
	return value as bool if value is bool else fallback
