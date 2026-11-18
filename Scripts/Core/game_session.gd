class_name GameSession
extends RefCounted
## Stato di una partita, senza dipendenze dai nodi.

var speed := SpeedController.new()
var score := ScoreService.new()
var ammo: int = GameConfig.START_AMMO
var elapsed: float = 0.0
## Regola del gioco: al primo colpo il piccione è spacciato.
var is_over: bool = false

var difficulty: float:
	get:
		return clampf(elapsed / GameConfig.DIFFICULTY_RAMP_TIME, 0.0, 1.0)


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
