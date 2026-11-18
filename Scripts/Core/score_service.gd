class_name ScoreService
extends RefCounted
## Punteggio: distanza × boost × bonus volo radente, colpi con combo, passaggi a filo.
## Tiene anche le statistiche che il server usa per le missioni giornaliere (runs.stats).

var distance: float = 0.0
var combo: int = 0
var hits: int = 0
var near_misses: int = 0
var best_combo: int = 0
var bus_hits: int = 0
var truck_hits: int = 0
## Metri volati di notte.
var night_distance: float = 0.0
var golden_crumbs: int = 0

var score: int:
	get:
		return int(_score)

var combo_multiplier: int:
	get:
		return clampi(combo, 1, GameConfig.MAX_COMBO_MULTIPLIER)

var combo_time_left: float:
	get:
		return _combo_timer / GameConfig.COMBO_WINDOW if combo > 0 else 0.0

var _score: float = 0.0 # float a 64 bit in GDScript
var _combo_timer: float = 0.0


func tick(dt: float, metres: float, speed_multiplier: float, low_flying: bool, night: bool = false) -> void:
	distance += metres
	if night:
		night_distance += metres
	_score += metres * speed_multiplier * (GameConfig.LOW_FLY_BONUS if low_flying else 1.0)
	if combo <= 0:
		return
	_combo_timer -= dt
	if _combo_timer <= 0.0:
		combo = 0


## Restituisce i punti assegnati per il colpo.
func register_hit(base_points: int, kind: VehicleCatalog.Kind = VehicleCatalog.Kind.CAR) -> int:
	if kind == VehicleCatalog.Kind.BUS:
		bus_hits += 1
	elif kind == VehicleCatalog.Kind.TRUCK:
		truck_hits += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	hits += 1
	_combo_timer = GameConfig.COMBO_WINDOW
	var points := base_points * combo_multiplier
	_score += points
	return points


## Restituisce i punti assegnati per il passaggio a filo.
func register_near_miss() -> int:
	near_misses += 1
	if combo > 0:
		_combo_timer = GameConfig.COMBO_WINDOW # un passaggio a filo tiene viva la combo
	var points := GameConfig.NEAR_MISS_POINTS * combo_multiplier
	_score += points
	return points


func register_golden_crumb(points: int) -> void:
	golden_crumbs += 1
	_score += points


func add_points(points: int) -> void:
	_score += points


func break_combo() -> void:
	combo = 0
	_combo_timer = 0.0
