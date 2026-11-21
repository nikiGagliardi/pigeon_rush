class_name SaveData
extends RefCounted
## Salvataggio locale in JSON con numero di versione (funziona uguale su PC e mobile).
## Scrittura su file temporaneo + rinomina: un'uscita a metà non corrompe il salvataggio.
## Al primo avvio importa il record dal vecchio file .cfg.

const VERSION := 2
const FILE_PATH := "user://save.json"
const TEMP_PATH := "user://save.json.tmp"
const LEGACY_PATH := "user://pigeon_rush.cfg"

var best_score: int = 0
var best_distance: int = 0
var runs_played: int = 0

# sfida giornaliera: si tiene solo il giorno attuale
var daily_date: String = ""
var daily_best: int = 0

# impostazioni
var sfx_volume: float = 1.0
var vibration: bool = true

# suggerimenti delle prime partite già mostrati (vedi TutorialHints)
var hints_seen: PackedStringArray = PackedStringArray()

## Cosa indossa il piccione (negozio). Si controlla contro gli oggetti posseduti (GameServicesClient.owned_items)
## prima di usarlo: un oggetto non posseduto torna al valore gratuito.
var bird_look: BirdLook = BirdLook.new()


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


## Aggiorna i record con la partita normale appena finita. Restituisce true se il punteggio è un nuovo record.
func record_run(score: int, distance: int) -> bool:
	runs_played += 1
	best_distance = maxi(best_distance, distance)
	if score <= best_score:
		return false
	best_score = score
	return true


## Sfida giornaliera: record separato, valido solo per quella data. Restituisce true se è il nuovo record del giorno.
func record_daily(date: String, score: int) -> bool:
	runs_played += 1
	if date != daily_date:
		daily_date = date
		daily_best = 0
	if score <= daily_best:
		return false
	daily_best = score
	return true


func daily_best_for(date: String) -> int:
	return daily_best if date == daily_date else 0


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"best_score": best_score,
		"best_distance": best_distance,
		"runs_played": runs_played,
		"daily": {
			"date": daily_date,
			"best": daily_best,
		},
		"settings": {
			"sfx_volume": sfx_volume,
			"vibration": vibration,
		},
		"tutorial": {
			"seen": Array(hints_seen),
		},
		"bird": bird_look.to_dict(),
	}


static func from_dict(d: Dictionary) -> SaveData:
	d = _migrate(d)
	var data := SaveData.new()
	data.best_score = maxi(0, _int(d, "best_score", 0))
	data.best_distance = maxi(0, _int(d, "best_distance", 0))
	data.runs_played = maxi(0, _int(d, "runs_played", 0))

	var raw_daily: Variant = d.get("daily", {})
	if raw_daily is Dictionary:
		var daily := raw_daily as Dictionary
		var date: Variant = daily.get("date", "")
		data.daily_date = date as String if date is String else ""
		data.daily_best = maxi(0, _int(daily, "best", 0))

	var raw_settings: Variant = d.get("settings", {})
	if raw_settings is Dictionary:
		var settings := raw_settings as Dictionary
		data.sfx_volume = clampf(_float(settings, "sfx_volume", 1.0), 0.0, 1.0)
		data.vibration = _bool(settings, "vibration", true)

	# "tutorial" manca nei salvataggi più vecchi: tutti i suggerimenti ancora da mostrare
	var raw_tutorial: Variant = d.get("tutorial", {})
	if raw_tutorial is Dictionary:
		var seen: Variant = (raw_tutorial as Dictionary).get("seen", [])
		if seen is Array:
			for id: Variant in seen as Array:
				if id is String and not data.hints_seen.has(id as String):
					data.hints_seen.append(id as String)

	# "bird" manca nei salvataggi più vecchi: piccione classico
	var raw_bird: Variant = d.get("bird", {})
	if raw_bird is Dictionary:
		data.bird_look = BirdLook.from_dict(raw_bird as Dictionary)
	return data


## Porta un salvataggio vecchio alla versione attuale (un passo per versione).
static func _migrate(d: Dictionary) -> Dictionary:
	var version := _int(d, "version", 0)
	if version > VERSION:
		push_warning("SaveData: versione %d più recente del gioco (%d), letta come %d" % [version, VERSION, VERSION])
	# v1 → v2: aggiunta la sfida giornaliera ("daily"); i valori mancanti valgono 0, niente da convertire
	if version < 2 and not d.has("daily"):
		d["daily"] = { "date": "", "best": 0 }
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
