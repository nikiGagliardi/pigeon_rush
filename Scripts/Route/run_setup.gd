class_name RunSetup
extends RefCounted
## Come parte una partita: modalità, seed e tratta di partenza.
## Normale: seed casuale; le prime partite da Roveredo (tratte corte, primo cartello presto), poi da una tratta
## a caso dell'anello, così si vedono anche Zurigo, il Walensee e il San Bernardino.
## Sfida giornaliera: seed e tratta di partenza uguali per tutti in quel giorno (UTC), così percorso e meteo
## sono gli stessi per ogni giocatore.

enum Mode { NORMAL, DAILY }

## Le prime partite normali partono sempre da Roveredo, mentre si imparano i comandi.
const HOME_START_RUNS := 3

var mode: Mode = Mode.NORMAL
var seed: int = 0
var start_segment: int = 0
## Solo per la sfida giornaliera: "2026-11-18".
var daily_date: String = ""


## runs_played: partite normali già finite (SaveData.runs_played).
static func normal(runs_played: int = HOME_START_RUNS) -> RunSetup:
	var setup := RunSetup.new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	setup.seed = rng.randi()
	if runs_played >= HOME_START_RUNS:
		var starts := RouteData.normal_starts()
		setup.start_segment = starts[rng.randi_range(0, starts.size() - 1)]
	return setup


static func daily(date: String = "") -> RunSetup:
	var setup := RunSetup.new()
	setup.mode = Mode.DAILY
	setup.daily_date = date if not date.is_empty() else today_utc()
	setup.seed = daily_seed(setup.daily_date)
	setup.start_segment = posmod(setup.seed, RouteData.count())
	return setup


## Data del giorno in UTC, uguale per tutti i fusi orari (il giorno nuovo parte all'1 di notte in Svizzera, alle 2 con l'ora legale).
static func today_utc() -> String:
	return Time.get_date_string_from_system(true)


## Seed stabile per una data. In Fase 5 lo darà il server con il ticket della partita.
static func daily_seed(date: String) -> int:
	return absi(("pigeon-rush/daily/" + date).hash())


## "Try again": la normale riparte con un seed e una partenza nuovi, la giornaliera ripete la stessa sfida.
func retry(runs_played: int) -> RunSetup:
	if mode == Mode.DAILY:
		return RunSetup.daily(daily_date)
	return RunSetup.normal(runs_played)


func is_daily() -> bool:
	return mode == Mode.DAILY
