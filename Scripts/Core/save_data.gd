class_name SaveData
extends RefCounted
## Record persistente in user:// (funziona uguale su PC e mobile).

const FILE_PATH := "user://pigeon_rush.cfg"
const SECTION := "records"
const BEST_KEY := "best_score"


static func load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(FILE_PATH) != OK:
		return 0
	var best: int = cfg.get_value(SECTION, BEST_KEY, 0)
	return best


static func save_best(score: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE_PATH) # se non esiste parte vuoto
	cfg.set_value(SECTION, BEST_KEY, score)
	cfg.save(FILE_PATH)
