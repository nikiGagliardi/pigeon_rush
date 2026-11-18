class_name RouteTracker
extends RefCounted
## Segue la partita sull'anello: tratta attuale, avanzamento, giro.
## Fornisce anche i seed derivati (per tratta e per giro) usati dal traffico e dal meteo:
## stessa partita = stessa sequenza, e una differenza in una tratta non si trascina nelle successive.

signal segment_entered(index: int, lap: int)

const LAP_SCORE_BONUS := 0.25 # moltiplicatore dei punti distanza: ×1, ×1.25, ×1.5…

enum Stream { STRUCTURES, ROWS, PICKUPS, LANES, WEATHER }

var run_seed: int = 0
var start_segment: int = 0
var segment_index: int = 0
var lap: int = 1
## Tratte completate in questa partita.
var segments_completed: int = 0

var _segment_start_distance: float = 0.0
var _distance: float = 0.0


func _init(p_seed: int = 0, p_start_segment: int = 0) -> void:
	run_seed = p_seed
	start_segment = posmod(p_start_segment, RouteData.count())
	segment_index = start_segment


var segment: RouteSegment:
	get:
		return RouteData.get_segment(segment_index)


## 0..1 dentro la tratta attuale.
var progress: float:
	get:
		return clampf((_distance - _segment_start_distance) / segment.length, 0.0, 1.0)


## Metri che mancano alla fine della tratta attuale.
var distance_to_end: float:
	get:
		return segment.length - (_distance - _segment_start_distance)


var lap_multiplier: float:
	get:
		return 1.0 + LAP_SCORE_BONUS * (lap - 1)


## Meteo della tratta attuale (per la Fase 4): casuale dal seed, quindi uguale per tutti nella sfida giornaliera.
var weather: String:
	get:
		return weather_for(run_seed, segment_index, lap)


## Avanza con i metri percorsi dalla partenza; emette segment_entered per ogni tratta nuova.
func update(distance: float) -> void:
	_distance = distance
	while _distance - _segment_start_distance >= segment.length:
		_segment_start_distance += segment.length
		segments_completed += 1
		segment_index += 1
		if segment_index >= RouteData.count():
			segment_index = 0
		# il giro cambia ripassando dal punto di partenza (Roveredo nelle partite normali)
		if segment_index == start_segment:
			lap += 1
		segment_entered.emit(segment_index, lap)


func next_segment_index() -> int:
	return posmod(segment_index + 1, RouteData.count())


func next_lap() -> int:
	return lap + 1 if next_segment_index() == start_segment else lap


## Titolo di cartello e banner: "LAP 2" ripassando dalla partenza, il cantone se cambia, altrimenti la zona.
func title_for(index: int, p_lap: int) -> String:
	var seg := RouteData.get_segment(index)
	if index == start_segment and p_lap > 1:
		return "LAP %d" % p_lap
	if enters_canton(index):
		return seg.canton.to_upper()
	return seg.region.to_upper()


static func enters_canton(index: int) -> bool:
	return RouteData.get_segment(index - 1).canton != RouteData.get_segment(index).canton


## "Lap 1 · Leventina 62%": fin dove si è arrivati (game over e, in Fase 5, classifica).
func reached_label() -> String:
	return "Lap %d · %s %d%%" % [lap, segment.region, roundi(progress * 100.0)]


func stream_seed(stream: Stream) -> int:
	return derived_seed(run_seed, stream, segment_index, lap)


static func derived_seed(p_seed: int, stream: Stream, index: int, p_lap: int) -> int:
	return hash([p_seed, int(stream), index, p_lap])


static func weather_for(p_seed: int, index: int, p_lap: int) -> String:
	var options := RouteData.get_segment(index).weathers
	var rng := RandomNumberGenerator.new()
	rng.seed = derived_seed(p_seed, Stream.WEATHER, index, p_lap)
	return options[rng.randi_range(0, options.size() - 1)]


## Verifica usata dalla prova automatica. Restituisce l'elenco degli errori.
static func self_check() -> PackedStringArray:
	var errors := PackedStringArray()
	var total := RouteData.total_length()
	if absf(total - 13200.0) > 1.0:
		errors.append("anello lungo %.0f m invece di 13200" % total)

	var entered: Array[int] = []
	var tracker := RouteTracker.new(123, 0)
	tracker.segment_entered.connect(func(index: int, _lap: int) -> void: entered.append(index))
	tracker.update(799.0)
	if tracker.segment_index != 0 or not entered.is_empty():
		errors.append("tratta cambiata prima della fine")
	tracker.update(800.0)
	if tracker.segment_index != 1 or entered.size() != 1 or entered[0] != 1:
		errors.append("ingresso nella seconda tratta non segnalato")
	tracker.update(total + 10.0)
	if tracker.lap != 2 or tracker.segment_index != 0 or tracker.segments_completed != RouteData.count():
		errors.append("giro non completato correttamente (giro %d, tratta %d)" % [tracker.lap, tracker.segment_index])

	# partenza a metà anello: il giro cambia ripassando dalla tratta di partenza, non da Roveredo
	var daily := RouteTracker.new(5, 5)
	daily.update(total - 1.0)
	if daily.lap != 1 or daily.segment_index != 4:
		errors.append("sfida giornaliera: giro cambiato troppo presto")
	daily.update(total + 1.0)
	if daily.lap != 2 or daily.segment_index != 5:
		errors.append("sfida giornaliera: giro non cambiato alla tratta di partenza")

	var a := RunSetup.daily("2026-11-18")
	var b := RunSetup.daily("2026-11-18")
	var c := RunSetup.daily("2026-11-19")
	if a.seed != b.seed or a.start_segment != b.start_segment:
		errors.append("sfida giornaliera diversa con la stessa data")
	if a.seed == c.seed:
		errors.append("sfida giornaliera uguale in due giorni diversi")
	if weather_for(a.seed, 2, 1) != weather_for(b.seed, 2, 1):
		errors.append("meteo diverso con lo stesso seed")
	return errors
