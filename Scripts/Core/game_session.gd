class_name GameSession
extends RefCounted
## Stato di una partita, senza dipendenze dai nodi.

var speed := SpeedController.new()
var score := ScoreService.new()
var setup := RunSetup.new()
var route := RouteTracker.new()
var ammo: int = GameConfig.START_AMMO
var elapsed: float = 0.0
## Regola del gioco: al primo colpo il piccione è spacciato.
var is_over: bool = false

## Cresce con i metri percorsi (non col tempo): stessa distanza = stesso percorso, a qualsiasi velocità.
var difficulty: float:
	get:
		return clampf(score.distance / GameConfig.DIFFICULTY_RAMP_DISTANCE, 0.0, 1.0)


func begin(p_setup: RunSetup) -> void:
	setup = p_setup
	route = RouteTracker.new(p_setup.seed, p_setup.start_segment)


func tick(dt: float) -> void:
	elapsed += dt
	speed.tick(dt)


func try_use_ammo() -> bool:
	if ammo <= 0:
		return false
	ammo -= 1
	return true


func add_ammo(amount: int) -> void:
	ammo = mini(GameConfig.MAX_AMMO, ammo + amount)


func crash() -> void:
	is_over = true
	speed.clear_boost()
	score.break_combo()


## Dopo il Continua: punteggio, distanza e velocità di base restano quelli raggiunti.
func revive() -> void:
	is_over = false
	speed.time_scale = 0.0 # riparte da fermo, poi accelera alla fine del countdown
