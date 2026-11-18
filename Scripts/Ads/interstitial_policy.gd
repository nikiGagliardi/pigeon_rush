class_name InterstitialPolicy
extends RefCounted
## Quando mostrare la pubblicità a schermo intero, che arriva premendo "Try again".
## Regole: mai nelle prime partite della sessione, una ogni qualche partita,
## un intervallo minimo da qualsiasi altra pubblicità, mai dopo una partita in cui si è guardata quella a premio.
## Il tempo è passato da fuori (secondi), così le regole si provano senza aspettare.

const FREE_RUNS := 3
const RUNS_BETWEEN := 3
const MIN_INTERVAL := 90.0

## Partite concluse in questa sessione dell'app.
var runs_finished: int = 0

var _runs_since_interstitial: int = 0
var _last_full_screen_ad: float = -INF
var _rewarded_this_run: bool = false


func on_run_started() -> void:
	_rewarded_this_run = false


func on_run_finished() -> void:
	runs_finished += 1
	_runs_since_interstitial += 1


func on_rewarded_shown(now: float) -> void:
	_rewarded_this_run = true
	_last_full_screen_ad = now


func on_interstitial_shown(now: float) -> void:
	_runs_since_interstitial = 0
	_last_full_screen_ad = now


func should_show_interstitial(now: float) -> bool:
	if _rewarded_this_run:
		return false
	if runs_finished <= FREE_RUNS:
		return false
	if _runs_since_interstitial < RUNS_BETWEEN:
		return false
	return now - _last_full_screen_ad >= MIN_INTERVAL


static func now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0


## Verifica delle regole, usata dalla prova automatica. Restituisce l'elenco degli errori (vuoto se va tutto bene).
static func self_check() -> PackedStringArray:
	var errors := PackedStringArray()
	var p := InterstitialPolicy.new()
	var t := 0.0
	for run in FREE_RUNS:
		p.on_run_started()
		t += 60.0
		p.on_run_finished()
		if p.should_show_interstitial(t):
			errors.append("mostrata durante le prime %d partite" % FREE_RUNS)

	p.on_run_started()
	t += 60.0
	p.on_run_finished()
	if not p.should_show_interstitial(t):
		errors.append("non mostrata dopo la partita %d" % (FREE_RUNS + 1))
	p.on_interstitial_shown(t)

	# subito dopo: serve aspettare RUNS_BETWEEN partite
	for run in RUNS_BETWEEN - 1:
		p.on_run_started()
		t += 60.0
		p.on_run_finished()
		if p.should_show_interstitial(t):
			errors.append("mostrata prima di %d partite dall'ultima" % RUNS_BETWEEN)

	# partite brevissime: le partite bastano, ma l'intervallo minimo no
	var q := InterstitialPolicy.new()
	for run in FREE_RUNS + 1:
		q.on_run_started()
		q.on_run_finished()
	q.on_interstitial_shown(1000.0)
	for run in RUNS_BETWEEN:
		q.on_run_started()
		q.on_run_finished()
	if q.should_show_interstitial(1000.0 + MIN_INTERVAL - 1.0):
		errors.append("intervallo minimo non rispettato")
	if not q.should_show_interstitial(1000.0 + MIN_INTERVAL):
		errors.append("non mostrata dopo l'intervallo minimo")

	# partita con la pubblicità a premio: niente schermo intero subito dopo
	q.on_run_started()
	q.on_rewarded_shown(5000.0)
	q.on_run_finished()
	if q.should_show_interstitial(9000.0):
		errors.append("mostrata dopo una pubblicità a premio")

	return errors
