class_name TrackConditions
extends RefCounted
## Meteo e ora del giorno di una tratta. Estratti dal seed della partita (per tratta e per giro):
## cambiano da una partita all'altra, ma nella sfida giornaliera sono uguali per tutti.
## La prima tratta della partita è sempre di giorno, così nessuno parte al buio.

const WEATHERS: PackedStringArray = ["sun", "cloudy", "fog", "rain", "snow"]
const TIMES: PackedStringArray = ["day", "sunset", "night"]
## Probabilità di giorno / tramonto / notte (dalla seconda tratta in poi).
const TIME_WEIGHTS: Array[float] = [0.6, 0.2, 0.2]

## Bonus sui punti distanza: meno si vede, più vale.
const WEATHER_MULTIPLIER := { "sun": 1.0, "cloudy": 1.0, "fog": 1.2, "rain": 1.1, "snow": 1.15 }
const TIME_MULTIPLIER := { "day": 1.0, "sunset": 1.0, "night": 1.3 }

var weather: String = "sun"
var time_of_day: String = "day"


static func make(p_weather: String, p_time: String) -> TrackConditions:
	var c := TrackConditions.new()
	c.weather = p_weather if WEATHERS.has(p_weather) else "sun"
	c.time_of_day = p_time if TIMES.has(p_time) else "day"
	return c


## Estrazione dal seed: prima il meteo (tra quelli possibili per la tratta), poi l'ora.
static func roll(p_seed: int, index: int, lap: int, first_of_run: bool) -> TrackConditions:
	var rng := RandomNumberGenerator.new()
	rng.seed = RouteTracker.derived_seed(p_seed, RouteTracker.Stream.WEATHER, index, lap)
	var options := RouteData.get_segment(index).weathers
	var p_weather := options[rng.randi_range(0, options.size() - 1)]
	var r := rng.randf() # estratto sempre, così la prima tratta non sposta le altre
	var p_time := "day"
	if not first_of_run:
		if r < TIME_WEIGHTS[0]:
			p_time = "day"
		elif r < TIME_WEIGHTS[0] + TIME_WEIGHTS[1]:
			p_time = "sunset"
		else:
			p_time = "night"
	return make(p_weather, p_time)


var score_multiplier: float:
	get:
		return (WEATHER_MULTIPLIER[weather] as float) * (TIME_MULTIPLIER[time_of_day] as float)


## "NIGHT ×1.3 · FOG ×1.2" per l'HUD; vuoto se non c'è bonus.
func bonus_label() -> String:
	var parts := PackedStringArray()
	var time_bonus: float = TIME_MULTIPLIER[time_of_day]
	var weather_bonus: float = WEATHER_MULTIPLIER[weather]
	if time_bonus > 1.0:
		parts.append("%s ×%s" % [time_of_day.to_upper(), _format(time_bonus)])
	if weather_bonus > 1.0:
		parts.append("%s ×%s" % [weather.to_upper(), _format(weather_bonus)])
	return "  ·  ".join(parts)


func equals(other: TrackConditions) -> bool:
	return other != null and other.weather == weather and other.time_of_day == time_of_day


func _to_string() -> String:
	return "%s/%s" % [weather, time_of_day]


static func _format(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0")
